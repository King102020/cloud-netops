variable "vpc_id" {
  type        = string
  description = "VPC the security groups and NACLs belong to."
}

variable "name_prefix" {
  type        = string
  description = "Name prefix, e.g. cnops-local-hq."

  validation {
    condition     = can(regex("^cnops-[a-z0-9]+-[a-z0-9]+$", var.name_prefix))
    error_message = "Prefix must be cnops-<env>-<site>."
  }
}

variable "tiers" {
  type        = set(string)
  description = "Workload tiers that get a security group (subset of users, servers, mgmt)."

  validation {
    condition     = length(setsubtract(var.tiers, ["users", "servers", "mgmt"])) == 0
    error_message = "tiers must be a subset of users, servers, mgmt."
  }
}

variable "users_cidrs" {
  type        = list(string)
  description = "USERS networks, on-prem and cloud (TO-SERVERS lines 30-50)."
}

variable "mgmt_cidrs" {
  type        = list(string)
  description = "MGMT networks, on-prem and cloud (MGMT-VTY)."
}

variable "subnet_ids_by_nacl" {
  type        = map(list(string))
  description = "Subnets per NACL, e.g. { private = [...], public = [...] }."
  default     = {}
}

variable "firewall_rules" {
  type = list(object({
    id          = string
    tier        = string
    protocol    = string
    from_port   = number
    to_port     = number
    cidr        = string
    description = string
  }))
  description = "Extra ingress rules managed by the control API."
  default     = []

  validation {
    condition     = alltrue([for r in var.firewall_rules : contains(["tcp", "udp", "icmp"], r.protocol)])
    error_message = "protocol must be tcp, udp or icmp."
  }

  validation {
    condition     = alltrue([for r in var.firewall_rules : can(cidrhost(r.cidr, 0)) && r.cidr != "0.0.0.0/0"])
    error_message = "cidr must be valid and not 0.0.0.0/0 (default deny, STANDARDS §2)."
  }

  validation {
    condition = alltrue([
      for r in var.firewall_rules :
      r.protocol == "icmp" || (r.from_port >= 1 && r.to_port <= 65535 && r.from_port <= r.to_port)
    ])
    error_message = "Ports must be 1-65535 with from_port <= to_port."
  }
}

variable "ephemeral_port_from" {
  type        = number
  description = "Start of the ephemeral range allowed back in through the NACLs (Linux uses 32768+)."
  default     = 32768

  validation {
    condition     = var.ephemeral_port_from > 3389 && var.ephemeral_port_from < 65535
    error_message = "Keep the range above well-known service ports (> 3389)."
  }
}
