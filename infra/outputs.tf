output "resource_group_name" {
  description = "Name of the Middle-earth resource group."
  value       = azurerm_resource_group.middleearth.name
}

output "shire_api_default_hostname" {
  description = "Default hostname for the Shire API App Service (dev)."
  value       = azurerm_app_service.shire_api.default_site_hostname
}

output "key_vault_name" {
  description = "Name of the One Ring Key Vault."
  value       = azurerm_key_vault.one_ring.name
}