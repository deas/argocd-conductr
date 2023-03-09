# https://github.com/hashicorp/terraform/issues/28580#issuecomment-831263879
terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "0.0.16"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.2"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.7.1"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.10.0"
    }
  }
}

provider "helm" {
  kubernetes {
    # config_path = kind_cluster.default.kubeconfig
    host                   = kind_cluster.default.endpoint
    client_certificate     = kind_cluster.default.client_certificate
    client_key             = kind_cluster.default.client_key
    cluster_ca_certificate = kind_cluster.default.cluster_ca_certificate
  }
}

provider "kind" {
}

provider "kubernetes" {
  # config_path = kind_cluster.default.kubeconfig
  # config_context = "kind-argocd"
  host                   = kind_cluster.default.endpoint
  client_certificate     = kind_cluster.default.client_certificate
  client_key             = kind_cluster.default.client_key
  cluster_ca_certificate = kind_cluster.default.cluster_ca_certificate
}

provider "kubectl" {
  host                   = kind_cluster.default.endpoint
  client_certificate     = kind_cluster.default.client_certificate
  client_key             = kind_cluster.default.client_key
  cluster_ca_certificate = kind_cluster.default.cluster_ca_certificate
  # token                  = data.aws_eks_cluster_auth.main.token
  load_config_file = false
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
  name           = var.kind_cluster_name
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

# TODO: We should probably create the namespace within the module to align with the flux module
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

// Keep the flux bits around for reference - for the moment
module "argocd" {
  source = "github.com/deas/terraform-modules//argocd?ref=main"
  # source               = "../../terraform-modules/argocd"
  # version
  namespace            = kubernetes_namespace.argocd.metadata[0].name
  application_manifest = file("../apps/root/templates/argocd.yaml")
  bootstrap_manifest   = file("${path.module}/../clusters/applicationset-cluster.yaml")
  additional_keys      = var.additional_keys
  # local.additional_keys
  # target_path = var.target_path
  # branch          = var.flux_branch
  # flux_install = file("${var.filename_flux_path}/gotk-components.yaml")
  # flux_sync    = file("${var.filename_flux_path}/gotk-sync.yaml")
  # tls_key = {
  #  private = file(var.id_rsa_fluxbot_ro_path)
  #  public  = file(var.id_rsa_fluxbot_ro_pub_path)
  #}
  #tls_key = {
  #  private = module.secrets.secret["id-rsa-fluxbot-ro"].secret_data
  #  public  = module.secrets.secret["id-rsa-fluxbot-ro-pub"].secret_data
  #}
  #additional_keys = {
  #  sops-gpg = {
  #    "sops.asc" = module.secrets.secret["sops-gpg"].secret_data
  #  }
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



/*
module "secrets" {
  source = "../../../google-secrets"
  gcp_credentials = var.gcp_secrets_credentials
  project_id      = var.gcp_secrets_project_id
  secrets         = var.flux_secrets
}
*/

# Ugly git submodule workaround
#module "flux-manifests" {
#  source = "git::https://github.com/.../foo-deployment.git//clusters/test/flux-system"
#}

resource "kubectl_manifest" "bootstrap" {
  for_each   = { for v in local.bootstrap : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content }
  depends_on = [kubernetes_namespace.argocd]
  yaml_body  = each.value
}


locals {
  # https://github.blog/changelog/2022-01-18-githubs-ssh-host-keys-are-now-published-in-the-api/
  # known_hosts = "github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg="
  bootstrap = try([for v in data.kubectl_file_documents.bootstrap[0].documents : {
    data : yamldecode(v)
    content : v
    }
  ], {})
}

# TODO: Should be replaced by kubectl (which uses apply and we need anyways )
/*
resource "kubernetes_namespace" "flux_system" {
  metadata {
    name = "flux-system"
  }

  lifecycle {
    ignore_changes = [
      metadata[0].labels,
    ]
  }
}
*/

data "kubectl_file_documents" "bootstrap" {
  count   = var.bootstrap_path != null ? 1 : 0
  content = file(var.bootstrap_path)
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

variable "dns_hosts" {
  type    = map(string)
  default = null
}


variable "extra_mounts" {
  type    = list(map(string))
  default = []
}
