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

resource "azurerm_storage_data_lake_gen2_path" "dynamic_raw_dirs" {
  for_each = toset(var.directory_structure)
  
  path               = each.value
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.raw.name
  storage_account_id = azurerm_storage_account.adls_gen2.id
  resource           = "directory"
}

resource "azurerm_storage_data_lake_gen2_path" "dynamic_silver_dirs" {
  for_each = toset(var.directory_structure)
  
  path               = each.value
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.silver.name
  storage_account_id = azurerm_storage_account.adls_gen2.id
  resource           = "directory"
}

resource "azurerm_storage_data_lake_gen2_path" "dynamic_gold_dirs" {
  for_each = toset(var.directory_structure)
  
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