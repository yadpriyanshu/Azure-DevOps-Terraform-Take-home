terraform {
  required_version = ">= 1.3.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
  }
}

provider "azurerm" {
  features {}

  # NOTE:
  # We intentionally do NOT set subscription details here, as you are not
  # expected to run `terraform apply` for this exercise.
  #
  # In a real setup you might set:
  # - subscription_id
  # - tenant_id
  # - client_id / client_secret (or use managed identities)
}

data "azurerm_client_config" "current" {}

locals {
  # Map environment to realm, used for naming and tags.
  realm_by_env = {
    dev  = "shire"
    prod = "gondor"
  }

  realm = local.realm_by_env[var.environment]

  vnet_address_space_by_env = {
    dev  = "10.10.0.0/16"
    prod = "10.20.0.0/16"
  }

  vnet_address_space = local.vnet_address_space_by_env[var.environment]

  subnet_address_prefixes_by_env = {
    dev  = "10.10.1.0/24"
    prod = "10.20.1.0/24"
  }

  subnet_address_prefixes = local.subnet_address_prefixes_by_env[var.environment]

  common_tags = merge(
    var.tags,
    {
      environment = var.environment
      realm       = local.realm
    }
  )
}

# -----------------------------
# Resource Group
# -----------------------------

resource "azurerm_resource_group" "middleearth" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location

  tags = local.common_tags
}

# -----------------------------
# Networking (VNet + Subnet)
# -----------------------------

resource "azurerm_virtual_network" "middleearth" {
  name                = "vnet-${local.realm}-${var.environment}"
  resource_group_name = azurerm_resource_group.middleearth.name
  address_space       = [local.vnet_address_space]
  location            = azurerm_resource_group.middleearth.location
  tags                = local.common_tags
}

resource "azurerm_subnet" "shire_app" {
  name                 = "snet-${local.realm}-app-${var.environment}"
  resource_group_name  = azurerm_resource_group.middleearth.name
  virtual_network_name = azurerm_virtual_network.middleearth.name
  address_prefixes     = [local.subnet_address_prefixes]
}

# -----------------------------
# App Service Plan + App
# -----------------------------

resource "azurerm_app_service_plan" "shire_plan" {
  name                = "asp-${local.realm}-${var.environment}"
  resource_group_name = azurerm_resource_group.middleearth.name
  location            = azurerm_resource_group.middleearth.location

  kind = "Linux"

  sku {
    tier = "Basic"
    size = "B1"
  }

  tags = local.common_tags
}

resource "azurerm_app_service" "shire_api" {
  name                = "app-${local.realm}-api-${var.environment}"
  resource_group_name = azurerm_resource_group.middleearth.name
  location            = azurerm_resource_group.middleearth.location
  app_service_plan_id = azurerm_app_service_plan.shire_plan.id

  https_only = true

  site_config {
    linux_fx_version = "DOTNETCORE|8.0"
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = merge(
    {
      "WEBSITE_RUN_FROM_PACKAGE" = "1"
      "REALM"                    = local.realm
      "ENVIRONMENT"              = var.environment
    },
    var.database_connection_string != null ? {
      "ConnectionStrings__Database" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault.one_ring.vault_uri}secrets/${azurerm_key_vault_secret.db_connection[0].name}/)"
    } : {}
  )

  tags = local.common_tags
}

# -----------------------------
# Managed Identity (optional)
# -----------------------------

# NOTE:
# We include this as a placeholder for a user-assigned identity if you
# prefer that pattern. You can either:
#  - Complete and use this identity with App Service, OR
#  - Stick to the system-assigned identity on the App Service.
#
# In either case, make sure the Key Vault access policy is correct.

resource "azurerm_user_assigned_identity" "shire_api" {
  name                = "uai-${local.realm}-api-${var.environment}"
  resource_group_name = azurerm_resource_group.middleearth.name
  location            = azurerm_resource_group.middleearth.location

  tags = local.common_tags
}

# -----------------------------
# Key Vault (One Ring)
# -----------------------------

resource "azurerm_key_vault" "one_ring" {
  name                = "kv-${local.realm}-one-ring-${var.environment}"
  resource_group_name = azurerm_resource_group.middleearth.name
  location            = azurerm_resource_group.middleearth.location
  sku_name            = "standard"
  tenant_id           = data.azurerm_client_config.current.tenant_id

  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [azurerm_subnet.shire_app.id]
  }

  purge_protection_enabled   = false
  soft_delete_retention_days = 7

  tags = local.common_tags
}

resource "azurerm_key_vault_secret" "db_connection" {
  count        = var.database_connection_string != null ? 1 : 0
  name         = "ConnectionStrings--Database"
  value        = var.database_connection_string
  key_vault_id = azurerm_key_vault.one_ring.id

  tags = local.common_tags
}

resource "azurerm_key_vault_access_policy" "shire_api" {
  key_vault_id = azurerm_key_vault.one_ring.id

  tenant_id = data.azurerm_client_config.current.tenant_id
  object_id = azurerm_app_service.shire_api.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

# -----------------------------
# Dev/prod split
# -----------------------------
#
# Dev (Shire) and prod (Gondor) are supported via var.environment with separate
# state files or workspaces (e.g. terraform plan -var-file=prod.tfvars). Naming
# and CIDRs are driven by locals. To run multiple environments in one config,
# consider a for_each over environments or a small module.
