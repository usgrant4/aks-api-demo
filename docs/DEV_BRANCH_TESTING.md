# Testing Workflow from Dev Branch

## Overview

The CI/CD workflow now supports testing from the `dev` branch before deploying to production (`main` branch). This allows you to validate all changes in an isolated environment.

---

## How It Works

### Branch Configuration

The workflow triggers on pushes to both branches:
```yaml
"on":
  push:
    branches: [main, dev]  # Both branches trigger the workflow
```

### Environment Separation

**Dev Branch (`dev`):**
- Environment: `dev`
- State file: `liatrio-demo-dev.tfstate`
- Concurrency group: `dev-deployment`
- Infrastructure prefix: Uses your existing `var.prefix` variable

**Main Branch (`main`):**
- Environment: `prod`
- State file: `liatrio-demo-prod.tfstate`
- Concurrency group: `production-deployment`
- Infrastructure prefix: Uses your existing `var.prefix` variable

### Separate Infrastructure

Dev and production deployments use **separate Terraform state files**, which means:
- ✅ Changes in dev **won't affect** production
- ✅ Both environments can exist **simultaneously**
- ✅ Different resource names (based on Terraform state)
- ✅ Isolated testing environment

---

## How to Test from Dev Branch

### 1. Ensure Dev Branch Exists Locally

```bash
# Check current branch
git branch

# If dev branch doesn't exist, create it
git checkout -b dev

# If dev branch exists, switch to it
git checkout dev
```

### 2. Make Your Changes

```bash
# Make changes to code, workflow, Terraform, etc.
# For example, edit app/main.py
```

### 3. Commit and Push to Dev

```bash
git add .
git commit -m "Test: Your change description"
git push -u origin dev
```

### 4. Monitor the Workflow

1. Go to your GitHub repository
2. Click **Actions** tab
3. Find your workflow run
4. Look for deployment to **dev** environment

### 5. Expected Behavior

**First Dev Deployment:**
- Creates Terraform state: `liatrio-demo-dev.tfstate`
- Provisions AKS cluster (takes ~8-10 minutes)
- Deploys application
- Provides LoadBalancer IP

**Subsequent Dev Deployments:**
- Updates existing dev infrastructure
- Faster (~6-8 minutes)
- Tests your changes in isolation

### 6. Verify Deployment

```bash
# After workflow completes, check the Actions output for:
# - LoadBalancer IP
# - Deployment success message

# Test the endpoint (replace with your dev IP)
curl http://<dev-loadbalancer-ip>/
curl http://<dev-loadbalancer-ip>/health
```

### 7. When Ready, Merge to Main

```bash
# Create pull request from dev to main
git checkout main
git merge dev
git push origin main

# Or use GitHub UI to create PR
```

---

## Workflow Behavior by Branch

| Aspect | Dev Branch | Main Branch |
|--------|-----------|-------------|
| **Trigger** | Push to `dev` | Push to `main` |
| **Environment** | dev | prod |
| **State File** | `liatrio-demo-dev.tfstate` | `liatrio-demo-prod.tfstate` |
| **Concurrency** | `dev-deployment` group | `production-deployment` group |
| **Infrastructure** | Separate (based on state) | Separate (based on state) |
| **Tests** | ✅ Run | ✅ Run |
| **Deployment** | ✅ Deploy | ✅ Deploy |
| **Rollback** | ✅ Enabled | ✅ Enabled |

---

## State File Separation

### Backend Configuration

Both environments share the same backend storage but use **different state files**:

```yaml
# Backend storage (shared)
TF_BACKEND_RG: tfstate-rg
TF_BACKEND_SA: tfstateugrantliatrio
TF_BACKEND_CONTAINER: tfstate

# State file (environment-specific)
# Dev:  liatrio-demo-dev.tfstate
# Prod: liatrio-demo-prod.tfstate
```

### What This Means

