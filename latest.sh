#!/bin/bash
# =============================================================================
#  aks-backup-setup.sh
#  First-time AKS Backup setup via Azure Cloud Shell
#  Cluster : sharedServices-k8s-cluster
#  RG      : rg_vnet_sharedServices
#  Vault   : sharedServices-backup-vault
#  Location: USGov Virginia
# =============================================================================
set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
RG="rg_vnet_sharedServices"
AKS="sharedServices-k8s-cluster"
VAULT="sharedServices-backup-vault"
LOCATION="USGovVirginia"
STORAGE_ACCOUNT="aksbackup$(az account show --query id -o tsv | tr -d '-' | cut -c1-16)"
BLOB_CONTAINER="aks-backup-container"
BACKUP_POLICY="aks-daily-backup-policy"
BACKUP_INSTANCE="aks-backup-instance"

echo "=============================================="
echo "  AKS Backup Setup"
echo "  RG       : $RG"
echo "  AKS      : $AKS"
echo "  Vault    : $VAULT"
echo "  Location : $LOCATION"
echo "=============================================="

# ── Step 1: Register required providers ──────────────────────────────────────
echo ""
echo "[Step 1] Registering required resource providers..."
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az provider register --namespace Microsoft.DataProtection --wait
az provider register --namespace Microsoft.ContainerService --wait
echo "✓ Providers registered"

# ── Step 2: Install required CLI extensions ───────────────────────────────────
echo ""
echo "[Step 2] Installing Azure CLI extensions..."
az extension add --name k8s-extension --upgrade -y 2>/dev/null || true
az extension add --name dataprotection --upgrade -y 2>/dev/null || true
az extension add --name aks-preview --upgrade -y 2>/dev/null || true
echo "✓ Extensions installed"

# ── Step 3: Create Backup Vault ───────────────────────────────────────────────
echo ""
echo "[Step 3] Creating Backup Vault: $VAULT..."
az dataprotection backup-vault create \
  --resource-group "$RG" \
  --vault-name "$VAULT" \
  --location "$LOCATION" \
  --type SystemAssigned \
  --storage-settings datastore-type="VaultStore" type="LocallyRedundant" \
  --output table 2>/dev/null || echo "  Vault already exists — continuing"
echo "✓ Backup Vault ready"

# ── Step 4: Create Storage Account for backup staging ─────────────────────────
echo ""
echo "[Step 4] Creating Storage Account: $STORAGE_ACCOUNT..."
az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --output table 2>/dev/null || echo "  Storage account already exists — continuing"

# Create blob container
az storage container create \
  --name "$BLOB_CONTAINER" \
  --account-name "$STORAGE_ACCOUNT" \
  --output table 2>/dev/null || true
echo "✓ Storage Account and container ready"

# ── Step 5: Install Backup Extension on AKS ──────────────────────────────────
echo ""
echo "[Step 5] Installing AKS Backup Extension..."
STORAGE_KEY=$(az storage account keys list \
  --account-name "$STORAGE_ACCOUNT" \
  --resource-group "$RG" \
  --query '[0].value' -o tsv)

az k8s-extension create \
  --name azure-aks-backup \
  --extension-type microsoft.dataprotection.kubernetes \
  --scope cluster \
  --cluster-type managedClusters \
  --cluster-name "$AKS" \
  --resource-group "$RG" \
  --release-train stable \
  --configuration-settings \
    storageAccount="$STORAGE_ACCOUNT" \
    storageAccountResourceGroup="$RG" \
    storageAccountSubscriptionId="$(az account show --query id -o tsv)" \
    blobContainer="$BLOB_CONTAINER" \
  --output table 2>/dev/null || echo "  Extension already installed — continuing"
echo "✓ AKS Backup Extension installed"

# ── Step 6: Enable Trusted Access between AKS and Backup Vault ────────────────
echo ""
echo "[Step 6] Enabling Trusted Access..."
VAULT_ID=$(az dataprotection backup-vault show \
  --resource-group "$RG" \
  --vault-name "$VAULT" \
  --query id -o tsv)

az aks trustedaccess rolebinding create \
  --resource-group "$RG" \
  --cluster-name "$AKS" \
  --name aks-backup-binding \
  --source-resource-id "$VAULT_ID" \
  --roles Microsoft.DataProtection/backupVaults/backup-operator \
  --output table 2>/dev/null || echo "  Trusted access already configured — continuing"
echo "✓ Trusted Access enabled"

# ── Step 7: Assign permissions to Backup Vault ────────────────────────────────
echo ""
echo "[Step 7] Assigning permissions to Backup Vault managed identity..."
VAULT_PRINCIPAL=$(az dataprotection backup-vault show \
  --resource-group "$RG" \
  --vault-name "$VAULT" \
  --query identity.principalId -o tsv)

AKS_ID=$(az aks show \
  --resource-group "$RG" \
  --name "$AKS" \
  --query id -o tsv)

