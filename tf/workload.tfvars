# Workload cluster (CAPI vocabulary: no cluster-management control plane of
# its own) running the pull model: kind + cilium + its OWN Argo CD, which
# pulls the promoted stage/cluster-prod branch (root app -> envs/workload).
# A Kargo controller shard on this cluster connects back to the hub's Kargo
# control plane (tools/kargo-shard-kubeconfig.sh); which stage the cluster
# plays comes from Stage.spec.shard, not from its identity.
# See docs/kargo-promotion.md. Use with:
#   tofu workspace select -or-create workload
#   tofu apply -var-file=workload.tfvars
env      = "workload" # root app path envs/workload
argo_env = "kind-helm" # reuse the hub cluster class's cilium + argo-cd values

argocd_install = "helm"
bootstrap_olm  = false
bootstrap_path = []

cilium_appset_path = "../envs/kind-helm/appset-infra-helm.yaml"
kind_cluster_name  = "argocd-conductr-workload"

# No host ports needed - overrides the default-workspace ArgoCD mapping
extra_port_mappings = []
