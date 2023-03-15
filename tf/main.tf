locals {
  kind_cluster_name = var.kind_cluster_name != null ? var.kind_cluster_name : null
}
module "olm" {
  source = "github.com/deas/terraform-modules//olm?ref=main"
  # source = "../../terraform-modules/olm"
  count = var.enable_olm ? 1 : 0
}

#data "http" "argocd_operator" {
#  url = "https://operatorhub.io/install/argocd-operator.yaml"
#}

# TODO: Remove me - helm should do
#data "http" "argocd" {
#  # kubectl create namespace argocd
#  url = "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
#}

# TODO: could not apply (policy/v1beta1, Kind=PodSecurityPolicy) - Gone since 1.25 - 0.13.3 operator too old
#data "http" "metallb_operator" {
#  url = "https://operatorhub.io/install/metallb-operator.yaml"
#}

#data "http" "metallb_native" {
#  url = "https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml"
#}

resource "kind_cluster" "default" {
  name           = local.kind_cluster_name
  count          = var.kubeconfig_path == null ? 1 : 0
  wait_for_ready = true # false likely needed for cilium bootstrap
  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"
      dynamic "extra_mounts" {
        for_each = var.extra_mounts
        content {
          container_path = extra_mounts.value["container_path"]
          host_path      = extra_mounts.value["host_path"]
        }
      }
    }
  }
}

module "kubeconfig" {
  source = "github.com/deas/terraform-modules//kubeconfig?ref=main"
  count  = var.kubeconfig_path != null ? 1 : 0
  # source     = "../../terraform-modules/kubeconfig"
  kubeconfig = file(var.kubeconfig_path)
}

// Keep the flux bits around for reference - for the moment
module "argocd" {
  source = "github.com/deas/terraform-modules//argocd?ref=main"
  # source = "../../terraform-modules/argocd"
  # version
  namespace            = "argocd"
  application_manifest = file("../apps/local/root/templates/argocd.yaml")
  bootstrap_path       = var.bootstrap_path
  cluster_manifest     = templatefile("${path.module}/../clusters/application-root.tmpl.yaml", { env = "local" })
  additional_keys      = var.additional_keys
  # local.additional_keys
  # tls_key = {
  #  private = file(var.id_rsa_fluxbot_ro_path)
  #  public  = file(var.id_rsa_fluxbot_ro_pub_path)
  #}
  #tls_key = {
  #  private = module.secrets.secret["id-rsa-fluxbot-ro"].secret_data
  #  public  = module.secrets.secret["id-rsa-fluxbot-ro-pub"].secret_data
  #}
  providers = {
    kubernetes = kubernetes
    kubectl    = kubectl
    helm       = helm
  }
}

# Be careful with this module. It will patch coredns configmap ;)
module "coredns" {
  # version
  # source          = "../../terraform-modules/coredns"
  source = "github.com/deas/terraform-modules//coredns?ref=main"
  hosts  = var.dns_hosts
  count  = var.dns_hosts != null ? 1 : 0
  providers = {
    kubectl = kubectl
  }
}

data "http" "metallb_native" {
  count = var.metallb ? 1 : 0
  url   = "https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml"
}

module "metallb_config" {
  count  = var.metallb ? 1 : 0
  source = "github.com/deas/terraform-modules//kind-metallb?ref=main"
}

module "metallb" {
  count  = var.metallb ? 1 : 0
  source = "github.com/deas/terraform-modules//metallb?ref=main"
  # source           = "../../terraform-modules/metallb"
  install_manifest = data.http.metallb_native[0].response_body
  config_manifest  = module.metallb_config[0].manifest
}
