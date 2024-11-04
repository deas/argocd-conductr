# https://github.com/hashicorp/terraform/issues/28580#issuecomment-831263879
terraform {
  required_version = ">= 1.2"

  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = ">= 0.0.16"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.2"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.7.1"
    }
    external = {
      source  = "hashicorp/external"
      version = ">= 2.3.0"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.2.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.10.0"
    }
    # kustomization = { # TODO: Should probably replace kubectl and kubernetes
    # source  = "kbst/kustomization"
    # version = ">= 0.9.6"
    # }
  }
}

