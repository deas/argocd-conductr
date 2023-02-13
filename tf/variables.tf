#variable "github_token" {
#  type        = string
#  description = "github token"
#}

variable "kind_cluster_name" {
  type        = string
  description = "Cluster name"
  default     = "argocd-conductr"
}

variable "bootstrap_path" {
  type        = string
  default     = null
  description = "bootstrap path"
}

/*
variable "argocd_version" {
  type    = string
  default = "5.19.15"
}

*/

variable "enable_olm" {
  type    = bool
  default = false
}

/*
variable "github_init" {
  type        = bool
  default     = false
  description = "Initialize github files"
}
*/

variable "additional_keys" {
  type    = map(any)
  default = {}
}

/*
variable "gcp_secrets_credentials" {
  type = string
}

variable "gcp_secrets_project_id" {
  type = string
}

variable "flux_secrets" {
  type = set(string)
}
*/
/*
variable "cluster" {
  type = string
}
*/