# Fix: Storage Blob Data Contributor Permission

## Issue

The workflow created the backend storage successfully but cannot access it due to missing permissions:

```
ERROR: Cannot access storage container. Checking permissions...
WARNING: Could not auto-grant permissions
Please ensure service principal has 'Storage Blob Data Contributor' role
```

## Root Cause

The service principal that GitHub Actions uses needs **two roles**:
1. ✅ **Contributor** - To create resources (you already have this)
2. ❌ **Storage Blob Data Contributor** - To access blob storage (missing)

The workflow tried to auto-grant this role but failed because the service principal cannot grant roles to itself.

---

## Solution: Grant Storage Blob Data Contributor Role

You need to manually grant this role **once**. After that, all future runs will work.

### Option 1: Grant on Entire Storage Account (Recommended)

This allows the service principal to access any container in the storage account:

```bash
# Get your service principal's client ID (from GitHub secrets)
CLIENT_ID="<your-AZURE_CLIENT_ID>"

# Get your subscription ID (from GitHub secrets)
SUBSCRIPTION_ID="<your-AZURE_SUBSCRIPTION_ID>"

# Grant the role
az role assignment create \
  --assignee $CLIENT_ID \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/tfstate-rg/providers/Microsoft.Storage/storageAccounts/tfstateugrantliatrio"
```

### Option 2: Grant on Specific Container

This is more restrictive (only the tfstate container):

```bash
# Get the storage account resource ID
STORAGE_ACCOUNT_ID=$(az storage account show \
  --name tfstateugrantliatrio \
  --resource-group tfstate-rg \
  --query id -o tsv)

# Grant the role on the container
az role assignment create \
  --assignee $CLIENT_ID \
  --role "Storage Blob Data Contributor" \
  --scope "$STORAGE_ACCOUNT_ID/blobServices/default/containers/tfstate"
```

### Option 3: Via Azure Portal

1. Go to Azure Portal
2. Navigate to **Storage Accounts** → **tfstateugrantliatrio**
3. Click **Access Control (IAM)** in left menu
4. Click **+ Add** → **Add role assignment**
5. Select **Storage Blob Data Contributor** role
6. Click **Next**
7. Click **+ Select members**
8. Search for your service principal name: `github-actions-liatrio-demo`
9. Select it and click **Select**
10. Click **Review + assign**
11. Click **Review + assign** again

---

## Quick Fix (Copy-Paste Ready)

Replace the placeholders and run:

```bash
# Set your values (get from GitHub secrets)
export AZURE_CLIENT_ID="YOUR_CLIENT_ID_HERE"
export AZURE_SUBSCRIPTION_ID="YOUR_SUBSCRIPTION_ID_HERE"

# Grant the role
az role assignment create \
  --assignee $AZURE_CLIENT_ID \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/tfstate-rg/providers/Microsoft.Storage/storageAccounts/tfstateugrantliatrio"

# Verify the role assignment
az role assignment list \
  --assignee $AZURE_CLIENT_ID \
  --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/tfstate-rg/providers/Microsoft.Storage/storageAccounts/tfstateugrantliatrio" \
  --output table
```

---

## After Granting Permission

### Re-run the Workflow

1. Go to GitHub → Actions tab
2. Find the failed workflow run
3. Click **Re-run failed jobs** or **Re-run all jobs**

OR

2. Make a small change and push again:
   ```bash
   git commit --allow-empty -m "Trigger workflow after permission fix"
   git push origin dev
   ```

### Expected Output

After granting the permission, you should see:

```
✓ Resource group exists: tfstate-rg
✓ Storage account exists: tfstateugrantliatrio
✓ Blob container exists: tfstate
Validating backend access...
✓ Backend access validated
✓ Terraform backend ready
```

---

## Why This Happened

### The Workflow's Auto-Grant Attempt

The workflow includes this code to auto-grant permissions:

```bash
az role assignment create \
  --assignee $CURRENT_USER \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/.../tfstateugrantliatrio"
```

### Why It Failed

The service principal needs **special permissions** to grant roles:
- **User Access Administrator** role, OR
- **Owner** role

Since your service principal only has **Contributor** role, it can create resources but cannot grant IAM roles.

**This is expected behavior and by design for security.**

---

