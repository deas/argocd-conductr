variable "env" {
  type        = string
  description = "The environment key to use to kickoff the ArgoCD deployments."
  default     = null
}

variable "pod_subnet" {
  type    = string
  default = "10.244.0.0/16"
}

variable "service_subnet" {
  type    = string
  default = "10.96.0.0/12"
}

variable "kind_cluster_name" {
  type        = string
  description = "Cluster name"
  default     = "argocd-conductr-spoke" # TODO: Use environment instead?
}

# localhost (default) env deploys cluster-manager by default
variable "bootstrap_olm" {
  type        = bool
  default     = true
  description = "Should the cluster have OLM before ArgoCD? (Openshift like)"
}

variable "bootstrap_path" {
  type        = string
  default     = null
  description = "Path to and additional boostrap manifest. Use this to inject decryption secrets."
}

variable "containerd_config_patches" {
  type        = list(string)
  description = "Containerd patches to apply to kind nodes"
  default     = []
}

variable "dns_hosts" {
  type        = map(string)
  description = "Additional Core DNS Entries we want in kind"
  default     = null
}

variable "extra_mounts" {
  type        = list(map(string))
  description = "Extra mount points we want in kind nodes"
  default     = []
}
