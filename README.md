# ArgoCD Conductr - GitOps Everything 🧪

This repo is mostly based on [flux-conductr](https://github.com/deas/flux-conductr).

The primary goal of this project is to exercise with ArgoCD based [GitOps](https://gitops.tech) deploymentcovering the full cycle - up to production via promotion, if you want to. Experimentation and production do not have to conflict.

The change process starts at localhost. Hence, we consider localhost experience (kind and maybe k3s soon) very important. Given that, some elements may be useful in CI context. Most things however, should play nice on produtive environments as well.

At the moment, we cover deployments of:
- Caretta
- Metallb
- Kube-Prometheus
- Loki/Promtail
- Flagger
- AWS Credentials Sync
- SOPS Secrets
- Argo-CD Image-Updater
- Argo rollouts
- Argo Events

## Bootrapping
Generate encryption keys TODO:

```shell
./scripts/gen-keys.sh
```

Optional: Add public deployment key to github. You may also want to disable github actions to start.
```
gh repo deploy-key add ...
```

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
- ~~default to auto update everything~~?
- ~~Proper self management of ArgoCD~~
- Proper dependencies sync-waves, phases, `Application(Set)`
- Environment propagation
- Try to make sense of olm in our context[redhat-na-ssa/demo-argocd-gitops](https://github.com/redhat-na-ssa/demo-argocd-gitops). Appears the basic reason for olm would be the fact that many off the shelf helm charts simply don't play with openshift because redhat is doing their own thing? [Manage Kubernetes Operators with ArgoCD](https://piotrminkowski.com/2023/05/05/manage-kubernetes-operators-with-argocd/)? No, honestly.
- Try [Argo-CD Autopilot](https://argocd-autopilot.readthedocs.io/en/stable/)
- Proper cascaded removal. ArgoCD should be last. Will likely involve terraform. 

## Known issues
- [Wildcards in ArgoCD sourceNamespaces prevent resource creation ](https://github.com/argoproj-labs/argocd-operator/issues/849)
- `argcocd` cli does not support apps with multiple sources.


## References
- [viaduct-ai/kustomize-sops](https://github.com/viaduct-ai/kustomize-sops)
- [Introduction to GitOps with ArgoCD](https://blog.codecentric.de/gitops-argocd)
- [3 patterns for deploying Helm charts with Argo CD](https://developers.redhat.com/articles/2023/05/25/3-patterns-deploying-helm-charts-argocd?sc_cid=7013a0000034Yq3AAE)
- [Self Managed Argo CD — App Of Everything](https://medium.com/devopsturkiye/self-managed-argo-cd-app-of-everything-a226eb100cf0)
- [Setting up Argo CD with Helm](https://www.arthurkoziel.com/setting-up-argocd-with-helm/)
- [terraform-argocd-bootstrap](https://github.com/iits-consulting/terraform-argocd-bootstrap)
- [ArgoCD with Kustomize and KSOPS using Age encryption](https://vikaspogu.dev/blog/argo-operator-ksops-age/)
- https://blog.devgenius.io/argocd-with-kustomize-and-ksops-2d43472e9d3b
- https://github.com/majinghe/argocd-sops
- https://dev.to/callepuzzle/secrets-in-argocd-with-sops-fc9
- [Argo CD Application Dependencies](https://codefresh.io/blog/argo-cd-application-dependencies/)
- [Progressive Syncs (alpha)](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Progressive-Syncs/)
