# Infrastructure Destroy - Quick Reference

## How to Destroy Infrastructure via GitHub Actions

### Quick Steps

1. **Go to GitHub**
   - Navigate to your repository
   - Click **Actions** tab
   - Select **ci-cd** workflow

2. **Run Workflow Manually**
   - Click **Run workflow** button (top right)
   - Select options:
     - **Destroy infrastructure**: `true`
     - **Environment to destroy**: `dev` or `prod`
   - Click **Run workflow**

3. **Monitor Progress**
   - Watch the workflow logs
   - Destruction typically takes 2-5 minutes
   - Look for: "✓ Infrastructure destroyed successfully"

4. **Verify in Azure Portal**
   - Check that resource group is deleted
   - Dev: `ugrant-liatrio-demo-dev-rg`
   - Prod: `ugrant-liatrio-demo-prod-rg`

## What It Does

- ✅ Destroys all Terraform-managed resources for selected environment
- ✅ Uses correct state file (dev or prod)
- ✅ Preserves Terraform backend and state history
- ✅ Skips build/test steps (not needed for destruction)
- ✅ Protected by concurrency locks

## What Gets Deleted

- Resource Group
- AKS Cluster
- Container Registry (ACR)
- Virtual Network
- All networking resources
- Kubernetes deployments

## What Does NOT Get Deleted

- Terraform backend resource group (`tfstate-rg`)
- Storage account (`tfstateugrantliatrio`)
- State files (remain in blob storage showing zero resources)

## Common Use Cases

### Before Deploying Major Changes
```
1. Destroy dev: Run workflow (destroy=true, env=dev)
2. Wait for completion
3. Push changes to dev branch
4. Fresh deployment with new configuration
```

### Weekend Cost Savings
```
Friday: Destroy dev environment (destroy=true, env=dev)
Monday: Redeploy (destroy=false, env=dev) OR push to dev
```

### Testing Fresh Deployment
```
1. Destroy existing: destroy=true
2. Redeploy: destroy=false or git push
3. Verify everything works from scratch
```

## Redeploying After Destroy

**Option 1: Manual Workflow**
- Run workflow with destroy=false, select environment

**Option 2: Git Push**
```bash
# For dev
git push origin dev

# For prod
git push origin main
```

## Safety Notes

⚠️ **Always double-check the environment** before destroying

⚠️ **Production destruction is irreversible** - data will be lost

⚠️ **Communicate with team** before destroying shared environments

✅ **State files are preserved** - you can always redeploy

✅ **Manual trigger only** - never destroys automatically

## Verification Commands

```bash
# Check if resource group exists (should fail after destroy)
az group show --name ugrant-liatrio-demo-dev-rg

# List resources with your prefix (should be empty)
az resource list --query "[?contains(name, 'liatrio-demo-dev')]" -o table
```

## Full Documentation

For detailed information, troubleshooting, and best practices, see:
- [docs/HOW_TO_DESTROY_INFRASTRUCTURE.md](docs/HOW_TO_DESTROY_INFRASTRUCTURE.md)

## Workflow Features

```yaml
workflow_dispatch:
  inputs:
    destroy:
      description: 'Destroy infrastructure (true/false)'
      type: choice
      options: ['false', 'true']
    environment:
      description: 'Environment to destroy (dev/prod)'
      type: choice
      options: ['dev', 'prod']
```

## Summary

The destroy feature provides a **safe, manual way** to tear down infrastructure for cost savings, testing, or decommissioning, while **preserving state history** for easy redeployment.
