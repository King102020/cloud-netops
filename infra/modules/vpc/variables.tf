variable "name" {
  type        = string
  description = "VPC name, e.g. cnops-local-hq-vpc."

  validation {
    condition     = can(regex("^cnops-[a-z0-9]+-[a-z0-9-]+$", var.name))
    error_message = "Name must follow cnops-<env>-<resource> (STANDARDS §4)."
  }
}

variable "cidr_block" {
  type        = string
  description = "VPC CIDR, one /16 per site (docs/network-design.md §9.2)."

  validation {
    condition     = can(cidrhost(var.cidr_block, 0)) && startswith(var.cidr_block, "10.")
    error_message = "CIDR must be a valid RFC 1918 block inside 10.0.0.0/8."
  }
}

variable "domain_name" {
  type        = string
  description = "DNS suffix handed out by DHCP (same as on-prem)."
  default     = "cnops.internal"
}

variable "enable_internet_gateway" {
  type        = bool
  description = "Create an internet gateway. Only the hq VPC needs one."
  default     = false
}

variable "enable_flow_logs" {
  type        = bool
  description = "Send VPC flow logs to CloudWatch Logs."
  default     = true
}

variable "flow_log_retention_days" {
  type        = number
  description = "Days to keep flow logs."
  default     = 14

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365], var.flow_log_retention_days)
    error_message = "Must be a CloudWatch Logs retention value."
  }
}
