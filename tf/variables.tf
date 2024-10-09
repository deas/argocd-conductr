variable "env" {
  type        = string
  description = "Environment"
  default     = null # "local"
}

variable "kind_cluster_name" {
  type        = string
  description = "Cluster name"
  default     = "argocd-conductr"
}

variable "kind_cluster_image" {
  type    = string
  default = "kindest/node:v1.31.0"
}

variable "kubeconfig_path" {
  type    = string
  default = null
}

variable "bootstrap_path" {
  type        = string
  default     = null
  description = "bootstrap path"
}

variable "cilium_helmrelease_path" {
  type    = string
  default = null # "../infrastructure/lib/config/cilium/release-cilium.yaml"
}

variable "additional_keys" {
  type    = map(any)
  default = {}
}

variable "metallb" {
  type    = bool
  default = true
}

variable "dns_hosts" {
  type    = map(string)
  default = null
}

variable "extra_mounts" {
  type    = list(map(string))
  default = []
}

