# Get storage account name from terraform output
storage_account_name=$(terraform output -raw storage_account_name)
echo $storage_account_name
storage_account_key=$(terraform output -raw storage_account_key)
echo $storage_account_key

# Upload single file
# az storage fs file upload \
#   --file-system source \
#   --account-name  $storage_account_name\
#   --source source_data/geography_and_drug/MUP_DPR_RY24_P04_V10_DY22_Geo.csv \
#   --path geography_and_drug/MUP_DPR_RY24_P04_V10_DY22_Geo.csv \
#   --account-key $storage_account_key


az storage fs file upload \
  --file-system source \
  --account-name  $storage_account_name\
  --source source_data/prescriber_by_provider/MUP_DPR_RY24_P04_V10_DY22_NPI.zip \
  --path prescriber_by_provider/MUP_DPR_RY24_P04_V10_DY22_NPI.zip \
  --account-key $storage_account_key \
  --timeout 1800

# az storage fs file upload \
#   --file-system source \
#   --account-name  $storage_account_name\
#   --source source_data/provider_and_drug/MUP_DPR_RY24_P04_V10_DY22_NPIBN.zip \
#   --path provider_and_drug/MUP_DPR_RY24_P04_V10_DY22_NPIBN.zip \
#   --account-key $storage_account_key \
#   --overwrite \
#   --timeout 1800