# Terraform State Storage Authentication Fix

## Problem

After successful deployment, accessing the storage account in Azure Portal shows:
```
Server failed to authenticate the request. Make sure the value of Authorization header is formed correctly including the signature.
Error code: 403
Signature did not match.
```

## Root Cause

The storage account `tfstateugrantliatrio` was created with Shared Key Access disabled for security. However, the service principal needs proper RBAC permissions to access it using Entra ID (Azure AD) authentication.

## Solution

Grant the service principal proper Storage Blob Data access roles.

### Option 1: Azure Portal (Recommended)

1. **Navigate to Storage Account**
   - Go to [Azure Portal](https://portal.azure.com)
   - Search for `tfstateugrantliatrio`
   - Click on the storage account

2. **Assign RBAC Role**
   - In the left menu, click **"Access Control (IAM)"**
   - Click **"+ Add"** → **"Add role assignment"**

3. **Select Role**
   - Role: **"Storage Blob Data Contributor"**
   - Click **"Next"**

4. **Select Members**
   - Assign access to: **"User, group, or service principal"**
   - Click **"+ Select members"**
   - Search for your service principal: `github-actions-aks-demo` (or `github-actions-liatrio-demo`)
   - Select it and click **"Select"**
   - Click **"Review + assign"**

5. **Also Add Your User Account** (for Portal access)
   - Repeat steps 2-4, but select your own user account
   - This allows YOU to view the storage account in the Portal

### Option 2: Azure CLI

```bash
# Set variables
SUBSCRIPTION_ID="<your-subscription-id>"  # Same as AZURE_SUBSCRIPTION_ID GitHub secret
SP_CLIENT_ID="<your-service-principal-client-id>"  # Same as AZURE_CLIENT_ID GitHub secret
STORAGE_ACCOUNT="tfstateugrantliatrio"
RESOURCE_GROUP="tfstate-rg"

# Login to Azure
az login

# Set subscription
az account set --subscription "$SUBSCRIPTION_ID"

# Get the storage account resource ID
STORAGE_SCOPE=$(az storage account show \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --query id \
  --output tsv)

# Get the service principal object ID
SP_OBJECT_ID=$(az ad sp list \
  --filter "appId eq '$SP_CLIENT_ID'" \
  --query "[0].id" \
  --output tsv)

# Assign Storage Blob Data Contributor role to service principal
az role assignment create \
  --assignee-object-id "$SP_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Contributor" \
  --scope "$STORAGE_SCOPE"

echo "✓ Service principal granted Storage Blob Data Contributor role"

# Also assign to your user account for Portal access
YOUR_USER_ID=$(az ad signed-in-user show --query id --output tsv)

az role assignment create \
  --assignee-object-id "$YOUR_USER_ID" \
  --assignee-principal-type User \
  --role "Storage Blob Data Contributor" \
  --scope "$STORAGE_SCOPE"

echo "✓ Your user account granted Storage Blob Data Contributor role"
```

### Option 3: Quick Fix (Enable Shared Key Access)

**⚠️ Not Recommended for Production** - This reduces security but provides immediate access.

```bash
az storage account update \
  --name tfstateugrantliatrio \
  --resource-group tfstate-rg \
  --allow-shared-key-access true
```

After this change:
- Portal access will work immediately
- However, this weakens security posture
- Better to use Option 1 or 2 above

## Why This Happened

The CI/CD workflow setup script likely:
1. Created the storage account with `--allow-shared-key-access false` (good security practice)
2. Granted the service principal roles during deployment
3. But didn't grant your user account the necessary RBAC role for Portal access

## Verification

After applying the fix:

1. **Wait 2-3 minutes** for RBAC permissions to propagate

2. **Refresh the Azure Portal page** for the storage account

3. **You should now see**:
   - Containers list (including `tfstate`)
   - Ability to browse blobs
   - No authentication errors

4. **Test from CLI**:
   ```bash
   az storage blob list \
     --account-name tfstateugrantliatrio \
     --container-name tfstate \
     --auth-mode login
   ```

   Should list the state files without errors.

## Understanding Storage Account Authentication

### Two Authentication Methods

1. **Shared Key (Access Keys)**
   - Uses account keys stored in the storage account
   - Higher security risk if keys are compromised
   - Can be disabled with `--allow-shared-key-access false`

2. **Entra ID (Azure AD) RBAC**
   - Uses Azure AD authentication
   - Requires proper role assignments
   - More secure, supports identity-based access
   - Requires roles like "Storage Blob Data Contributor"

### Current Configuration

Your storage account is configured for **Entra ID (RBAC) authentication**:
- Shared Key Access: **Disabled** ✅ (good for security)
- Authentication: **Entra ID** ✅ (more secure)
- Issue: Missing RBAC role assignments for Portal access

## Required Roles

| Role | Purpose | Who Needs It |
|------|---------|--------------|
| Storage Blob Data Contributor | Read/write/delete blobs | Service Principal (GitHub Actions), Your User Account |
| Storage Blob Data Reader | Read-only access | Read-only users (optional) |
| Owner/Contributor | Manage storage account settings | Administrators only |

## CI/CD Workflow Already Has Access

The GitHub Actions workflow likely already has the necessary permissions because:
1. The Terraform backend setup script grants `Storage Blob Data Contributor` to the service principal
2. This happens automatically during the "Setup Terraform Backend" step
3. The workflow can read/write state files successfully

**You're seeing this error only in the Portal** because your personal user account doesn't have the RBAC role yet.

## Security Best Practices

✅ **Do:**
- Keep Shared Key Access disabled
- Use Entra ID (Azure AD) RBAC authentication
- Grant least privilege roles (Storage Blob Data Contributor, not Owner)
- Assign roles to service principals and user accounts as needed

❌ **Don't:**
- Re-enable Shared Key Access unless absolutely necessary
- Share storage account keys
- Grant overly broad roles like Owner when Contributor is sufficient

## Troubleshooting

### Still getting 403 errors after role assignment?

**Wait longer:**
```bash
# RBAC propagation can take up to 5 minutes
sleep 300
```

**Verify role assignment:**
```bash
az role assignment list \
  --scope "/subscriptions/<subscription-id>/resourceGroups/tfstate-rg/providers/Microsoft.Storage/storageAccounts/tfstateugrantliatrio" \
  --output table
```

Look for your user principal and the service principal with "Storage Blob Data Contributor" role.

### Portal still shows errors?

1. **Clear browser cache** or try incognito mode
2. **Sign out and sign back in** to Azure Portal
3. **Try a different browser**

### Need to access storage immediately?

Temporarily enable Shared Key Access (Option 3 above), then disable it after granting RBAC roles.

## References

- [Azure Storage authentication](https://learn.microsoft.com/azure/storage/common/authorize-data-access)
- [Prevent Shared Key authorization](https://learn.microsoft.com/azure/storage/common/shared-key-authorization-prevent)
- [Assign Azure roles](https://learn.microsoft.com/azure/role-based-access-control/role-assignments-portal)

## Quick Fix Summary

**Fastest solution** (Option 1 - Azure Portal):
1. Go to storage account `tfstateugrantliatrio`
2. Access Control (IAM) → Add role assignment
3. Role: "Storage Blob Data Contributor"
4. Members: Add your user account
5. Review + assign
6. Wait 2 minutes
7. Refresh Portal

**Most secure solution** (Option 2 - Azure CLI):
- Grants roles to both service principal AND your user account
- Keeps Shared Key Access disabled
- Uses Entra ID authentication
