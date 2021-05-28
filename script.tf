terraform {
    backend "s3" {
        bucket         = "terraformcicd9200"
        access_key     = ""
        secret_key     = ""
        key            = "terraform.tfstate"
        region         = "us-east-2"
    }
}

terraform {
    required_providers {
        okta = {
            source = "okta/okta"
            version = "~> 3.10"
        }
    }
}

provider "okta" {
    org_name  = var.org_name
    base_url  = var.base_url
    api_token = var.api_token
}


# ? Resource to create APP
resource "okta_app_saml" "App" {
    label                    = var.application_name
    auto_submit_toolbar      = false
    hide_ios                 = false
    hide_web                 = false
    sso_url                  = var.sso_url
    recipient                = var.sso_url
    destination              = var.sso_url
    audience                 = var.audience_url
    idp_issuer               = "http://www.okta.com/$${org.externalKey}"
    subject_name_id_template = "$${user.userName}"
    subject_name_id_format   = "urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified"
    response_signed          = true
    request_compressed       = false
    signature_algorithm      = "RSA_SHA256"
    digest_algorithm         = "SHA256"
    honor_force_authn        = true
    authn_context_class_ref  = "urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport"

    attribute_statements {
        type         = "EXPRESSION"
        name         = "FirstName"
        namespace    = "urn:oasis:names:tc:SAML:2.0:attrname-format:unspecified"
        values       = [ "user.firstName" ]
    }

    attribute_statements {
        type         = "EXPRESSION"
        name         = "LastName"
        namespace    = "urn:oasis:names:tc:SAML:2.0:attrname-format:unspecified"
        values       = [ "user.lastName" ]
    }

    attribute_statements {
        type         = "EXPRESSION"
        name         = "UserName"
        namespace    = "urn:oasis:names:tc:SAML:2.0:attrname-format:unspecified"
        values       = [ "user.login" ]
    }

    attribute_statements {
        type         = "EXPRESSION"
        name         = "Email"
        namespace    = "urn:oasis:names:tc:SAML:2.0:attrname-format:unspecified"
        values       = [ "user.email" ]
    }

    attribute_statements {
        type         = "EXPRESSION"
        name         = "Role"
        namespace    = "urn:oasis:names:tc:SAML:2.0:attrname-format:unspecified"
        values       = [ "appuser.role" ]
    }

    attribute_statements {
        type         = "EXPRESSION"
        name         = "PrimaryAgency"
        namespace    = "urn:oasis:names:tc:SAML:2.0:attrname-format:unspecified"
        values       = [ "appuser.agency_num" ]
    }
}

# ? Ouptut Application Id 
output "application_id" {
    value = okta_app_saml.App.id
}

# ? Adding Custom attribute --> Role to created Application User Schema
# ? Visible at Directory --> Profile Editor --> Application --> View Profile
resource "okta_app_user_schema" "Role" {
    app_id      = okta_app_saml.App.id
    index       = "role"
    title       = "Role"
    type        = "string"
    scope       = "NONE"
    permissions = "READ_ONLY"
    master      = "PROFILE_MASTER"
}


# ? Adding Custom attribute --> AgencyNup to created Application User Schema
# ? Visible at Directory --> Profile Editor --> Application --> View Profile
# !!! Remember to add depends_on !!!
resource "okta_app_user_schema" "AgencyNup" {
    app_id      = okta_app_saml.App.id
    index       = "agencyNup"
    title       = "Agency Nup"
    type        = "string"
    scope       = "NONE"
    permissions = "READ_ONLY"
    master      = "PROFILE_MASTER"
    depends_on  = [
        okta_app_user_schema.Role
    ]
}


# ? Getting Data from Group named Agents
# !!! If there are no groups with the provided name this will throw an error !!!
data "okta_group" "Agents" {
    name = "Agents"
}

# ? Assigning Group --> Agents to created Application
resource "okta_app_group_assignment" "GroupAssignment" {
    app_id   = okta_app_saml.App.id
    group_id = data.okta_group.Agents.id
}


# ? Getting Data from UserType named Agent
# !!! If there are no UserType with the provided name this will throw an error !!!
# !!! There must be Custom Attributes Named --> ['Role', 'Agency Nup'] in this UserType Profile !!!
data "okta_user_type" "UserType" {
    name = "Agent"
}

# ? Ouptut User Type Id 
output "user_type_id" {
    value = data.okta_user_type.UserType.id
}


# ? Mapping Attributes from UserType --> App 
resource "okta_profile_mapping" "Mappings" {
    source_id          = data.okta_user_type.UserType.id
    target_id          = okta_app_saml.App.id

    mappings {
        id         = "role"
        expression = "user.role"
        push_status = "PUSH"
    }
    mappings {
        id         = "agencyNup"
        expression = "user.agencyNup"
        push_status = "PUSH"
    }
    depends_on = [
        okta_app_user_schema.Role,
        okta_app_user_schema.AgencyNup
    ]
}


#############################################

variable "org_name" {
    description = "Enter Orgranisation Name --> "
}

variable "base_url" {
    description = "Enter orgranisation base URL --> "
}

variable "api_token" {
    description = "Enter API Token --> "
}

variable "application_name" {
    description = "Enter Application Name --> "
}


variable "sso_url" {
    description = "Enter SSO URL --> "
}

variable "audience_url" {
    description = "Enter Audience url --> "
}
