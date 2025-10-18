# Troubleshooting: MissingSubscription Error

## Error You're Seeing

```
(MissingSubscription) The request did not have a subscription or a valid tenant level resource provider.
Code: MissingSubscription
Message: The request did not have a subscription or a valid tenant level resource provider.
```

---

## Common Causes & Solutions

### 1. Not Logged In or Session Expired

**Check if you're logged in:**
```bash
az account show
```

**If not logged in or expired:**
```bash
# Login to Azure
az login

# If you have multiple tenants, specify the tenant
az login --tenant <YOUR_TENANT_ID>
```

### 2. Wrong Subscription Set as Default

**Check current subscription:**
```bash
# Show current subscription
az account show --query "{Name:name, ID:id, TenantId:tenantId}" -o table
```

**Set the correct subscription:**
```bash
# List all subscriptions you have access to
az account list --output table

# Set the subscription you want to use
az account set --subscription 4ad94cd2-015f-4fe6-8651-b42a4379384b

# Verify it's set
az account show
```

### 3. Insufficient Permissions

You might not have permission to grant roles on this subscription.

**Check your permissions:**
```bash
# See what roles you have
az role assignment list --assignee $(az account show --query user.name -o tsv) --output table
```

**You need one of these roles to grant User Access Administrator:**
- Owner
- User Access Administrator

---

## Step-by-Step Fix

```bash
# Step 1: Login to Azure
az login

# Step 2: List your subscriptions
az account list --query "[].{Name:name, ID:id, IsDefault:isDefault}" -o table

# Step 3: Set the correct subscription
az account set --subscription 4ad94cd2-015f-4fe6-8651-b42a4379384b

# Step 4: Verify you have permission
az role assignment list \
  --assignee $(az account show --query user.name -o tsv) \
  --scope /subscriptions/4ad94cd2-015f-4fe6-8651-b42a4379384b \
  --output table

# Step 5: Now try granting the role again
az role assignment create \
  --assignee 9d99e5bd-6613-4c79-a8a1-5f2bbeaaf991 \
  --role "User Access Administrator" \
  --scope /subscriptions/4ad94cd2-015f-4fe6-8651-b42a4379384b
```

---

## Alternative: Grant via Azure Portal

If the CLI continues to fail, use the Azure Portal:

### Steps:

1. Go to **Azure Portal** (portal.azure.com)
2. Navigate to **Subscriptions**
3. Click on your subscription (ID: `4ad94cd2-015f-4fe6-8651-b42a4379384b`)
4. Click **Access control (IAM)** in the left menu
5. Click **+ Add** → **Add role assignment**
6. Select **User Access Administrator** role
7. Click **Next**
8. Click **+ Select members**
9. In the search box, paste: `9d99e5bd-6613-4c79-a8a1-5f2bbeaaf991`
10. Select the service principal that appears
11. Click **Select**
12. Click **Review + assign**
13. Click **Review + assign** again

---

## Verify the Service Principal Exists

```bash
# Check if the service principal exists and get its details
az ad sp show --id 9d99e5bd-6613-4c79-a8a1-5f2bbeaaf991

# If it exists, you should see details like displayName, appId, etc.
```

---

## Complete Verification Script

