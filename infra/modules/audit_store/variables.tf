variable "name_prefix" {
  type        = string
  description = "Name prefix, e.g. cnops-local."

  validation {
    condition     = can(regex("^cnops-[a-z0-9]+$", var.name_prefix))
    error_message = "Prefix must be cnops-<env>."
  }
}

variable "deletion_protection" {
  type        = bool
  description = "Protect tables from deletion. Off locally so a reset is one command."
  default     = false
}
