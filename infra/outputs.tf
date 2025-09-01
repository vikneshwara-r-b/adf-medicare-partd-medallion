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

output "synapse_workspace_name" {
  description = "Name of the Azure Synapse Workspace"
  value       = var.enable_synapse_workspace ? azurerm_synapse_workspace.main[0].name : null
}

output "synapse_workspace_url" {
  description = "URL of the Azure Synapse Workspace"
  value       = var.enable_synapse_workspace ? "https://${azurerm_synapse_workspace.main[0].name}.dev.azuresynapse.net" : null
}

output "synapse_spark_pool_name" {
  description = "Name of the Synapse Spark Pool"
  value       = var.enable_synapse_workspace && var.enable_synapse_spark_pool ? azurerm_synapse_spark_pool.main[0].name : null
}

output "synapse_admin_username" {
  description = "Synapse SQL Administrator username"
  value       = var.enable_synapse_workspace ? var.synapse_admin_username : null
}

output "delta_lake_connection_info" {
  description = "Connection information for Delta Lake operations"
  value = var.enable_synapse_workspace ? {
    storage_account_name = azurerm_storage_account.adls_gen2.name
    dfs_endpoint        = azurerm_storage_account.adls_gen2.primary_dfs_endpoint
    filesystems = {
      source  = azurerm_storage_data_lake_gen2_filesystem.source.name
      staging = azurerm_storage_data_lake_gen2_filesystem.staging.name
      raw     = azurerm_storage_data_lake_gen2_filesystem.raw.name
      silver  = azurerm_storage_data_lake_gen2_filesystem.silver.name
      gold    = azurerm_storage_data_lake_gen2_filesystem.gold.name
    }
    delta_paths = {
      raw_delta    = "abfss://raw@${azurerm_storage_account.adls_gen2.name}.dfs.core.windows.net/delta/"
      silver_delta = "abfss://silver@${azurerm_storage_account.adls_gen2.name}.dfs.core.windows.net/delta/"
      gold_delta   = "abfss://gold@${azurerm_storage_account.adls_gen2.name}.dfs.core.windows.net/delta/"
    }
  } : null
}

# output "synapse_query_examples" {
#   description = "Example queries and code for accessing Delta Lake tables from Synapse"
#   value = var.enable_synapse_workspace ? {
#     spark_configuration = "spark.conf.set(\"fs.azure.account.auth.type.${azurerm_storage_account.adls_gen2.name}.dfs.core.windows.net\", \"OAuth\")"
#     read_delta_table = "df = spark.read.format('delta').load('abfss://silver@${azurerm_storage_account.adls_gen2.name}.dfs.core.windows.net/delta/your_table/')"
#     serverless_sql_query = "SELECT * FROM OPENROWSET(BULK 'https://${azurerm_storage_account.adls_gen2.name}.dfs.core.windows.net/silver/delta/your_table/', FORMAT = 'DELTA') AS [result]"
#   } : null
# }