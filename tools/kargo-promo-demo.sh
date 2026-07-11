#!/usr/bin/env bash
# End-to-end demo of Kargo-based promotion for the orders app (rendered
# configs pattern, see assets/kargo/manifest-kargo.yaml and
# docs/kargo-promotion.md):
#
#   1. bump APP_VERSION in apps/apps/orders/base and push to wip
#   2. the Warehouse turns that commit into Freight
#   3. auto-promotion renders it into test (rendered/apps/orders/test on
#      stage/kargo) and Argo CD deploys orders-test
#   4. once the Freight is verified in test, we promote it to prod by
#      creating a Promotion resource - the "manual gate", done with kubectl
#
# Deliberately imperative: the version bump is a real commit on wip (that is
# what Freight is), everything else only creates Kargo Promotion resources.
#
# Assumes: a running local/local-helm cluster with kargo + the rendered-apps
# ApplicationSet synced, `make kargo-setup` applied (project, stages, git
# credentials), kubectl pointing at the cluster and push rights on the repo.

set -euo pipefail

project=kargo-default
repo_root=$(git rev-parse --show-toplevel)
deployment_yml=apps/apps/orders/base/deployment.yml
source_branch=wip
rendered_branch=stage/kargo

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
  kubectl -n "$project" get secret kargo-default-repo >/dev/null 2>&1 ||
    { echo "git credentials missing - run 'make kargo-setup' with GITHUB_USERNAME/GITHUB_PAT" >&2; exit 1; }
  kubectl -n argocd get appset rendered-apps >/dev/null 2>&1 ||
    { echo "rendered-apps ApplicationSet missing - is the env root app synced?" >&2; exit 1; }
}

# First-run bootstrap: a promotion's argocd-update step needs the
# orders-<stage> Application, but the ApplicationSet only generates it once
# rendered/apps/orders/<stage> exists on stage/kargo. Seed missing folders
# with a render of the current sources so the apps exist before promoting.
seed_rendered() {
  local tmp seeded=""
  tmp=$(mktemp -d)
  git clone --quiet --branch "$rendered_branch" --depth 1 \
    "$(git -C "$repo_root" remote get-url origin)" "$tmp"
  for stage in test prod; do
    if [ ! -d "$tmp/rendered/apps/orders/$stage" ]; then
      mkdir -p "$tmp/rendered/apps/orders/$stage"
      kustomize build "$repo_root/apps/apps/orders/envs/$stage" \
        > "$tmp/rendered/apps/orders/$stage/manifest.yaml"
      seeded="$seeded $stage"
    fi
  done
  if [ -n "$seeded" ]; then
    git -C "$tmp" add rendered
    git -C "$tmp" commit --quiet -m "chore: seed rendered stage folders ($seeded)"
    git -C "$tmp" push --quiet origin "$rendered_branch"
    log "Seeded rendered folders on $rendered_branch:$seeded"
  fi
  rm -rf "$tmp"
  # The appset git generator polls every ~3min
  for stage in test prod; do
    wait_for "Application orders-$stage generated" 30 15 \
      kubectl -n argocd get app "orders-$stage"
  done
}

bump_version() {
  cd "$repo_root"
  local current next
  current=$(sed -n '/name: APP_VERSION/{n;s/.*value: "\(.*\)"/\1/p}' "$deployment_yml")
  next=$((current + 1))
  sed -i "/name: APP_VERSION/{n;s/value: \"$current\"/value: \"$next\"/}" "$deployment_yml"
  git add "$deployment_yml"
  git commit --quiet -m "chore(orders): bump APP_VERSION to $next for kargo promo demo"
  git push --quiet origin "$source_branch"
  commit=$(git rev-parse HEAD)
  log "Pushed APP_VERSION=$next as $commit"
}

freight_for_commit() {
  kubectl -n "$project" get freight \
    -o jsonpath='{.items[?(@.commits[0].id=="'"$1"'")].metadata.name}' 2>/dev/null | grep .
}

promotion_phase() { # <stage> <freight>
  kubectl -n "$project" get promotions \
    -o jsonpath='{range .items[?(@.spec.freight=="'"$2"'")]}{.spec.stage}={.status.phase} {end}' 2>/dev/null |
    tr ' ' '\n' | grep -x "$1=Succeeded"
}

app_env_version() { # <namespace> <expected>
  kubectl -n "$1" get deploy simple-deployment \
    -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="APP_VERSION")].value}' 2>/dev/null |
    grep -x "$2"
}

freight_verified_in() { # <freight> <stage>
  kubectl -n "$project" get freight "$1" \
    -o jsonpath='{.status.verifiedIn}' 2>/dev/null | grep -q "\"$2\""
}

promote() { # <stage> <freight>
  # Unlike the kargo CLI/UI, directly-created Promotions must carry their
  # steps - the admission webhook only inflates task refs, it does not copy
  # the Stage's promotionTemplate
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
        name: promo-process
      as: promo-process
EOF
}

require
seed_rendered
bump_version

log "Refreshing Warehouse (default poll interval is several minutes)"
kubectl -n "$project" annotate warehouse orders \
  kargo.akuity.io/refresh="$(date +%s)" --overwrite >/dev/null

log "Waiting for Freight from $commit"
wait_for "Freight discovered" 30 10 freight_for_commit "$commit"
freight=$(freight_for_commit "$commit")
log "Freight: $freight"

next=$(sed -n '/name: APP_VERSION/{n;s/.*value: "\(.*\)"/\1/p}' "$deployment_yml")

log "Waiting for auto-promotion into test"
wait_for "Promotion test/$freight Succeeded" 60 10 promotion_phase test "$freight"
wait_for "orders-test runs APP_VERSION=$next" 30 10 app_env_version orders-test "$next"

log "Waiting for Freight verification in test (stage healthy)"
wait_for "Freight verified in test" 30 10 freight_verified_in "$freight" test

log "Promoting to prod (the manual gate - a human creating a Promotion)"
promote prod "$freight"
wait_for "Promotion prod/$freight Succeeded" 60 10 promotion_phase prod "$freight"
wait_for "orders-prod runs APP_VERSION=$next" 30 10 app_env_version orders-prod "$next"

log "Done: APP_VERSION=$next promoted wip -> test -> prod"
kubectl -n "$project" get freight,stages,promotions
