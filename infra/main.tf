terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

# Get current client configuration
data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.common_tags
}

# ADLS Gen2 Storage Account
resource "azurerm_storage_account" "adls_gen2" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true # Enable hierarchical namespace for ADLS Gen2
  
  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  tags = local.common_tags
}

# Storage containers for data lake zones
resource "azurerm_storage_data_lake_gen2_filesystem" "source" {
  name               = "source"
  storage_account_id = azurerm_storage_account.adls_gen2.id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "staging" {
  name               = "staging"
  storage_account_id = azurerm_storage_account.adls_gen2.id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "raw" {
  name               = "raw"
  storage_account_id = azurerm_storage_account.adls_gen2.id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "silver" {
  name               = "silver"
  storage_account_id = azurerm_storage_account.adls_gen2.id
}

resource "azurerm_storage_data_lake_gen2_filesystem" "gold" {
  name               = "gold"
  storage_account_id = azurerm_storage_account.adls_gen2.id
}

# Create directories from variable structure
resource "azurerm_storage_data_lake_gen2_path" "dynamic_source_dirs" {
  for_each = toset(var.directory_structure)
  
  path               = each.value
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.source.name
  storage_account_id = azurerm_storage_account.adls_gen2.id
  resource           = "directory"
}

resource "azurerm_storage_data_lake_gen2_path" "dynamic_staging_dirs" {
  for_each = toset(var.directory_structure)
  
  path               = each.value
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.staging.name
  storage_account_id = azurerm_storage_account.adls_gen2.id
  resource           = "directory"
}

resource "azurerm_storage_data_lake_gen2_path" "dynamic_raw_dirs" {
  for_each = toset(var.directory_structure)
  
  path               = each.value
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.raw.name
  storage_account_id = azurerm_storage_account.adls_gen2.id
  resource           = "directory"
}

resource "azurerm_storage_data_lake_gen2_path" "dynamic_silver_dirs" {
  for_each = toset(var.silver_zone_directory_structure)
  
  path               = each.value
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.silver.name
  storage_account_id = azurerm_storage_account.adls_gen2.id
  resource           = "directory"
}

resource "azurerm_storage_data_lake_gen2_path" "dynamic_gold_dirs" {
  for_each = toset(var.gold_zone_directory_structure)
  
  path               = each.value
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.gold.name
  storage_account_id = azurerm_storage_account.adls_gen2.id
  resource           = "directory"
}

# Azure Key Vault
resource "azurerm_key_vault" "main" {
  name                       = local.key_vault_name
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Create",
      "Get",
      "List",
      "Delete",
      "Update"
    ]

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Recover"
    ]

    certificate_permissions = [
      "Get",
      "List",
      "Create",
      "Delete",
      "Update"
    ]
  }

  tags = local.common_tags
}

