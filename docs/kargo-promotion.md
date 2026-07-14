# Kargo promotion

Two working promotion pipelines, both defined in
`assets/kargo/manifest-kargo.yaml` (project `kargo-default`):

1. **Per-app, hydrated** (`test` → `prod`): the `orders` app, Rendered
   Configs pattern — this section.
2. **Whole-env, between clusters** (`cluster-test` → `cluster-prod`): the
   hub and a workload kind cluster — see
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
`cluster-test`) and a **workload cluster** (`argocd-conductr-workload`,
stage `cluster-prod`) — Cluster API vocabulary: it has no cluster-management
control plane of its own. The two stages use the two multi-cluster models:

- `cluster-test` is **local**: the hub's own Argo CD syncs its gated appsets
  from `stage/cluster-test`.
- `cluster-prod` is **pull**: the workload cluster runs its *own* slim Argo
  CD (root app → `envs/workload`) that pulls `stage/cluster-prod`, plus a
  **Kargo controller shard** ([sharded topology](https://docs.kargo.io/operator-guide/architecture))
  that connects back to the hub's Kargo control plane and executes only
  resources with `shard: workload` — the `cluster-prod` Stage. Its
  `argocd-update` step and Stage health checks resolve against the local
  Argo CD, which is what keeps freight verification working without the hub
  ever reaching into the workload cluster. There is no Argo CD cluster
  secret on the hub anymore; the only cross-cluster credential points the
  other way (shard → hub, see below).

("Hub and spoke" is deliberately avoided here: in this repo that pair
historically meant Open Cluster Management roles.) Which stage the cluster
plays is not part of its identity — it comes from `Stage.spec.shard`
matching the shard controller's name, and from which stage branch
`envs/workload` tracks.

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
- **Workload-cluster apps** (`envs/workload/`, plain Applications — a
  deliberately slim subset: `ingress-nginx`, `orders`) are synced by the
  workload cluster's own Argo CD from `stage/cluster-prod`. Plain names are
  fine: they live in a different Argo CD, so they cannot collide with
  pipeline 1's `orders-prod` on the hub.
- **The control plane is deliberately NOT promoted**: `envs/**` (root apps,
  appsets, `app-argo-cd`, the kargo shard) and the cilium bootstrap keep
  tracking `wip` on *both* clusters. Never gate the machinery that applies
  promotions — in particular the shard controller tracks `wip` (values
  inline in `envs/workload/app-kargo-shard.yaml`) so a broken promotion can
  never take down the thing that would promote the fix.

Break-glass: kargo's own values are gated like any workload. If a promoted
change breaks kargo, it cannot promote the fix — push the fix directly to
`stage/cluster-test` (the branches are machine-owned, but a human commit is a
legitimate manual override; the next promotion overwrites it).

### Workload cluster lifecycle

```sh
cd tf
tofu workspace select -or-create workload
tofu apply -var-file=workload.tfvars -target='kind_cluster.default[0]'  # first time
tofu apply -var-file=workload.tfvars
```

(kind + cilium + Argo CD — no OLM. The two-phase apply works around the
kubectl provider needing a reachable endpoint at plan time. opentofu
bootstraps Argo CD and the root app pointing at `envs/workload`; from there
the cluster manages itself, including the `argo-cd` app taking over the helm
release and the `kargo-shard` app installing the controller-only kargo
chart.)

Wire the shard to the hub's Kargo control plane:

```sh
tools/kargo-shard-kubeconfig.sh
```

The script mints a long-lived token for the hub's `kargo-controller`
ServiceAccount — reusing that SA means the per-Project secret RoleBindings
Kargo maintains (git credentials!) apply to the shard as well — and stores
it as kubeconfig secret `kargo-control-plane-kubeconfig` on the workload
cluster. The server is `https://argocd-conductr-helm-control-plane:6443`:
the container name resolves through docker's embedded DNS inside the kind
network and is in the API server cert SANs, so it is immune to container IP
drift.

### Running it

```sh
make kargo-cluster-demo
```

`tools/kargo-cluster-demo.sh` bumps `APP_VERSION` in the orders base (the
same knob as pipeline 1 — both warehouses watch `wip`, so the bump feeds both
pipelines; they are independent), waits for `cluster` Freight, auto-promotion
into `cluster-test`, verification (hub gate apps `ingress-nginx` and
`reflector` healthy at the new revision), then creates the `cluster-prod`
Promotion and waits until the workload cluster's `orders` deployment serves
the new version.

Notes:

- The hub gate's `argocd-update` checks a representative subset — every hub
  workload app reads the branch, but promotion health does not hinge on the
  heavyweight monitoring stack.
- `cluster-prod` Promotions execute on the workload cluster's shard
  controller, including their git steps — the shard reads the repo
  credentials from the Project namespace on the hub and pushes to GitHub
  itself. kubectl-created Promotions work unchanged: the hub's mutating
  webhook stamps the Stage's shard label onto them.
- A no-op promotion (apps/ tree unchanged on the branch) makes `git-commit`
  return `Skipped` — same caveat as pipeline 1.
- Next step once stable: switch the source branch `wip` → `main` (Warehouse
  subscriptions + the pinned control-plane refs + tf).
