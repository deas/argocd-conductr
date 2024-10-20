variable "env" {
  type        = string
  description = "The environment key to use to kickoff the ArgoCD deployments."
  default     = null # "local"
}

variable "kind_cluster_name" {
  type        = string
  description = "Cluster name"
  default     = "argocd-conductr" # TODO: Use environment instead?
}

variable "kind_child_cluster_name" {
  type        = string
  description = "Child cluster name"
  default     = null # "argocd-conductr-child"
}
variable "broker_secret_get" {
  type        = list(string)
  description = "The command to execute to obtain the submariner broker secret"
  default     = []
}
variable "kind_cluster_image" {
  type        = string
  description = "The kind image to use"
  default     = "kindest/node:v1.31.0"
}

variable "kubeconfig_path" {
  type        = string
  description = "Path to a kubeconfig file of a cluster to use instead of creating a kind instance."
  default     = null
}

variable "bootstrap_path" {
  type        = string
  default     = null
  description = "Path to and additional boostrap manifest. Use this to inject decryption secrets."
}

variable "submariner_name" {
  type        = string
  default     = "submariner-operator"
  description = "Submariner ArgoCD application name where we create the Submariner linked its Broker"
}

variable "cilium_name" {
  type        = string
  description = "Cilium ArgoCD application name in case we are using ArgoCD managed Cilium"
  default     = "cilium"
}

variable "cilium_appset_path" {
  type        = string
  description = "Path to the ArgoCD ApplicationSet to look up the Cilium Application. This is how we choose if we want the Cilium CNI in kind"
  default     = null # "envs/local/appset-infra-helm.yaml"
}

variable "containerd_config_patches" {
  type        = list(string)
  description = "Containerd patches to apply to kind nodes"
  default     = []
}

variable "additional_keys" {
  type        = map(any)
  description = "Files to use to create secrets "
  default     = {}
}

variable "metallb" {
  type        = bool
  default     = true
  description = "If we want to use MetallLb on kind"
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

