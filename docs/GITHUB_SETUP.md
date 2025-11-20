# GitHub Repository Setup Guide

This document outlines the secrets and configuration required to run the CI/CD pipeline for this project.

## Required GitHub Secrets

Your CI/CD pipeline uses **Azure OIDC (OpenID Connect) authentication** and requires three secrets to be configured in your GitHub repository:

1. **`AZURE_CLIENT_ID`** - The client ID of your Azure AD application/service principal
2. **`AZURE_TENANT_ID`** - Your Azure AD tenant ID
3. **`AZURE_SUBSCRIPTION_ID`** - Your Azure subscription ID

## Azure OIDC Setup Instructions

Follow these steps to set up Azure authentication for GitHub Actions:

### 1. Create an Azure AD App Registration

```bash
az ad app create --display-name "github-actions-aks-demo"
```

Note the `appId` from the output - this is your `AZURE_CLIENT_ID`.

### 2. Create a Service Principal

```bash
az ad sp create --id <APP_ID_from_step_1>
```

### 3. Configure Federated Credentials

Replace `<YOUR_GITHUB_USERNAME>` and `<YOUR_REPO_NAME>` with your actual GitHub username and repository name:

```bash
az ad app federated-credential create \
  --id <APP_ID> \
  --parameters '{
    "name": "github-actions-main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:<YOUR_GITHUB_USERNAME>/<YOUR_REPO_NAME>:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

### 4. Assign Contributor Role

Grant the service principal permission to manage resources in your subscription:

```bash
az role assignment create \
  --assignee <APP_ID> \
  --role Contributor \
  --scope /subscriptions/<SUBSCRIPTION_ID>
```

### 5. Retrieve Required Values

Get the values you need to add as GitHub secrets:

```bash
# Tenant ID
az account show --query tenantId -o tsv

# Subscription ID
az account show --query id -o tsv

# Client ID (from step 1)
az ad app list --display-name "github-actions-aks-demo" --query [0].appId -o tsv
```

## Adding Secrets to GitHub

1. Navigate to your GitHub repository
2. Go to **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add each of the following secrets:

| Secret Name | Value |
|-------------|-------|
| `AZURE_CLIENT_ID` | The app ID from step 1 |
| `AZURE_TENANT_ID` | Your Azure tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Your Azure subscription ID |

## Branch Configuration

**Important:** The CI/CD pipeline is configured to trigger on pushes to the `main` branch. Your current branch is `master`.

You have two options:

### Option 1: Rename your branch (Recommended)
```bash
git branch -m master main
git push -u origin main
```

### Option 2: Update the workflow file
Edit `.github/workflows/ci-cd.yml` and change line 6 from:
```yaml
branches: [main]
```
to:
```yaml
branches: [master]
```

Also update line 42:
```yaml
if: github.ref == 'refs/heads/main' && github.event_name == 'push'
```
to:
```yaml
if: github.ref == 'refs/heads/master' && github.event_name == 'push'
```

## Terraform State Management

The project is configured to use Azure Blob Storage as the remote backend for Terraform state. This ensures state persistence across GitHub Actions workflow runs.

### Backend Configuration

The backend is configured in `terraform/main.tf`:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "tfstate-rg"
    storage_account_name = "tfstateugrantliatrio"
    container_name       = "tfstate"
    key                  = "aks-demo.tfstate"
  }
}
```

### Automated Backend Setup

**The backend is automatically created by the GitHub Actions workflow!** No manual setup is required.

