locals {
  host                   = var.kubeconfig_path == null ? kind_cluster.default[0].endpoint : module.kubeconfig[0].host
  client_certificate     = var.kubeconfig_path == null ? kind_cluster.default[0].client_certificate : module.kubeconfig[0].client_certificate
  client_key             = var.kubeconfig_path == null ? kind_cluster.default[0].client_key : module.kubeconfig[0].client_key
  cluster_ca_certificate = var.kubeconfig_path == null ? kind_cluster.default[0].cluster_ca_certificate : module.kubeconfig[0].cluster_ca_certificate
  #kubeconfig             = try(kind_cluster.default[0].kubeconfig, null)
  #load_config_file       = try(kind_cluster.default[0].endpoint, null) != null ? false : true
}

# TODO: Awesome! three providers, three different env variables for the same thing
provider "kubernetes" {
  # KUBE_CONFIG_PATH env
  # config_path = kind_cluster.default.kubeconfig
  # config_context = "kind-flux"
  # config_path            = null
  host                   = local.host
  client_certificate     = local.client_certificate
  client_key             = local.client_key
  cluster_ca_certificate = local.cluster_ca_certificate
}

provider "kubectl" {
  # KUBE_CONFIG_PATH or KUBECONFIG
  # token                  = data.aws_eks_cluster_auth.main.token
  host                   = local.host
  client_certificate     = local.client_certificate
  client_key             = local.client_key
  cluster_ca_certificate = local.cluster_ca_certificate
  load_config_file       = false
}

#provider "kustomization" {
#  # KUBECONFIG_PATH
#  # kubeconfig_path = 
#  kubeconfig_raw = local.kubeconfig
#}

# TODO Catchup with ka0s
provider "helm" {
  kubernetes {
    # config_path = kind_cluster.default.kubeconfig
    host                   = local.host
    client_certificate     = local.client_certificate
    client_key             = local.client_key
    cluster_ca_certificate = local.cluster_ca_certificate
  }
}

provider "kind" {
}