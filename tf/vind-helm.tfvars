# vind (vCluster in Docker) flavor of the helm-based default cluster.
#
# Instead of a kind node, the substrate is a "vcluster standalone" running in
# Docker (a KinD alternative, see docs/vind.md). We point the OpenTofu module
# at that cluster in EXTERNAL-CLUSTER mode: kubeconfig_path is set, so
# kind_cluster.default is count=0 and the k8s/helm/kubectl providers fall back
# to the KUBECONFIG env (tools/vind.sh exports it to tf/argocd-conductr-vind-config).
#
# Driven by tools/vind.sh (make vind-up / vind-down):
#   vcluster create ... --driver docker
#   tofu workspace select -or-create vind
#   KUBECONFIG=<vind kubeconfig> tofu apply -var-file=vind-helm.tfvars
#
# NOTE: terraform.tfvars is auto-loaded first (bootstrap_path, proxies, ...);
# the values below override it for this flavor.
env      = "vind-helm" # root app path envs/vind-helm (kind-helm minus cilium)
argo_env = "kind-helm" # reuse the kind-helm class's argo-cd values + bootstrap

argocd_install = "helm"
bootstrap_olm  = false # override terraform.tfvars (it defaults the olm flavor on)

# Submariner broker export OFF. It defaults true (variables.tf) and drives a
# data.external that runs tf/tools/get-secret.sh, which BLOCKS up to 300s polling
# for the submariner-k8s-broker-client-token secret and then fails the apply.
# That secret only exists in the multi-cluster hub flow; vind is a single
# standalone dev cluster, so there is no broker to export and the wait is pure
# dead weight (it also trips a "v1 Endpoints deprecated" warning on vind's
# k8s v1.36 that the external provider surfaces as an error).
export_submariner_broker_secret = false

# External-cluster mode: use the vind kubeconfig instead of creating a kind node.
# Relative to the tf/ module dir; tools/vind.sh writes it here and also exports
# KUBECONFIG to the same file for the providers. Covered by tf/.gitignore (*-config).
kubeconfig_path   = "argocd-conductr-vind-config"
kind_cluster_name = "argocd-conductr-vind" # inert here (kind_cluster count=0), for labelling only

# Cilium OFF: the vind substrate already ships a working CNI (flannel), so we
# neither bootstrap cilium via tofu (cilium_appset_path unset => cilium_enabled
# false) nor let Argo CD manage it (envs/vind-helm omits the cilium element).
# null overrides the cilium_appset_path that terraform.tfvars sets.
cilium_appset_path = null

# kind-only knobs are inert in external-cluster mode (they only feed the
# count=0 kind_cluster resource) - zero them so an inherited terraform.tfvars
# value can never surprise us.
extra_mounts              = []
extra_port_mappings       = []
kubeadm_config_patches    = []
containerd_config_patches = []
