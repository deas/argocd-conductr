# Finding: Flux as an alternative GitOps engine for this repo

**Date:** 2026-07-28
**Context:** Evaluating whether Flux could be introduced alongside Argo CD
without restructuring `apps/` or `envs/`
**Verdict:** The layout plays — this repo *was* a Flux repo. Introduce it as a
new `envs/kind-flux` flavor, not a fork. One decision (Helm values overlays)
gates the whole port; settle it with a single-component spike first
(`.scratch/experiments/issues/05-flux-spike.md`).

## Prior art: this repo has Flux ancestry

Flux residue is still checked in, which is the strongest evidence the layout
tolerates both engines:

| Location | Residue |
| --- | --- |
| `tools/validate.sh:8` | *"Copyright 2020 The Flux authors"* — it downloads `flux2` `crd-schemas.tar.gz` and validates "Flux custom resources". It is the script from `flux2-kustomize-helm-example`, currently validating schemas nothing here uses. |
| `.github/workflows/e2e.yaml:17-49` | Fully commented-out `flux install` + `flux create source git` + `kustomization/infrastructure` e2e block. |
| `tf/cilium-values.yaml:2` | `k8sServiceHost: flux-conductr-control-plane` |
| `tf/main.tf:273-281` | *"Keep the flux bits around for reference"* (`id_rsa_fluxbot_ro`) |
| `git log` `4ccfc34` | *"Catchup with **flux-conductor** — terraform, make, proxy support"* |

An ancestor repo `flux-conductr` existed and this one was converted from it.

## Does the folder structure play?

The canonical Flux example layout is `apps/ + infrastructure/ + clusters/`.
Ours is `apps/apps/ + apps/infra/ + envs/` — the same shape with different
names, including the "bootstrap manifests only, no component config" rule for
`envs/`, which is exactly what `clusters/<name>/` is for.

### Maps 1:1, no file changes

| This repo | Flux |
| --- | --- |
| `apps/apps/orders/{base,envs/kind,stages/*}` | `Kustomization` per path |
| `apps/infra/{private,cluster,gatekeeper-library,ocm-policy-framework,openshift-config}/envs/kind` | `Kustomization` |
| `rendered/` branch + `appset-rendered-apps` | `GitRepository` ref `rendered` + `Kustomization` per stage path |
| `stage/cluster-test` gating | `GitRepository.spec.ref.branch` — same gate, simpler |
| `envs/<env>/` (bootstrap only) | `clusters/<name>/` |
| Argo CD sync waves | `Kustomization.spec.dependsOn` |

### The one real friction: remote chart + two values overlays

Our appsets do:

```yaml
valueFiles:
  - "$values/apps/infra/<c>/values.yaml"
  - "$values/apps/infra/<c>/envs/kind/values.yaml"
```

