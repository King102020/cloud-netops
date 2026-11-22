variable "region" {
  type        = string
  description = "AWS region (design: ap-south-1, Mumbai)."
  default     = "ap-south-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.region))
    error_message = "Must look like an AWS region, e.g. ap-south-1."
  }
}

variable "localstack_endpoint" {
  type        = string
  description = "LocalStack edge URL. Must be local: this env never talks to real AWS."
  default     = "http://localhost:4566"

  validation {
    condition = can(regex(
      "^https?://(localhost|127\\.0\\.0\\.1|localstack|host\\.docker\\.internal|localhost\\.localstack\\.cloud)(:[0-9]+)?/?$",
      var.localstack_endpoint
    ))
    error_message = "localstack_endpoint must be a local address (safety guard: no real AWS)."
  }
}

variable "owner" {
  type        = string
  description = "Value for the Owner tag."
  default     = "cloud-netops"
}

variable "managed_dir" {
  type        = string
  description = "Folder with API-managed JSON (firewall_rules.json, subnets.json). Git-ignored."
  default     = ".cnops"
}

variable "enable_vpn" {
  type        = bool
  description = "Create the site-to-site VPN to on-prem hq-edge-01."
  default     = true
}

variable "enable_flow_logs" {
  type        = bool
  description = "VPC flow logs to CloudWatch."
  default     = true
}
