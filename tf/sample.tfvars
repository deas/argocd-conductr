# dns_hosts = { "192.168.1.121" = "proxy.local" }
# kubeconfig_path = "/home/deas/.kube/config"
# bootstrap_path  = "./bootstrap.yaml"
# enable_olm = true
additional_keys = {
  "sops-age" = { "keys.txt" = "../sample-key.txt" }
"sops-gpg" = { "sops.asc" = "../keys/argocd-conductr-priv.asc" } }
# extra_mounts = [{
#   "container_path" = "/etc/ssl/certs/ca-certificates.crt"
#   "host_path"      = "/etc/ssl/certs/ca-certificates.crt"
# }]

