#locals {
#  kind_cluster_name = var.kind_cluster_name != null ? var.kind_cluster_name : null
#}

module "spoke" {
  source                          = "../.."
  metallb                         = false
  export_submariner_broker_secret = false
  env                             = var.env
  argocd_install                  = "helm"
  kind_cluster_name               = var.kind_cluster_name
  bootstrap_olm                   = var.bootstrap_olm
  pod_subnet                      = var.pod_subnet
  service_subnet                  = var.service_subnet
  containerd_config_patches       = var.containerd_config_patches
  bootstrap_path                  = var.bootstrap_path
  dns_hosts                       = var.dns_hosts
  extra_mounts                    = var.extra_mounts
}
