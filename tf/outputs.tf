output "cluster" {
  value = kind_cluster.default

  description = "Object describing the whole created project"
}

output "broker" {
  value = try(data.external.broker_secret[0].result, null)
}
