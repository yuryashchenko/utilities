data "azuread_service_principal" "scim_sp" {
  client_id = var.app_id
}

data "onepassword_vault" "scim_vault" {
  name = var.onepassword_vault_name
}

data "onepassword_item" "login" {
  vault = split("/", data.onepassword_vault.scim_vault.id)[1]
  title = var.onepassword_login_name
}

# Using as replacement for azuread_synchronization_secret resource
# This resource is just a setting on the service principal.
# It cannot be destroyed, only updated or nulled
# Terraform destroy tries to set it to null, but it does not work getting API error
# So we need to use local-exec to update the credentials
# This is a workaround for the bug in Entra ID API

resource "terraform_data" "scim_creds" {
  input = {
    scim_settings = jsonencode(var.sync_settings_map),
    scim_url      = data.onepassword_item.login.username,
    scim_password = data.onepassword_item.login.password
    spid          = data.azuread_service_principal.scim_sp.object_id
  }

  triggers_replace = [
    jsonencode(var.sync_settings_map),
    data.onepassword_item.login.username,
    data.onepassword_item.login.password,
    data.azuread_service_principal.scim_sp.object_id
  ]

  provisioner "local-exec" {
    environment = {
      scim_settings     = jsonencode(var.sync_settings_map)
      scim_url          = data.onepassword_item.login.username
      scim_password     = data.onepassword_item.login.password
      delete_credential = false
      spid              = data.azuread_service_principal.scim_sp.object_id
    }
    interpreter = ["pwsh", "-File"]
    command     = "./${path.module}/scripts/Set-SCIM-Credentials.ps1"
  }
  provisioner "local-exec" {
    when = destroy
    environment = {
      delete_credential = true
      spid              = self.input.spid
    }
    interpreter = ["pwsh", "-File"]
    command     = "./${path.module}/scripts/Set-SCIM-Credentials.ps1"
  }
}


data "external" "template_id" {
  count = var.sync_job_template_id == "" ? 1 : 0
  program = ["pwsh",
    "./${path.module}/scripts/Get-TemplateID.ps1",
    data.azuread_service_principal.scim_sp.object_id
  ]
}

resource "azuread_synchronization_job" "scim-job" {
  service_principal_id = data.azuread_service_principal.scim_sp.id
  template_id          = var.sync_job_template_id == "" ? one(data.external.template_id).result["id"] : var.sync_job_template_id
  enabled              = var.synchronization_job_enabled
}

# we need this to update attribute mappings of the sync job
# for example replace UPN with email address
resource "terraform_data" "update_sync_job" {
  triggers_replace = [
    jsonencode(var.attribute_mappings),
    azuread_synchronization_job.scim-job.id,
    jsonencode(var.users_filter)
  ]

  provisioner "local-exec" {
    environment = {
      spoid        = data.azuread_service_principal.scim_sp.object_id
      json_attrs   = jsonencode(var.attribute_mappings)
      users_filter = jsonencode(var.users_filter)
    }
    interpreter = ["pwsh", "-File"]
    command     = "./${path.module}/scripts/SCIM-Schema-Update.ps1"
  }
  depends_on = [azuread_synchronization_job.scim-job]
}