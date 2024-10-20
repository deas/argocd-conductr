variable "submariner_name" {
  type        = string
  default     = "submariner-operator"
  description = "Submariner application name where we create the Submariner linked its Broker"
}

variable "namespace" {
  type = string
}

variable "broker" {
  type = object({
    k8s_apiserver = string
    k8s_ca        = string
    token         = string
    namespace     = string
  })
  # broker: "${BROKER}"
  # brokerK8sApiServer: "${SUBMARINER_BROKER_URL}"
  # brokerK8sApiServerToken: "${SUBMARINER_BROKER_TOKEN}"
  # brokerK8sCA: "${SUBMARINER_BROKER_CA}"
  # brokerK8sRemoteNamespace: "${BROKER_NS}"
  # brokerK8sSecret: submariner-broker-secret
}
