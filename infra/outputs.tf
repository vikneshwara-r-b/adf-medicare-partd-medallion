output "resource_group_name" {
  description = "Name of the created resource group"
  value       = azurerm_resource_group.main.name
}

output "storage_account_name" {
  description = "Name of the ADLS Gen2 storage account"
  value       = azurerm_storage_account.adls_gen2.name
}

output "storage_account_primary_dfs_endpoint" {
  description = "Primary DFS endpoint of the storage account"
  value       = azurerm_storage_account.adls_gen2.primary_dfs_endpoint
}

output "data_factory_name" {
  description = "Name of the Azure Data Factory"
  value       = azurerm_data_factory.main.name
}

output "data_factory_identity" {
  description = "System assigned identity of the Data Factory"
  value       = azurerm_data_factory.main.identity[0].principal_id
}

output "key_vault_name" {
  description = "Name of the Azure Key Vault"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "URI of the Azure Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

output "storage_account_key" {
  description = "Storage Account Key value of the storage account"
  value       = azurerm_storage_account.adls_gen2.primary_access_key
  sensitive = true
}