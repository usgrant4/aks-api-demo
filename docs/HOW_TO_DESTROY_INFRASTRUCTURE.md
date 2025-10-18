# How to Destroy Infrastructure Using GitHub Actions

This guide explains how to safely destroy your deployed infrastructure using the GitHub Actions workflow.

## Overview

The CI/CD workflow now supports manual infrastructure destruction through GitHub's workflow dispatch feature. This allows you to destroy infrastructure for either the `dev` or `prod` environment without pushing code changes.

## When to Use Destroy

You should use the destroy workflow when:

1. **Before Deploying Major Changes**: Destroy existing infrastructure before deploying significant architectural changes
2. **Cost Management**: Tear down dev/test environments when not in use to save costs
3. **Testing Fresh Deployments**: Start with a clean slate to test deployment from scratch
4. **Decommissioning**: Permanently remove environments that are no longer needed

## How to Destroy Infrastructure

### Step 1: Navigate to GitHub Actions

1. Go to your GitHub repository
2. Click on the **Actions** tab at the top
3. Select the **ci-cd** workflow from the left sidebar

### Step 2: Trigger Manual Workflow

1. Click the **Run workflow** button (top right)
2. You'll see a dropdown with two options:

   - **Destroy infrastructure**: Select `true` to destroy, `false` to deploy
   - **Environment to destroy**: Choose `dev` or `prod`

### Step 3: Confirm and Run

1. Select your desired options:
   - Set "Destroy infrastructure" to `true`
   - Choose the environment (`dev` or `prod`)
2. Click the green **Run workflow** button
3. The workflow will start immediately

### Step 4: Monitor Progress

1. Click on the running workflow to see real-time logs
2. The workflow will:
   - Skip the build-test job (not needed for destruction)
   - Initialize Terraform with the correct backend state
   - Run `terraform destroy -auto-approve`
   - Delete all infrastructure resources for that environment

## What Gets Destroyed

When you destroy an environment, the following resources are deleted:

- **Resource Group**: `{prefix}-liatrio-demo-{environment}-rg`
- **AKS Cluster**: `{prefix}-liatrio-demo-{environment}-aks`
- **Container Registry**: `{prefix}liatriodemo{environment}acr`
- **Virtual Network**: `{prefix}-liatrio-demo-{environment}-vnet`
- **All associated networking resources**
- **Kubernetes deployments and services** (deleted when AKS is destroyed)

**Note**: The Terraform backend resources (tfstate-rg, storage account, state files) are **NOT** destroyed. This preserves your state history.

## Safety Features

### 1. Environment Isolation

The destroy workflow uses the correct state file for the selected environment:
- `dev` → uses `liatrio-demo-dev.tfstate`
- `prod` → uses `liatrio-demo-prod.tfstate`

This prevents accidental destruction of the wrong environment.

### 2. Concurrency Protection

The workflow uses concurrency groups to prevent:
- Multiple simultaneous destructions of the same environment
- Destruction while a deployment is in progress

### 3. Manual Trigger Only

Infrastructure can only be destroyed by manually triggering the workflow. It will **never** destroy automatically on push or PR.

## Example Workflows

### Scenario 1: Destroy Dev Before Deploying New Changes

**Goal**: Test the new environment naming scheme from scratch

```bash
# Step 1: Destroy existing dev infrastructure via GitHub UI
# - Go to Actions → ci-cd → Run workflow
# - Set destroy=true, environment=dev

# Step 2: Wait for destruction to complete (2-5 minutes)

# Step 3: Push your new changes to dev branch
git push origin dev

# Step 4: New deployment will create resources with updated naming
```

### Scenario 2: Weekend Cost Savings

**Goal**: Tear down dev environment Friday evening, rebuild Monday morning

```bash
# Friday evening:
# - Run workflow with destroy=true, environment=dev

# Monday morning:
# - Run workflow with destroy=false, environment=dev
# OR push a commit to dev branch to trigger automatic deployment
```

### Scenario 3: Production Decommissioning

**Goal**: Permanently remove production infrastructure

```bash
# Step 1: Ensure you really want to do this (irreversible!)

# Step 2: Destroy production via GitHub UI
# - Go to Actions → ci-cd → Run workflow
# - Set destroy=true, environment=prod

# Step 3: Verify all resources deleted in Azure Portal
az resource list --resource-group ugrant-liatrio-demo-prod-rg
# Should return: (empty)

# Step 4: Optionally clean up state file
# - Delete liatrio-demo-prod.tfstate from storage account (optional)
```

