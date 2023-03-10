# ArgoCD Conductr - GitOps Everything 🧪

This repo is mostly based on [flux-conductr](https://github.com/deas/flux-conductr).

The primary goal of this project is to excercize and experiment with [GitOps](https://gitops.tech) orchestration of components with ArgoCD. As such, I consider localhost experience (hence `kind` and maybe `k3s` soon) very important. Given that, some elements may be useful in CI context. Most things however, should play nice on bigger or even produtive environments as well.

I'm aiming to cover the most essential bits such as secret support and aggregration/composition + dependencies.


Generate encryption keys TODO:

```shell
./scripts/gen-keys.sh
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
make apply
```
should spin up an ArgoCD managed `kind` cluster.

## TODO
- Naming?
- Deduplicate/Dry things
- `terraform`? (just like in `tf-controller`)
- ~~basic sops/lastpass/github key managment?~~
- ~~default to auto update everything?~~
- Modularize metallb/pull IPAM from docker
- ~~Proper self management of ArgoCD~~
- Proper dependencies sync-waves, phases, `Application(Set)`
- ~~Extract modules to `deas/terraform-modules`~~
- Environment propagation
- Support for ksops + gpg
- Testing (`terratest`), linting, format enforcement via GH actions
- Try to make sense of olm in our context[redhat-na-ssa/demo-argocd-gitops](https://github.com/redhat-na-ssa/demo-argocd-gitops)

## Known issues
- [Wildcards in ArgoCD sourceNamespaces prevent resource creation ](https://github.com/argoproj-labs/argocd-operator/issues/849)


## References
- [viaduct-ai/kustomize-sops](https://github.com/viaduct-ai/kustomize-sops)
- [Introduction to GitOps with ArgoCD](https://blog.codecentric.de/gitops-argocd)
- [Self Managed Argo CD — App Of Everything](https://medium.com/devopsturkiye/self-managed-argo-cd-app-of-everything-a226eb100cf0)
- [Setting up Argo CD with Helm](https://www.arthurkoziel.com/setting-up-argocd-with-helm/)
- [terraform-argocd-bootstrap](https://github.com/iits-consulting/terraform-argocd-bootstrap)
- [ArgoCD with Kustomize and KSOPS using Age encryption](https://vikaspogu.dev/blog/argo-operator-ksops-age/)
- https://blog.devgenius.io/argocd-with-kustomize-and-ksops-2d43472e9d3b
- https://github.com/majinghe/argocd-sops
- https://dev.to/callepuzzle/secrets-in-argocd-with-sops-fc9
- [Argo CD Application Dependencies](https://codefresh.io/blog/argo-cd-application-dependencies/)
- [Progressive Syncs (alpha)](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Progressive-Syncs/)
