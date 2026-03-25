Get Backup Instance Name
bash# List all backup instances across all vaults
az dataprotection backup-instance list \
  --resource-group <YOUR_RG> \
  --vault-name <VAULT_NAME> \
  --query "[].{InstanceName:name, State:properties.currentProtectionState, Datasource:properties.dataSourceInfo.resourceName}" \
  -o table

Get Storage Account Name
bash# List all storage accounts in your resource group
az storage account list \
  --resource-group <YOUR_RG> \
  --query "[].{Name:name, Location:location, Kind:kind}" \
  -o table

# List all storage accounts across entire subscription
az storage account list \
  --query "[].{Name:name, ResourceGroup:resourceGroup, Location:location}" \
  -o table

Get Blob Container Name
bash# List containers in a specific storage account
az storage container list \
  --account-name <STORAGE_ACCOUNT_NAME> \
  --query "[].{Container:name}" \
  -o table

Get Everything in One Shot
bash#!/bin/bash
RG="<YOUR_RG>"
VAULT="<VAULT_NAME>"

echo "=== Backup Instances ==="
az dataprotection backup-instance list \
  --resource-group $RG \
  --vault-name $VAULT \
  --query "[].{InstanceName:name,State:properties.currentProtectionState}" \
  -o table

echo ""
echo "=== Storage Accounts ==="
az storage account list \
  --resource-group $RG \
  --query "[].{StorageAccount:name,Location:location}" \
  -o table

echo ""
echo "=== Backup Vaults ==="
az dataprotection backup-vault list \
  --resource-group $RG \
  --query "[].{VaultName:name,Location:location}" \
  -o table

If You Don't Know Your Resource Group
bash# List ALL resource groups
az group list --query "[].{Name:name, Location:location}" -o table

# Find AKS clusters across all RGs
az aks list --query "[].{Name:name, ResourceGroup:resourceGroup, Location:location}" -o table
Paste the output and I'll plug the exact values into your backup script.
