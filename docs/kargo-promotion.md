# Kargo promotion

Two working promotion pipelines, both defined in
`assets/kargo/manifest-kargo.yaml` (project `kargo-default`):

1. **Per-app, hydrated** (`test` → `prod`): the `orders` app, Rendered
   Configs pattern — this section.
2. **Whole-env, between clusters** (`cluster-test` → `cluster-prod`): the
   hub and a spoke kind cluster — see
   [Whole-env promotion between clusters](#whole-env-promotion-between-clusters).

## Pipeline 1: orders (rendered configs, test → prod)

Minimal working example of Kargo-based promotion for the `orders` app,
following the **Rendered Configs** pattern on a single long-lived branch.

## What is promoted

A git commit on `wip` touching `apps/apps/orders/**`. The Kargo `Warehouse`
(project `kargo-default`) subscribes to the repo with those `includePaths` and
turns each qualifying commit into **Freight** — the unit of promotion. We
promote versions of the app's config sources, not images.

## Branches and folders — env vs stage

**Envs** (`envs/kind-olm`, `apps/*/envs/<env>`) describe *what a target looks
like* — a cluster footprint (OLM vs helm, kind vs remote). Nothing promotes
between envs. **Stages** (`apps/apps/orders/stages/<stage>`) describe *which
version is deployed where* — positions in a promotion pipeline. Folders
express variance on both axes; human-edited branches never encode deployment
state. The only extra long-lived branch is `rendered` — machine-owned output,
never merged, regenerable — and even there stages are folders:

| | `wip` (sources) | `rendered` (hydrated output) |
|---|---|---|
| Written by | humans | only Kargo promotions |
| Contains | kustomize base + per-stage overlays (`apps/apps/orders/stages/<stage>`) | flat YAML under `rendered/apps/orders/<stage>/` |
| Read by | Kargo (warehouse, render input) | Argo CD (the `orders-<stage>` apps) |

Argo CD never runs kustomize for the promoted app — it deploys the
pre-rendered YAML, so every promotion is a plain, diffable commit of exactly
what hits the cluster.

## The moving parts

- `assets/kargo/manifest-kargo.yaml` — Project, ProjectConfig (auto-promotion
  into `test`), Warehouse, PromotionTask `promo-process` and Stages
  `test` → `prod`. Applied by `make kargo-setup` together with the git
  credentials secret (needs `GITHUB_USERNAME`/`GITHUB_PAT` with push rights).
- `envs/*/appset-rendered-apps.yaml` — generates one Application per
  `rendered/apps/orders/<stage>` folder on `rendered`, named
  `orders-<stage>`, annotated `kargo.akuity.io/authorized-stage` so the
  matching Stage's `argocd-update` step may act on it.
- `apps/apps/orders/stages/test|prod` — per-stage overlays (namespace
  `orders-<stage>`, `STAGE` env var, prod runs 2 replicas). The app's
  `envs/kind-olm` overlay is the non-Kargo path and stays under `envs/`.

A promotion runs `promo-process`: clone the Freight's commit (`./src`) and
`rendered` (`./out`), `kustomize build` the stage overlay into
`./out/rendered/apps/orders/<stage>/manifest.yaml`, commit + push, then
`argocd-update` the `orders-<stage>` Application to the new revision.

Freight flows into `test` automatically (ProjectConfig promotion policy).
`prod` only accepts Freight already **verified in `test`** (stage healthy
after promotion) and requires someone to create a `Promotion` — the manual
gate.

## Running it

```sh
export GITHUB_USERNAME=... GITHUB_PAT=...   # push rights on the repo
make kargo-setup                            # project, stages, credentials
make kargo-demo                             # bump wip -> test -> prod
```

`tools/kargo-promo-demo.sh` bumps `APP_VERSION` in the orders base (a real
commit on `wip` — that *is* the Freight), waits for discovery, auto-promotion
into `test` and verification, then promotes the same Freight to `prod` by
creating a `Promotion` with kubectl. Verify with the env vars the app serves:
`orders-test`/`orders-prod` namespaces, `STAGE` and `APP_VERSION`.

Notes:

- First-run chicken-and-egg: `argocd-update` needs the `orders-<stage>` app,
  which the ApplicationSet only generates once the rendered folder exists.
  The demo script therefore seeds missing `rendered/apps/orders/<stage>`
  folders (a plain render of the current sources) before promoting.
- Re-promoting Freight whose rendered output is already on `rendered`
  makes `git-commit` return `Skipped`, leaving `desiredRevision` empty — fine
  for the demo, but a real setup may want to handle the no-change case.
- kubectl-created Promotions need **time-sortable names**: the stage
  controller assumes names sort chronologically (Kargo generates
  `<stage>.<ulid>.<freight-prefix>`) and silently ignores any Promotion whose
  name sorts before `status.lastPromotion` — with `generateName`'s random
  suffix the Stage may never record the result (stale `CURRENT FREIGHT`,
  health pinned to an old revision). The demo scripts mint ULID names.
- Both orders stages read folders on the *same* `rendered` branch, and the
  argocd-update health check pins each stage to its promotion's commit — so
  promoting one stage advances the branch head and flips the *other* stage
  Unhealthy (revision mismatch) until it is re-promoted (a no-op render).
  Kargo's docs recommend branch-per-stage for exactly this reason; the
  cluster pipeline (separate `stage/cluster-*` branches) is immune.

## Whole-env promotion between clusters

Pipeline 2 promotes the **entire workload config** (`apps/**`) between two
kind clusters on the same host: the hub (`argocd-conductr-helm`, stage
`cluster-test`) and a spoke (`argocd-conductr-spoke`, stage `cluster-prod`).
Hub-and-spoke: the hub's Argo CD and Kargo manage both clusters — that is
what makes `argocd-update` and freight verification work for the spoke.

### What is promoted

Any `wip` commit touching `apps/**` becomes Freight of the `cluster`
Warehouse. Unlike pipeline 1 there is no hydration: each stage branch
(`stage/cluster-test`, `stage/cluster-prod`) carries a machine-owned **copy
of the `apps/` tree** at the promoted commit, and Argo CD keeps rendering
helm/kustomize from it exactly as it would from `wip`. Promotion is a plain
copy (git-clone → git-clear → copy → commit → push → argocd-update).

### Who reads what

- **Hub workload appsets** (`infra-helm`, `infra-misc`, `infra-helm-local`)
  are gated: their git generators and `$values`/source revisions point at
  `stage/cluster-test`. A push to `wip` changes *nothing* on the hub until
  auto-promotion lands it on the branch.
- **Spoke appsets** (`appset-cluster-prod.yaml`) generate `<app>-spoke`
  Applications (slim subset: `ingress-nginx-spoke`, `orders-spoke`) from
  `stage/cluster-prod` once a cluster secret labeled
  `kargo-stage: cluster-prod` exists. Names are suffixed with the cluster
  secret's name, so they cannot collide with pipeline 1's `orders-prod`.
- **The control plane is deliberately NOT promoted**: `envs/**` (root app,
  the appsets themselves, `app-argo-cd`) and the cilium bootstrap keep
  tracking `wip`. Never gate the machinery that applies promotions.

Break-glass: kargo's own values are gated like any workload. If a promoted
change breaks kargo, it cannot promote the fix — push the fix directly to
`stage/cluster-test` (the branches are machine-owned, but a human commit is a
legitimate manual override; the next promotion overwrites it).

### Spoke cluster lifecycle

```sh
cd tf
tofu workspace select -or-create spoke
tofu apply -var-file=spoke.tfvars -target='kind_cluster.default[0]'  # first time
tofu apply -var-file=spoke.tfvars
```

(kind + cilium only — no Argo CD, no OLM. The two-phase apply works around
the kubectl provider needing a reachable endpoint at plan time.)

Register it on the hub as an Argo CD cluster secret — server is the spoke
control-plane container IP on the shared kind docker network (kind includes
it in the API server cert SANs):

```sh
docker inspect argocd-conductr-spoke-control-plane \
  -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'   # -> server
kubectl config view --raw ...                                     # -> ca/cert/key data
```

The secret needs `argocd.argoproj.io/secret-type: cluster` and
`kargo-stage: cluster-prod` labels, `name: spoke`, `server: https://<ip>:6443`
and a `config` JSON with `tlsClientConfig.{caData,certData,keyData}`.

### Running it

```sh
make kargo-cluster-demo
```

`tools/kargo-cluster-demo.sh` bumps `APP_VERSION` in the orders base (the
same knob as pipeline 1 — both warehouses watch `wip`, so the bump feeds both
pipelines; they are independent), waits for `cluster` Freight, auto-promotion
into `cluster-test`, verification (hub gate apps `ingress-nginx` and
`reflector` healthy at the new revision), then creates the `cluster-prod`
Promotion and waits until the spoke's `orders` deployment serves the new
version.

Notes:

- The hub gate's `argocd-update` checks a representative subset — every hub
  workload app reads the branch, but promotion health does not hinge on the
  heavyweight monitoring stack.
- A no-op promotion (apps/ tree unchanged on the branch) makes `git-commit`
  return `Skipped` — same caveat as pipeline 1.
- Next step once stable: switch the source branch `wip` → `main` (Warehouse
  subscriptions + the pinned control-plane refs + tf).
