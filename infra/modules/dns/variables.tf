variable "zone_name" {
  type        = string
  description = "Private zone name."
  default     = "cnops.internal"

  validation {
    condition     = endswith(var.zone_name, ".internal")
    error_message = "Use the ICANN-reserved .internal TLD for private zones."
  }
}

variable "vpc_ids" {
  type        = map(string)
  description = "VPCs to associate, keyed by site."

  validation {
    condition     = length(var.vpc_ids) >= 1
    error_message = "A private zone needs at least one VPC."
  }
}

variable "a_records" {
  type        = map(string)
  description = "A records: short name => IPv4 address."
  default     = {}
}
