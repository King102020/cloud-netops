variable "name_prefix" {
  type        = string
  description = "Name prefix, e.g. cnops-local."
}

variable "transit_gateway_id" {
  type        = string
  description = "TGW the VPN terminates on."
}

variable "transit_gateway_route_table_id" {
  type        = string
  description = "TGW route table to associate the VPN with and add on-prem routes to."
}

variable "customer_gateway_ip" {
  type        = string
  description = "Public IP of hq-edge-01 (203.0.113.2 in the design; TEST-NET-3)."

  validation {
    condition     = can(cidrhost("${var.customer_gateway_ip}/32", 0))
    error_message = "Must be an IPv4 address."
  }
}

variable "customer_bgp_asn" {
  type        = number
  description = "On-prem BGP ASN (required by AWS even for static routing)."
  default     = 65010
}

variable "tunnel_inside_cidrs" {
  type        = list(string)
  description = "Two /30s from 169.254.10.0/24 (design §2) for the tunnels."
  default     = ["169.254.10.0/30", "169.254.10.4/30"]

  validation {
    condition = length(var.tunnel_inside_cidrs) == 2 && alltrue([
      for c in var.tunnel_inside_cidrs : startswith(c, "169.254.") && endswith(c, "/30")
    ])
    error_message = "Need exactly two /30s inside 169.254.0.0/16."
  }
}

variable "onprem_cidrs" {
  type        = list(string)
  description = "On-prem site blocks reachable over the VPN."
  default     = ["10.10.0.0/16", "10.20.0.0/16", "10.30.0.0/16"]
}
