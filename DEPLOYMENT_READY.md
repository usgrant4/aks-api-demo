# Ready to Deploy - Quick Start

## You're Almost There! Just One Command Needed

Since you deleted the `tfstate-rg` resource group, you need to grant the User Access Administrator role at the **subscription level** first.

---

## ⚡ Quick Start (Copy & Run)

```bash
# Replace with your actual values from GitHub secrets
az role assignment create \
  --assignee <YOUR_AZURE_CLIENT_ID> \
  --role "User Access Administrator" \
  --scope /subscriptions/<YOUR_AZURE_SUBSCRIPTION_ID>
```

**That's it!** After this one-time command, everything is automated.

---

## Then Deploy

```bash
# Push to dev branch to test
git push origin dev

# Or push to main for production
git push origin main
```

---

## Why This is Needed

**The Problem:**
- Your service principal has `Contributor` role (can create resources)
- But needs `User Access Administrator` role to grant Storage Blob Data Contributor
- Can't scope to `tfstate-rg` because it doesn't exist yet

**The Solution:**
- Grant User Access Administrator at **subscription level**
- Workflow can then create tfstate-rg
- Workflow can then grant Storage Blob Data Contributor automatically

---

## What Happens Next

After you grant this permission and push:

1. ✅ Workflow creates `tfstate-rg` resource group
2. ✅ Workflow creates `tfstateugrantliatrio` storage account
3. ✅ **Workflow automatically grants Storage Blob Data Contributor** ← NEW!
4. ✅ Workflow creates `tfstate` container
5. ✅ Workflow validates access
6. ✅ Terraform deploys infrastructure
7. ✅ Application deploys to Kubernetes

**All fully automated - zero manual intervention!**

---

## Verify Your Current Permissions

```bash
# Check what roles your service principal has
az role assignment list \
  --assignee <YOUR_AZURE_CLIENT_ID> \
  --scope /subscriptions/<YOUR_AZURE_SUBSCRIPTION_ID> \
  --output table
```

**Before:** You should see:
- `Contributor`

**After running the command above:** You should see:
- `Contributor`
- `User Access Administrator`

---

## Expected Workflow Output

```
Creating resource group: tfstate-rg
✓ Resource group created
Creating storage account: tfstateugrantliatrio
✓ Storage account created
✓ Storage account provisioning complete
Granting Storage Blob Data Contributor role to service principal...
✓ Storage Blob Data Contributor role granted  ← Automated!
Waiting 10s for backend stabilization and role propagation...
Creating blob container: tfstate
✓ Blob container created
Validating backend access...
✓ Backend access validated
✓ Terraform backend ready

[Terraform deployment proceeds...]
```

---

## Summary

**What you need to do:**
1. Run the `az role assignment create` command above (one time)
2. Push to GitHub

**What the workflow does:**
- Everything else automatically!

**Total setup time:** ~2 minutes
**Deployment time:** ~8-10 minutes (first run)

---

## Full Documentation

- **This guide:** Quick start
- **`GRANT_PERMISSIONS_FIRST.md`:** Detailed explanation
- **`AUTOMATED_PERMISSION_GRANT.md`:** How automation works
- **`docs/GITHUB_SETUP.md`:** Complete setup guide
- **`DEV_TESTING_QUICK_START.md`:** Testing from dev branch

---

## Ready?

```bash
# 1. Grant permission
az role assignment create \
  --assignee <YOUR_AZURE_CLIENT_ID> \
  --role "User Access Administrator" \
  --scope /subscriptions/<YOUR_AZURE_SUBSCRIPTION_ID>

# 2. Deploy
git push origin dev

# 3. Monitor
# Go to GitHub → Actions tab → Watch the magic happen! ✨
```

That's it! 🚀
