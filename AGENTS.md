# AGENTS.md

## What this repo is

A self-managed **Argo CD GitOps** monorepo ("Argo CD Conductr") that deploys a
Kubernetes platform and its workloads following the **App-of-Apps** pattern. It
targets `kind`, vanilla Kubernetes, and OpenShift/`crc`. The change process
starts on localhost; experimentation and production must not conflict.

State is changed **declaratively**: edit manifests, commit, and let Argo CD
sync. Do not `kubectl apply` to mutate cluster state except during initial
bootstrap.

## Repository layout

- `envs/<env>/` — Argo CD bootstrap manifests only (root `Application` +
  `ApplicationSet`s). No component config lives here. An env names a
  **cluster class + bootstrap flavor**: `kind-olm` (kind, OLM-bootstrapped)
  and `kind-helm` (kind, helm-only — the hub). Stages are NOT envs (see
  docs/kargo-promotion.md). `workload` is the one cluster env: the workload
  cluster's own slim Argo CD control plane (pull model — plain Applications
  tracking the promoted stage branch, plus a Kargo controller shard).
- `apps/infra/<component>/` — platform components. Two shapes:
  - **Remote Helm chart**: `values.yaml` (shared) + `envs/kind/values.yaml`
    (the shared **class** overlay both flavors reuse). The chart version is
    pinned in the ApplicationSet element lists in `envs/*/appset-*.yaml`.
    Flavor-specific components (argo-cd, cilium bootstrap) instead carry
    `envs/kind-olm` / `envs/kind-helm` overlays.
  - **Local chart or Kustomize/OLM**: `Chart.yaml` + `templates/`, or
    `base/` + `envs/kind/` overlays.
- `apps/apps/<app>/` — workload apps (e.g. `orders`) as Kustomize `base/` +
  `envs/kind/` class overlays and `stages/<stage>/` promotion overlays.
  **Keep Argo CD resources out of `apps/`** by design —
  this preserves separation and fast local testing.
- `tools/` — helper Bash scripts (`argocd.sh`, `gen-keys.sh`,
  `validate.sh`, `wait-for-k8s.sh`, …).
- `tf/` — self-contained OpenTofu entrypoint for those who want IaC
  on top. It **stands on its own and includes everything**: `make -C tf apply`
  creates the `kind` cluster → OLM → Argo CD → root app, driven entirely by
  `tf/main.tf` (it does not call back into the root `Makefile`). Teardown is
  `make -C tf quick-destroy`.
- `.github/workflows/` — CI.
- `main.go`, `test/` — small Go helper + Ginkgo cluster tests.

## App-of-Apps chain

`root` (`envs/<env>/app-root.yaml`, points at `envs/<env>`)
→ ApplicationSets (`infra-helm`, `infra-helm-local`, `infra-misc`, …)
→ individual components under `apps/infra`.
The `workload` env has no checked-in `app-root.yaml`; its root app is
templated from `envs/app-root.tmpl.yaml` by `tf/main.tf`.

The olm-less `kind-helm` env replaces the OLM-provided operators of
`kind-olm` with helm charts (argo-cd chart instead of the ArgoCD CR,
cert-manager, grafana-operator; `registration-operator-hub` covers the OCM
cluster-manager operator). Both flavors' ApplicationSets reuse the shared
`envs/kind` per-component class overlays.

The control plane (`envs/**`, root, argo-cd) tracks a branch directly
(currently `wip`; update across `envs` with `make set-gitops-rev`). Workload
appsets are **gated**: they read the machine-owned `stage/cluster-test`
branch, written only by Kargo promotions. Makefile variables: `ENV` (default
`kind-olm`) selects the root-app dir; `ARGO_ENV` (default `kind-olm`) the OLM
flavor overlay; `ARGO_HELM_ENV` (default `kind-helm`) the helm flavor values;
`ARGO_CLASS` (default `kind`) the shared class overlay.

Promotion uses **Kargo** (docs/kargo-promotion.md): per-app Rendered Configs
on the `rendered` branch (stages `test` → `prod`), and whole-env promotion
between clusters via `stage/cluster-*` branches (`cluster-test` on the hub →
`cluster-prod` on the workload kind cluster).

