# Terraform State File Versioning

## Overview

This project implements **Azure Blob Versioning** for Terraform state files, providing automatic versioning, state history tracking, and recovery capabilities without manual backup processes.

## What is Blob Versioning?

Azure Blob Versioning automatically maintains previous versions of blobs (including Terraform state files) whenever they are modified. Each time Terraform updates the state file, Azure Storage automatically creates a new version while preserving all historical versions.

## Benefits

### 1. **Automatic State History**
- Every Terraform apply operation creates a new version
- No manual backup scripts required
- Complete audit trail of infrastructure changes

### 2. **Point-in-Time Recovery**
- Restore state to any previous version
- Recover from accidental state corruption
- Rollback infrastructure changes if needed

### 3. **No Performance Impact**
- Versioning happens transparently
- No changes required to Terraform workflow
- Works with existing backend configuration

### 4. **Cost-Effective**
- Only stores incremental changes between versions
- Automatic lifecycle management available
- Storage costs are minimal for state files

## How It Works

### Automatic Versioning

When enabled, Azure Storage automatically:

1. **Creates a new version** when a blob is modified
2. **Preserves the current version** before overwriting
3. **Assigns a unique version ID** (timestamp-based)
4. **Maintains all previous versions** indefinitely (or per lifecycle policy)

### Version Structure

Each state file version is identified by:
```
Blob Name: aks-demo-dev.tfstate
Version ID: 2025-01-20T15:30:45.1234567Z (example)
```

## Implementation

### Automatic Setup (CI/CD)

The GitHub Actions workflow automatically enables versioning:

```yaml
- name: Setup Terraform backend
  run: |
    # Enable blob versioning for state file history
    az storage account blob-service-properties update \
      --account-name $STORAGE_ACCOUNT_NAME \
      --resource-group $RESOURCE_GROUP_NAME \
      --enable-versioning true \
      --enable-change-feed false
```