- ✅ Both environments in same storage account
- ✅ Different state files = isolated infrastructure
- ✅ No conflicts between dev and prod
- ✅ Can destroy dev without affecting prod

---

## Azure Service Principal Setup

### Option 1: Same Service Principal (Easier)

Use the same service principal for both dev and prod:

```bash
# Add federated credential for dev branch
az ad app federated-credential create \
  --id <APP_ID> \
  --parameters '{
    "name": "github-actions-dev",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:<GITHUB_USERNAME>/<REPO_NAME>:ref:refs/heads/dev",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Existing credential for main branch stays in place
```

**Pros:** Simple, reuses existing secrets
**Cons:** Same permissions for both environments

### Option 2: Separate Service Principals (More Secure)

Create separate service principals for dev and prod:

```bash
# Create dev service principal
az ad app create --display-name "github-actions-liatrio-demo-dev"

# Create federated credential
az ad app federated-credential create \
  --id <DEV_APP_ID> \
  --parameters '{
    "name": "github-actions-dev",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:<GITHUB_USERNAME>/<REPO_NAME>:ref:refs/heads/dev",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Assign Contributor role
az role assignment create \
  --assignee <DEV_APP_ID> \
  --role Contributor \
  --scope /subscriptions/<SUBSCRIPTION_ID>
```

Then create environment-specific secrets in GitHub:
- `AZURE_CLIENT_ID_DEV`
- `AZURE_CLIENT_ID_PROD`

And update workflow to use environment-specific secrets (requires workflow modification).

**Recommendation:** Start with Option 1 (same service principal), upgrade to Option 2 later if needed.

---

## GitHub Secrets Configuration

### Required Secrets (Same for Both Environments)

If using the same service principal (Option 1):

- `AZURE_CLIENT_ID` - Your service principal client ID
- `AZURE_TENANT_ID` - Your Azure tenant ID
- `AZURE_SUBSCRIPTION_ID` - Your Azure subscription ID

These secrets work for both dev and main branches.

### Federated Credentials Needed

You need **two** federated credentials on your service principal:

1. **For Main Branch** (production)
   ```json
   {
     "name": "github-actions-main",
     "subject": "repo:<USERNAME>/<REPO>:ref:refs/heads/main"
   }
   ```

2. **For Dev Branch** (testing)
   ```json
   {
     "name": "github-actions-dev",
     "subject": "repo:<USERNAME>/<REPO>:ref:refs/heads/dev"
   }
   ```

---

## Testing Checklist

### Initial Setup (One-Time)
- [ ] Add federated credential for dev branch
- [ ] Verify GitHub secrets are configured
- [ ] Create and push dev branch

### Each Test Cycle
- [ ] Make changes on dev branch
- [ ] Commit and push to dev
- [ ] Monitor workflow in Actions tab
- [ ] Verify deployment succeeds
- [ ] Test dev LoadBalancer endpoint
- [ ] If successful, merge to main

### Cleanup (Optional)
- [ ] If you want to destroy dev infrastructure:
  ```bash
  # Manually destroy via Azure CLI or portal
  # Or trigger workflow_dispatch destroy job
  ```

---

## Common Workflows

### Scenario 1: Test Infrastructure Changes

```bash
# Edit Terraform files
vim terraform/main.tf

# Commit and push to dev
git add terraform/
git commit -m "Test: Update AKS node size"
git push origin dev

# Wait for deployment, verify in Azure
# If good, merge to main
```

### Scenario 2: Test Application Changes

```bash
# Edit application code
vim app/main.py

# Commit and push to dev
git add app/
git commit -m "Test: Add new API endpoint"
git push origin dev

# Wait for deployment
# Test: curl http://<dev-ip>/new-endpoint
# If good, merge to main
```

### Scenario 3: Test Workflow Changes

```bash
# Edit workflow
vim .github/workflows/ci-cd.yml

# Commit and push to dev
git add .github/
git commit -m "Test: Update deployment timeout"
git push origin dev

# Monitor workflow execution
# If good, merge to main
```

