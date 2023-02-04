terraform {
  # We want this overriden by tf-controller
  backend "s3" {
    bucket = "contentreich-terraform"
    # key     = "states/${gitops_branch:=none}/datadog"
    # key = "states/local/hello"
    region  = "eu-west-1"
    encrypt = true
    #dynamodb_table = "terraform-datadog-lock-staging"
  }

  required_version = ">= 0.12.26"
}