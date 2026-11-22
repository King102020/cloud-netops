# LocalStack ONLY. Every endpoint is pinned to var.localstack_endpoint (which
# is validated to be a local address) and the keys are LocalStack's dummy
# "test" values, so even a plain `terraform apply` here cannot reach real AWS
# (STANDARDS §0, ADR 0001). `lstk terraform` works on top of this too.
provider "aws" {
  region = var.region

  # checkov:skip=CKV_AWS_41: LocalStack dummy credentials, not secrets.
  access_key = "test"
  secret_key = "test"

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    cloudwatchlogs = var.localstack_endpoint
    dynamodb       = var.localstack_endpoint
    ec2            = var.localstack_endpoint
    iam            = var.localstack_endpoint
    route53        = var.localstack_endpoint
    sts            = var.localstack_endpoint
  }

  default_tags {
    tags = local.tags
  }
}
