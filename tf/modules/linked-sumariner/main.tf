
resource "helm_release" "main" {
  name       = var.name
  repository = var.repository
  chart      = var.name
  version    = var.chart_version
  namespace  = var.namespace
  values     = var.values
}

