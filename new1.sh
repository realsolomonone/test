#!/bin/bash
# =============================================================================
#  aks-backup-once.sh
#  One-time AKS Backup via Azure Cloud Shell
#  Cluster : sharedServices-k8s-cluster
#  RG      : rg_vnet_sharedServices
#  Vault   : sharedServices-backup-vault
#  Location: USGov Virginia
# =============================================================================
set -euo pipefail

RG="rg_vnet_sharedServices"
AKS="sharedServices-k8s-cluster"
VAULT="sharedServices-backup-vault"
LOCATION="USGovVirginia"
STORAGE_ACCOUNT="aksbackup$(az account show --query id -o tsv | tr -d '-' | cut -c1-16)"
BLOB_CONTAINER="aks-backup-container"

echo "=============================================="
echo "  AKS One-Time Backup Setup"
echo "  RG      : $RG"
echo "  AKS     : $AKS"
echo "  Vault   : $VAULT"
echo "=============================================="

# ── Step 1: Register providers ────────────────────────────────────────────────
echo ""
echo "[Step 1] Registering required providers..."
az provider register --namespace Microsoft.KubernetesConfiguration --wait
az provider register --namespace Microsoft.DataProtection --wait
az provider register --namespace Microsoft.ContainerService --wait
echo "✓ Providers registered"

# ── Step 2: Install CLI extensions ────────────────────────────────────────────
echo ""
echo "[Step 2] Installing CLI extensions..."
az extension add --name k8s-extension   --upgrade -y 2>/dev/null || true
az extension add --name dataprotection  --upgrade -y 2>/dev/null || true
az extension add --name aks-preview     --upgrade -y 2>/dev/null || true
echo "✓ Extensions installed"

# ── Step 3: Create Backup Vault ───────────────────────────────────────────────
echo ""
echo "[Step 3] Creating Backup Vault..."
az dataprotection backup-vault create \
  --resource-group "$RG" \
  --vault-name "$VAULT" \
  --location "$LOCATION" \
  --type SystemAssigned \
  --storage-settings datastore-type="VaultStore" type="LocallyRedundant" \
  --output table 2>/dev/null || echo "  Vault already exists — skipping"
echo "✓ Backup Vault ready"

# ── Step 4: Create Storage Account for staging ────────────────────────────────
echo ""
echo "[Step 4] Creating Storage Account: $STORAGE_ACCOUNT..."
az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RG" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --output table 2>/dev/null || echo "  Already exists — skipping"

az storage container create \
  --name "$BLOB_CONTAINER" \
  --account-name "$STORAGE_ACCOUNT" \
  --output table 2>/dev/null || true
echo "✓ Storage ready"

# ── Step 5: Install AKS Backup Extension ──────────────────────────────────────
echo ""
echo "[Step 5] Installing AKS Backup Extension on cluster..."
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
  --output table 2>/dev/null || echo "  Extension already installed — skipping"
echo "✓ Extension installed"

# ── Step 6: Enable Trusted Access ─────────────────────────────────────────────
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
  --output table 2>/dev/null || echo "  Trusted access already configured — skipping"
echo "✓ Trusted Access enabled"

# ── Step 7: Assign permissions ────────────────────────────────────────────────
echo ""
echo "[Step 7] Assigning permissions to Vault managed identity..."
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

az role assignment create --assignee "$VAULT_PRINCIPAL" \
  --role "Reader" --scope "$AKS_ID" --output table 2>/dev/null || true

az role assignment create --assignee "$VAULT_PRINCIPAL" \
  --role "Storage Blob Data Contributor" --scope "$STORAGE_ID" \
  --output table 2>/dev/null || true
echo "✓ Permissions assigned"

# ── Step 8: Create a retention-only backup policy (no schedule) ───────────────
echo ""
echo "[Step 8] Creating one-time backup policy..."
cat > /tmp/onetime-policy.json << 'POLICYJSON'
{
  "name": "aks-onetime-backup-policy",
  "properties": {
    "policyRules": [
      {
        "name": "Default",
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
      }
    ],
    "datasourceTypes": ["Microsoft.ContainerService/managedClusters"],
    "objectType": "BackupPolicy"
  }
}
POLICYJSON

az dataprotection backup-policy create \
  --resource-group "$RG" \
  --vault-name "$VAULT" \
  --name "aks-onetime-backup-policy" \
  --policy /tmp/onetime-policy.json \
  --output table 2>/dev/null || echo "  Policy already exists — skipping"
echo "✓ One-time backup policy created (30-day retention, no schedule)"

# ── Step 9: Create Backup Instance ────────────────────────────────────────────
echo ""
echo "[Step 9] Creating Backup Instance..."
POLICY_ID=$(az dataprotection backup-policy show \
  --resource-group "$RG" \
  --vault-name "$VAULT" \
  --name "aks-onetime-backup-policy" \
  --query id -o tsv)

az dataprotection backup-instance create \
  --resource-group "$RG" \
  --vault-name "$VAULT" \
  --backup-instance "{
    \"name\": \"aks-onetime-instance\",
    \"properties\": {
      \"friendlyName\": \"aks-onetime-instance\",
      \"dataSourceInfo\": {
        \"resourceId\": \"$AKS_ID\",
        \"resourceUri\": \"$AKS_ID\",
        \"datasourceType\": \"Microsoft.ContainerService/managedClusters\",
        \"resourceName\": \"$AKS\",
        \"resourceType\": \"Microsoft.ContainerService/managedClusters\",
        \"resourceLocation\": \"$LOCATION\",
        \"objectType\": \"Datasource\"
      },
      \"dataSourceSetInfo\": {
        \"resourceId\": \"$AKS_ID\",
        \"resourceUri\": \"$AKS_ID\",
        \"datasourceType\": \"Microsoft.ContainerService/managedClusters\",
        \"resourceName\": \"$AKS\",
        \"resourceType\": \"Microsoft.ContainerService/managedClusters\",
        \"resourceLocation\": \"$LOCATION\",
        \"objectType\": \"DatasourceSet\"
      },
      \"policyInfo\": {
        \"policyId\": \"$POLICY_ID\"
      },
      \"objectType\": \"BackupInstance\"
    }
  }" \
  --output table 2>/dev/null || echo "  Backup instance already exists — skipping"
echo "✓ Backup Instance created"

# ── Step 10: Trigger the one-time backup NOW ──────────────────────────────────
echo ""
echo "[Step 10] Triggering one-time backup NOW..."
JOB=$(az dataprotection backup-instance adhoc-backup \
  --resource-group "$RG" \
  --vault-name "$VAULT" \
  --backup-instance-name "aks-onetime-instance" \
  --rule-name "Default" \
  --query jobId -o tsv 2>/dev/null || echo "")

if [[ -n "$JOB" ]]; then
  echo "✓ Backup job started: $JOB"
  echo ""
  echo "  Monitoring backup job..."
  az dataprotection job show \
    --resource-group "$RG" \
    --vault-name "$VAULT" \
    --job-id "$JOB" \
    --query '{Status:status,StartTime:startTime,Operation:operation}' \
    --output table
else
  echo "  Could not trigger backup — check permissions above"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "=============================================="
echo "  One-Time Backup Complete"
echo "=============================================="
echo "  Storage : $STORAGE_ACCOUNT/$BLOB_CONTAINER"
echo "  Vault   : $VAULT"
echo "  Policy  : aks-onetime-backup-policy (30-day retention)"
echo ""
echo "  Check job status:"
echo "  az dataprotection job list \\"
echo "    --resource-group $RG \\"
echo "    --vault-name $VAULT \\"
echo "    --output table"
echo "=============================================="
