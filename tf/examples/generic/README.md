# terraform argocd conductr example generic

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
| bootstrap\_olm | Should the cluster have OLM before ArgoCD? (Openshift like) | `bool` | `true` | no |
| bootstrap\_path | Path to and additional boostrap manifest. Use this to inject decryption secrets. | `list(string)` | `null` | no |
| containerd\_config\_patches | Containerd patches to apply to kind nodes | `list(string)` | `[]` | no |
| dns\_hosts | Additional Core DNS Entries we want in kind | `map(string)` | `null` | no |
| env | The environment key to use to kickoff the ArgoCD deployments. | `string` | `"kargo"` | no |
| extra\_mounts | Extra mount points we want in kind nodes | `list(map(string))` | `[]` | no |
| pod\_subnet | n/a | `string` | `"10.244.0.0/16"` | no |
| service\_subnet | n/a | `string` | `"10.96.0.0/12"` | no |

## Outputs

No outputs.

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
