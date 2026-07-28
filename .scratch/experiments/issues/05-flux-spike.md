# Try Flux as an alternative GitOps engine

Status: needs-triage

Spike [Flux](https://fluxcd.io) alongside Argo CD. Research and full mapping in
[docs/finding-flux-as-argo-cd-alternative.md](../../../docs/finding-flux-as-argo-cd-alternative.md)
— the layout plays (this repo has `flux-conductr` ancestry), so the shape would
be a new `envs/kind-flux` bootstrap flavor rather than a fork.

**Do this first, before anything else in the port:** take `ingress-nginx`
end-to-end in a throwaway `kind-flux` env and settle the one open question —
how to feed a remote Helm chart our two values overlays
(`apps/infra/ingress-nginx/values.yaml` + `envs/kind/values.yaml`), since Flux
`HelmRelease` has no equivalent to Argo CD's multi-source `$values`
([helm-controller#814](https://github.com/fluxcd/helm-controller/issues/814)).

Candidates to compare in the spike:

1. `ArtifactGenerator` + `ExternalArtifact` with `strategy: Merge` — closest to
   current behaviour, but beta (`source.extensions.fluxcd.io/v1beta1`) and needs
   the source-watcher extension controller.
2. `configMapGenerator` + `HelmRelease.spec.valuesFrom` — GA and boring, costs a
   ConfigMap per component plus explicit overlay ordering.

The answer decides whether the `values.yaml` + `envs/<class>/values.yaml`
overlay model survives the port or `apps/infra/` has to be restructured.
Everything else is mechanical.
