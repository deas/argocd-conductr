locals {
  kind_cluster_name = var.kind_cluster_name != null ? var.kind_cluster_name : null
  version_env       = var.env != null ? var.env : "local"
  # TODO: Whoa! The ultimate mess. Can we do better?
  cilium_app     = try([for app in yamldecode(file(var.cilium_appset_path))["spec"]["generators"][0]["matrix"]["generators"][0]["list"]["elements"] : app if app.appName == var.cilium_name][0], null)
  cilium_version = try(local.cilium_app["targetRevision"], null)
  cilium_enabled = local.cilium_version != null
  cilium_values = try([
    file("../apps/infra/cilium/envs/${local.version_env}/values.yaml"),
    yamlencode({
      "hubble" = {
        "metrics" = {
          "dashboards"     = { "enabled" = false },
          "serviceMonitor" = { "enabled" = false }
        },
        "relay" = { "prometheus" = { "serviceMonitor" = { "enabled" = false } } }
      }
    })
  ], [])
  argocd_chart_version = try(yamldecode(file("${path.module}/../envs/${local.version_env}/app-argo-cd.yaml")).spec.sources[0].targetRevision, null)
  broker_secret_get = length(var.broker_secret_get) > 0 ? var.broker_secret_get : ["sh", "-c", format(<<EOT
"%s/tools/get-secret.sh"
EOT
  , abspath(path.module))]
  ocm_bootstrap_get = length(var.ocm_bootstrap_get) > 0 ? var.ocm_bootstrap_get : ["sh", "-c", format(<<EOT
"%s/tools/get-ocm-bs.sh"
EOT
  , abspath(path.module))]
}

resource "kind_cluster" "default" {
  name           = local.kind_cluster_name
  count          = var.kubeconfig_path == null ? 1 : 0
  wait_for_ready = !local.cilium_enabled
  kind_config {
    kind                      = "Cluster"
    api_version               = "kind.x-k8s.io/v1alpha4"
    containerd_config_patches = var.containerd_config_patches
    feature_gates             = {}
    node {
      role                   = "control-plane"
      labels                 = { "submariner.io/gateway" = true }
      image                  = var.kind_cluster_image
      kubeadm_config_patches = var.kubeadm_config_patches
      dynamic "extra_mounts" {
        for_each = var.extra_mounts
        content {
          container_path = extra_mounts.value["container_path"]
          host_path      = extra_mounts.value["host_path"]
        }
      }
    }
    runtime_config = {}
    networking {
      dns_search     = tolist([])
      pod_subnet     = var.pod_subnet
      service_subnet = var.service_subnet
      # By default, kind uses 10.244.0.0/16 pod subnet for IPv4 and fd00:10:244::/56 pod subnet for IPv6.
      disable_default_cni = local.cilium_enabled # do not install kindnet for cilium
      # kube_proxy_mode     = local.cilium_enabled ? "none" : "iptables"
      # "none"  breaks cilium installation these days
    }
  }
}

data "external" "broker_secret" {
  count      = var.export_submariner_broker_secret && var.argocd_install == "helm" ? 1 : 0
  program    = local.broker_secret_get
  depends_on = [module.argocd_helm]
  query = {
    resource  = "secret/submariner-k8s-broker-client-token"
    namespace = "submariner-k8s-broker"
    timeout   = "300"
  }
}

data "external" "ocm_bootstrap" {
  count      = var.export_ocm_bootstrap_secret ? 1 : 0
  program    = local.ocm_bootstrap_get
  depends_on = [module.argocd_helm]
  query = {
    context   = local.kind_cluster_name
    sa        = "cluster-bootstrap"
    namespace = "open-cluster-management"
    timeout   = "300"
    server    = "https://${var.kind_cluster_name}-control-plane:6443"
  }
}

