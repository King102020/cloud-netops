variable "name_prefix" {
  type        = string
  description = "Name prefix, e.g. cnops-local."

  validation {
    condition     = can(regex("^cnops-[a-z0-9]+$", var.name_prefix))
    error_message = "Prefix must be cnops-<env>."
  }
}

variable "amazon_side_asn" {
  type        = number
  description = "Private BGP ASN for the AWS side (used by the VPN)."
  default     = 64512

  validation {
    condition     = var.amazon_side_asn >= 64512 && var.amazon_side_asn <= 65534
    error_message = "Use a 16-bit private ASN (64512-65534)."
  }
}

variable "vpc_attachments" {
  type = map(object({
    vpc_id          = string
    subnet_ids      = list(string)
    route_table_ids = map(string)
    destinations    = list(string)
  }))
  description = <<-EOT
    Per site: the VPC, its dedicated TGW subnets (one per AZ), the VPC route
    tables that should point at the TGW, and the destination CIDRs to send there.
  EOT

  validation {
    condition     = alltrue([for a in var.vpc_attachments : length(a.subnet_ids) >= 1])
    error_message = "Each attachment needs at least one subnet."
  }
}

variable "default_route_attachment" {
  type        = string
  description = "Key of the attachment that gets 0.0.0.0/0 (the site with the internet exit), or null."
  default     = null
}
