# Azure AKS Backup Guide
> Complete guide to backing up AKS clusters, namespaces, pods, and services via Azure Cloud Shell

---

## Prerequisites — Install AKS Backup Extension

```bash
# Install required CLI extensions
az extension add --name k8s-extension
az extension add --name dataprotection

# Register required providers
az provider register --namespace Microsoft.KubernetesConfiguration
az provider register --namespace Microsoft.DataProtection

# Verify registration
az provider show --namespace Microsoft.DataProtection --query registrationState
```

---

## Step 1 — Create a Backup Vault

```bash
az dataprotection backup-vault create \
  --resource-group <YOUR_RG> \
  --vault-name <VAULT_NAME> \
  --location <LOCATION> \
  --type SystemAssigned \
  --storage-settings datastore-type="VaultStore" type="LocallyRedundant"
```

---

## Step 2 — Install AKS Backup Extension on Cluster

```bash
az k8s-extension create \
  --name azure-aks-backup \
  --extension-type microsoft.dataprotection.kubernetes \
  --scope cluster \
  --cluster-type managedClusters \
  --cluster-name <AKS_CLUSTER_NAME> \
  --resource-group <YOUR_RG> \
  --release-train stable \
  --configuration-settings \
    blobContainer=<BLOB_CONTAINER> \
    storageAccount=<STORAGE_ACCOUNT> \
    storageAccountResourceGroup=<STORAGE_RG> \
    storageAccountSubscriptionId=<SUBSCRIPTION_ID>
```

---

## Step 3 — Create Backup Policy

```bash
# Get policy template
az dataprotection backup-policy get-default-policy-template \
  --datasource-type AzureKubernetesService \
  > akspolicy.json

# Create the policy
az dataprotection backup-policy create \
  --resource-group <YOUR_RG> \
  --vault-name <VAULT_NAME> \
  --name <POLICY_NAME> \
  --policy akspolicy.json
```

---

## Step 4 — Configure Backup

```bash
# Get AKS cluster ID
AKS_ID=$(az aks show \
  --resource-group <YOUR_RG> \
  --name <AKS_CLUSTER_NAME> \
  --query id -o tsv)

# Get Backup vault ID
VAULT_ID=$(az dataprotection backup-vault show \
  --resource-group <YOUR_RG> \
  --vault-name <VAULT_NAME> \
  --query id -o tsv)

# Get policy ID
POLICY_ID=$(az dataprotection backup-policy show \
  --resource-group <YOUR_RG> \
  --vault-name <VAULT_NAME> \
  --name <POLICY_NAME> \
  --query id -o tsv)
```

---

## Step 5 — Create Backup Instance

```bash
az dataprotection backup-instance create \
  --resource-group <YOUR_RG> \
  --vault-name <VAULT_NAME> \
  --backup-instance \
  datasource-id=$AKS_ID \
  datasource-type="AzureKubernetesService" \
  datasource-location=<LOCATION> \
  policy-id=$POLICY_ID \
  --friendly-name <BACKUP_INSTANCE_NAME>
```

---

## Step 6 — Trigger On-Demand Backup

```bash
az dataprotection backup-instance adhoc-backup \
  --resource-group <YOUR_RG> \
  --vault-name <VAULT_NAME> \
  --backup-instance-name <BACKUP_INSTANCE_NAME> \
  --rule-name BackupHourly
```

---

## Step 7 — Verify Backup Jobs

```bash
az dataprotection job list \
  --resource-group <YOUR_RG> \
  --vault-name <VAULT_NAME> \
  --query "[].{Name:name,Status:properties.status,StartTime:properties.startTime}" \
  -o table
```

---

## Backup Options

### Option A — Backup Entire Cluster

```bash
az dataprotection backup-instance adhoc-backup \
  --resource-group <YOUR_RG> \
  --vault-name <VAULT_NAME> \
  --backup-instance-name <BACKUP_INSTANCE_NAME> \
  --rule-name BackupHourly
```

### Option B — Backup Specific Namespace/Pods

```bash
cat > backup-config.json << 'EOF'
{
  "includeClusterScopeResources": false,
  "includedNamespaces": [
    "my-namespace",
    "production",
    "staging"
  ],
  "excludedNamespaces": [],
  "includedResourceTypes": [
    "pods",
    "services",
    "deployments",
    "configmaps",
    "secrets",
    "persistentvolumeclaims"
  ],
  "excludedResourceTypes": [],
  "labelSelectors": []
}
EOF
```

