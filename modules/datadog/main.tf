# Providers
terraform {
  #backend "s3" {
  #  bucket = "tqgg-terraform-state"
  #  #key            = "states/staging/datadog"
  #  region  = "eu-central-1"
  #  encrypt = true
  #  #dynamodb_table = "terraform-datadog-lock-staging"
  #}
  required_providers {
    datadog = {
      source = "DataDog/datadog"
    }
  }
}

variable "env" {
  type    = string
  default = "todo"
}

provider "datadog" {
  #   version = "2.8.0"
  #   api_url = var.datadog_api_url
  #   api_key = var.datadog_api_key
  #   app_key = var.datadog_app_key
}

resource "datadog_dashboard_json" "flux" {
  dashboard = templatefile("${path.module}/assets/dashboard-flux.json", {
    env = var.env
  })
}