#!/usr/bin/env bash
# End-to-end demo of the in-cluster Gitea (apps/infra/gitea) as an Argo CD
# git remote: create a repo, push manifests, watch Argo CD sync, then
# exercise update, prune and self-heal before cleaning up after itself.
#
# Deliberately imperative: everything it creates (repo content, Application,
# namespace) is ephemeral demo state, removed on exit. The platform itself
# stays declarative.
#
# Assumes: a running local/local-helm cluster with the gitea app synced,
# kubectl pointing at it, and git + curl on the PATH.

set -euo pipefail

gitea_ns=gitea
gitea_user=gitea_admin
gitea_pass='r8sA8CPHD9!bt6d' # chart default - local throwaway
port=${GITEA_DEMO_PORT:-3000}
repo=sync-lab
app=sync-lab
app_ns=sync-lab
workdir=$(mktemp -d)
clone_dir="$workdir/$repo"
pf_pid=""

log() { echo "==> $*"; }

cleanup() {
  log "Cleaning up (app, namespace, port-forward - the git repo is kept)"
  kubectl -n argocd delete app "$app" --ignore-not-found --timeout=90s
  kubectl delete ns "$app_ns" --ignore-not-found --timeout=60s
  [ -n "$pf_pid" ] && kill "$pf_pid" 2>/dev/null
  rm -rf "$workdir"
}
trap cleanup EXIT

require_gitea() {
  kubectl -n "$gitea_ns" get svc gitea-http >/dev/null 2>&1 ||
    { echo "gitea-http service not found - is the gitea app synced?" >&2; exit 1; }
}

start_port_forward() {
  kubectl -n "$gitea_ns" port-forward "svc/gitea-http" "$port:3000" >/dev/null 2>&1 &
  pf_pid=$!
  sleep 2
}

gitea_api() {
  local method=$1 path=$2 data=${3:-}
  curl -sf -u "$gitea_user:$gitea_pass" -X "$method" \
    -H 'Content-Type: application/json' ${data:+-d "$data"} \
    "http://localhost:$port/api/v1$path"
}

recreate_repo() {
  gitea_api DELETE "/repos/$gitea_user/$repo" >/dev/null 2>&1 || true
  gitea_api POST /user/repos \
    "{\"name\": \"$repo\", \"auto_init\": true, \"default_branch\": \"main\"}" >/dev/null
}

clone_repo() {
  git clone -q "http://$gitea_user:${gitea_pass//!/%21}@localhost:$port/$gitea_user/$repo.git" "$clone_dir"
  git -C "$clone_dir" config user.email "$gitea_user@local.domain"
  git -C "$clone_dir" config user.name "$gitea_user"
}

write_configmap() {
  local name=$1 value=$2
  cat >"$clone_dir/configmap-$name.yaml" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: $name
data:
  greeting: $value
EOF
}

push() {
  git -C "$clone_dir" add -A
  git -C "$clone_dir" commit -qm "$1"
  git -C "$clone_dir" push -q origin main
}

apply_application() {
  kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: http://gitea-http.$gitea_ns.svc.cluster.local:3000/$gitea_user/$repo.git
    targetRevision: main
    path: .
  destination:
    server: https://kubernetes.default.svc
    namespace: $app_ns
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
    automated:
      prune: true
      selfHeal: true
EOF
}

refresh_app() {
  kubectl -n argocd annotate app "$app" argocd.argoproj.io/refresh=normal --overwrite >/dev/null
}

wait_until() {
  local tries=$1; shift
  for _ in $(seq "$tries"); do
    "$@" && return 0
    sleep 3
  done
  echo "Timed out waiting for: $*" >&2
  return 1
}

app_synced() {
  kubectl -n argocd get app "$app" \
    -o jsonpath='{.status.sync.status}/{.status.health.status}' 2>/dev/null |
    grep -qx "Synced/Healthy"
}

greeting_is() {
  kubectl -n "$app_ns" get cm alpha -o jsonpath='{.data.greeting}' 2>/dev/null |
    grep -qx "$1"
}

beta_pruned() { ! kubectl -n "$app_ns" get cm beta >/dev/null 2>&1; }

main() {
  require_gitea
  start_port_forward
  recreate_repo
  clone_repo

  log "Phase 1: initial sync"
  write_configmap alpha hello-from-gitea
  write_configmap beta prune-candidate
  push "two configmaps"
  apply_application
  wait_until 40 app_synced
  wait_until 10 greeting_is hello-from-gitea
  log "alpha and beta synced into namespace $app_ns"

  log "Phase 2: update + prune"
  write_configmap alpha hello-from-gitea-v2
  git -C "$clone_dir" rm -q configmap-beta.yaml
  push "bump alpha, drop beta"
  refresh_app
  wait_until 40 greeting_is hello-from-gitea-v2
  wait_until 10 beta_pruned
  log "alpha updated, beta pruned"

  log "Phase 3: self-heal"
  kubectl -n "$app_ns" patch cm alpha -p '{"data":{"greeting":"manual-drift"}}' >/dev/null
  wait_until 40 greeting_is hello-from-gitea-v2
  log "manual drift reverted from git"

  log "Demo succeeded"
}

main