### Option C — Backup Specific Services Only

```bash
cat > service-backup-config.json << 'EOF'
{
  "includeClusterScopeResources": false,
  "includedNamespaces": ["production"],
  "includedResourceTypes": [
    "services",
    "endpoints",
    "deployments"
  ],
  "labelSelectors": [
    "app=my-app",
    "environment=production"
  ]
}
EOF
```

---

## One-Time Backup Script

```bash
#!/bin/bash
set -euo pipefail

# -----------------------------------------------
# ONE-TIME AKS BACKUP SCRIPT
# Run this once to trigger an immediate backup
# -----------------------------------------------

# Set your variables
RG="<YOUR_RG>"
VAULT="<VAULT_NAME>"
INSTANCE="<BACKUP_INSTANCE_NAME>"
BACKUP_NAME="onetime-backup-$(date +%Y%m%d-%H%M%S)"

echo "================================================"
echo " AKS One-Time Backup"
echo " Started: $(date)"
echo " Backup Name: $BACKUP_NAME"
echo "================================================"

# Step 1 — Trigger the backup
echo ""
echo "[1/3] Triggering one-time backup..."
az dataprotection backup-instance adhoc-backup \
  --resource-group $RG \
  --vault-name $VAULT \
  --backup-instance-name $INSTANCE \
  --rule-name BackupHourly
echo "[OK] Backup triggered"

# Step 2 — Wait for job to start
echo ""
echo "[2/3] Waiting for backup job to register (30s)..."
sleep 30

# Step 3 — Check job status
echo ""
echo "[3/3] Backup job status:"
az dataprotection job list \
  --resource-group $RG \
  --vault-name $VAULT \
  --query "[0].{Name:name,Status:properties.status,StartTime:properties.startTime,EndTime:properties.endTime}" \
  -o table

echo ""
echo "================================================"
echo " Backup complete: $(date)"
echo " Check Azure Portal > Backup Center for details"
echo "================================================"
```

---

## Monitor Backup Progress

```bash
# Watch backup jobs in real time
watch -n 10 az dataprotection job list \
  --resource-group <YOUR_RG> \
  --vault-name <VAULT_NAME> \
  --query "[].{Name:name,Status:properties.status,Progress:properties.extendedInfo.progressPercentage}" \
  -o table
```

---

## Restore Options

```bash
# Restore entire cluster
az dataprotection backup-instance restore trigger \
  --resource-group <YOUR_RG> \
  --vault-name <VAULT_NAME> \
  --backup-instance-name <BACKUP_INSTANCE_NAME> \
  --restore-request-object restore-config.json

# List available restore points
az dataprotection recovery-point list \
  --resource-group <YOUR_RG> \
  --vault-name <VAULT_NAME> \
  --backup-instance-name <BACKUP_INSTANCE_NAME> \
  --query "[].{ID:name,Time:properties.recoveryPointTime}" \
  -o table
```

---

## What Gets Backed Up Per Option

| Resource                | Entire Cluster | Namespace | Services Only |
|-------------------------|:--------------:|:---------:|:-------------:|
| Pods                    | ✅             | ✅        | ❌            |
| Services                | ✅             | ✅        | ✅            |
| Deployments             | ✅             | ✅        | ✅            |
| ConfigMaps              | ✅             | ✅        | ❌            |
| Secrets                 | ✅             | ✅        | ❌            |
| PVCs/PVs                | ✅             | ✅        | ❌            |
| Cluster Roles           | ✅             | ❌        | ❌            |
| Namespaces              | ✅             | ✅        | ❌            |

---

## Quick Reference — Replace These Values

| Placeholder               | Description                          |
|---------------------------|--------------------------------------|
| `<YOUR_RG>`               | Your resource group name             |
| `<VAULT_NAME>`            | Name for your backup vault           |
| `<LOCATION>`              | Azure region e.g. `eastus`           |
| `<AKS_CLUSTER_NAME>`      | Your AKS cluster name                |
| `<STORAGE_ACCOUNT>`       | Storage account for backups          |
| `<BLOB_CONTAINER>`        | Blob container name                  |
| `<POLICY_NAME>`           | Name for your backup policy          |
| `<BACKUP_INSTANCE_NAME>`  | Name for your backup instance        |
| `<SUBSCRIPTION_ID>`       | Your Azure subscription ID           |
| `<STORAGE_RG>`            | Resource group of storage account    |
