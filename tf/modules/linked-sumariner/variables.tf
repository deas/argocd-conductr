variable "install" {
  type        = bool
  default     = true
  description = "Install (or patch)"
}

variable "chart_version" {
  type        = string
  default     = "0.18.1"
  description = "Version of the Operator"
}
variable "name" {
  type        = string
  default     = "submariner-operator"
  description = "Submariner application name where we create the Submariner linked its Broker"
}

variable "namespace" {
  type        = string
  default     = "submariner-operator"
  description = "The namespace holding the Submariner"
}

variable "broker" {
  type = object({
    k8s_apiserver = string
    k8s_ca        = string
    token         = string
    namespace     = string
  })

  # apps/infra/submariner-operator
  # https://submariner-io.github.io/submariner-charts/charts
  #
  ## broker: "${BROKER}"
  # brokerK8sApiServer: "${SUBMARINER_BROKER_URL}"
  # brokerK8sApiServerToken: "${SUBMARINER_BROKER_TOKEN}"
  # brokerK8sCA: "${SUBMARINER_BROKER_CA}"
  # brokerK8sRemoteNamespace: "${BROKER_NS}"
  # brokerK8sSecret: submariner-broker-secret
}
variable "values" {
  type        = list(string)
  default     = []
  description = "Helm values to use"

}
variable "repository" {
  type        = string
  default     = "https://submariner-io.github.io/submariner-charts/charts"
  description = "Submariner helm repository to use"
}