**Location**: [.github/workflows/ci-cd.yml](.github/workflows/ci-cd.yml#L177-187)

### Manual Setup

If you need to enable versioning manually:

```bash
# Set variables
STORAGE_ACCOUNT="tfstateugrantliatrio"
RESOURCE_GROUP="tfstate-rg"

# Enable versioning
az storage account blob-service-properties update \
  --account-name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --enable-versioning true
```

## Using State Versioning

### View Available Versions

List all versions of a state file:

```bash
# Set variables
STORAGE_ACCOUNT="tfstateugrantliatrio"
CONTAINER="tfstate"
STATE_FILE="aks-demo-dev.tfstate"

# List all versions
az storage blob list \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --prefix $STATE_FILE \
  --include v \
  --auth-mode login \
  --query "[].{Name:name, VersionId:versionId, LastModified:properties.lastModified, IsCurrentVersion:isCurrentVersion}" \
  --output table
```

**Example Output:**
```
Name                    VersionId                          LastModified                IsCurrentVersion
----------------------  ---------------------------------  --------------------------  ------------------
aks-demo-dev.tfstate    2025-01-20T18:30:00.0000000Z      2025-01-20T18:30:00+00:00   True
aks-demo-dev.tfstate    2025-01-20T15:15:00.0000000Z      2025-01-20T15:15:00+00:00   False
aks-demo-dev.tfstate    2025-01-19T14:00:00.0000000Z      2025-01-19T14:00:00+00:00   False
```

### Download a Specific Version

Retrieve a previous version of the state file:

```bash
# Download current version
az storage blob download \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --name $STATE_FILE \
  --file ./current-state.tfstate \
  --auth-mode login

# Download specific version (replace VERSION_ID)
VERSION_ID="2025-01-19T14:00:00.0000000Z"
az storage blob download \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --name $STATE_FILE \
  --version-id $VERSION_ID \
  --file ./previous-state.tfstate \
  --auth-mode login
```

### Compare State Versions

Compare two versions to see what changed:

```bash
# Download two versions
az storage blob download \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --name $STATE_FILE \
  --file ./current.tfstate \
  --auth-mode login

az storage blob download \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --name $STATE_FILE \
  --version-id "2025-01-19T14:00:00.0000000Z" \
  --file ./previous.tfstate \
  --auth-mode login

# Compare using jq (human-readable)
diff <(jq -S . current.tfstate) <(jq -S . previous.tfstate)

# Or use terraform show for formatted diff
terraform show current.tfstate > current.txt
terraform show previous.tfstate > previous.txt
diff current.txt previous.txt
```

### Restore a Previous Version

**Method 1: Promote a Previous Version (Recommended)**

This makes a previous version the current version:

```bash
# Promote version to current
VERSION_ID="2025-01-19T14:00:00.0000000Z"

az storage blob copy start \
  --account-name $STORAGE_ACCOUNT \
  --destination-container $CONTAINER \
  --destination-blob $STATE_FILE \
  --source-account-name $STORAGE_ACCOUNT \
  --source-container $CONTAINER \
  --source-blob $STATE_FILE \
  --source-version-id $VERSION_ID \
  --auth-mode login

echo "✓ Version $VERSION_ID promoted to current"
```

**Method 2: Manual Download and Upload**

```bash
# 1. Download the desired version
az storage blob download \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --name $STATE_FILE \
  --version-id $VERSION_ID \
  --file ./restored-state.tfstate \
  --auth-mode login

# 2. Backup current state (optional but recommended)
az storage blob download \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --name $STATE_FILE \
  --file ./backup-before-restore.tfstate \
  --auth-mode login

# 3. Upload the restored version as current
az storage blob upload \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --name $STATE_FILE \
  --file ./restored-state.tfstate \
  --overwrite \
  --auth-mode login

echo "✓ State restored from version $VERSION_ID"
```

**Method 3: Using Terraform Force Unlock (if state is locked)**

```bash
# If state is locked, first unlock it
cd terraform
terraform force-unlock <LOCK_ID>

# Then restore using Method 1 or 2 above
```

### Delete a Specific Version

Remove a specific version (keeps current version):

```bash
# Delete a specific version
az storage blob delete \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --name $STATE_FILE \
  --version-id $VERSION_ID \
  --auth-mode login
```

## Lifecycle Management

### Automatic Version Cleanup

To prevent unlimited version accumulation, configure lifecycle policies:

```bash
# Create lifecycle policy JSON
cat > lifecycle-policy.json <<'EOF'
{
  "rules": [
    {
      "enabled": true,
      "name": "delete-old-state-versions",
      "type": "Lifecycle",
      "definition": {
        "actions": {
          "version": {
            "delete": {
              "daysAfterCreationGreaterThan": 90
            }
          }
        },
        "filters": {
          "blobTypes": ["blockBlob"],
          "prefixMatch": ["aks-demo"]
        }
      }
    }
  ]
}
EOF

# Apply lifecycle policy
az storage account management-policy create \
  --account-name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --policy @lifecycle-policy.json
```

**Policy Effects:**
- Deletes state file versions older than 90 days
- Keeps current version indefinitely
- Only affects state files (prefix: aks-demo)
- Runs automatically daily

### Recommended Retention Policies

| Retention Period | Use Case |
|------------------|----------|
| **30 days** | Development environments, frequent changes |
| **90 days** | Production environments, compliance requirements |
| **180 days** | Long-term audit trail, regulatory compliance |
| **Unlimited** | Critical production, legal hold requirements |

## Monitoring and Auditing

### Check Versioning Status

```bash
# Verify versioning is enabled
az storage account blob-service-properties show \
  --account-name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --query "isVersioningEnabled" \
  --output tsv
```

Expected output: `true`

### View Version Count

```bash
# Count total versions for a state file
az storage blob list \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --prefix $STATE_FILE \
  --include v \
  --auth-mode login \
  --query "length(@)" \
  --output tsv
```

### Storage Cost Analysis

```bash
# Calculate total storage used by all versions
az storage blob list \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --prefix $STATE_FILE \
  --include v \
  --auth-mode login \
  --query "sum([].properties.contentLength)" \
  --output tsv | awk '{printf "%.2f MB\n", $1/1024/1024}'
```

## Disaster Recovery Scenarios

### Scenario 1: Accidental State Corruption

**Problem:** Terraform state becomes corrupted during a failed apply

**Solution:**
```bash
# 1. List recent versions
az storage blob list \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --prefix $STATE_FILE \
  --include v \
  --auth-mode login \
  --query "[?isCurrentVersion==\`false\`] | [0:5]" \
  --output table

# 2. Restore last known good version (from 10 minutes ago)
VERSION_ID="<version-id-from-list>"
az storage blob copy start \
  --account-name $STORAGE_ACCOUNT \
  --destination-container $CONTAINER \
  --destination-blob $STATE_FILE \
  --source-account-name $STORAGE_ACCOUNT \
  --source-container $CONTAINER \
  --source-blob $STATE_FILE \
  --source-version-id $VERSION_ID \
  --auth-mode login

# 3. Verify restoration
terraform init -reconfigure
terraform plan
```

### Scenario 2: Rollback Infrastructure Changes

**Problem:** Recent infrastructure changes need to be reverted

**Solution:**
```bash
# 1. Find version before problematic deployment
# List versions with timestamps
az storage blob list \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --prefix $STATE_FILE \
  --include v \
  --auth-mode login \
  --output table

# 2. Download and inspect version
VERSION_ID="<before-bad-deployment>"
az storage blob download \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --name $STATE_FILE \
  --version-id $VERSION_ID \
  --file ./before-changes.tfstate \
  --auth-mode login

# 3. Verify it's the correct version
terraform show before-changes.tfstate

# 4. Restore version
az storage blob copy start \
  --account-name $STORAGE_ACCOUNT \
  --destination-container $CONTAINER \
  --destination-blob $STATE_FILE \
  --source-account-name $STORAGE_ACCOUNT \
  --source-container $CONTAINER \
  --source-blob $STATE_FILE \
  --source-version-id $VERSION_ID \
  --auth-mode login

# 5. Run terraform to revert infrastructure
terraform init -reconfigure
terraform plan  # Review changes
terraform apply  # Apply rollback
```

### Scenario 3: State File Accidentally Deleted

**Problem:** Current state file was deleted

**Solution:**
```bash
# Azure Blob Versioning automatically preserves deleted blobs!
# List versions including soft-deleted current version
az storage blob list \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --prefix $STATE_FILE \
  --include v,d \
  --auth-mode login \
  --output table

# Restore most recent version
VERSION_ID="<most-recent-version-id>"
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

## Security Considerations

### Access Control

- Versioned blobs inherit the same RBAC permissions as current versions
- Use `Storage Blob Data Contributor` role for read/write access to versions
- Use `Storage Blob Data Reader` role for read-only access to versions

### Audit Trail

Every version change is logged in Azure Activity Logs:

```bash
# View state file modification history
az monitor activity-log list \
  --resource-group $RESOURCE_GROUP \
  --start-time "2025-01-01T00:00:00Z" \
  --query "[?contains(resourceId, '$STORAGE_ACCOUNT')]" \
  --output table
```

### Compliance

Blob versioning supports:
- **SOC 2**: Immutable audit trail of infrastructure changes
- **HIPAA**: Historical state tracking for compliance audits
- **GDPR**: Point-in-time recovery for data protection

## Best Practices

### 1. **Enable Versioning Early**
- Enable versioning before first deployment
- Already configured automatically in CI/CD pipeline

### 2. **Regular Version Audits**
- Review version count monthly
- Implement lifecycle policies for automatic cleanup

### 3. **Test Restoration Process**
- Periodically test state restoration in non-production
- Document recovery procedures for team

### 4. **Monitor Storage Costs**
- Track version count and storage growth
- Adjust retention policies based on actual needs

### 5. **Combine with State Locking**
- Versioning complements but doesn't replace state locking
- Always use `-lock=true` with Terraform (default)

### 6. **Document Version IDs**
- Record version IDs for major deployments
- Include in deployment notes for easy rollback

## Comparison with Manual Backups

| Feature | Blob Versioning | Manual Backups |
|---------|----------------|----------------|
| **Automation** | Fully automatic | Requires scripts/cron |
| **Storage Efficiency** | Incremental only | Full file copies |
| **Version Management** | Built-in Azure tools | Custom tooling needed |
| **Point-in-Time Recovery** | Any version, instant | Limited by backup frequency |
| **Cost** | Pay for incremental changes | Pay for full copies |
| **Maintenance** | Zero | Ongoing script maintenance |
| **Reliability** | Azure-managed | Script/process dependent |

**Recommendation**: Use blob versioning instead of manual backups for Terraform state.

## Troubleshooting

### Versioning Not Working

**Check if enabled:**
```bash
az storage account blob-service-properties show \
  --account-name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP
```

**Enable if disabled:**
```bash
az storage account blob-service-properties update \
  --account-name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --enable-versioning true
```

### Can't See Old Versions

**Check permissions:**
```bash
# Verify you have Storage Blob Data Contributor role
az role assignment list \
  --scope "/subscriptions/<sub-id>/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT" \
  --query "[?principalName=='<your-email>']" \
  --output table
```

### Version Restoration Failed

**Verify version exists:**
```bash
# List all versions
az storage blob list \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --prefix $STATE_FILE \
  --include v \
  --auth-mode login
```

## Additional Resources

- [Azure Blob Versioning Documentation](https://learn.microsoft.com/azure/storage/blobs/versioning-overview)
- [Terraform Backend Configuration](https://developer.hashicorp.com/terraform/language/backend/azurerm)
- [Azure Storage Lifecycle Management](https://learn.microsoft.com/azure/storage/blobs/lifecycle-management-overview)
- [Terraform State Management Best Practices](https://developer.hashicorp.com/terraform/language/state)

## Summary

Blob versioning for Terraform state provides:

✅ **Automatic versioning** - No manual intervention required
✅ **Complete history** - Every state change preserved
✅ **Easy recovery** - Restore any previous version
✅ **Cost-effective** - Only incremental storage costs
✅ **Zero maintenance** - Azure-managed infrastructure
✅ **Audit compliance** - Full change history for compliance

**Status**: ✅ Enabled automatically in CI/CD pipeline
**Configuration**: [.github/workflows/ci-cd.yml](.github/workflows/ci-cd.yml#L177-187)
**Storage Account**: `tfstateugrantliatrio`
**Container**: `tfstate`
