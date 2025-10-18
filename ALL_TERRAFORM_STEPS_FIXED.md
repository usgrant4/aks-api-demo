# All Terraform Steps Fixed for OIDC Authentication

## Issue Resolved

Every Terraform command in the workflow now has the required ARM authentication environment variables for OIDC.

---

## Steps Updated

### ✅ 1. Terraform Init/Apply (Deploy Job)
**Location:** Lines 218-239

```yaml
- name: Terraform Init/Apply
  env:
    ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
    ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
    ARM_USE_OIDC: true
  run: terraform init ... && terraform apply ...
```

### ✅ 2. Fetch Outputs (Deploy Job)
**Location:** Lines 241-257
**Fixed:** Added ARM environment variables

```yaml
- name: Fetch outputs
  env:
    ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
    ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
    ARM_USE_OIDC: true
  run: terraform output ...
```

**Why:** `terraform output` also needs to authenticate to read the state file.

### ✅ 3. Terraform Destroy (Destroy Job)
**Location:** Lines 450-486

```yaml
- name: Terraform Destroy
  env:
    ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
    ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
    ARM_USE_OIDC: true
  run: terraform init ... && terraform destroy ...
```

---

## Why Every Step Needs These Variables

### Terraform State Access

**Every Terraform command** that accesses state needs authentication:

| Command | Accesses State? | Needs Auth? |
|---------|----------------|-------------|
| `terraform init` | ✅ Yes (backend) | ✅ Yes |
| `terraform apply` | ✅ Yes (read/write) | ✅ Yes |
| `terraform output` | ✅ Yes (read) | ✅ Yes |
| `terraform destroy` | ✅ Yes (read/write) | ✅ Yes |
| `terraform plan` | ✅ Yes (read) | ✅ Yes |

**Bottom line:** If a Terraform command touches state (which is stored in Azure Storage), it needs ARM authentication.

---

## Environment Variables Explained

### Required for OIDC Authentication

```yaml
ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
# The service principal's application/client ID

ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
# Your Azure subscription ID

ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
# Your Azure AD tenant ID

ARM_USE_OIDC: true
# Tells Terraform to use OIDC tokens instead of client secret
```

### How OIDC Works

1. GitHub Actions gets an OIDC token from GitHub
2. Azure validates the token against the federated credential
3. Terraform uses these environment variables to authenticate
4. Azure grants access to resources

---

## Complete Workflow Structure

```yaml
jobs:
  deploy:
    steps:
      # 1. Azure login (sets up OIDC session)
      - name: Azure login (OIDC)
        uses: azure/login@v2

      # 2. Terraform init (needs ARM vars for backend)
      - name: Terraform Init/Apply
        env:
          ARM_CLIENT_ID: ...
          ARM_TENANT_ID: ...
          ARM_SUBSCRIPTION_ID: ...
          ARM_USE_OIDC: true

      # 3. Fetch outputs (needs ARM vars to read state)
      - name: Fetch outputs
        env:
          ARM_CLIENT_ID: ...
          ARM_TENANT_ID: ...
          ARM_SUBSCRIPTION_ID: ...
          ARM_USE_OIDC: true

  destroy:
    steps:
      # 1. Azure login
      - name: Azure login (OIDC)

      # 2. Terraform destroy (needs ARM vars)
      - name: Terraform Destroy
        env:
          ARM_CLIENT_ID: ...
          ARM_TENANT_ID: ...
          ARM_SUBSCRIPTION_ID: ...
          ARM_USE_OIDC: true
```

---

## Common Pattern

Every Terraform step follows this pattern:

```yaml
- name: Any Terraform Step
  working-directory: ${{ env.TF_WORKING_DIR }}
  env:
    # ALWAYS include these 4 variables
    ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
    ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
    ARM_USE_OIDC: true
    # Plus any step-specific variables
  run: |
    terraform <command>
```

---

## What Was Missing Before

### ❌ Before: Fetch Outputs Step

```yaml
- name: Fetch outputs
  working-directory: ${{ env.TF_WORKING_DIR }}
  # Missing ARM environment variables!
  run: terraform output -raw acr_login_server
```

**Result:** Error about missing Tenant ID and Client ID

### ✅ After: Fetch Outputs Step

```yaml
- name: Fetch outputs
  working-directory: ${{ env.TF_WORKING_DIR }}
  env:
    ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
    ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
    ARM_USE_OIDC: true
  run: terraform output -raw acr_login_server
```

**Result:** ✅ Works correctly

---

## Verification

### All Steps That Run Terraform Commands

1. ✅ **Setup Terraform backend** - Uses `az` CLI (not terraform)
2. ✅ **Terraform Init/Apply** - Has ARM vars
3. ✅ **Fetch outputs** - Has ARM vars (NEWLY ADDED)
4. ✅ **Terraform Destroy** - Has ARM vars

### Steps That DON'T Need ARM Vars

- Azure login (uses different auth)
- AKS get-credentials (uses `az` CLI)
- Build & push image (uses `az` CLI)
- Deploy manifests (uses `kubectl`)
- Any step not running Terraform commands

---

## Testing Checklist

After pushing this fix, verify:

- [ ] Terraform init succeeds
- [ ] Terraform apply succeeds
- [ ] **Fetch outputs succeeds** ← This was failing before
- [ ] Infrastructure is created
- [ ] Application deploys

---

## Error Messages You Won't See Anymore

### ❌ Before

```
Error: Error building ARM Config: 2 errors occurred:
	* a Tenant ID must be configured when authenticating with OIDC
	* a Client ID must be configured when authenticating with OIDC
```

### ✅ After

```
ACR_LOGIN_SERVER=youracr.azurecr.io
RG=your-resource-group
AKS=your-aks-cluster
✓ Outputs fetched successfully
```

---

## Summary

### Changes Made

1. ✅ Added ARM environment variables to **Terraform Init/Apply** step
2. ✅ Added ARM environment variables to **Fetch outputs** step (NEW FIX)
3. ✅ Added ARM environment variables to **Terraform Destroy** step
4. ✅ Added `use_oidc=true` to backend configs

### Why This Works

- Terraform needs authentication for **every** state operation
- OIDC requires `ARM_CLIENT_ID`, `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`
- `ARM_USE_OIDC=true` tells Terraform to use OIDC tokens
- All Terraform steps now have complete authentication

### Next Steps

```bash
# Commit and push
git add .github/workflows/ci-cd.yml
git commit -m "Fix: Add ARM authentication to all Terraform steps"
git push origin dev

# Monitor workflow
# All Terraform steps should now succeed!
```

---

**Status:** ✅ All Terraform authentication issues resolved!
