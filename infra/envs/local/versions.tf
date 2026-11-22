terraform {
  required_version = "~> 1.17"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.73"
    }
  }

  # Local backend on purpose (STANDARDS §4): LocalStack state is throw-away.
  # Remote S3 + locking only when the AWS phase is approved.
}
