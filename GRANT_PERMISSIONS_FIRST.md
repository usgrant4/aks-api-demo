# Grant Permissions BEFORE First Run

## The Chicken-and-Egg Problem

You can't grant User Access Administrator role on `tfstate-rg` resource group if it doesn't exist yet!

**Solution:** Grant the role at the **subscription level** instead.

---

## Quick Fix (Run This First)

```bash
# Grant User Access Administrator at subscription level
az role assignment create \
  --assignee <YOUR_AZURE_CLIENT_ID> \
  --role "User Access Administrator" \
  --scope /subscriptions/<YOUR_AZURE_SUBSCRIPTION_ID>
```

Replace:
- `<YOUR_AZURE_CLIENT_ID>` - From your GitHub secrets
- `<YOUR_AZURE_SUBSCRIPTION_ID>` - From your GitHub secrets

---

## What This Does

Your service principal will have **two roles** at the subscription level:

1. ✅ **Contributor** - Can create/manage resources
2. ✅ **User Access Administrator** - Can grant IAM roles

This allows the workflow to:
- Create the tfstate-rg resource group (Contributor)
- Create the storage account (Contributor)
- Grant Storage Blob Data Contributor to itself (User Access Administrator)

---

## Security Consideration

### Option 1: Subscription-Level (Easiest)

```bash
az role assignment create \
  --assignee <CLIENT_ID> \
  --role "User Access Administrator" \
  --scope /subscriptions/<SUBSCRIPTION_ID>
```

**Pros:**
- ✅ Works immediately
- ✅ Works even if tfstate-rg doesn't exist
- ✅ Simple one-time setup

**Cons:**
- ⚠️ Service principal can grant roles anywhere in subscription
- ⚠️ More permissions than strictly necessary

### Option 2: Pre-create RG, then scope to RG (More Secure)

```bash
# Step 1: Create the resource group first
az group create \
  --name tfstate-rg \
  --location westus2 \
  --tags "purpose=terraform-state"

# Step 2: Grant User Access Administrator on the resource group only
az role assignment create \
  --assignee <CLIENT_ID> \
  --role "User Access Administrator" \
  --scope /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/tfstate-rg
```

**Pros:**
- ✅ More restrictive (scoped to one resource group)
- ✅ Better security posture

**Cons:**
- ⚠️ Requires manual resource group creation first
- ⚠️ Two-step process

---

## Recommended Approach

**For Demo/Testing:** Use Option 1 (subscription-level)

**For Production:** Use Option 2 (pre-create RG, then scope to RG)

---

## Complete Setup Commands

### Quick Setup (Subscription-Level)

```bash
# Set your values
export AZURE_CLIENT_ID="<your-client-id>"
export AZURE_SUBSCRIPTION_ID="<your-subscription-id>"

# Grant User Access Administrator
az role assignment create \
  --assignee $AZURE_CLIENT_ID \
  --role "User Access Administrator" \
  --scope /subscriptions/$AZURE_SUBSCRIPTION_ID

# Verify both roles are assigned
az role assignment list \
  --assignee $AZURE_CLIENT_ID \
  --scope /subscriptions/$AZURE_SUBSCRIPTION_ID \
  --output table

# Should show:
# - Contributor
# - User Access Administrator
```

### Secure Setup (Resource Group-Level)

```bash
# Set your values
export AZURE_CLIENT_ID="<your-client-id>"
export AZURE_SUBSCRIPTION_ID="<your-subscription-id>"
export LOCATION="westus2"

# Step 1: Create resource group
az group create \
  --name tfstate-rg \
  --location $LOCATION \
  --tags "purpose=terraform-state" "managed_by=manual"

# Step 2: Grant Contributor on subscription (for creating app resources)
# This should already exist, but verify:
az role assignment list \
  --assignee $AZURE_CLIENT_ID \
  --role Contributor \
  --scope /subscriptions/$AZURE_SUBSCRIPTION_ID

# Step 3: Grant User Access Administrator on tfstate-rg only
az role assignment create \
  --assignee $AZURE_CLIENT_ID \
  --role "User Access Administrator" \
  --scope /subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/tfstate-rg

# Step 4: Verify
az role assignment list \
  --assignee $AZURE_CLIENT_ID \
  --all \
  --output table
```

---

## After Granting Permissions

### Test the Workflow

```bash
# Push to trigger workflow
git commit --allow-empty -m "Test automated permission grant"
git push origin dev
```

### Expected Output

```
Creating resource group: tfstate-rg
✓ Resource group created
Creating storage account: tfstateugrantliatrio
✓ Storage account created
✓ Storage account provisioning complete
Granting Storage Blob Data Contributor role to service principal...
✓ Storage Blob Data Contributor role granted
Waiting 10s for backend stabilization and role propagation...
Creating blob container: tfstate
✓ Blob container created
Validating backend access...
✓ Backend access validated
✓ Terraform backend ready
```

---

## Why This Works

### The Permission Chain

1. **User Access Administrator** (subscription or RG level)
   - Allows service principal to run `az role assignment create`
   - Needed to grant Storage Blob Data Contributor

2. **Contributor** (subscription level)
   - Allows creating resource groups, storage accounts, etc.
   - Does NOT allow granting IAM permissions

3. **Storage Blob Data Contributor** (storage account level)
   - Granted automatically by workflow
   - Allows reading/writing Terraform state files

---

## Alternative: Use Azure CLI Login

If you don't want to grant User Access Administrator role, you can run the setup manually:

```bash
# Login with your own account (which likely has Owner role)
az login

# Run the backend setup manually
cd terraform
./setup-backend.sh  # (Create this script or run commands manually)

# Grant permission to service principal
az role assignment create \
  --assignee <SERVICE_PRINCIPAL_CLIENT_ID> \
  --role "Storage Blob Data Contributor" \
  --scope "/subscriptions/<SUBSCRIPTION_ID>/resourceGroups/tfstate-rg/providers/Microsoft.Storage/storageAccounts/tfstateugrantliatrio"
```

**Pros:** No need for User Access Administrator role
**Cons:** Manual one-time setup required

---

## Verification Checklist

Before pushing:

- [ ] Grant User Access Administrator role (subscription or RG level)
- [ ] Verify service principal has both roles:
  ```bash
  az role assignment list \
    --assignee <CLIENT_ID> \
    --all \
    --output table
  ```
- [ ] Should see at least:
  - `Contributor` (subscription level)
  - `User Access Administrator` (subscription or tfstate-rg level)

After first successful run:

- [ ] Backend resources created
- [ ] Storage Blob Data Contributor granted automatically
- [ ] Terraform state initialized
- [ ] Application deployed

---

## Summary

**The Issue:** Can't grant role on resource group that doesn't exist

**The Solution:** Grant User Access Administrator at subscription level (or pre-create RG first)

**Minimum Command Required:**

```bash
az role assignment create \
  --assignee <YOUR_AZURE_CLIENT_ID> \
  --role "User Access Administrator" \
  --scope /subscriptions/<YOUR_AZURE_SUBSCRIPTION_ID>
```

**Then:** Push to dev and watch it work! 🚀

---

## Quick Reference Card

```bash
# One-time setup (run this first)
az role assignment create \
  --assignee <CLIENT_ID> \
  --role "User Access Administrator" \
  --scope /subscriptions/<SUBSCRIPTION_ID>

# Verify
az role assignment list \
  --assignee <CLIENT_ID> \
  --scope /subscriptions/<SUBSCRIPTION_ID> \
  --output table

# Then deploy
git push origin dev
```

That's it! The workflow handles everything else automatically.
