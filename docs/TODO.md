# TODO

Tracked work items, grouped by area. Keep entries short and actionable; link
code/issues for context. See the
[open issues](https://github.com/deas/argocd-conductr/issues) for the full list
of proposed features and known issues.

## Argo CD & Rollouts

- [ ] Re-enable Rollouts UI — `server.enableRolloutsUI` is `false` in
      `../apps/infra/argo-cd/envs/kind-olm/argocd-argocd.yaml` as a workaround for an
      upstream regression; catch up with upstream and re-enable once fixed.
- [ ] Canary / blue-green deployments via Argo Rollouts
- [ ] Argo CD RBAC / multi-tenancy

## Promotion & GitOps workflow

- [ ] Environment propagation — try [Kargo](https://kargo.io)
- [ ] Try [argocd-diff-preview](https://github.com/dag-andersen/argocd-diff-preview)
- [ ] Proper cascaded removal (Argo CD torn down last; likely involves OpenTofu)

## OLM / Operators

- [ ] [Operator Controller should provide a standard install process](https://github.com/operator-framework/operator-controller/issues/1026)
- [ ] OLM-based OCM install still requires the [hub registration-operator](../apps/infra/registration-operator-hub) — investigate why
- [ ] Evaluate [managing operators with Argo CD](https://piotrminkowski.com/2023/05/05/manage-kubernetes-operators-with-argocd/)

## OpenShift

- [ ] Improve ad hoc task support (smart branching) for [OpenShift GitOps](https://github.com/redhat-developer/gitops-operator) — ns, secrets, and Ingress (login)
- [ ] Improve OpenShift harmonization (naming / namespaces)
- [ ] OpenShift proxy / global pull secrets, Ingress + API server certs, IDP integration
- [ ] Service-account-based OAuth on OpenShift — [Red Hat blog](https://cloud.redhat.com/blog/openshift-authentication-integration-with-argocd), [Dex connector](https://dexidp.io/docs/connectors/openshift)

## Multi-cluster (OCM / ACM)

- [ ] Compare Argo CD vs ACM / Open Cluster Management
- [ ] [OCM integration with Argo CD](https://open-cluster-management.io/docs/scenarios/integration-with-argocd/), [ocm solutions](https://github.com/open-cluster-management-io/ocm/tree/main/solutions)
- [ ] CSR auto-approval — introduce [`csr-approver`](https://github.com/deas/csr-approver) (ACM auto-approves; OSS approvers target cert-manager/kubelet only)

## Observability & monitoring

- [ ] Prometheus-based sync-failure alerts (see Known Issues)
- [ ] Prometheus takes too long to come up — investigate
- [ ] Notifications: sync alerts to Slack / Matrix
- [ ] Tracing (Zipkin / Tempo) + OpenTelemetry sample; evaluate Aspire dashboard (lightweight oTel)
- [ ] More Grafana dashboards / OpenShift Console plugin integration

## Networking

- [ ] Replace MetalLB with [`cloud-provider-kind`](https://github.com/kubernetes-sigs/cloud-provider-kind) on `kind`
- [ ] Evaluate Contour
- [ ] IPv6 with `crc` / kvm

## Auth & security

- [ ] Keycloak + SSO (local DNS trickery)

## CI & testing

- [ ] `kind`-based testing
- [ ] Improve unit / integration test coverage
- [ ] `kubeconform` in CI
- [ ] Improve GitHub Actions quality gates

## Tooling & DX

- [ ] Migrate `make` → `just`; dedupe / modularize `Makefile` / `Justfile`
- [ ] Go deeper with `nix` / `devenv` — maybe replace `mise`
- [ ] `opentofu` within Argo CD (à la `tf-controller`)
- [ ] Resolve the in-code `TODO` tags (they carry context)

## Experiments / evaluate

- [ ] Try [kro](https://kro.io)
- [ ] Crossplane
- [ ] Try [Argo CD Autopilot](https://argocd-autopilot.readthedocs.io/en/stable/)
- [ ] Customer use-case chaos demo — bring Litmus chaos bits to Argo CD (see [`deas/kaos`](https://github.com/deas/ka0s/))

## Done

- [x] Proper self-management of Argo CD
- [x] Default to auto-update everything
- [x] [Applications in any namespace](https://argo-cd.readthedocs.io/en/stable/operator-manual/app-any-namespace/)
- [x] GitOps time travel (tags / hashes)
- [x] OPA policies: Gatekeeper + usage in CI
- [x] Cilium
- [x] metrics-server
- [x] Argo CD Grafana dashboard
- [x] Argo CD ServiceMonitor (depends on Prometheus)
- [x] Helm job sample
