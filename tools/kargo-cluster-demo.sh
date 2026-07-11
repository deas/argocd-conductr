#!/usr/bin/env bash
# End-to-end demo of whole-env promotion between clusters (pipeline 2 in
# assets/kargo/manifest-kargo.yaml, see docs/kargo-promotion.md):
#
#   1. bump APP_VERSION in apps/apps/orders/base and push to wip
#   2. the `cluster` Warehouse turns that commit into Freight (any apps/**
#      change qualifies - the whole env is the unit of promotion)
#   3. auto-promotion copies the apps/ tree to stage/cluster-test and the
#      hub's workload apps sync to it
#   4. once the Freight is verified in cluster-test, we promote it to
#      cluster-prod - the spoke cluster - by creating a Promotion with kubectl
#
# The same bump also feeds the per-app orders pipeline (both warehouses watch
# wip) - that is expected; the pipelines are independent.
#
# Assumes: hub cluster with kargo + gated appsets synced, spoke cluster
# provisioned (tf/spoke.tfvars) and registered as an Argo CD cluster secret
# labeled kargo-stage: cluster-prod, `make kargo-setup` applied, kubectl
# pointing at the hub and push rights on the repo.

set -euo pipefail

project=kargo-default
warehouse=cluster
repo_root=$(git rev-parse --show-toplevel)
deployment_yml=apps/apps/orders/base/deployment.yml
source_branch=wip
spoke_context=kind-argocd-conductr-spoke

log() { echo "==> $*"; }

# wait_for <description> <attempts> <sleep_s> <command...>
wait_for() {
  local desc=$1 attempts=$2 pause=$3; shift 3
  for _ in $(seq 1 "$attempts"); do
    if "$@" >/dev/null 2>&1; then log "$desc: OK"; return 0; fi
    sleep "$pause"
  done
  echo "Timed out waiting for: $desc" >&2
  return 1
}

require() {
  kubectl get ns "$project" >/dev/null 2>&1 ||
    { echo "project namespace '$project' missing - run 'make kargo-setup'" >&2; exit 1; }
  kubectl -n "$project" get warehouse "$warehouse" >/dev/null 2>&1 ||
    { echo "warehouse '$warehouse' missing - run 'make kargo-setup'" >&2; exit 1; }
  kubectl -n argocd get app orders-spoke ingress-nginx-spoke >/dev/null 2>&1 ||
    { echo "spoke apps missing - is the spoke cluster registered (kargo-stage: cluster-prod)?" >&2; exit 1; }
  kubectl --context "$spoke_context" get nodes >/dev/null 2>&1 ||
    { echo "cannot reach spoke cluster context $spoke_context" >&2; exit 1; }
}

bump_version() {
  cd "$repo_root"
  local current next
  current=$(sed -n '/name: APP_VERSION/{n;s/.*value: "\(.*\)"/\1/p}' "$deployment_yml")
  next=$((current + 1))
  sed -i "/name: APP_VERSION/{n;s/value: \"$current\"/value: \"$next\"/}" "$deployment_yml"
  git add "$deployment_yml"
  git commit --quiet -m "chore(orders): bump APP_VERSION to $next for kargo cluster demo"
  git push --quiet origin "$source_branch"
  commit=$(git rev-parse HEAD)
  log "Pushed APP_VERSION=$next as $commit"
}

# Both warehouses watch wip, so a commit can yield two Freight - filter by
# origin
freight_for_commit() { # <commit>
  kubectl -n "$project" get freight \
    -o jsonpath='{range .items[?(@.origin.name=="'"$warehouse"'")]}{.metadata.name}={.commits[0].id} {end}' 2>/dev/null |
    tr ' ' '\n' | sed -n "s/=$1\$//p" | grep .
}

promotion_phase() { # <stage> <freight>
  kubectl -n "$project" get promotions \
    -o jsonpath='{range .items[?(@.spec.freight=="'"$2"'")]}{.spec.stage}={.status.phase} {end}' 2>/dev/null |
    tr ' ' '\n' | grep -x "$1=Succeeded"
}

freight_verified_in() { # <freight> <stage>
  kubectl -n "$project" get freight "$1" \
    -o jsonpath='{.status.verifiedIn}' 2>/dev/null | grep -q "\"$2\""
}

spoke_orders_version() { # <expected>
  kubectl --context "$spoke_context" -n orders get deploy simple-deployment \
    -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="APP_VERSION")].value}' 2>/dev/null |
    grep -x "$1"
}

promote() { # <stage> <freight> <task>
  # Directly-created Promotions must carry their steps - the admission
  # webhook only inflates task refs, it does not copy the Stage's
  # promotionTemplate
  kubectl create -f - <<EOF
apiVersion: kargo.akuity.io/v1alpha1
kind: Promotion
metadata:
  generateName: $1-
  namespace: $project
spec:
  stage: $1
  freight: $2
  steps:
    - task:
        name: $3
      as: promote
EOF
}

require
bump_version

log "Refreshing Warehouse (default poll interval is several minutes)"
kubectl -n "$project" annotate warehouse "$warehouse" \
  kargo.akuity.io/refresh="$(date +%s)" --overwrite >/dev/null

log "Waiting for Freight from $commit"
wait_for "Freight discovered" 30 10 freight_for_commit "$commit"
freight=$(freight_for_commit "$commit")
log "Freight: $freight"

next=$(sed -n '/name: APP_VERSION/{n;s/.*value: "\(.*\)"/\1/p}' "$deployment_yml")

log "Waiting for auto-promotion into cluster-test (hub)"
wait_for "Promotion cluster-test/$freight Succeeded" 60 10 promotion_phase cluster-test "$freight"

log "Waiting for Freight verification in cluster-test (hub gate apps healthy)"
wait_for "Freight verified in cluster-test" 30 10 freight_verified_in "$freight" cluster-test

log "Promoting to cluster-prod (the manual gate - a human creating a Promotion)"
promote cluster-prod "$freight" promote-cluster-prod
wait_for "Promotion cluster-prod/$freight Succeeded" 60 10 promotion_phase cluster-prod "$freight"
wait_for "spoke orders runs APP_VERSION=$next" 30 10 spoke_orders_version "$next"

log "Done: APP_VERSION=$next promoted wip -> cluster-test (hub) -> cluster-prod (spoke)"
kubectl -n "$project" get freight,stages,promotions
