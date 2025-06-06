#locals {
#  kind_cluster_name = var.kind_cluster_name != null ? var.kind_cluster_name : null
#}

module "main" {
  source                          = "../.."
  metallb                         = false
  export_submariner_broker_secret = false
  env                             = var.env
  argocd_install                  = "olm"
  kind_cluster_name               = "argocd-conductr-${var.env}"
  bootstrap_olm                   = var.bootstrap_olm
  pod_subnet                      = var.pod_subnet
  service_subnet                  = var.service_subnet
  containerd_config_patches       = var.containerd_config_patches
  # TODO: bootstrap root relies on ../apps - need to spin up cluster to validate changes
  bootstrap_path = var.bootstrap_path
  dns_hosts      = var.dns_hosts
  extra_mounts   = var.extra_mounts
}
