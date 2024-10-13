locals {
  kind_cluster_name = var.kind_cluster_name != null ? var.kind_cluster_name : null
  # TODO: Whoa! The ultimate mess. Can we do better?
  # [for app in [] : app if app.appName == "cilium"]
  cilium_spec = try(yamldecode(file(var.cilium_appset_path))["spec"]["generators"][0]["matrix"]["generators"][0]["list"]["elements"], null)
  # cilium_spec         = try(yamldecode(file(var.cilium_appset_path))["spec"], null)
  cilium_version      = try(local.cilium_spec["chart"]["spec"]["version"], null)
  cilium_release_name = try(local.cilium_spec["releaseName"], null)
  cilium_values = try(yamlencode(merge(
    local.cilium_spec["values"],
    {
      "hubble" = {
        "metrics" = { "serviceMonitor" = { "enabled" = false } },
        "relay"   = { "prometheus" = { "serviceMonitor" = { "enabled" = false } } }
      }
    }
  )), null)
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
  wait_for_ready = false # false likely needed for cilium bootstrap
  kind_config {
    kind                      = "Cluster"
    api_version               = "kind.x-k8s.io/v1alpha4"
    containerd_config_patches = var.containerd_config_patches
    node {
      role  = "control-plane"
      image = var.kind_cluster_image
      dynamic "extra_mounts" {
        for_each = var.extra_mounts
        content {
          container_path = extra_mounts.value["container_path"]
          host_path      = extra_mounts.value["host_path"]
        }
      }
    }

    networking {
      disable_default_cni = var.cilium_appset_path != null                       # do not install kindnet for cilium
      kube_proxy_mode     = var.cilium_appset_path != null ? "none" : "iptables" # do not run kube-proxy for cilium
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
  # source = "../../terraform-modules/argocd"
  count         = var.env != null ? 1 : 0
  source        = "github.com/deas/terraform-modules//argocd?ref=wip"
  namespace     = "argocd"
  chart_version = yamldecode(file("${path.module}/../envs/${var.env}/app-argo-cd.yaml")).spec.sources[0].targetRevision
  # TODO: Should probly support two values files.
  values = [
    file("${path.module}/../apps/infra/argo-cd/values.yaml"),
    file("${path.module}/../apps/infra/argo-cd/envs/${var.env}/values.yaml")
  ]
  bootstrap_path   = var.bootstrap_path
  cluster_manifest = templatefile("${path.module}/../envs/app-root.tmpl.yaml", { env = var.env })
  additional_keys  = var.additional_keys
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

# Bare minimum to get CNI up here (Won't work via flux)
resource "helm_release" "cilium" {
  count      = var.cilium_appset_path != null ? 1 : 0 # var.cilium_version != null ? 1 : 0
  name       = local.cilium_release_name
  repository = "https://helm.cilium.io"
  chart      = "cilium"
  version    = local.cilium_version # var.cilium_version
  namespace  = "kube-system"
  values     = [local.cilium_values]
  # file("../infrastructure/lib/config/cilium/values-cilium.yaml")]
  # values     = [file("cilium-values.yaml")]
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
