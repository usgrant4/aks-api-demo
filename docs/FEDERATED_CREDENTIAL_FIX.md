# Fixing Federated Identity Credential for Multi-Branch Support

## Problem

GitHub Actions CI/CD fails on the `dev` branch with:
```
AADSTS700213: No matching federated identity record found for presented assertion subject
'repo:usgrant4/aks-api-demo:ref:refs/heads/dev'
```

This occurs because the Azure AD App Registration only has a federated credential configured for the `main` branch.

## Solution

You need to add a separate federated identity credential for the `dev` branch.

### Option 1: Azure Portal (Recommended for Quick Fix)

1. **Navigate to Azure Portal**
   - Go to [Azure Portal](https://portal.azure.com)
   - Search for "App registrations" or "Microsoft Entra ID"

2. **Find Your App Registration**
   - Click on "App registrations" in the left menu
   - Find and click on your app (the one with CLIENT_ID that matches your GitHub secret `AZURE_CLIENT_ID`)

3. **Add Federated Credential for Dev Branch**
   - In the left menu, click **"Certificates & secrets"**
   - Click on the **"Federated credentials"** tab
   - Click **"+ Add credential"**
   - Select scenario: **"GitHub Actions deploying Azure resources"**

4. **Configure the Credential**
   - **Organization**: `usgrant4`
   - **Repository**: `aks-api-demo`
   - **Entity type**: `Branch`
   - **GitHub branch name**: `dev`
   - **Name**: `github-aks-demo-dev` (or any descriptive name)
   - **Description**: `Federated credential for dev branch deployments`
   - **Audience**: `api://AzureADTokenExchange` (default, should already be filled)

5. **Save**
   - Click **"Add"**
   - Wait a few seconds for the credential to propagate

6. **Verify Configuration**
   You should now see at least two federated credentials:
   - One for `main` branch (subject: `repo:usgrant4/aks-api-demo:ref:refs/heads/main`)
   - One for `dev` branch (subject: `repo:usgrant4/aks-api-demo:ref:refs/heads/dev`)

### Option 2: Azure CLI

```bash
# Set variables
APP_ID="<your-app-registration-client-id>"  # Same as AZURE_CLIENT_ID GitHub secret
SUBSCRIPTION_ID="<your-subscription-id>"

# Login to Azure
az login

# Set subscription
az account set --subscription "$SUBSCRIPTION_ID"

# Add federated credential for dev branch
az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters '{
    "name": "github-aks-demo-dev",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:usgrant4/aks-api-demo:ref:refs/heads/dev",
    "audiences": ["api://AzureADTokenExchange"],
    "description": "Federated credential for dev branch deployments"
  }'

# List all federated credentials to verify
az ad app federated-credential list --id "$APP_ID"
```

### Option 3: Add Support for All Branches (Pull Requests)

If you want to support deployments from any branch or pull requests:

**For Pull Requests:**
```bash
az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters '{
    "name": "github-aks-demo-pr",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:usgrant4/aks-api-demo:pull_request",
    "audiences": ["api://AzureADTokenExchange"],
    "description": "Federated credential for pull request deployments"
  }'
```

**For Environment-based (Alternative Approach):**
If you want to use GitHub Environments instead of branches:
```bash
# For 'dev' environment
az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters '{
    "name": "github-aks-demo-env-dev",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:usgrant4/aks-api-demo:environment:dev",
    "audiences": ["api://AzureADTokenExchange"],
    "description": "Federated credential for dev environment"
  }'

# For 'prod' environment
az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters '{
    "name": "github-aks-demo-env-prod",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:usgrant4/aks-api-demo:environment:prod",
    "audiences": ["api://AzureADTokenExchange"],
    "description": "Federated credential for prod environment"
  }'
```

## Verification

After adding the federated credential:

1. **Wait 1-2 minutes** for the credential to propagate in Azure AD

2. **Re-run the GitHub Actions workflow**
   - Go to GitHub → Actions
   - Select the failed workflow run
   - Click "Re-run all jobs"

3. **Check the Azure CLI Login step**
   - It should now succeed with:
     ```
     Attempting Azure CLI login by using OIDC...
     Login successful.
     ```

## Understanding Federated Credentials

### What is the Subject Claim?

The subject claim identifies WHO is requesting the token. GitHub Actions sends this automatically based on:

- **Branch**: `repo:OWNER/REPO:ref:refs/heads/BRANCH_NAME`
- **Pull Request**: `repo:OWNER/REPO:pull_request`
- **Tag**: `repo:OWNER/REPO:ref:refs/tags/TAG_NAME`
- **Environment**: `repo:OWNER/REPO:environment:ENV_NAME`

### Current Workflow Triggers

Your [.github/workflows/ci-cd.yml](../.github/workflows/ci-cd.yml) workflow triggers on:
```yaml
on:
  push:
    branches:
      - main
      - dev
  workflow_dispatch:
    inputs:
      action_type:
        type: choice
        options:
          - deploy
          - destroy
      environment:
        type: choice
        options:
          - dev
          - prod
```

This means you need credentials for:
- ✅ `main` branch (already exists)
- ❌ `dev` branch (needs to be added) ← **This is the problem**
- Optional: Pull requests (if you want to test deployments from PRs)

## Recommended Configuration

For this project, I recommend having **TWO** federated credentials:

### 1. Main Branch (Production)
```
Name: github-aks-demo-main
Subject: repo:usgrant4/aks-api-demo:ref:refs/heads/main
Description: Federated credential for production deployments
```

### 2. Dev Branch (Development)
```
Name: github-aks-demo-dev
Subject: repo:usgrant4/aks-api-demo:ref:refs/heads/dev
Description: Federated credential for development deployments
```

## Troubleshooting

### Issue: Still getting authentication errors after adding credential

**Solution:**
1. Verify the credential was created:
   ```bash
   az ad app federated-credential list --id "$APP_ID" --output table
   ```

2. Check the subject claim matches exactly (case-sensitive):
   - Expected: `repo:usgrant4/aks-api-demo:ref:refs/heads/dev`
   - Common mistake: `repo:usgrant4/aks-api-demo:dev` (missing `ref:refs/heads/`)

3. Wait 2-5 minutes for Azure AD to propagate the changes

4. Verify GitHub secrets are correct:
   - Go to GitHub → Settings → Secrets and variables → Actions
   - Verify `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` are set

### Issue: Don't know which App Registration to use

**Find the App Registration ID:**
1. Go to [Azure Portal](https://portal.azure.com)
2. Search "App registrations"
3. Click "All applications"
4. Look for an app with a name like "github-oidc" or similar
5. The **Application (client) ID** should match your `AZURE_CLIENT_ID` GitHub secret

Alternatively, using Azure CLI:
```bash
# List all app registrations
az ad app list --show-mine --output table

# Find the one with matching client ID
az ad app list --show-mine --query "[?appId=='<AZURE_CLIENT_ID>'].{Name:displayName, AppId:appId}" --output table
```

### Issue: Getting "insufficient privileges" error when adding credentials

**Solution:** You need one of these roles:
- Application Administrator
- Cloud Application Administrator
- Global Administrator
- Owner of the App Registration

Contact your Azure AD administrator if you don't have these permissions.

## Security Considerations

### Least Privilege Principle

Each federated credential should only grant access to what's needed:

- **Dev branch credential**: Should only deploy to dev environment
- **Main branch credential**: Should only deploy to prod environment

To enforce this, you can:
1. Use separate Service Principals for dev and prod
2. Assign different Azure RBAC roles per environment
3. Use Azure Resource Groups for environment isolation

### Audit and Monitoring

Monitor federated credential usage:
```bash
# View sign-in logs for the service principal
az ad sp list --display-name "github-oidc" --query "[].{Name:displayName, AppId:appId, ObjectId:id}" --output table

# Or in Azure Portal:
# Azure AD → Enterprise Applications → Your App → Sign-in logs
```

## References

- [Azure Workload Identity Federation](https://learn.microsoft.com/entra/workload-id/workload-identity-federation)
- [GitHub OIDC with Azure](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-azure)
- [Azure Login Action Documentation](https://github.com/Azure/login#readme)

## Quick Fix Command

If you have the necessary permissions, run this ONE command to fix the issue:

```bash
# Replace with your actual App Registration Client ID
APP_ID="<paste-AZURE_CLIENT_ID-here>"

az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters '{
    "name": "github-aks-demo-dev",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:usgrant4/aks-api-demo:ref:refs/heads/dev",
    "audiences": ["api://AzureADTokenExchange"],
    "description": "Federated credential for dev branch deployments"
  }'
```

Then wait 2 minutes and re-run your GitHub Actions workflow.