# Azure Data Factory
resource "azurerm_data_factory" "main" {
  name                = local.data_factory_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Git configuration (optional - configure if git_repo_url is provided)
  dynamic "github_configuration" {
    for_each = var.git_repo_url != "" && can(regex("github.com", var.git_repo_url)) ? [1] : []
    content {
      account_name    = split("/", split("github.com/", var.git_repo_url)[1])[0]
      branch_name     = var.git_branch
      git_url         = var.git_repo_url
      repository_name = split("/", split("github.com/", var.git_repo_url)[1])[1]
      root_folder     = var.git_root_folder
    }
  }

  dynamic "vsts_configuration" {
    for_each = var.git_repo_url != "" && can(regex("dev.azure.com|visualstudio.com", var.git_repo_url)) ? [1] : []
    content {
      account_name    = split("/", var.git_repo_url)[3]
      branch_name     = var.git_branch
      project_name    = split("/", var.git_repo_url)[4]
      repository_name = split("/", var.git_repo_url)[5]
      root_folder     = var.git_root_folder
      tenant_id       = data.azurerm_client_config.current.tenant_id
    }
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# Grant ADF access to Key Vault
resource "azurerm_key_vault_access_policy" "adf_policy" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_data_factory.main.identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

# Grant ADF access to Storage Account
resource "azurerm_role_assignment" "adf_storage_blob_data_contributor" {
  scope                = azurerm_storage_account.adls_gen2.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_factory.main.identity[0].principal_id
}

# Store storage account connection string in Key Vault
resource "azurerm_key_vault_secret" "storage_connection_access_key" {
  name         = "storage-connection-access-key"
  value        = azurerm_storage_account.adls_gen2.primary_access_key
  key_vault_id = azurerm_key_vault.main.id
  depends_on = [azurerm_key_vault_access_policy.adf_policy]
}

# Assign Storage Account Contributor role to current user
resource "azurerm_role_assignment" "storage_account_contributor" {
  scope                = azurerm_storage_account.adls_gen2.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Random password generation for Synapse (if not provided)
resource "random_password" "synapse_admin_password" {
  count   = var.enable_synapse_workspace && var.synapse_admin_password == "" ? 1 : 0
  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric = true
}

# Create dedicated filesystem for Synapse workspace
resource "azurerm_storage_data_lake_gen2_filesystem" "synapse" {
  count              = var.enable_synapse_workspace ? 1 : 0
  name               = "synapse"
  storage_account_id = azurerm_storage_account.adls_gen2.id
}

# Azure Synapse Workspace
resource "azurerm_synapse_workspace" "main" {
  count                                = var.enable_synapse_workspace ? 1 : 0
  name                                 = "syn-${local.project_short}${local.project_short}${random_string.suffix.result}"
  resource_group_name                  = azurerm_resource_group.main.name
  location                             = azurerm_resource_group.main.location
  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.synapse[0].id

  sql_administrator_login          = var.synapse_admin_username
  sql_administrator_login_password = var.synapse_admin_password != "" ? var.synapse_admin_password : random_password.synapse_admin_password[0].result

  # Enable managed identity
  identity {
    type = "SystemAssigned"
  }

  # Azure AD admin (uses current user)
  aad_admin {
    login     = data.azurerm_client_config.current.object_id
    object_id = data.azurerm_client_config.current.object_id
    tenant_id = data.azurerm_client_config.current.tenant_id
  }

  # Public network access
  public_network_access_enabled = true

  tags = local.common_tags
}

# Synapse Spark Pool for Delta Lake operations
resource "azurerm_synapse_spark_pool" "main" {
  count                = var.enable_synapse_workspace && var.enable_synapse_spark_pool ? 1 : 0
  spark_version        = "3.3"
  name                 = "sparkpool"
  synapse_workspace_id = azurerm_synapse_workspace.main[0].id
  node_size_family     = "MemoryOptimized"
  node_size            = "Small"  # 4 vCores, 32 GB RAM
  auto_scale {
    max_node_count = 5
    min_node_count = 3
  }

  auto_pause {
    delay_in_minutes = 15
  }

  # Delta Lake and other libraries
  library_requirement {
    content  = <<EOF
delta-spark==2.4.0
pandas==1.5.3
numpy==1.24.3
pyarrow==12.0.1
matplotlib==3.7.1
seaborn==0.12.2
requests==2.31.0
azure-storage-file-datalake==12.12.0
EOF
    filename = "requirements.txt"
  }

  tags = local.common_tags
}

# Grant Synapse Workspace access to ADLS Gen2 Storage Account
resource "azurerm_role_assignment" "synapse_storage_blob_data_contributor" {
  count                = var.enable_synapse_workspace ? 1 : 0
  scope                = azurerm_storage_account.adls_gen2.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_synapse_workspace.main[0].identity[0].principal_id
}

# Additional role for Delta Lake operations (needed for ACID operations)
resource "azurerm_role_assignment" "synapse_storage_blob_data_owner" {
  count                = var.enable_synapse_workspace ? 1 : 0
  scope                = azurerm_storage_account.adls_gen2.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_synapse_workspace.main[0].identity[0].principal_id
}

# Grant Synapse access to Key Vault
resource "azurerm_key_vault_access_policy" "synapse_policy" {
  count        = var.enable_synapse_workspace ? 1 : 0
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_synapse_workspace.main[0].identity[0].principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

# Grant current user access to Synapse workspace (ADD DEPENDENCY)
# resource "azurerm_synapse_role_assignment" "current_user_workspace_admin" {
#   count                = var.enable_synapse_workspace ? 1 : 0
#   synapse_workspace_id = azurerm_synapse_workspace.main[0].id
#   role_name           = "Synapse Administrator"
#   principal_id        = data.azurerm_client_config.current.object_id
  
#   # Add dependency to ensure firewall rules are created first
#   depends_on = [
#     azurerm_synapse_firewall_rule.allow_azure_services
#   ]
# }

# Firewall rule to allow Azure services
resource "azurerm_synapse_firewall_rule" "allow_azure_services" {
  count                = var.enable_synapse_workspace ? 1 : 0
  name                 = "AllowAllWindowsAzureIps"  # <- FIXED: Correct name
  synapse_workspace_id = azurerm_synapse_workspace.main[0].id
  start_ip_address     = "0.0.0.0"
  end_ip_address       = "0.0.0.0"
}

# # Allow current IP address (FIXED: Use actual current IP)
# resource "azurerm_synapse_firewall_rule" "allow_current_ip" {
#   count                = var.enable_synapse_workspace ? 1 : 0
#   name                 = "AllowCurrentIP"
#   synapse_workspace_id = azurerm_synapse_workspace.main[0].id
#   start_ip_address     = local.current_ip  # <- FIXED: Use actual IP
#   end_ip_address       = local.current_ip  # <- FIXED: Use actual IP
# }

# Store Synapse credentials in Key Vault
resource "azurerm_key_vault_secret" "synapse_admin_password" {
  count        = var.enable_synapse_workspace ? 1 : 0
  name         = "synapse-admin-password"
  value        = var.synapse_admin_password != "" ? var.synapse_admin_password : random_password.synapse_admin_password[0].result
  key_vault_id = azurerm_key_vault.main.id
  
  depends_on = [azurerm_key_vault_access_policy.adf_policy]
}

resource "azurerm_key_vault_secret" "synapse_connection_string" {
  count        = var.enable_synapse_workspace ? 1 : 0
  name         = "synapse-connection-string"
  value        = "Server=tcp:${azurerm_synapse_workspace.main[0].name}.sql.azuresynapse.net,1433;Database=master;User ID=${var.synapse_admin_username};Password=${var.synapse_admin_password != "" ? var.synapse_admin_password : random_password.synapse_admin_password[0].result};Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  key_vault_id = azurerm_key_vault.main.id
  
  depends_on = [azurerm_key_vault_access_policy.adf_policy]
}

# Store storage account connection info for Synapse
resource "azurerm_key_vault_secret" "storage_account_name" {
  name         = "storage-account-name"
  value        = azurerm_storage_account.adls_gen2.name
  key_vault_id = azurerm_key_vault.main.id
  
  depends_on = [azurerm_key_vault_access_policy.adf_policy]
}

resource "azurerm_key_vault_secret" "storage_account_dfs_endpoint" {
  name         = "storage-account-dfs-endpoint"
  value        = azurerm_storage_account.adls_gen2.primary_dfs_endpoint
  key_vault_id = azurerm_key_vault.main.id
  
  depends_on = [azurerm_key_vault_access_policy.adf_policy]
}