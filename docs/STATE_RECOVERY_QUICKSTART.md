# Terraform State Recovery - Quick Start Guide

## Emergency State Recovery

If you need to quickly recover from state file issues, follow these steps.

## Prerequisites

```bash
# Set these variables
STORAGE_ACCOUNT="tfstateugrantliatrio"
RESOURCE_GROUP="tfstate-rg"
CONTAINER="tfstate"
STATE_FILE="aks-demo-dev.tfstate"  # or aks-demo-prod.tfstate
```

## Quick Recovery Steps

### Step 1: List Available Versions

```bash
az storage blob list \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --prefix $STATE_FILE \
  --include v \
  --auth-mode login \
  --query "[].{VersionId:versionId, LastModified:properties.lastModified, IsCurrentVersion:isCurrentVersion}" \
  --output table
```

### Step 2: Identify Good Version

Look at the `LastModified` timestamps and identify the version from before the problem occurred.

### Step 3: Restore the Version

```bash
# Replace VERSION_ID with the version from Step 1
VERSION_ID="2025-01-20T15:00:00.0000000Z"

az storage blob copy start \
  --account-name $STORAGE_ACCOUNT \
  --destination-container $CONTAINER \
  --destination-blob $STATE_FILE \
  --source-account-name $STORAGE_ACCOUNT \
  --source-container $CONTAINER \
  --source-blob $STATE_FILE \
  --source-version-id $VERSION_ID \
  --auth-mode login
```

### Step 4: Verify Restoration

```bash
cd terraform
terraform init -reconfigure
terraform plan
```

## Common Scenarios

### Scenario: State Corrupted After Failed Apply

```bash
# 1. Find version from before the failed apply (10-15 minutes ago)
az storage blob list \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --prefix $STATE_FILE \
  --include v \
  --auth-mode login \
  --output table

# 2. Restore that version
VERSION_ID="<version-before-failure>"
az storage blob copy start \
  --account-name $STORAGE_ACCOUNT \
  --destination-container $CONTAINER \
  --destination-blob $STATE_FILE \
  --source-account-name $STORAGE_ACCOUNT \
  --source-container $CONTAINER \
  --source-blob $STATE_FILE \
  --source-version-id $VERSION_ID \
  --auth-mode login

# 3. Verify
cd terraform
terraform init -reconfigure
terraform plan
```

### Scenario: Need to Rollback Infrastructure

```bash
# 1. List versions and find the one from before deployment
az storage blob list \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --prefix $STATE_FILE \
  --include v \
  --auth-mode login \
  --output table

# 2. Download and inspect to confirm it's correct
VERSION_ID="<before-deployment>"
az storage blob download \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --name $STATE_FILE \
  --version-id $VERSION_ID \
  --file ./verify-state.tfstate \
  --auth-mode login

terraform show verify-state.tfstate  # Inspect

# 3. If correct, restore it
az storage blob copy start \
  --account-name $STORAGE_ACCOUNT \
  --destination-container $CONTAINER \
  --destination-blob $STATE_FILE \
  --source-account-name $STORAGE_ACCOUNT \
  --source-container $CONTAINER \
  --source-blob $STATE_FILE \
  --source-version-id $VERSION_ID \
  --auth-mode login

# 4. Apply rollback
cd terraform
terraform init -reconfigure
terraform plan
terraform apply
```

### Scenario: State File Deleted

```bash
# 1. List versions (including deleted current version)
az storage blob list \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --prefix $STATE_FILE \
  --include v,d \
  --auth-mode login \
  --output table

# 2. Restore most recent version
VERSION_ID="<most-recent>"
az storage blob copy start \
  --account-name $STORAGE_ACCOUNT \
  --destination-container $CONTAINER \
  --destination-blob $STATE_FILE \
  --source-account-name $STORAGE_ACCOUNT \
  --source-container $CONTAINER \
  --source-blob $STATE_FILE \
  --source-version-id $VERSION_ID \
  --auth-mode login
```

## PowerShell Equivalent

For Windows users, here's the PowerShell version:

```powershell
# Set variables
$STORAGE_ACCOUNT = "tfstateugrantliatrio"
$RESOURCE_GROUP = "tfstate-rg"
$CONTAINER = "tfstate"
$STATE_FILE = "aks-demo-dev.tfstate"

# List versions
az storage blob list `
  --account-name $STORAGE_ACCOUNT `
  --container-name $CONTAINER `
  --prefix $STATE_FILE `
  --include v `
  --auth-mode login `
  --output table

# Restore version
$VERSION_ID = "2025-01-20T15:00:00.0000000Z"
az storage blob copy start `
  --account-name $STORAGE_ACCOUNT `
  --destination-container $CONTAINER `
  --destination-blob $STATE_FILE `
  --source-account-name $STORAGE_ACCOUNT `
  --source-container $CONTAINER `
  --source-blob $STATE_FILE `
  --source-version-id $VERSION_ID `
  --auth-mode login

# Verify
cd terraform
terraform init -reconfigure
terraform plan
```

## Troubleshooting

### Can't See Versions

**Check permissions:**
```bash
# Verify you have the right role
az role assignment list \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT" \
  --query "[?principalName=='<your-email>']"
```

**Required role:** `Storage Blob Data Contributor`

### Copy Failed

**Check if version exists:**
```bash
az storage blob list \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --prefix $STATE_FILE \
  --include v \
  --auth-mode login \
  --query "[?versionId=='$VERSION_ID']"
```

### Terraform Still Showing Errors

**Re-initialize Terraform:**
```bash
cd terraform
rm -rf .terraform .terraform.lock.hcl
terraform init -reconfigure
```

## Getting Help

For detailed documentation, see:
- [TERRAFORM_STATE_VERSIONING.md](TERRAFORM_STATE_VERSIONING.md) - Complete guide
- [README.md](../README.md) - Project documentation

## Emergency Contact

If state recovery fails, escalate immediately:
1. Document the exact error messages
2. Note the last known good deployment time
3. DO NOT run `terraform apply` until state is recovered
4. Contact the infrastructure team
