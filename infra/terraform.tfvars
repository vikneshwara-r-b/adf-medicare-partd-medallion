project_name = "medicaredatapipeline"
environment = "dev"
location = "East US"
git_repo_url = "https://github.com/vikneshwara-r-b/adf-medicare-partd-medallion"
git_branch = "main"
directory_structure = [
    "geography_and_drug",
    "prescriber_by_provider",
    "provider_and_drug"
]
silver_zone_directory_structure = [ 
    "silver_providers_cleaned",
    "silver_drugs_standardized",
    "silver_prescriptions_validated",
    "silver_geography_reference"
]
gold_zone_directory_structure = [ 
    "gold_provider_performance_metrics",
    "gold_drug_market_analysis",
    "gold_market_geography_insights",
    "gold_therapeutic_area_trends"
]