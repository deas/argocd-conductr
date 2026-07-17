#!/usr/bin/env bash
# vind (vCluster in Docker) bring-up / tear-down for the helm-flavor default
# cluster - a KinD alternative that runs a "vcluster standalone" Kubernetes
# straight in Docker (no host cluster needed). See docs/vind.md.
#
#   up         create the vind cluster, export its kubeconfig to
#              tf/<name>-config, then reconcile the helm-flavor Argo CD stack
#              onto it via the OpenTofu module in external-cluster mode
#              (kubeconfig_path => kind_cluster count=0, providers use KUBECONFIG)
#   kubeconfig (re)export the vind kubeconfig to tf/<name>-config and print its path
#   down       remove the tofu-tracked resources from state, delete the vind
#              cluster, drop the exported kubeconfig
#
# The vcluster API is published on a stable host port by the docker driver, so
# the exported kubeconfig (insecure-skip-tls-verify, no background proxy) stays
# valid for tofu/helm/kubectl on this host for the life of the cluster.
set -euo pipefail

name=${VIND_NAME:-argocd-conductr-vind}
workspace=${VIND_WORKSPACE:-vind}
tfvars=${VIND_TFVARS:-vind-helm.tfvars}
k8s_version=${VIND_K8S_VERSION:-} # e.g. v1.31.0; empty => vind default

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
kubeconfig="${repo_root}/tf/${name}-config"

driver=(--driver docker)

export_kubeconfig() {
  vcluster connect "$name" "${driver[@]}" --print --background-proxy=false >"$kubeconfig"
}

case "${1:-up}" in
up)
  create=(vcluster create "$name" "${driver[@]}" --connect=false --upgrade)
  [ -n "$k8s_version" ] && create+=(--set "controlPlane.distro.k8s.version=${k8s_version}")
  "${create[@]}"
  export_kubeconfig
  echo "vind kubeconfig -> $kubeconfig"
  cd "${repo_root}/tf"
  tofu workspace select -or-create "$workspace"
  # External-cluster mode: single-pass apply (kind_cluster is count=0, so the
  # two-pass '-target=kind_cluster.default' dance in tf/Makefile is a no-op).
  # With host attrs null the providers fall back to env vars - and they each read
  # a *different* one (see the TODO in tf/providers.tf): the kubernetes and helm
  # providers read KUBE_CONFIG_PATH, the kubectl provider reads KUBECONFIG. Export
  # both so all three reach the vind cluster instead of localhost.
  KUBECONFIG="$kubeconfig" KUBE_CONFIG_PATH="$kubeconfig" \
    tofu apply -var-file="$tfvars" -auto-approve
  ;;
kubeconfig)
  export_kubeconfig
  echo "$kubeconfig"
  ;;
down)
  if (cd "${repo_root}/tf" && tofu workspace select "$workspace" 2>/dev/null); then
    (cd "${repo_root}/tf" && tofu state list | cut -f1 -d'[' | sort -u | xargs -r tofu state rm) || true
  fi
  vcluster delete "$name" "${driver[@]}" || true
  rm -f "$kubeconfig"
  ;;
*)
  echo "usage: $0 {up|kubeconfig|down}" >&2
  exit 1
  ;;
esac
