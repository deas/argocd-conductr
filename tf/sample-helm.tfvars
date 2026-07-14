# olm-less test flavor - this is the default. Just run:
#   make apply
# (the Makefile defaults TFVARS to this file, on the default workspace).
# terraform.tfvars is auto-loaded first (proxies, audit, bootstrap_path);
# values here override it.
env                = "kind-helm"
argo_env           = "kind-helm"
argocd_install     = "helm"
bootstrap_olm      = false
cilium_appset_path = "../envs/kind-helm/appset-infra-helm.yaml"
kind_cluster_name  = "argocd-conductr-helm"

# Host port shifted - 11080 is taken by the default-workspace cluster
extra_port_mappings = [
  {
    container_port = 31080
    host_port      = 11081 # ArgoCD Server
  }
]
