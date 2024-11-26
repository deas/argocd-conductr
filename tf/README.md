# terraform infra for argocd conductr

## Usage
```shell
cp sample.tfvars terraform.tfvars
# Set proper values in terraform.tfvars
terraform apply
```
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| additional\_keys | Files to use to create secrets | `map(any)` | `{}` | no |
| argocd\_install | If/How to install ArgoCD | `string` | `"helm"` | no |
| bootstrap\_olm | Should the cluster have OLM before ArgoCD? (Openshift like) | `bool` | `true` | no |
| bootstrap\_path | Path to and additional boostrap manifest. Use this to inject decryption secrets. | `string` | `null` | no |
| broker\_secret\_get | The command to execute to obtain the submariner broker secret | `list(string)` | `[]` | no |
| cilium\_appset\_path | Path to the ArgoCD ApplicationSet to look up the Cilium Application. This is how we choose if we want the Cilium CNI in kind | `string` | `null` | no |
| cilium\_name | Cilium ArgoCD application name in case we are using ArgoCD managed Cilium | `string` | `"cilium"` | no |
| containerd\_config\_patches | Containerd patches to apply to kind nodes | `list(string)` | `[]` | no |
| dns\_hosts | Additional Core DNS Entries we want in kind | `map(string)` | `null` | no |
| env | The environment key to use to kickoff the ArgoCD deployments. | `string` | `"local"` | no |
| export\_ocm\_bootstrap\_secret | Whether we want export/output open cluster management secrets | `bool` | `false` | no |
| export\_submariner\_broker\_secret | Whether we want export/output submariner broker secrets | `bool` | `true` | no |
| extra\_mounts | Extra mount points we want in kind nodes | `list(map(string))` | `[]` | no |
| kind\_cluster\_image | The kind image to use | `string` | `"kindest/node:v1.31.0"` | no |
| kind\_cluster\_name | Cluster name | `string` | `"argocd-conductr"` | no |
| kubeconfig\_linked | kubeconfig file and context for a cluster linked to this one. | <pre>object({<br>    path    = string<br>    context = string<br>  })</pre> | `null` | no |
| kubeconfig\_path | Path to a kubeconfig file of a cluster to use instead of creating a kind instance. | `string` | `null` | no |
| metallb | If we want to use MetallLb on kind | `bool` | `false` | no |
| ocm\_bootstrap\_get | The command to execute to obtain the ocm bootstrapsecret | `list(string)` | `[]` | no |
| pod\_subnet | n/a | `string` | `"10.243.0.0/16"` | no |
| service\_subnet | n/a | `string` | `"10.95.0.0/12"` | no |

## Outputs

| Name | Description |
|------|-------------|
| broker | n/a |
| cluster | Object describing the whole created project |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->