variable "env" {
  type        = string
  description = "The environment key to use to kickoff the ArgoCD deployments."
  default     = "local"
}


variable "argocd_install" {
  description = "If/How to install ArgoCD"
  type        = string

  validation {
    condition     = contains(["helm", "olm"], var.argocd_install)
    error_message = "The argocd_install must be one of 'helm' or 'olm'."
  }
  default  = "helm"
  nullable = true
}

variable "kind_cluster_name" {
  type        = string
  description = "Cluster name"
  default     = "argocd-conductr" # TODO: Use environment instead?
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

variable "kubeconfig_linked" {
  type = object({
    path    = string
    context = string
  })
  nullable = true
  default  = null
  #type = string
  description = "kubeconfig file and context for a cluster linked to this one."
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

#variable "submariner_name" {
#  type        = string
#  default     = "submariner-operator"
#  description = "Submariner ArgoCD application name where we create the Submariner linked its Broker"
#}

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
  default     = true # TODO argocd helm release readyness depends on service (currently type LB) being ready
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