```bash
#!/bin/bash

echo "=== Azure Environment Check ==="
echo ""

# Check if logged in
echo "1. Checking Azure login status..."
if az account show &>/dev/null; then
    echo "✓ Logged in"
    az account show --query "{User:user.name, Subscription:name, TenantId:tenantId}" -o table
else
    echo "✗ Not logged in. Run: az login"
    exit 1
fi

echo ""
echo "2. Checking subscription access..."
SUBSCRIPTION_ID="4ad94cd2-015f-4fe6-8651-b42a4379384b"
if az account show --subscription $SUBSCRIPTION_ID &>/dev/null; then
    echo "✓ Have access to subscription: $SUBSCRIPTION_ID"
else
    echo "✗ No access to subscription: $SUBSCRIPTION_ID"
    echo "Available subscriptions:"
    az account list --query "[].{Name:name, ID:id}" -o table
    exit 1
fi

echo ""
echo "3. Checking your permissions on subscription..."
az role assignment list \
    --assignee $(az account show --query user.name -o tsv) \
    --scope /subscriptions/$SUBSCRIPTION_ID \
    --query "[].{Role:roleDefinitionName, Scope:scope}" \
    -o table

echo ""
echo "4. Checking if service principal exists..."
SP_ID="9d99e5bd-6613-4c79-a8a1-5f2bbeaaf991"
if az ad sp show --id $SP_ID &>/dev/null; then
    echo "✓ Service principal exists"
    az ad sp show --id $SP_ID --query "{DisplayName:displayName, AppId:appId, ObjectId:id}" -o table
else
    echo "✗ Service principal not found: $SP_ID"
    exit 1
fi

echo ""
echo "=== All checks passed! You can proceed with role assignment ==="
```

---

## Most Likely Issue: Need to Set Subscription

The most common cause is that Azure CLI isn't using the right subscription. Try this:

```bash
# Set the subscription explicitly
az account set --subscription 4ad94cd2-015f-4fe6-8651-b42a4379384b

# Then retry the role assignment
az role assignment create \
  --assignee 9d99e5bd-6613-4c79-a8a1-5f2bbeaaf991 \
  --role "User Access Administrator" \
  --scope /subscriptions/4ad94cd2-015f-4fe6-8651-b42a4379384b
```

---

## If You Don't Have Permission

If you get an authorization error after setting the subscription, you'll need to:

1. **Contact your Azure subscription administrator** to grant you Owner or User Access Administrator role

2. **OR use an account that has Owner permissions** to run the role assignment

3. **OR use the Azure Portal** (sometimes has different permission caching)

---

## Quick Fix Attempt

```bash
# Quick fix sequence
az login
az account set --subscription 4ad94cd2-015f-4fe6-8651-b42a4379384b
az account show  # Verify it's set

# Now try the role assignment
az role assignment create \
  --assignee 9d99e5bd-6613-4c79-a8a1-5f2bbeaaf991 \
  --role "User Access Administrator" \
  --scope /subscriptions/4ad94cd2-015f-4fe6-8651-b42a4379384b
```

---

## Expected Success Output

When it works, you should see:

```json
{
  "condition": null,
  "conditionVersion": null,
  "createdBy": null,
  "createdOn": "2025-10-18T...",
  "delegatedManagedIdentityResourceId": null,
  "description": null,
  "id": "/subscriptions/4ad94cd2-015f-4fe6-8651-b42a4379384b/providers/Microsoft.Authorization/roleAssignments/...",
  "name": "...",
  "principalId": "9d99e5bd-6613-4c79-a8a1-5f2bbeaaf991",
  "principalType": "ServicePrincipal",
  "roleDefinitionId": "/subscriptions/4ad94cd2-015f-4fe6-8651-b42a4379384b/providers/Microsoft.Authorization/roleDefinitions/18d7d88d-d35e-4fb5-a5c3-7773c20a72d9",
  "scope": "/subscriptions/4ad94cd2-015f-4fe6-8651-b42a4379384b",
  "type": "Microsoft.Authorization/roleAssignments",
  "updatedBy": "...",
  "updatedOn": "2025-10-18T..."
}
```

---

## Summary

**Most likely fix:**
```bash
az account set --subscription 4ad94cd2-015f-4fe6-8651-b42a4379384b
```

**Then retry:**
```bash
az role assignment create \
  --assignee 9d99e5bd-6613-4c79-a8a1-5f2bbeaaf991 \
  --role "User Access Administrator" \
  --scope /subscriptions/4ad94cd2-015f-4fe6-8651-b42a4379384b
```

If that doesn't work, try Azure Portal or contact your admin.
