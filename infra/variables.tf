variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "rg-data-platform"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

variable "storage_account_name" {
  description = "Name of the ADLS Gen2 storage account (must be globally unique)"
  type        = string
  default     = "adlsgen2storage"
}

variable "data_factory_name" {
  description = "Name of the Azure Data Factory"
  type        = string
  default     = "adf-data-platform"
}

variable "key_vault_name" {
  description = "Name of the Azure Key Vault (must be globally unique)"
  type        = string
  default     = "kv-data-platform"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for naming convention"
  type        = string
  default     = "dataplatform"
}

variable "git_repo_url" {
  description = "Git repository URL for ADF source control"
  type        = string
  default     = ""
}

variable "git_branch" {
  description = "Git branch for ADF collaboration"
  type        = string
  default     = "main"
}

variable "git_root_folder" {
  description = "Root folder in git repository for ADF artifacts"
  type        = string
  default     = "/"
}

variable "directory_structure" {
  description = "Directory structure for each filesystem"
  type = list(string)
  default = [
    "geography_and_drug",
    "prescriber_by_provider",
    "provider_and_drug"
  ]
}

variable "silver_zone_directory_structure" {
  description = "Directory structure for silver container"
  type = list(string)
  default = [ 
    "silver_providers_cleaned",
    "silver_drugs_standardized",
    "silver_prescriptions_validated",
    "silver_geography_reference"
  ]
}

variable "gold_zone_directory_structure" {
  description = "Directory structure for gold container"
  type = list(string)
  default = [ 
    "gold_provider_performance_metrics",
    "gold_drug_market_analysis",
    "gold_market_geography_insights",
    "gold_therapeutic_area_trends"
  ]
}
