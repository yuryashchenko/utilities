variable "app_id" {
  description = "Azure Service Principal Application ID"
}

variable "onepassword_vault_name" {
  description = "1Password Vault Name"
}

variable "onepassword_login_name" {
  description = "1Password login name"

}

variable "sync_settings_map" {
  description = "Map of sync settings"
  type        = map(string)
}

variable "attribute_mappings" {
  description = "Map of attribute mappings specific to IAG and application"
  type        = map(string)
}

variable "sync_job_template_id" {
  description = "Sync job template ID. Should be used only if you need to override the default one set by vendor on Entra ID"
  default     = ""
}

variable "synchronization_job_enabled" {
  description = "Enable synchronization job by default"
  type        = bool
  default     = "false"
}

variable "users_filter" {
  description = "Filter to apply to users in the SCIM API"
  type = list(object({
    name = string
    clauses = list(object({
      operatorName      = string
      sourceOperandName = string
      targetOperand = object({
        values = list(string)
      })
    }))
  }))
  default = []
}