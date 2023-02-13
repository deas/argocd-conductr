# https://github.com/hashicorp/terraform/issues/28580#issuecomment-831263879
terraform {
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "0.0.16"
    }
    /*
    github = {
      source  = "integrations/github"
      version = ">= 4.5.2"
    }*/
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
    /*
    tls = {
      source  = "hashicorp/tls"
      version = "3.1.0"
    }*/
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
  source = "github.com/deas/terraform-modules//olm"
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

data "http" "metallb_native" {
  url = "https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml"
}

resource "kind_cluster" "default" {
  name           = var.kind_cluster_name
  wait_for_ready = true # false likely needed for cilium bootstrap
  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"
    }

    # Cilium
    #networking {
    #  disable_default_cni = true   # do not install kindnet
    #  kube_proxy_mode     = "none" # do not run kube-proxy
    #}

    #node {
    #  role = "worker"
    #  image = "kindest/node:v1.19.1"
    #}
    # Guess this will work as the creation changes to context?
  }
  // TODO: Should be covered by wait_for_ready?
  /*
  provisioner "local-exec" {
    command = "kubectl -n kube-system wait --timeout=180s --for=condition=ready pod -l tier=control-plane"
  }
  */
}

/*
resource "helm_release" "cilium" {
  name = "cilium"

  repository = "https://helm.cilium.io"
  chart      = "cilium"
  version    = "1.12.3"
  namespace  = "kube-system"
  values     = [file("cilium-values.yaml")]
}
*/

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

// Keep the flux bits around for reference - for the moment
module "argocd" {
  source = "github.com/deas/terraform-modules//argocd"
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
  metallb_native = [for v in data.kubectl_file_documents.metallb_native.documents : {
    data : yamldecode(v)
    content : v
    }
  ]
  metallb_config = [for v in data.kubectl_file_documents.metallb_config.documents : {
    data : yamldecode(v)
    content : v
    }
  ]
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

# TODO: metallb should probably be kicked off via argocd as well
data "kubectl_file_documents" "metallb_native" {
  content = data.http.metallb_native.response_body
}

data "kubectl_file_documents" "metallb_config" {
  content = file("${path.module}/../apps/metallb/manifest-config.yaml")
}

resource "kubectl_manifest" "metallb_native" {
  for_each  = { for v in local.metallb_native : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content }
  yaml_body = each.value
}

resource "null_resource" "metallb_wait" {
  depends_on = [kubectl_manifest.metallb_native]
  provisioner "local-exec" {
    command = "kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=90s"
  }
}

resource "kubectl_manifest" "metallb_config" {
  for_each   = { for v in local.metallb_config : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content }
  yaml_body  = each.value
  depends_on = [null_resource.metallb_wait]
}