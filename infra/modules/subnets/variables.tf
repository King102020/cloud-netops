variable "vpc_id" {
  type        = string
  description = "VPC to create the subnets in."
}

variable "name_prefix" {
  type        = string
  description = "Name prefix, e.g. cnops-local-hq. Subnets become <prefix>-<key>."

  validation {
    condition     = can(regex("^cnops-[a-z0-9]+-[a-z0-9]+$", var.name_prefix))
    error_message = "Prefix must be cnops-<env>-<site>."
  }
}

variable "subnets" {
  type = map(object({
    cidr_block        = string
    availability_zone = string
    tier              = string
  }))
  description = "Subnets keyed by <tier>-<az letter>, e.g. users-a. Tier = VLAN name in lower case."

  validation {
    condition     = alltrue([for s in var.subnets : can(cidrhost(s.cidr_block, 0))])
    error_message = "Every cidr_block must be a valid CIDR."
  }

  validation {
    condition = alltrue([
      for s in var.subnets : contains(["public", "users", "servers", "mgmt", "tgw"], s.tier)
    ])
    error_message = "tier must be one of public, users, servers, mgmt, tgw."
  }
}

variable "internet_gateway_id" {
  type        = string
  description = "Internet gateway for the public tier's default route, or null."
  default     = null
}

variable "create_public_default_route" {
  type        = bool
  description = "Add 0.0.0.0/0 -> internet_gateway_id to the public tier. Needs a public tier."
  default     = false
}

variable "nat_gateway_subnet_key" {
  type        = string
  description = "Key of the public subnet that hosts the NAT gateway, or null for no NAT."
  default     = null
}

variable "nat_route_tiers" {
  type        = list(string)
  description = "Tiers whose default route goes to the NAT gateway."
  default     = []
}