# kubectl more robust then kubernetes resource with regards to "make quick-destroy" leaving the linked resource in place
resource "kubectl_manifest" "bootstrap_hub_kubeconfig" {
  count    = var.export_ocm_bootstrap_secret ? 1 : 0
  provider = kubectl.linked
  yaml_body = yamlencode({
    apiVersion = "v1"
    kind       = "Secret"
    metadata = {
      name      = "bootstrap-hub-kubeconfig"
      namespace = "open-cluster-management-agent"
    }
    data = {
      # https://ocm-hub-control-plane:6443"
      kubeconfig = base64encode(yamlencode({
        "clusters" = [
          {
            "cluster" = {
              "certificate-authority-data" = data.external.ocm_bootstrap[0].result["certificate-authority-data"]
              "server"                     = data.external.ocm_bootstrap[0].result["server"]
            }
            "name" = "hub"
          }
        ]

        "contexts" = [
          {
            "context" = {
              "cluster"   = "hub"
              "namespace" = "default"
              "user"      = "bootstrap"
            }
            "name" = "bootstrap"
          }
        ]
        "current-context" = "bootstrap"
        "preferences"     = {}
        "users" = [
          {
            "name" = "bootstrap"
            "user" = {
              "token" = data.external.ocm_bootstrap[0].result["token"]
            }
          }
        ]
      }))
    }
    type = "Opaque"
    }
  )
}

# TODO: We should probably replace this with our very own crs-approver deployment/helm_release
#resource "null_resource" "ocm_hub_approval" {
#  count      = 0 # var.export_ocm_bootstrap_secret ? 1 : 0
#  depends_on = [kubectl_manifest.bootstrap_hub_kubeconfig]
#  provisioner "local-exec" {
#    command = "${path.module}/tools/approve-ocm-csr.sh spoke 300"
#  }
#}

resource "helm_release" "linked_submariner" {
  count    = var.kubeconfig_linked != null ? 1 : 0
  provider = helm.linked
  # atomic           = true
  create_namespace = true
  name             = "submariner-operator"
  repository       = "../apps/infra"
  chart            = "submariner-operator"
  namespace        = "submariner-operator"
  upgrade_install  = true # "make quick-destroy" does not remove linked helm release
  values = [yamlencode(
    {
      "broker" = {
        "server"    = data.external.broker_secret[0].result["broker_server"]
        "token"     = data.external.broker_secret[0].result["token"]
        "namespace" = data.external.broker_secret[0].result["namespace"]
        "ca"        = data.external.broker_secret[0].result["ca.crt"]
        # "globalnet" = null
      }
      "postInstallJob" = {
        "enabled" = false
      }
      "submariner" = {
        "clusterId" = "linked"
        #"clusterCidr" = null
        #"serviceCidr" = null
        #"globalCidr" = null
        "natEnabled" = "false"
      }
      "ipsec" = {
        "psk" = "dummy"
      }
    }

  )] #var.values
  #set_sensitive = {
  #  name  = ""
  #  value = ""
  #}
}

module "kubeconfig" {
  source = "github.com/deas/terraform-modules//kubeconfig?ref=main"
  count  = var.kubeconfig_path != null ? 1 : 0
  # source     = "../../terraform-modules/kubeconfig"
  kubeconfig = file(var.kubeconfig_path)
}

# TODO: Could wrap this in a module providing default values
resource "helm_release" "olm" {
  count      = (var.bootstrap_olm || var.argocd_install == "olm") ? 1 : 0
  name       = "olm"
  repository = "oci://ghcr.io/cloudtooling/helm-charts"
  chart      = "olm"
  version    = "0.30.0"
  # namespace  = "olm"
  # values     = []
}

# Needed as a dep when we we bootstrap both : OLM and ArgoCD OLM. The latter module depends on the subscription
data "kubernetes_resource" "subscription_crd" {
  count       = (var.bootstrap_olm || var.argocd_install == "olm") ? 1 : 0
  api_version = "apiextensions.k8s.io/v1"
  kind        = "CustomResourceDefinition"

  metadata {
    name = "subscriptions.operators.coreos.com"
  }
  depends_on = [helm_release.olm[0]]
}

