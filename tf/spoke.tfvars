# prod-stage spoke cluster: kind + cilium only - no Argo CD, no OLM. Managed
# by the hub cluster's Argo CD (envs/kind-helm/appset-cluster-prod.yaml) and
# promoted into via Kargo (docs/kargo-promotion.md). Use with:
#   tofu workspace select -or-create spoke
#   tofu apply -var-file=spoke.tfvars
env      = "spoke"
argo_env = "kind-helm" # reuse the hub cluster class's cilium bootstrap values

argocd_install = null
bootstrap_olm  = false
bootstrap_path = []

cilium_appset_path = "../envs/kind-helm/appset-infra-helm.yaml"
kind_cluster_name  = "argocd-conductr-spoke"

# No host ports needed - overrides the default-workspace ArgoCD mapping
extra_port_mappings = []
