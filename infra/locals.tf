locals {
  # Generate unique resource names using project, environment, and random suffix
  resource_suffix = random_string.suffix.result

  # Storage account name: max 24 chars, lowercase letters and numbers only
  # Truncate project name if needed to fit within limits
  project_short = substr(lower(replace(var.project_name, "/[^a-z0-9]/", "")), 0, 8)
  
  storage_account_name = "${local.project_short}${var.environment}sa"
  data_factory_name    = "adf-${var.project_name}-${var.environment}-${local.resource_suffix}"
  key_vault_name       = "kv-${local.project_short}-${var.environment}"
  resource_group_name  = "rg-${var.project_name}-${var.environment}"
  
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
  }
}

# Random string for unique naming
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}