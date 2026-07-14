#!/usr/bin/env bash
# Wire the workload cluster's Kargo controller shard (envs/workload/
# app-kargo-shard.yaml) to the hub's Kargo control plane: mint a long-lived
# token for the hub's kargo-controller ServiceAccount and store it as a
# kubeconfig secret on the workload cluster (docs/kargo-promotion.md).
#
# Reusing the hub controller's ServiceAccount means the per-Project secret
# RoleBindings that Kargo's management controller maintains apply to the
# shard as well - the shard reads git credentials from Project namespaces on
# the hub exactly like the hub's own controller does.
#
# No secret material is printed.
set -euo pipefail

hub_context=${HUB_CONTEXT:-kind-argocd-conductr-helm}
workload_context=${WORKLOAD_CONTEXT:-kind-argocd-conductr-workload}
# The container name resolves through docker's embedded DNS from inside the
# kind network and is in the API server cert SANs - immune to IP drift
# (unlike the container IP)
hub_server=https://argocd-conductr-helm-control-plane:6443

kubectl --context "$hub_context" -n kargo apply -f - <<'EOF' >/dev/null
apiVersion: v1
kind: Secret
metadata:
  name: kargo-controller-workload-shard
  namespace: kargo
  annotations:
    kubernetes.io/service-account.name: kargo-controller
type: kubernetes.io/service-account-token
EOF

# The token controller populates the secret asynchronously
token=""
for _ in $(seq 1 30); do
  token=$(kubectl --context "$hub_context" -n kargo get secret kargo-controller-workload-shard \
    -o jsonpath='{.data.token}' 2>/dev/null || true)
  [ -n "$token" ] && break
  sleep 1
done
[ -n "$token" ] || { echo "token secret never populated" >&2; exit 1; }
ca=$(kubectl --context "$hub_context" -n kargo get secret kargo-controller-workload-shard \
  -o jsonpath='{.data.ca\.crt}')

kubeconfig=$(mktemp)
trap 'rm -f "$kubeconfig"' EXIT
cat >"$kubeconfig" <<EOF
apiVersion: v1
kind: Config
clusters:
  - name: hub
    cluster:
      server: $hub_server
      certificate-authority-data: $ca
users:
  - name: kargo-controller
    user:
      token: $(echo "$token" | base64 -d)
contexts:
  - name: hub
    context:
      cluster: hub
      user: kargo-controller
current-context: hub
EOF

kubectl --context "$workload_context" create namespace kargo \
  --dry-run=client -o yaml | kubectl --context "$workload_context" apply -f - >/dev/null
# Key kubeconfig.yaml - the kargo chart mounts exactly that
kubectl --context "$workload_context" -n kargo create secret generic kargo-control-plane-kubeconfig \
  --from-file=kubeconfig.yaml="$kubeconfig" --dry-run=client -o yaml |
  kubectl --context "$workload_context" apply -f - >/dev/null
echo "wired: workload shard controller -> $hub_server"
