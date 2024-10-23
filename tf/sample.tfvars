# dns_hosts = { "192.168.1.121" = "proxy.local" }
# kubeconfig_path = "/home/deas/.kube/config"
# bootstrap_path  = ../secret-sealed-secrets.yaml"
# cilium_appset_path = "../envs/local/appset-infra-helm.yaml"
# bootstrap_olm = true

#additional_keys = {
#  "sops-age" = { "keys.txt" = "../sample-key.txt" }
#  "sops-gpg" = { "sops.asc" = "../keys/argocd-conductr-priv.asc" }
#}
#kubeconfig_linked = {
#  path    = "~/.kube/config"
#  context = "kind-kind"
#}
# extra_mounts = [{
#   "container_path" = "/etc/ssl/certs/ca-certificates.crt"
#   "host_path"      = "/etc/ssl/certs/ca-certificates.crt"
# }]


# cluster = "local"
# extra_port_mappings = [
#   {
#     container_port = 30080
#     host_port      = 3000 # Grafana
#   },
#   {
#     container_port = 30180
#     host_port      = 3100 # Loki
#   },
#   {
#     container_port = 30280
#     host_port      = 9411 # Zipkin
#   },
#   {
#     container_port = 30380
#     host_port      = 10080 # Istio-Ingress
#   },
#   {
#     container_port = 30580
#     host_port      = 10280 # Hubble-UI
#   }
# ]
#
# https://dev.to/maelvls/pull-through-docker-registry-on-kind-clusters-cpo
# containerd_config_patches = [
#  <<-EOF
#          [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
#            endpoint = ["http://docker-proxy:5000"]
#          [plugins."io.containerd.grpc.v1.cri".registry.mirrors."quay.io"]
#            endpoint = ["http://quay-proxy:5000"]
#          [plugins."io.containerd.grpc.v1.cri".registry.mirrors."registry.k8s.io"]
#            endpoint = ["http://k8s-proxy:5000"]
#          [plugins."io.containerd.grpc.v1.cri".registry.mirrors."ghcr.io"]
#            endpoint = ["http://ghcr-proxy:5000"]
#          [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:5000"]
#            endpoint = ["http://registry:5000"]
#          EOF
#]
