variable "environment" {
  description = "Deployment environment, e.g. dev (Shire) or prod (Gondor)."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be one of: dev, prod."
  }
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "uksouth"
}

variable "project_name" {
  description = "Logical project name used for naming resources."
  type        = string
  default     = "middleearth"
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default = {
    project     = "middleearth"
    managed_by  = "adroit"
    cost_centre = "fellowship"
  }
}

variable "database_connection_string" {
  description = "Database connection string stored in Key Vault. In production, set via pipeline or Key Vault (e.g. CI secret); App Service reads it via Key Vault reference."
  type        = string
  sensitive   = true
  default     = null
}
