# Kargo promotion (rendered configs, test → prod)

Minimal working example of Kargo-based promotion for the `orders` app,
following the **Rendered Configs** pattern on a single long-lived branch.

## What is promoted

A git commit on `wip` touching `apps/apps/orders/**`. The Kargo `Warehouse`
(project `kargo-default`) subscribes to the repo with those `includePaths` and
turns each qualifying commit into **Freight** — the unit of promotion. We
promote versions of the app's config sources, not images.

## Branches and folders — env vs stage

**Envs** (`envs/local`, `apps/*/envs/<env>`) describe *what a target looks
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
  `envs/local` overlay is the non-Kargo path and stays under `envs/`.

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
