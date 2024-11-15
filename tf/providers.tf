locals {
  host                   = try(kind_cluster.default[0].endpoint, null)
  client_certificate     = try(kind_cluster.default[0].client_certificate, null)
  client_key             = try(kind_cluster.default[0].client_key, null)
  cluster_ca_certificate = try(kind_cluster.default[0].cluster_ca_certificate, null)
  # kubeconfig             = try(kind_cluster.default[0].kubeconfig, null)
  load_config_file = try(kind_cluster.default[0].endpoint, null) != null ? false : true

}
# TODO: Awesome! three providers, three different env variables for the same thing
#provider "kind" {
#}

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

provider "kubernetes" {
  alias          = "linked"
  config_path    = var.kubeconfig_linked != null ? var.kubeconfig_linked.path : null
  config_context = var.kubeconfig_linked != null ? var.kubeconfig_linked.context : null
}

provider "kubectl" {
  # KUBE_CONFIG_PATH or KUBECONFIG
  # token                  = data.aws_eks_cluster_auth.main.token
  host                   = local.host
  client_certificate     = local.client_certificate
  client_key             = local.client_key
  cluster_ca_certificate = local.cluster_ca_certificate
  load_config_file       = local.load_config_file
}

provider "helm" {
  kubernetes {
    # config_path = kind_cluster.default.kubeconfig
    host                   = local.host
    client_certificate     = local.client_certificate
    client_key             = local.client_key
    cluster_ca_certificate = local.cluster_ca_certificate
  }
}

provider "helm" {
  alias = "linked"
  kubernetes {
    config_path    = var.kubeconfig_linked != null ? var.kubeconfig_linked.path : null
    config_context = var.kubeconfig_linked != null ? var.kubeconfig_linked.context : null
  }
}
#provider "kustomization" {
#  # KUBECONFIG_PATH
#  # kubeconfig_path = 
#  kubeconfig_raw = local.kubeconfig
#}