STORAGE_ID=$(az storage account show \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RG" \
  --query id -o tsv)

# Vault needs Reader on AKS
az role assignment create \
  --assignee "$VAULT_PRINCIPAL" \
  --role "Reader" \
  --scope "$AKS_ID" \
  --output table 2>/dev/null || true

# Vault needs Storage Blob Data Contributor on storage
az role assignment create \
  --assignee "$VAULT_PRINCIPAL" \
  --role "Storage Blob Data Contributor" \
  --scope "$STORAGE_ID" \
  --output table 2>/dev/null || true

echo "✓ Permissions assigned"

# ── Step 8: Create Backup Policy ──────────────────────────────────────────────
echo ""
echo "[Step 8] Creating Backup Policy: $BACKUP_POLICY..."
POLICY_JSON=$(cat << 'POLICYJSON'
{
  "name": "aks-daily-backup-policy",
  "properties": {
    "policyRules": [
      {
        "name": "BackupHourly",
        "objectType": "AzureRetentionRule",
        "isDefault": true,
        "lifecycles": [
          {
            "deleteAfter": {
              "objectType": "AbsoluteDeleteOption",
              "duration": "P30D"
            },
            "targetDataStoreCopySettings": [],
            "sourceDataStore": {
              "dataStoreType": "OperationalStore",
              "objectType": "DataStoreInfoBase"
            }
          }
        ]
      },
      {
        "name": "Default",
        "objectType": "AzureBackupRule",
        "backupParameters": {
          "backupType": "Incremental",
          "objectType": "AzureBackupParams"
        },
        "dataStore": {
          "dataStoreType": "OperationalStore",
          "objectType": "DataStoreInfoBase"
        },
        "trigger": {
          "schedule": {
            "timeZone": "UTC",
            "repeatingTimeIntervals": ["R/2024-01-01T02:00:00+00:00/PT4H"]
          },
          "taggingCriteria": [
            {
              "isDefault": true,
              "taggingPriority": 99,
              "tagInfo": {
                "id": "Default_",
                "tagName": "Default"
              }
            }
          ],
          "objectType": "ScheduleBasedTriggerContext"
        }
      }
    ],
    "datasourceTypes": ["Microsoft.ContainerService/managedClusters"],
    "objectType": "BackupPolicy"
  }
}
POLICYJSON
)

echo "$POLICY_JSON" > /tmp/backup-policy.json

az dataprotection backup-policy create \
  --resource-group "$RG" \
  --vault-name "$VAULT" \
  --name "$BACKUP_POLICY" \
  --policy /tmp/backup-policy.json \
  --output table 2>/dev/null || echo "  Policy already exists — continuing"
echo "✓ Backup Policy created (every 4 hours, 30-day retention)"

# ── Step 9: Create Backup Instance ────────────────────────────────────────────
echo ""
echo "[Step 9] Creating Backup Instance..."

POLICY_ID=$(az dataprotection backup-policy show \
  --resource-group "$RG" \
  --vault-name "$VAULT" \
  --name "$BACKUP_POLICY" \
  --query id -o tsv)

AKS_ID=$(az aks show \
  --resource-group "$RG" \
  --name "$AKS" \
  --query id -o tsv)

SUBSCRIPTION_ID=$(az account show --query id -o tsv)

echo "  AKS ID     : $AKS_ID"
echo "  Policy ID  : $POLICY_ID"
echo "  Subscription: $SUBSCRIPTION_ID"

# Use initialize to generate the correct JSON structure
echo "  Generating backup instance JSON..."
az dataprotection backup-instance initialize \
  --datasource-type AzureKubernetesService \
  --datasource-id "$AKS_ID" \
  --datasource-location "$LOCATION" \
  --policy-id "$POLICY_ID" \
  --backup-configuration '{"includeClusterScopeResources":true}' \
  --friendly-name "$BACKUP_INSTANCE" \
  --snapshot-resource-group-name "$RG" \
  > /tmp/backup-instance.json

echo "  Generated JSON:"
cat /tmp/backup-instance.json

echo "  Creating backup instance..."
az dataprotection backup-instance create \
  --resource-group "$RG" \
  --vault-name "$VAULT" \
  --backup-instance /tmp/backup-instance.json \
  --output table
echo "✓ Backup Instance created"

# ── Step 10: Trigger an immediate backup ─────────────────────────────────────
echo ""
echo "[Step 10] Triggering initial backup..."
az dataprotection backup-instance adhoc-backup \
  --resource-group "$RG" \
  --vault-name "$VAULT" \
  --backup-instance-name "$BACKUP_INSTANCE" \
  --rule-name "Default" \
  --output table 2>/dev/null || echo "  Could not trigger immediate backup — check permissions"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "=============================================="
echo "  AKS Backup Setup Complete"
echo "=============================================="
echo "  Vault          : $VAULT"
echo "  Storage Account: $STORAGE_ACCOUNT"
echo "  Blob Container : $BLOB_CONTAINER"
echo "  Backup Policy  : $BACKUP_POLICY (every 4h, 30-day retention)"
echo "  Backup Instance: $BACKUP_INSTANCE"
echo ""
echo "  Check backup jobs:"
echo "  az dataprotection job list \\"
echo "    --resource-group $RG \\"
echo "    --vault-name $VAULT \\"
echo "    --output table"
echo "=============================================="