---

## Cost Considerations

### Dev Environment Costs

Running a dev environment will incur additional Azure costs:
- AKS cluster (nodes, networking)
- Container Registry (shared with prod - no extra cost)
- LoadBalancer
- Storage

**Estimated Cost:** ~$50-100/month for basic AKS cluster (depends on node size)

### Cost Optimization Tips

1. **Use Smaller Nodes for Dev:**
   ```hcl
   # In terraform/variables.tf or via workflow
   node_vm_size = "Standard_B2s"  # Cheaper for dev
   ```

2. **Destroy Dev When Not Needed:**
   ```bash
   # Use workflow_dispatch to destroy dev infrastructure
   # Or manually via Azure CLI/Portal
   ```

3. **Shared Resources:**
   - Container Registry is shared (no duplication)
   - Storage account is shared (minimal cost)

---

## Troubleshooting

### Workflow Doesn't Trigger

**Cause:** Push didn't include changed paths

**Solution:** Workflow only triggers when you change:
- `app/**`
- `Dockerfile`
- `kubernetes/**`
- `terraform/**`
- `.github/workflows/ci-cd.yml`

Changing README or docs won't trigger deployment.

### Authentication Failed

**Cause:** Missing federated credential for dev branch

**Solution:**
```bash
# Add federated credential for dev branch
az ad app federated-credential create \
  --id <APP_ID> \
  --parameters '{
    "name": "github-actions-dev",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:<USERNAME>/<REPO>:ref:refs/heads/dev",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

### State Lock Conflict

**Cause:** Another workflow run is in progress

**Solution:** Wait for previous run to complete. Concurrency protection prevents simultaneous runs.

### Dev and Prod Using Same Resources

**Cause:** Terraform state files might be confused

**Solution:** Verify environment is set correctly:
1. Check workflow logs for "Deploying to environment: dev"
2. Verify state file name in logs
3. Check Azure resources have expected names

---

## Cleanup

### Destroy Dev Environment

**Option 1: Via Workflow (Recommended)**

Manually trigger destroy workflow for dev state file (requires workflow modification to support environment selection).

**Option 2: Via Azure CLI**

```bash
# Initialize Terraform with dev state
cd terraform
terraform init \
  -backend-config="resource_group_name=tfstate-rg" \
  -backend-config="storage_account_name=tfstateugrantliatrio" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=liatrio-demo-dev.tfstate"

# Destroy dev infrastructure
terraform destroy
```

**Option 3: Via Azure Portal**

1. Find resource group for dev environment
2. Delete resource group
3. Clean up Terraform state manually if needed

---

## Best Practices

### 1. Always Test in Dev First
- Never push breaking changes directly to main
- Use dev to validate infrastructure changes
- Test application changes end-to-end

### 2. Keep Dev and Main in Sync
- Regularly merge main into dev to avoid drift
- Don't let dev diverge too much from main

### 3. Clean Up Regularly
- Destroy dev environment when not actively testing
- Recreate when needed (workflow automates this)

### 4. Monitor Costs
- Check Azure cost analysis for dev resource group
- Destroy dev infrastructure overnight/weekends if not needed

### 5. Document Changes
- Use descriptive commit messages
- Note what you're testing in commit message
- Track issues in GitHub Issues

---

## Summary

✅ **Dev branch testing is now enabled**
✅ **Separate infrastructure for dev and prod**
✅ **Same workflow, different state files**
✅ **Safe testing without affecting production**

**To test:** Just push to the `dev` branch and monitor the Actions tab!

---

## Quick Reference

```bash
# Switch to dev branch
git checkout dev

# Make changes
vim app/main.py

# Test deployment
git add .
git commit -m "Test: Your change"
git push origin dev

# Monitor: GitHub → Actions tab

# When ready: Merge to main
git checkout main
git merge dev
git push origin main
```

**That's it!** The workflow handles the rest automatically. 🚀
