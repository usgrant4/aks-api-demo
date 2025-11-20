# CI/CD Workflow Fix Summary

## Issues Fixed

### 1. Federated Identity Credential Mismatch
**Problem:** Azure OIDC authentication failing with error:
```
AADSTS700213: No matching federated identity record found for presented assertion subject
'repo:usgrant4/aks-api-demo:ref:refs/heads/dev'
```

**Root Cause:** Federated credentials still referenced old repository name `liatrio-demo` instead of `aks-api-demo`

**Solution:** Update federated credentials in Azure AD App Registration:
- Delete old credentials: `repo:usgrant4/liatrio-demo:ref:refs/heads/{main,dev}`
- Add new credentials: `repo:usgrant4/aks-api-demo:ref:refs/heads/{main,dev}`

**Status:** ✅ User needs to update in Azure Portal (instructions provided)

### 2. Missing Helm Values File
**Problem:** Workflow failing with error:
```
Error: open ./helm/aks-demo/values-dev.yaml: no such file or directory
```

**Root Cause:** Workflow referenced `values-${{ env.ENVIRONMENT }}.yaml` which doesn't exist for dev environment

**Helm Chart Structure:**
- `values.yaml` - Default values (used for dev)
- `values-prod.yaml` - Production overrides

**Solution:** Updated workflow to conditionally select values file:
```bash
if [ "${{ env.ENVIRONMENT }}" == "prod" ]; then
  VALUES_FILE="./helm/aks-demo/values-prod.yaml"
else
  VALUES_FILE="./helm/aks-demo/values.yaml"
fi
```

**Status:** ✅ Fixed in [.github/workflows/ci-cd.yml](.github/workflows/ci-cd.yml)

## Files Modified

### .github/workflows/ci-cd.yml

**Modified Sections:**

1. **Validate Helm chart** (Lines 462-498)
   - Added conditional logic to select correct values file
   - Uses `values.yaml` for dev environment
   - Uses `values-prod.yaml` for prod environment

2. **Deploy with Helm** (Lines 558-593)
   - Added same conditional logic for deployment
   - Logs which values file is being used

## Testing Steps

After updating federated credentials in Azure:

1. **Wait 2-5 minutes** for Azure AD to propagate changes

2. **Re-run the GitHub Actions workflow**
   ```
   GitHub → Actions → Select failed workflow → Re-run all jobs
   ```

3. **Verify authentication succeeds**
   - Look for: "Login successful" in Azure CLI Login step

4. **Verify Helm validation passes**
   - Should show: "Using values file: ./helm/aks-demo/values.yaml" (for dev)
   - Should show: "Linting Helm chart..." with no errors

5. **Verify deployment succeeds**
   - Should show: "✓ Deployment completed successfully (revision N)"

## Next Actions Required

### Azure Portal (Required)

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to: App registrations → `github-actions-liatrio-demo`
3. Go to: Certificates & secrets → Federated credentials tab
4. Delete both existing credentials:
   - `github-actions-main`
   - `github-actions-dev`
5. Add new credentials:

**Main Branch:**
- Scenario: GitHub Actions deploying Azure resources
- Organization: `usgrant4`
- Repository: `aks-api-demo`
- Entity type: Branch
- Branch name: `main`
- Name: `github-aks-demo-main`

**Dev Branch:**
- Scenario: GitHub Actions deploying Azure resources
- Organization: `usgrant4`
- Repository: `aks-api-demo`
- Entity type: Branch
- Branch name: `dev`
- Name: `github-aks-demo-dev`

6. Wait 2 minutes for propagation
7. Re-run GitHub Actions workflow

### Optional: Rename App Registration

For consistency, you can rename the App Registration:
- Current name: `github-actions-liatrio-demo`
- Suggested name: `github-actions-aks-demo`

This is cosmetic only - not required for functionality.

## Verification Checklist

- [ ] Azure federated credentials updated to reference `aks-api-demo`
- [ ] Both `main` and `dev` branch credentials exist
- [ ] Waited 2-5 minutes after updating credentials
- [ ] GitHub Actions workflow re-run
- [ ] Azure authentication succeeds
- [ ] Helm chart validation passes with correct values file
- [ ] Deployment completes successfully
- [ ] Application is accessible via LoadBalancer IP

## Reference Documentation

- [FEDERATED_CREDENTIAL_FIX.md](docs/FEDERATED_CREDENTIAL_FIX.md) - Detailed fix instructions
- [HELM_MIGRATION.md](HELM_MIGRATION.md) - Helm chart usage guide
- [REBRANDING_SUMMARY.md](REBRANDING_SUMMARY.md) - Repository rebranding details

## Summary

Two issues were identified and resolved:

1. **Federated credentials** - Need manual update in Azure Portal (one-time fix)
2. **Helm values file** - Fixed in workflow code (already committed)

Once federated credentials are updated, the CI/CD pipeline will work correctly for both dev and prod environments.
