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
| additional\_keys | n/a | `map(any)` | `{}` | no |
| bootstrap\_path | bootstrap path | `string` | `null` | no |
| dns\_hosts | n/a | `map(string)` | `null` | no |
| enable\_olm | n/a | `bool` | `false` | no |
| extra\_mounts | n/a | `list(map(string))` | `[]` | no |
| kind\_cluster\_name | Cluster name | `string` | `"argocd-conductr"` | no |
| kubeconfig\_path | n/a | `string` | `null` | no |
| metallb | n/a | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster | Object describing the whole created project |

<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->