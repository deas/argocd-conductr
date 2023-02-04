# Flux Conductr - GitOps Everything 🧪

The primary goal of this project is to excersize orchestration of components playing with Flux based [GitOps](https://gitops.tech). As such, I consider localhost experience (hence `kind` and maybe `k3s` soon) very important. Given that, some elements may be useful in CI context. Most things however, should play nice on bigger or even produtive environments as well.

A secondary goal is offering a playground for experimentation - still broadly scoped to Flux. At the moment, experimenation targets Terraform, Crossplane, Cilium and Knative - amongst other things. ;)

This repo is mostly based on [flux2-kustomize-helm-example](https://github.com/fluxcd/flux2-kustomize-helm-example). The docs over there should still be pretty accurate.

Generate encryption keys for ssh/gpg:

```shell
./script/gen-keys.sh
```
Add public deployment key to github. You may also want to disable github actions to start.
```
gh repo deploy-key add ...
```


## Bootrapping

There is a `terraform` + `kind` based bootstrap in [`tf`](./tf):

```shell
cp sample.tfvars terraform.tfvars
# Set proper values in terraform.tfvars
terraform apply
```
Alternatively, you can bootstrap or even upgrade an existing cluster (be sure to have current kube context set properly). Also, make sure `flux --version` shows desired version.

```sh
./scripts/flux-bootstrap.sh
```

## Known issues
- knative challenging (Some bits need `kustomize.toolkit.fluxcd.io/substitute: disabled` in our context, other things need tweaks to upstream yaml to play with GitOps "... configured")

## TODO
- Naming?
- Deduplicate/Dry things
- ~~Setup "envs" properly / remove literals~~
- Flux Dashboard?
- [Grafana/Prometheus](https://fluxcd.io/flux/guides/monitoring/)?
- Flagger? Rolling, Blue/Green, Canary?
- Validation ( -> Monitoring)
- local k3s (Speed?)
- Borrow bits from Tanzu?
- Manage github with `terraform`/crossplane
- bb scripting?
- `tfctl` app/`terraform` plan approval via ChatOps (Slack?)
- basic sops/lastpass/github key managment?
- ~~knative?~~
- contour appear to play with knative, kind and flux! (use from bitnami)
- provide tool to wipe (shipping) encrypted secrets
- default to auto update everything?
- ~~[Kind cluster with Cilium and no kube-proxy](https://medium.com/@charled.breteche/kind-cluster-with-cilium-and-no-kube-proxy-c6f4d84b5a9d)~~
