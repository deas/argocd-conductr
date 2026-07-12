# Copilot instructions

Self-managed **Argo CD GitOps** monorepo deploying a Kubernetes platform and its
workloads via the **App-of-Apps** pattern. Targets `kind`, vanilla Kubernetes,
and OpenShift/`crc`. See `AGENTS.md` and `README.md` for full detail.

## How change works

State is **declarative**: edit manifests, commit, let Argo CD sync. Do not
`kubectl apply` to mutate cluster state except during bootstrap.

App-of-Apps chain: `root` (`envs/<env>/app-root.yaml`) → ApplicationSets
(`infra-helm`, `infra-helm-local`, `infra-misc`, …) → components under
`apps/infra`. Control-plane `targetRevision` tracks a branch (currently
`wip`; update with `make set-gitops-rev`); workload appsets read the
Kargo-promoted `stage/cluster-test` branch (docs/kargo-promotion.md).

## Layout

- `envs/<env>/` — Argo CD bootstrap manifests only (root app + ApplicationSets).
  Envs name cluster class + bootstrap flavor: `kind-olm`, `kind-helm`.
- `apps/infra/<component>/` — platform components. Remote Helm charts use
  `values.yaml` + `envs/kind/values.yaml` (shared class overlay), with the
  version pinned in `envs/*/appset-*.yaml`. Local charts/Kustomize use
  `Chart.yaml`+`templates/` or `base/`+`envs/kind/`.
- `apps/apps/<app>/` — workload apps as Kustomize `base/` + `envs/kind/` +
  `stages/<stage>/`. **Keep Argo CD resources out of `apps/`.**
- `docs/` — `TODO.md`, `kargo-promotion.md`.
- `tools/` — Bash helpers. `tf/` — self-contained OpenTofu
  entrypoint that stands on its own: `make -C tf apply` brings up everything from
  scratch (`kind` cluster → OLM → Argo CD → root app). Don't unify it with the
  root `Makefile`, which instead assumes a cluster already exists.

## Commands

Bootstrap is either `make -C tf apply` (full `kind` environment from scratch) or
the root Makefile's `argocd-helm-install-basic`/`argocd-olm-install-basic` +
`argocd-apply-root` (into an existing cluster). Run `make` for the full list.
CI (`pr.yml`) runs `make fmt`, `make lint`,
`make gator-verify`, `make test-prom-rules`; the test workflow runs
`tools/validate.sh` (`kubeconform`). Tools are pinned in `.tool-versions` and
installed via `mise`.

## Conventions

- Functional style: pure functions, immutability, composition, declarative code.
  No OOP. Small, well-named functions; handle errors via exceptions.
- Secrets: prefer **Sealed Secrets** (`kubeseal`); SOPS/`age` also supported.
  Never commit plaintext secrets or private keys.