## Prevention for Future

### Option 1: Update Service Principal Role (More Permissions)

Give your service principal the ability to manage IAM:

```bash
# Grant User Access Administrator role (in addition to Contributor)
az role assignment create \
  --assignee $AZURE_CLIENT_ID \
  --role "User Access Administrator" \
  --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/tfstate-rg"
```

**Pros:** Workflow can auto-grant permissions
**Cons:** More permissions than needed for day-to-day operations

### Option 2: Pre-create Backend with Permissions (Recommended)

Create the backend infrastructure ahead of time with proper permissions:

```bash
# Create resource group
az group create \
  --name tfstate-rg \
  --location westus2

# Create storage account
az storage account create \
  --name tfstateugrantliatrio \
  --resource-group tfstate-rg \
  --location westus2 \
  --sku Standard_LRS \
  --encryption-services blob \
  --https-only true \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false

# Create container
az storage container create \
  --name tfstate \
  --account-name tfstateugrantliatrio \
  --auth-mode login

# Grant permissions
az role assignment create \
  --assignee $AZURE_CLIENT_ID \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/tfstate-rg/providers/Microsoft.Storage/storageAccounts/tfstateugrantliatrio"
```

**Pros:** Minimal permissions, infrastructure as code
**Cons:** One-time manual setup

**Recommendation:** Use Option 2 (pre-create with permissions)

---

## Understanding the Roles

### Contributor Role (You Have This)
- ✅ Create/delete resources
- ✅ Modify resource configurations
- ❌ Manage access control (IAM)
- ❌ Grant roles to other principals

### Storage Blob Data Contributor Role (You Need This)
- ✅ Read, write, delete blobs
- ✅ List containers
- ✅ Access blob data
- ❌ Manage storage account configuration

### User Access Administrator Role (Optional)
- ✅ Manage role assignments
- ✅ Grant/revoke access
- ❌ Manage resources themselves

---

## Verification Steps

After granting the role, verify it's working:

```bash
# Check role assignments
az role assignment list \
  --assignee $AZURE_CLIENT_ID \
  --all \
  --output table

# You should see both:
# - Contributor (on subscription)
# - Storage Blob Data Contributor (on storage account)
```

---

## Common Issues

### Issue: "Principal does not exist"

**Cause:** Client ID is incorrect or service principal was deleted

**Solution:**
```bash
# Verify service principal exists
az ad sp show --id $AZURE_CLIENT_ID

# If not found, recreate it (see docs/GITHUB_SETUP.md)
```

### Issue: "Insufficient privileges"

**Cause:** You don't have permission to grant roles

**Solution:**
- Use an account with Owner or User Access Administrator role
- Or ask your Azure admin to grant the role

### Issue: "Cannot find storage account"

**Cause:** Storage account creation failed or wrong name

**Solution:**
```bash
# Check if storage account exists
az storage account show \
  --name tfstateugrantliatrio \
  --resource-group tfstate-rg
```

---

## Alternative: Use Managed Identity (Advanced)

For self-hosted runners, you can use Azure Managed Identity instead of service principal:

**Pros:**
- No secrets to manage
- Automatic permission inheritance

**Cons:**
- Requires self-hosted runner in Azure
- More complex setup

See Azure documentation for Managed Identity setup.

---

## Summary

**Immediate Action Required:**

```bash
# 1. Get your client ID from GitHub secrets
# 2. Run this command (replace YOUR_CLIENT_ID and YOUR_SUBSCRIPTION_ID):

az role assignment create \
  --assignee YOUR_CLIENT_ID \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/YOUR_SUBSCRIPTION_ID/resourceGroups/tfstate-rg/providers/Microsoft.Storage/storageAccounts/tfstateugrantliatrio"

# 3. Re-run the workflow
```

**Why:** Service principal can create storage but needs explicit permission to access blob data.

**One-time fix:** This only needs to be done once. Future runs will work automatically.

---

## Next Steps

After fixing:
1. ✅ Grant Storage Blob Data Contributor role (above)
2. ✅ Re-run the workflow
3. ✅ Verify "✓ Backend access validated" appears
4. ✅ Deployment should proceed normally

---

**Questions?** Check `docs/GITHUB_SETUP.md` for full setup documentation.