module "argocd_olm" {
  # source = "../../terraform-modules/argocd-olm"
  count           = var.argocd_install == "olm" ? 1 : 0
  source          = "github.com/deas/terraform-modules//argocd-olm?ref=main"
  namespace       = "argocd"
  argocd_instance = file("${path.module}/../apps/infra/argo-cd/envs/${var.env}/argocd-argocd.yaml")
  subscription = {
    yaml_body    = file("${path.module}/../apps/infra/argo-cd-operator/base/subscription-argo-cd-operator.yaml")
    crd_dep_hack = data.kubernetes_resource.subscription_crd[0].object.metadata.name
  }
  bootstrap_path   = var.bootstrap_path
  cluster_manifest = var.env != null ? templatefile("${path.module}/../envs/app-root.tmpl.yaml", { env = var.env }) : null
  additional_keys  = var.additional_keys
  # Beware of module level deps! Breads dynamic module internal bits (e.g. for_each) 
  # depends_on       = [helm_release.olm[0]]
  # local.bootstrap will be known only after apply
  # local.argocd_cluster will be known only after apply
}


module "argocd_helm" {
  # source = "../../terraform-modules/argocd"
  count         = var.argocd_install == "helm" ? 1 : 0
  source        = "github.com/deas/terraform-modules//argocd?ref=main"
  namespace     = "argocd"
  chart_version = local.argocd_chart_version
  values = [
    file("${path.module}/../apps/infra/argo-cd/values.yaml"),
    var.env != null ? file("${path.module}/../apps/infra/argo-cd/envs/${var.env}/values.yaml") : "",
    file("${path.module}/../apps/infra/argo-cd/bootstrap-override-values.yaml")
  ]
  bootstrap_path   = var.bootstrap_path
  cluster_manifest = var.env != null ? templatefile("${path.module}/../envs/app-root.tmpl.yaml", { env = var.env }) : null
  additional_keys  = var.additional_keys
  # Keep the flux bits around for reference - for the moment
  # local.additional_keys
  # tls_key = {
  #  private = file(var.id_rsa_fluxbot_ro_path)
  #  public  = file(var.id_rsa_fluxbot_ro_pub_path)
  #}
  #tls_key = {
  #  private = module.secrets.secret["id-rsa-fluxbot-ro"].secret_data
  #  public  = module.secrets.secret["id-rsa-fluxbot-ro-pub"].secret_data
  #}
  #providers = {
  #  kubernetes = kubernetes
  #  kubectl    = kubectl
  #  helm       = helm
  #}
}

# Be careful with this module. It will patch coredns configmap ;)
module "coredns" {
  # source = "../../terraform-modules/coredns"
  source = "github.com/deas/terraform-modules//coredns?ref=main"
  hosts  = var.dns_hosts
  count  = var.dns_hosts != null ? 1 : 0
  #providers = {
  #  kubectl = kubectl
  #}
}

# Bare minimum to get CNI up here (Won't work via argocd)
resource "helm_release" "cilium" {
  count      = local.cilium_enabled ? 1 : 0
  name       = var.cilium_name
  repository = try(local.cilium_app["repoURL"], null)
  chart      = "cilium"
  version    = local.cilium_version
  namespace  = "kube-system"
  values     = local.cilium_values
}


resource "helm_release" "metallb" {
  count      = var.metallb ? 1 : 0
  name       = "metallb"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "metallb"
  version    = "6.3.15"
  namespace  = "metallb-system"
  # values     = [] # local.cilium_values
}

# TODO: This module should depend on the helm_release and create the resources
module "metallb_config" {
  count  = var.metallb ? 1 : 0
  source = "github.com/deas/terraform-modules//kind-metallb?ref=main"
}

# The Following module should be replaced by the bitnami helm chart
module "metallb" {
  # source = "../../terraform-modules/metallb"
  count            = var.metallb ? 1 : 0
  source           = "github.com/deas/terraform-modules//metallb?ref=main"
  install_manifest = "" # data.http.metallb_native[0].response_body
  config_manifest  = module.metallb_config[0].manifest
  depends_on       = [helm_release.metallb]
}