Flux's `HelmRelease` has **no equivalent to Argo CD's multi-source `$values`**.
For a chart pulled from a `HelmRepository`, `valuesFiles` must live *inside the
chart*. Tracked upstream as
[helm-controller#814](https://github.com/fluxcd/helm-controller/issues/814),
still open. Three viable answers:

1. **`ArtifactGenerator`** (`source.extensions.fluxcd.io/v1beta1`, provided by
   the **source-watcher** extension controller — *not* part of a default Flux
   install). Composes chart + git values into one `ExternalArtifact` using
   `strategy: Merge`, a Helm-compatible deep merge (arrays replaced entirely,
   same semantics as repeated `-f`). Closest match to what we have today; Flux
   2.8 extended it specifically for Helm charts. Beta API.
2. **`configMapGenerator` + `HelmRelease.spec.valuesFrom`** — the boring, GA,
   widely-used route. Costs a ConfigMap per component and explicit per-overlay
   ordering.
3. **Vendor the charts** — already done for `registration-operator-hub`,
   `submariner-operator`, `monitoring-webhook`,
   `openshift-user-workload-monitoring`.

This decision determines whether the port preserves the `values.yaml` +
`envs/<class>/values.yaml` overlay model or forces a restructure of
`apps/infra/`. Everything else in the port is mechanical.

## What has no clean equivalent

- **ApplicationSet matrix (`list` × `git.directories`).** Flux OSS has nothing.
  The [flux-operator](https://github.com/controlplaneio-fluxcd/flux-operator)
  `ResourceSet` API covers it: static `spec.inputs`, Go templates with `<< >>`
  delimiters (to avoid clashing with Helm), `dependsOn`, and per-input
  enable/disable via the `fluxcd.controlplane.io/reconcile` annotation.
  **But** `ResourceSetInputProvider` has ~20 provider types (branches, tags,
  PRs, OCI tags) and **none enumerates git directories**. In practice that is
  fine — our matrix is list-driven anyway; the `git.directories` half only
  confirms `apps/infra/<c>/envs/kind` exists, so it collapses to `spec.inputs`.
  **Caveat: flux-operator is AGPL-3.0.**
- **`templatePatch` / `ignoreDifferences`.** Flux `Kustomization` has
  `.spec.ignore` (JSON Pointer + target selectors) and the
  `kustomize.toolkit.fluxcd.io/ssa: Override|Merge|IfNotPresent|Ignore`
  annotation. Several current entries — the sealed-secrets `ServiceMonitor`
  annotation one especially — are Argo-diff artifacts that likely evaporate
  under Flux's SSA-everywhere model.
- **`reflector`.** `apps/infra/reflector/base/kustomization.yaml` is our **only**
  `helmCharts` user, and kustomize-controller deliberately does **not** support
  `--enable-helm` ([flux2#2310](https://github.com/fluxcd/flux2/discussions/2310)).
  The Flux answer is `HelmRelease.spec.postRenderers.kustomize.patches` for the
  SCC augmentation — arguably cleaner. Already commented out of
  `appset-infra-helm.yaml`, so this is a one-component problem.
- **Kargo — the sharpest edge.** `argocd-update` is the only promotion step that
  registers *ongoing health checks*, and there is no Flux twin. The git-driven
  parts (`git-commit`/`git-push` → `rendered` and `stage/cluster-*`) work
  unchanged; Flux reconciles from a branch, so the pull model documented in
  [kargo-promotion.md](./kargo-promotion.md) actually fits *better*. What is
  lost is Stage health derived from Application health — it would need
  `Kustomization`/`HelmRelease` readiness via a custom verification step.
- **`kind-olm` flavor.** Survivable: flux-operator publishes an OLM bundle on
  operatorhub.io, so an OLM-bootstrapped Flux flavor is possible in principle.

## What gets better

- **SOPS is native** (`Kustomization.spec.decryption`; age/PGP/KMS).
  `apps/infra/private/secret.enc.yaml` works directly and `kustomize-sops` can
  be dropped from `flake.nix`.
- **`tools/validate.sh` becomes correct again** — it is already the right script
  for the wrong tool.
- Flux **2.8 GA** (2026-02-24, current patch 2.8.8) brought Helm v4 support,
  server-side apply for Helm releases, and CEL readiness checks.

## How to introduce it (new env, not a fork)

1. **`envs/kind-flux/`** — bootstrap only, honoring the existing contract:
   `GitRepository` + root `Kustomization` → `ResourceSet`s (or plain
   `HelmRelease`s) → `apps/infra/*`. Reuses the shared `envs/kind` class
   overlays untouched.
2. **`tf/`** — `var.argocd_install` already accepts `helm | olm | null`, and
   `null` already yields "cluster + cilium, no GitOps" — exactly the hand-off
   point for a `flux bootstrap`. Either add a `gitops_install` variable or a
   `module "flux"` gated the same way. Note that `local.cilium_app` in
   `tf/main.tf` parses `var.cilium_appset_path` for the pinned Cilium version
   (the `# TODO: Whoa! The ultimate mess` block) and would need a flux-shaped
   source.
3. **`Makefile`** — `make cluster-flux-up` selecting a `flux` tofu workspace +
   `flux.tfvars`, matching the existing `cluster-workload-up` pattern.

Rough effort: the kustomize-shaped half is near-free. The ~20 remote-chart
components are the bulk and are repetitive once the values pattern is fixed.
Kargo integration is the only place a capability is genuinely lost.

## TODO

- **Spike `ingress-nginx` end-to-end in a throwaway `kind-flux` env** to settle
  the values-overlay question (ArtifactGenerator vs. configMapGenerator) before
  committing to any of the above. Tracked at
  `.scratch/experiments/issues/05-flux-spike.md`.
- Decide repo topology: two-flavor repo, or a sibling `flux-conductr` again (the
  historical split).

## References

- [Announcing Flux 2.8 GA](https://fluxcd.io/blog/2026/02/flux-v2.8.0/)
- [Artifact Generators](https://fluxcd.io/flux/components/source/artifactgenerators/)
- [Kustomization spec](https://fluxcd.io/flux/components/kustomize/kustomizations/)
- [Flux for Helm Users](https://fluxcd.io/flux/use-cases/helm/)
- [helm-controller#814 — HelmRelease valueFiles (multiple sources)](https://github.com/fluxcd/helm-controller/issues/814)
- [flux2#2310 — HelmChartInflationGenerator support](https://github.com/fluxcd/flux2/discussions/2310)
- [ResourceSet CRD](https://fluxoperator.dev/docs/crd/resourceset/)
- [ResourceSetInputProvider CRD](https://fluxoperator.dev/docs/crd/resourcesetinputprovider/)
- [flux-operator (AGPL-3.0)](https://github.com/controlplaneio-fluxcd/flux-operator)
- [Kargo `argocd-update` promotion step](https://docs.kargo.io/user-guide/reference-docs/promotion-steps/argocd-update)
- [flux2-kustomize-helm-example](https://github.com/fluxcd/flux2-kustomize-helm-example)
- [Ways of structuring your repositories](https://fluxcd.io/flux/guides/repository-structure/)
