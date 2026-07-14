# Finding: vind (vCluster in Docker) as a kind replacement

**Date:** 2026-07-13
**Context:** Local dev substrate for this repo (currently `kind` via the
`tehcyx/kind` Terraform provider)
**Verdict:** Right shape, wrong time — keep `kind`; revisit vind later.

## What vind is (and is not)

- **vind** = vCluster's **Docker driver**: a *standalone, real* Kubernetes
  control plane (with its own kubelet[s]) in Docker containers. It is a
  kind-shaped tool and is the only sensible comparison to our setup.
- It is **not** classic vcluster. Classic vcluster is a *virtual* control plane
  running as pods **inside a host cluster** with no nodes of its own; workloads
  sync down to the host and run on the host's kubelet/CNI/network. That model
  virtualizes the *app* layer, but this repo's product *is* the *platform* layer
  (CNI, operators, admission control, cross-cluster networking), so classic
  vcluster is structurally unsuitable and is out of scope for this finding.

## Why vind is capable (fits our needs)

Unlike classic vcluster, vind runs a real control plane, so the things we test
survive:

- **Real, swappable CNI.** We disable the default CNI and run **Cilium** with
  `kubeProxyReplacement` (`tf/main.tf`, `helm_release.cilium`). vind supports
  disabling its default (Flannel + kube-proxy) and installing Cilium — Loft
  publishes an official Cilium-on-vind guide.
- **Real nodes.** submariner gateways (`submariner.io/gateway` node label) and
  two-cluster kargo promotion need real per-node identity and networking; vind
  has it, classic vcluster does not.
- **LoadBalancer out of the box** (auto HAProxy) — overlaps with our
  cloud-provider-kind preference (see `tf/README.md`).
- **Shared Docker image cache** (no `kind load` round-trips),
  **pause/resume/sleep**, **snapshots**, and **multi-node** via
  `experimental.docker.nodes`.

## Why we are not switching now (three concrete frictions)

1. **No drop-in Terraform provider.** Our provisioning *is* the `tehcyx/kind`
   provider: the `kind_cluster` resource drives `disable_default_cni`,
   `extra_mounts`, `extra_port_mappings`, `containerd_config_patches`,
   `kubeadm_config_patches`, `feature_gates`, node labels and subnets
   (`tf/main.tf`, `tf/providers.tf`), and the k8s/helm/kubectl providers derive
   their connection *from that resource*. The `loft-sh/loft` Terraform provider
   manages *virtual clusters on a Loft platform*, **not** standalone vind. There
   is a `setup-vind` GitHub Action and a CLI + `vcluster.yaml`, but adopting vind
   means **rewriting the provisioning spine**, not flipping a provider.
2. **Cilium-on-vind is explicitly experimental** (config under
   `experimental.docker.nodes`) with a sharp gotcha: with kube-proxy disabled,
   `k8sServiceHost` must be the API server's **literal IP** or Cilium hangs at
   `Init:0/6`. We would be re-solving CNI bring-up we already have working and
   pinned.
3. **Maturity delta.** `kind` is a k8s-SIG project our entire flow — and our
   accumulated finding docs — is hardened against. vind is a 2025-era product.
   Swapping the substrate is riskiest exactly when the stack (submariner, OLM,
   two-cluster kargo) is most integration-sensitive.

## Recommendation

- **Stay on `kind`** for the platform/provisioning layer.
- vind is worth a **time-boxed spike** for fast app inner-loop work (image
  cache + built-in LoadBalancer + sleep/wake) *alongside* kind — not a
  migration.
- **Revisit** if vind ships a first-class Terraform provider **and**
  Cilium + kube-proxy-replacement graduates out of `experimental`.

## Sources

- <https://github.com/loft-sh/vind> · vind vs kind:
  <https://github.com/loft-sh/vind/blob/main/docs/vind-vs-kind.md>
- Cilium on vind (Part 1):
  <https://www.vcluster.com/blog/cilium-powered-tenant-clusters-part-1-cilium-cni-vind>
- vind advanced features (sleep/wake, registry proxy, custom networking):
  <https://www.vcluster.com/blog/vind-advanced-features-sleep-wake-registry-proxy-custom-networking>
- `setup-vind` action: <https://github.com/loft-sh/setup-vind> · Loft Terraform
  provider: <https://registry.terraform.io/providers/loft-sh/loft/latest/docs>