## Bootstrap: two entrypoints

There are two parallel ways to bring an environment up. Pick one:

- **With IaC (`tf/`)** — `make -C tf apply` brings up everything from scratch
  (cluster + OLM + Argo CD + root app). Use this for the local `kind` workflow.
- **Without IaC (root `Makefile`)** — assumes a cluster **already exists** in
  your current `kubectl` context. It only installs Argo CD and applies the root
  app; it has no `kind` cluster lifecycle target. The overlap with `tf/` is
  intentional layering, not duplication — do not try to unify them.

## Common commands

| Command | Purpose |
| --- | --- |
| `make` | List available targets (root `Makefile`) |
| `make -C tf apply` / `make -C tf quick-destroy` | Bring up / tear down the full `kind` environment via OpenTofu |
| `make install-tools` | Install pinned tools via `mise` |
| `make argocd-helm-install-basic argocd-apply-root` | Install Argo CD (Helm) + apply the root app into an existing cluster |
| `make argocd-olm-install-basic` | Install Argo CD via OLM instead (into an existing cluster) |
| `make test` | Go/Ginkgo tests (needs a live cluster) |
| `make test-watch` | `ginkgo watch ./...` |
| `make lint` | `go vet` + `tflint --recursive` |
| `make fmt` | `tofu fmt --check --recursive` |
| `make gator-verify` | OPA Gatekeeper constraint tests |
| `make test-prom-rules` | `promtool` unit tests for Prometheus rules |
| `make argocd-initial-admin-password` / `argocd-admin-login` | Argo CD admin access |
| `make argocd-disable-sync` / `argocd-enable-sync` | Pause/resume sync for all apps |

CI: the **Pull Request** workflow (`.github/workflows/pr.yml`) runs `make fmt`,
`make lint`, `make gator-verify`, and `make test-prom-rules`. The **test**
workflow runs `tools/validate.sh` (`kubeconform` manifest validation). Tools
are provisioned with `jdx/mise-action`.

## Tooling & environment

- Tool versions are pinned in `.tool-versions` and installed with **`mise`**
  (`sops`, `tflint`, `opentofu`, `gator`, `kubeconform`, `kustomize`, `yq`,
  `promtool`, `helm`). A `nix`/`devenv` flake (`flake.nix` + `direnv`) provides
  `argocd`, `argocd-autopilot`, and `kustomize-sops`.
- Languages present: Go (`main.go`, `test/`), Clojure
  (`apps/infra/monitoring-webhook/src/server.clj`, `apps/infra/olmv1`), and Bash.

## Secrets

Prefer **Sealed Secrets** (`kubeseal`, cert at `assets/kubeseal.pem`); **SOPS**
with `age`/GPG is also supported (`tools/gen-keys.sh`). Out-of-git bootstrap
secrets are applied from `keys/bootstrap.yaml` (gitignored). Never commit
plaintext secrets or private keys.

## Coding principles

When writing code, you MUST follow these principles:
- Code should be easy to read and understand.
- Keep the code as simple as possible. Avoid unnecessary complexity.
- Use meaningful names for variables, functions, etc. Names should reveal
  intent.
- Functions should be small and do one thing well. They should not exceed a few
  lines.
- Function names should describe the action being performed.
- Prefer fewer arguments in functions. Ideally, aim for no more than two or
  three.
- Only use comments when necessary, as they can become outdated. Instead, strive
  to make the code self-explanatory.
- When comments are used, they should add useful information that is not readily
  apparent from the code itself.
- Properly handle errors and exceptions to ensure the software's robustness.
- Use exceptions rather than error codes for handling errors.
- Consider security implications of the code. Implement security best practices
  to protect against vulnerabilities and attacks.
- Adhere to these 4 principles of Functional Programming:
  1. Pure Functions
  2. Immutability
  3. Function Composition
  4. Declarative Code
- Do not use object oriented programming.

## Agent skills

### Issue tracker

Issues and specs live as markdown files under `.scratch/<feature-slug>/` in this repo — no external tracker. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles, using default label strings, recorded on a `Status:` line in each issue file. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.