The workflow includes a "Setup Terraform backend" step that:
- Creates the resource group `tfstate-rg` (if it doesn't exist)
- Creates the storage account `tfstateugrantliatrio` (if it doesn't exist)
- Creates the blob container `tfstate` (if it doesn't exist)
- Uses your service principal credentials (via OIDC) for authentication

This happens automatically on every workflow run, making the deployment fully automated and idempotent.

### How It Works

When you push to the `main` branch, the workflow:
1. Authenticates to Azure using OIDC
2. Checks if backend resources exist, creates them if needed
3. Initializes Terraform with the remote backend
4. Deploys your infrastructure

The service principal already has `Contributor` role on the subscription, which provides sufficient permissions to create and manage the backend storage resources.

## Pipeline Architecture

The CI/CD workflow has been optimized with production-grade reliability features including automatic rollback, retry logic, and comprehensive error handling.

### Build & Test Job
Runs on all pushes and pull requests:
- Python 3.11 setup with dependency caching
- Install dependencies from `app/requirements.txt`
- Run pytest with verbose output

### Deploy Job
Runs only on pushes to main branch with the following enhanced steps:

**Concurrency Protection:** Only one deployment runs at a time. Additional pushes queue automatically.

#### 1. Backend Setup (Automated)
- Checks if Terraform backend resources exist
- Creates resource group, storage account, and container if needed
- Waits for provisioning to complete (prevents race conditions)
- Validates access permissions
- Auto-grants "Storage Blob Data Contributor" role if needed
- Comprehensive error handling with clear messages

#### 2. Infrastructure Provisioning
- Azure OIDC authentication (passwordless)
- Terraform init with remote backend
- Terraform apply with auto-approval
- Capture outputs (ACR, AKS, Resource Group names)

#### 3. AKS Configuration
- Get AKS credentials with automatic retry (3 attempts)
- ACR authentication managed by Terraform (no manual attachment needed)

#### 4. Image Build (Platform-Specific)
- Uses `az acr build` with `--platform linux/amd64`
- Prevents multi-platform manifest issues
- Tags: `v1.0.${{ github.sha }}` and `latest`
- Builds directly in ACR (no local Docker required)

#### 5. Manifest Verification
- Validates image platform metadata
- Detects `unknown/unknown` platform issues
- Provides early warning for malformed manifests

#### 6. Deployment with Rollback
- **Pre-deployment:** Saves current deployment state for rollback
- **Health check:** Verifies current deployment status
- **Deploy:** Applies new manifest with versioned image tag
- **Rollout:** Waits up to 5 minutes for rollout completion
- **Auto-rollback:** If rollout fails, automatically reverts to previous version
- **Validation:** Verifies all pods are ready (dynamic replica count check)

#### 7. Smoke Test
- Waits for LoadBalancer IP assignment (up to 5 minutes)
- Tests HTTP connectivity with retries
- Validates API response
- Shows deployment summary on success

### Destroy Job
Manually triggered via workflow_dispatch:
- **Concurrency Protected:** Uses same group as deploy to prevent conflicts
- **Backend Handling:** Gracefully handles missing backend (falls back to local state)
- Terraform destroy with auto-approval

Check the **Actions** tab in your GitHub repository to monitor pipeline execution.

## Troubleshooting

### Common Issues

**Authentication failures**
- Verify all three Azure secrets are correctly set in GitHub
- Check service principal has Contributor role on subscription
- Verify federated credential subject matches your repo exactly

**Pipeline not triggering**
- Check branch name matches workflow configuration (`main` vs `master`)
- Verify changes are in monitored paths (app/, kubernetes/, terraform/, etc.)

**Terraform errors**
- Ensure service principal has Contributor role on subscription
- Check Azure quotas for your subscription
- Verify unique naming (ACR names must be globally unique)

**Image platform issues** (Fixed in current workflow)
- Workflow now uses `az acr build` with `--platform linux/amd64`
- Manifest verification step detects platform issues early
- No more `unknown/unknown` platform manifests

**ImagePullBackOff errors** (Fixed in current workflow)
- Workflow now attaches ACR to AKS automatically
- 30s wait ensures credentials propagate
- No manual ACR authentication needed

**Pod failures**
- Check pod logs: `kubectl logs -l app=aks-demo`
- Describe pod: `kubectl describe pod <pod-name>`
- Workflow shows detailed diagnostics on failure

**LoadBalancer IP not assigned**
- Can take 2-5 minutes on Azure
- Workflow waits up to 5 minutes automatically
- Check service status: `kubectl describe svc aks-demo-svc`
