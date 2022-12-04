# Fetching the current Azure client configuration
data "azuread_client_config" "current" {}

# Generating a random UUID to assign to the role assignment later
resource "random_uuid" "msiam_access" {}

# Fetching the Azure AD group
data "azuread_group" "aad_group" {
    display_name     = var.aad_group_name
    security_enabled = true
}

# Fetching the specified Azure AD Gallery application
data "azuread_application_template" "app_template" {
    display_name = var.app_gallery_name
}

# Creating the application
resource "azuread_application" "app" {
    display_name    = var.display_name
    template_id     = data.azuread_application_template.app_template.template_id
    identifier_uris = var.identifier_uris
    web {
        homepage_url  = var.homepage_url
        redirect_uris = var.redirect_uris
        implicit_grant {
            access_token_issuance_enabled = false
            id_token_issuance_enabled     = true
        }
    }
    app_role {
        allowed_member_types = ["User"]
        description          = "SSO user for the application {var.display_name}"
        display_name         = "{var.aad_group_name}"
        enabled              = true
        value                = "{var.aad_group_name}"
        id                   = random_uuid.msiam_access.result
    }
}

# Creating an Enterprise application(service principal) from the application
resource "azuread_service_principal" "sp" {
    application_id                = azuread_application.app.application_id
    preferred_single_sign_on_mode = "saml"
    app_role_assignment_required  = True
    login_url                     = var.login_url
}

# Assigning the users of the specified aad_group_name to the Enterprise application
resource "azuread_app_role_assignment" "role_assignment" {
    app_role_id = azuread_application.app.app_role_ids[random_uuid.msiam_access.result]
    principal_object_id = data.azuread_group.aad_group.object_id
    resource_object_id  = azuread_service_principal.sp.object_id
}