## Verifying Destruction

### Check GitHub Actions Logs

Look for these success messages in the workflow logs:

```
⚠️  DESTROYING infrastructure for environment: dev
⚠️  This action is irreversible!
...
Destroy complete! Resources: X destroyed.
✓ Infrastructure destroyed successfully
```

### Check Azure Portal

1. Navigate to Azure Portal → Resource Groups
2. Verify the resource group no longer exists:
   - Dev: `ugrant-liatrio-demo-dev-rg`
   - Prod: `ugrant-liatrio-demo-prod-rg`

### Check with Azure CLI

```bash
# Set your subscription
az account set --subscription <YOUR_SUBSCRIPTION_ID>

# Check if resource group exists (should fail with NotFound)
az group show --name ugrant-liatrio-demo-dev-rg

# List all resources with your prefix
az resource list --query "[?contains(name, 'liatrio-demo-dev')]" -o table
```

## Redeploying After Destruction

After destroying infrastructure, you can redeploy in two ways:

### Method 1: Manual Workflow Trigger

1. Go to Actions → ci-cd → Run workflow
2. Set:
   - **Destroy infrastructure**: `false`
   - **Environment**: Choose `dev` or `prod`
3. Click Run workflow

### Method 2: Push to Branch

Simply push a commit to the appropriate branch:

```bash
# For dev environment
git push origin dev

# For prod environment
git push origin main
```

The workflow will automatically build, test, and deploy.

## Troubleshooting

### Error: "No state file found"

This can happen if you destroyed resources outside of Terraform (e.g., deleted resource group manually in Azure Portal).

**Solution**: The state file still exists but resources don't. You can:

1. Run workflow with destroy=false to let Terraform recreate resources
2. Or manually delete the state file from the storage account (if you're certain resources are gone)

### Error: "Failed to destroy resources"

Some resources may have dependencies that prevent deletion.

**Solution**:
1. Check the workflow logs for specific error messages
2. Manually delete problematic resources in Azure Portal
3. Re-run the destroy workflow

### Warning: "Using local state - backend not available"

This means Terraform couldn't access the remote state file.

**Solution**:
- This is usually fine for destruction if you're certain the resources exist
- Terraform will use local state tracking
- Verify in Azure Portal that resources were actually destroyed

## Best Practices

1. **Always verify environment**: Double-check you selected the correct environment (dev vs prod)
2. **Backup important data**: Before destroying prod, ensure any important data is backed up
3. **Communicate with team**: Let your team know before destroying shared environments
4. **Check costs first**: Review Azure Cost Management before destroying to understand savings
5. **Keep state files**: Don't delete state files unless you're absolutely sure infrastructure is gone

## State File Management

The Terraform state files are stored in:
- Storage Account: `tfstateugrantliatrio`
- Container: `tfstate`
- Dev State: `liatrio-demo-dev.tfstate`
- Prod State: `liatrio-demo-prod.tfstate`

After destruction, the state file will show zero resources but preserve the history. This is useful for:
- Auditing what was previously deployed
- Redeploying with the same configuration
- Tracking infrastructure changes over time

## FAQ

**Q: Does destroying also delete the Terraform state file?**
A: No, the state file remains in blob storage but shows zero resources.

**Q: Can I destroy only specific resources?**
A: No, the destroy workflow destroys all Terraform-managed resources for that environment. To delete specific resources, use Azure Portal or CLI.

**Q: How long does destruction take?**
A: Typically 2-5 minutes, depending on the number of resources.

**Q: Can I cancel a destroy in progress?**
A: Yes, but it may leave resources in an inconsistent state. You'll need to run destroy again to clean up.

**Q: What if I accidentally destroy production?**
A: You can redeploy immediately using the workflow (destroy=false, environment=prod). However, any data in the environment will be lost.

**Q: Does destroy affect the tfstate-rg resource group?**
A: No, the backend resources (tfstate-rg, storage account) are never destroyed automatically.

## Related Documentation

- [Environment Tagging and Naming](./ENVIRONMENT_TAGGING_AND_NAMING.md) - Understanding environment-specific resource names
- [GitHub Setup Guide](./GITHUB_SETUP.md) - Initial workflow setup and secrets
- [How to Test Deployment](../HOW_TO_TEST_DEPLOYMENT.md) - Testing after redeployment
