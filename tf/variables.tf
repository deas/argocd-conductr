variable "kind_cluster_name" {
  type        = string
  description = "Cluster name"
  default     = "argocd-conductr"
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

variable "enable_olm" {
  type    = bool
  default = false
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

