# Terraform OIDC Authentication Fix

## Issue: "Authenticating using the Azure CLI is only supported as a User"

### Error You Were Seeing

```
Error: Error building ARM Config: Authenticating using the Azure CLI is only supported as a User (not a Service Principal).

To authenticate to Azure using a Service Principal, you can use the separate 'Authenticate using a Service Principal'
auth method
```

### Root Cause

Terraform was trying to use Azure CLI authentication for the backend, but:
- GitHub Actions authenticates using **OIDC (OpenID Connect)** with a service principal
- Terraform backend needs to be explicitly told to use **OIDC authentication**
- Without the right environment variables, Terraform defaults to Azure CLI auth (which doesn't work with service principals)

---

## Solution Applied

Added ARM authentication environment variables to Terraform steps:

### Environment Variables Added

```yaml
env:
  ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
  ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
  ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
  ARM_USE_OIDC: true  # ← Critical! Tells Terraform to use OIDC
```

### Backend Configuration Updated

```yaml
terraform init \
  -backend-config="resource_group_name=$ARM_BACKEND_RESOURCE_GROUP" \
  -backend-config="storage_account_name=$ARM_BACKEND_STORAGE_ACCOUNT" \
  -backend-config="container_name=$ARM_BACKEND_CONTAINER" \
  -backend-config="key=$ARM_BACKEND_KEY" \
  -backend-config="use_oidc=true" \  # ← Also added here
  -input=false
```

---

## What Changed

### Deploy Job (Lines 218-239)

**Before:**
```yaml
- name: Terraform Init/Apply
  env:
    ARM_BACKEND_RESOURCE_GROUP: ${{ env.TF_BACKEND_RG }}
    # ... only backend config vars
  run: terraform init ...
```

**After:**
```yaml
- name: Terraform Init/Apply
  env:
    ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}           # ← Added
    ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }} # ← Added
    ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}           # ← Added
    ARM_USE_OIDC: true                                       # ← Added
    ARM_BACKEND_RESOURCE_GROUP: ${{ env.TF_BACKEND_RG }}
    # ... backend config vars
  run: terraform init -backend-config="use_oidc=true" ...  # ← Added flag
```

### Destroy Job (Lines 450-481)

Same changes applied to the destroy job for consistency.

---

## How OIDC Authentication Works

### The Authentication Flow

1. **GitHub Actions** requests an OIDC token from GitHub
2. **Azure Login Action** exchanges the token for Azure credentials
3. **Terraform** uses the same OIDC flow via environment variables
4. **Azure** validates the token and grants access

### Required Environment Variables

| Variable | Purpose |
|----------|---------|
| `ARM_CLIENT_ID` | Service principal client ID |
| `ARM_SUBSCRIPTION_ID` | Azure subscription ID |
| `ARM_TENANT_ID` | Azure AD tenant ID |
| `ARM_USE_OIDC` | Tells Terraform to use OIDC instead of CLI |

### Backend Configuration

The `-backend-config="use_oidc=true"` flag tells the Terraform **backend** (Azure Storage) to also use OIDC for authentication.

---

## Why This Is Better Than Client Secret

### OIDC (What We're Using) ✅

- ✅ No secrets stored in GitHub
- ✅ Short-lived tokens (expire quickly)
- ✅ Automatic token rotation
- ✅ Azure validates the token on each request
- ✅ Better security posture

### Client Secret (Alternative) ❌

- ❌ Long-lived secret in GitHub
- ❌ Manual rotation required
- ❌ Secret can be leaked
- ❌ More attack surface

---

## Verification

### Expected Terraform Init Output

```
Initializing the backend...

Successfully configured the backend "azurerm"! Terraform will automatically
use this backend unless the backend configuration changes.

Initializing provider plugins...
- Finding hashicorp/azurerm versions matching "~> 3.116"...
- Installing hashicorp/azurerm v3.116.0...
```

### No More Errors

You should **NOT** see:
- ❌ "Authenticating using the Azure CLI is only supported as a User"
- ❌ "Error building ARM Config"
- ❌ "Service Principal authentication required"

---

## Troubleshooting

### If You Still Get Authentication Errors

**Check GitHub Secrets:**
```bash
# Verify these secrets exist in GitHub:
# Settings → Secrets and variables → Actions
- AZURE_CLIENT_ID
- AZURE_TENANT_ID
- AZURE_SUBSCRIPTION_ID
```

**Check Federated Credential:**
```bash
# Verify federated credential exists for your branch
az ad app federated-credential list \
  --id <YOUR_APP_ID> \
  --query "[].{Name:name, Subject:subject}" -o table

# Should show credentials for both main and dev branches
```

**Check OIDC Token:**
The workflow automatically gets the OIDC token from GitHub. If this fails:
- Ensure workflow has `id-token: write` permission (already set)
- Check Azure login step succeeds before Terraform runs

---

## Related Configuration

### GitHub Actions Permissions (Already Set)

```yaml
permissions:
  id-token: write  # ← Required for OIDC
  contents: read
```

### Azure Login Step (Already Configured)

```yaml
- name: Azure login (OIDC)
  uses: azure/login@v2
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

This step authenticates the session, and then Terraform inherits that authentication via the ARM_* environment variables.

---

## Common Mistakes (Now Avoided)

### ❌ Wrong: Using Azure CLI for Backend
```yaml
# This doesn't work with service principals
terraform init (without ARM_USE_OIDC)
```

### ✅ Right: Using OIDC for Backend
```yaml
# This works with service principals
env:
  ARM_USE_OIDC: true
terraform init -backend-config="use_oidc=true"
```

### ❌ Wrong: Missing Backend OIDC Flag
```yaml
# Backend won't authenticate properly
terraform init -backend-config="resource_group_name=..."
# (missing use_oidc=true)
```

### ✅ Right: Including Backend OIDC Flag
```yaml
# Backend authenticates with OIDC
terraform init \
  -backend-config="use_oidc=true" \
  -backend-config="resource_group_name=..."
```

---

## Summary

### What Was Fixed

1. ✅ Added `ARM_CLIENT_ID`, `ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID` to Terraform steps
2. ✅ Added `ARM_USE_OIDC=true` environment variable
3. ✅ Added `-backend-config="use_oidc=true"` flag to terraform init
4. ✅ Applied to both deploy and destroy jobs

### Why It Works Now

- Terraform knows to use OIDC authentication (not Azure CLI)
- Backend uses the same OIDC authentication
- Service principal credentials properly propagated
- Fully automated, no manual intervention

### Next Steps

Push your changes and the workflow should now successfully:
1. Authenticate to Azure via OIDC ✅
2. Initialize Terraform backend via OIDC ✅
3. Deploy infrastructure ✅

---

## Testing

```bash
# Commit and push
git add .github/workflows/ci-cd.yml
git commit -m "Fix: Configure Terraform to use OIDC authentication"
git push origin dev

# Monitor the workflow
# GitHub → Actions → Watch "Terraform Init/Apply" step
# Should see: "Successfully configured the backend azurerm!"
```

---

**Status:** ✅ Fixed and ready to deploy!
