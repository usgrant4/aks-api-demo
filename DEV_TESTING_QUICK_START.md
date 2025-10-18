# Dev Branch Testing - Quick Start

## ✅ Yes, You Can Test from Dev Branch!

The workflow is now configured to run on both `dev` and `main` branches with **separate infrastructure**.

---

## Quick Setup

### 1. Add Federated Credential for Dev Branch

```bash
az ad app federated-credential create \
  --id <YOUR_APP_ID> \
  --parameters '{
    "name": "github-actions-dev",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:usgrant4/liatrio-demo:ref:refs/heads/dev",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

**Note:** Replace `<YOUR_APP_ID>` with your Azure AD app ID.

---

## How to Test

```bash
# 1. Switch to dev branch (you're already on it!)
git status  # Shows: On branch dev

# 2. Make your changes
# (files are already modified)

# 3. Push to dev
git push origin dev

# 4. Monitor workflow
# Go to GitHub → Actions tab
# Watch the deployment to "dev" environment

# 5. Test the deployment
# Get LoadBalancer IP from workflow output
curl http://<dev-ip>/
curl http://<dev-ip>/health
```

---

## What Happens

**Dev Branch:**
- Environment: `dev`
- State file: `liatrio-demo-dev.tfstate`
- Separate infrastructure from production
- Safe to test without affecting main

**Main Branch:**
- Environment: `prod`
- State file: `liatrio-demo-prod.tfstate`
- Production infrastructure
- Only updated when you merge dev → main

---

## Key Changes Made

### 1. Workflow Triggers on Dev
```yaml
branches: [main, dev]  # Added dev
```

### 2. Environment Detection
- Automatically detects branch
- Sets environment to `dev` or `prod`
- Uses different state files

### 3. Separate Concurrency Groups
- Dev deployments queue separately from prod
- No conflicts between environments

---

## Current Status

You're already on the `dev` branch with changes ready to push:

```bash
# Check your current branch
git branch
# * dev  ← You're here

# Check your changes
git status
# M .github/workflows/ci-cd.yml  ← Workflow now supports dev
# M terraform/main.tf            ← P0/P1 fixes applied
# ... other files
```

---

## Next Steps

### Option 1: Test Changes Now

```bash
# Push to dev and test
git push origin dev

# Monitor: https://github.com/usgrant4/liatrio-demo/actions
```

### Option 2: Review Changes First

```bash
# See what will be deployed
git diff main..dev

# Review workflow changes
git diff main..dev -- .github/workflows/ci-cd.yml
```

### Option 3: Merge to Main Directly

```bash
# If you want to skip dev testing
git checkout main
git merge dev
git push origin main
```

---

## Important Notes

### Azure Setup Required

Before pushing to dev, ensure:
- [ ] Federated credential for dev branch exists
- [ ] Same GitHub secrets work for both branches
  - `AZURE_CLIENT_ID`
  - `AZURE_TENANT_ID`
  - `AZURE_SUBSCRIPTION_ID`

### Cost Awareness

Dev environment creates **separate Azure resources**:
- Separate AKS cluster
- Separate LoadBalancer
- Shared Container Registry
- **Estimated cost:** ~$50-100/month (can destroy when not needed)

### Testing Safety

✅ Changes in dev **won't affect** production
✅ Both environments can exist simultaneously
✅ Same workflow, different state files
✅ Automatic rollback enabled for both

---

## Workflow Summary

| Feature | Dev Branch | Main Branch |
|---------|-----------|-------------|
| **Trigger** | ✅ Push to dev | ✅ Push to main |
| **Tests** | ✅ Run pytest | ✅ Run pytest |
| **Deploy** | ✅ To dev | ✅ To prod |
| **State** | dev.tfstate | prod.tfstate |
| **Rollback** | ✅ Enabled | ✅ Enabled |
| **P0/P1 Fixes** | ✅ Applied | ✅ Applied |

---

## Quick Commands

```bash
# Test in dev
git push origin dev

# View workflow
open https://github.com/usgrant4/liatrio-demo/actions

# When ready, promote to production
git checkout main
git merge dev
git push origin main
```

---

## Documentation

- **Full Guide:** `docs/DEV_BRANCH_TESTING.md`
- **Setup Guide:** `docs/GITHUB_SETUP.md`
- **All Fixes:** `docs/P0_P1_FIXES_APPLIED.md`
- **Final Status:** `FINAL_STATUS.md`

---

## Questions?

**Q: Do I need separate Azure credentials for dev?**
A: No, add a federated credential for dev branch to your existing service principal.

**Q: Will dev affect production?**
A: No, completely separate infrastructure via different state files.

**Q: Can I destroy dev when not testing?**
A: Yes, use workflow_dispatch destroy or Azure CLI/Portal.

**Q: What if dev and prod conflict?**
A: They can't conflict - separate concurrency groups and state files.

---

**Ready to test?** Just push to dev! 🚀

```bash
git push origin dev
```
