# vind (vCluster in Docker) — helm-flavor cluster spike

`make vind-up` brings up the **helm-flavor default cluster** on
[vind](https://github.com/loft-sh/vind) (a "vcluster standalone" — a real,
KinD-shaped Kubernetes control plane running straight in Docker) instead of a
`kind` node. It is the time-boxed spike recommended in
[finding-vind-evaluation.md](./finding-vind-evaluation.md): vind runs
*alongside* kind, it does not replace the provisioning spine.

## How it fits together

We do **not** provision vind through OpenTofu (there is no drop-in vind TF
provider — see the finding). Instead:

1. **`vcluster` CLI creates the cluster** in Docker
   (`vcluster create argocd-conductr-vind --driver docker`).
2. Its kubeconfig is exported to `tf/argocd-conductr-vind-config`
   (a stable published host port, `insecure-skip-tls-verify`).
3. **OpenTofu consumes it in external-cluster mode**: `tf/vind-helm.tfvars`
   sets `kubeconfig_path`, so `kind_cluster.default` is `count=0`, the providers'
   `host` attrs go null, and they fall back to env vars. Note the three providers
   read *different* env vars (see the TODO in `tf/providers.tf`): `kubernetes`
   and `helm` read `KUBE_CONFIG_PATH`, `kubectl` reads `KUBECONFIG` — `vind.sh`
   exports both. Tofu then installs the same helm-flavor Argo CD stack as on kind.

`tools/vind.sh` orchestrates all three steps.

```
make vind-up      # create vind cluster + reconcile helm-flavor Argo CD onto it
make vind-down    # tofu state rm + vcluster delete + drop the kubeconfig
./tools/vind.sh kubeconfig   # (re)export tf/argocd-conductr-vind-config
```

## What differs from `make cluster-up` (kind)

| | `cluster-up` (kind) | `vind-up` |
|---|---|---|
| Substrate | `kind` node via `tehcyx/kind` provider | `vcluster` standalone in Docker |
| Root env | `envs/kind-helm` | `envs/vind-helm` (kind-helm **minus cilium**) |
| CNI | kindnet disabled → **cilium** (tofu + Argo CD) | vind's built-in **flannel** |
| tofu workspace | `default` | `vind` |
| tfvars | `sample-helm.tfvars` | `vind-helm.tfvars` (external mode) |

**Why no cilium.** vind already ships a working CNI (flannel), so
`envs/vind-helm` omits the cilium Application and `vind-helm.tfvars` leaves
`cilium_appset_path` unset (`cilium_enabled=false`) — a second CNI would fight
the first. Everything else (ingress-nginx, monitoring, kargo, gatekeeper, …)
is identical to `kind-helm`, pulled from the same `stage/cluster-test` overlays.

Cilium *can* run on vind (Loft publishes a guide), but it is experimental with
`kubeProxyReplacement` gotchas; the spike deliberately stays on flannel.

## Host prerequisite: `br_netfilter` (this box)

vind's flannel (vxlan) needs the `br_netfilter` kernel module —
`/proc/sys/net/bridge/bridge-nf-call-iptables`. If it is missing, flannel
crash-loops and coredns/pods never get networking (the API server stays up, so
`kubectl get nodes` still works — but nothing schedulable runs).

```bash
sudo modprobe br_netfilter overlay bridge   # load it (persist via /etc/modules-load.d)
ls /proc/sys/net/bridge/bridge-nf-call-iptables   # should now exist
```

> On this machine the module was unavailable because the running kernel
> (`7.1.3-arch1-2`) did not match the installed module tree (`7.1.3-arch2-1`) —
> the box had been upgraded but not rebooted. A reboot into the installed
> kernel makes `br_netfilter` loadable. This is also why the kind flavor uses
> cilium (eBPF, no `br_netfilter`) rather than flannel.

## Accessing Argo CD

Unlike kind, vind does not map NodePorts to host ports here
(`extra_port_mappings` is inert in external mode). Reach the UI via a
port-forward against the exported kubeconfig:

```bash
export KUBECONFIG=$PWD/tf/argocd-conductr-vind-config
kubectl -n argocd port-forward svc/argo-cd-argocd-server 8080:443
# initial admin password:
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

`vcluster connect argocd-conductr-vind --driver docker` also switches your
current kube-context to the vind cluster for ad-hoc `kubectl`.

## Knobs (env vars for `tools/vind.sh`)

- `VIND_NAME` (default `argocd-conductr-vind`) — cluster name; also the
  `tf/<name>-config` kubeconfig basename.
- `VIND_WORKSPACE` (default `vind`), `VIND_TFVARS` (default `vind-helm.tfvars`).
- `VIND_K8S_VERSION` (e.g. `v1.31.0`) — override vind's default Kubernetes
  version; empty uses the vind default.
