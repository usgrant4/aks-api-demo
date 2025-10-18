# Environment Tagging and Naming Strategy

## Overview

All Azure resources now include environment-specific naming and tags for clear separation between dev, staging, and prod environments.

---

## Environment Variable

### Terraform Variable

**File:** `terraform/variables.tf`

```hcl
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}
```

**Validation:** Only allows `dev`, `staging`, or `prod` values.

---

## Resource Naming Convention

### Pattern

All resources follow this naming pattern:

```
{prefix}-liatrio-demo-{environment}-{resource-type}
```

### Examples by Environment

| Environment | Resource Group | AKS Cluster | ACR (no hyphens) |
|-------------|---------------|-------------|------------------|
| **dev** | `ugrant-liatrio-demo-dev-rg` | `ugrant-liatrio-demo-dev-aks` | `ugrantliatriodemodevacr` |
| **prod** | `ugrant-liatrio-demo-prod-rg` | `ugrant-liatrio-demo-prod-aks` | `ugrantliatriodemodprodacr` |

### Terraform Configuration

**File:** `terraform/main.tf`

```hcl
locals {
  # Include environment in resource naming
  name = "${var.prefix}-liatrio-demo-${var.environment}"

  # Common tags with environment
  common_tags = {
    project     = "liatrio-devops-demo"
    managed_by  = "terraform"
    environment = var.environment
    deployed_by = "github-actions"
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "${local.name}-rg"
  # Results in: ugrant-liatrio-demo-dev-rg
  tags     = local.common_tags
}

resource "azurerm_kubernetes_cluster" "aks" {
  name     = "${local.name}-aks"
  # Results in: ugrant-liatrio-demo-dev-aks
  tags     = local.common_tags
}

resource "azurerm_container_registry" "acr" {
  name     = replace("${var.prefix}liatriodemo${var.environment}acr", "-", "")
  # Results in: ugrantliatriodemodevacr (ACR names can't have hyphens)
  tags     = local.common_tags
}
```

---

## Resource Tags

### Common Tags Applied to All Resources

```hcl
common_tags = {
  project     = "liatrio-devops-demo"
  managed_by  = "terraform"
  environment = var.environment        # dev, staging, or prod
  deployed_by = "github-actions"
}
```

### Tag Details

| Tag | Value | Purpose |
|-----|-------|---------|
| `project` | liatrio-devops-demo | Identifies the project |
| `managed_by` | terraform | Shows infrastructure is managed by Terraform |
| `environment` | dev/staging/prod | **Identifies the environment** |
| `deployed_by` | github-actions | Shows deployment source |

---

## Workflow Integration

### Environment Detection

**File:** `.github/workflows/ci-cd.yml`

```yaml
- name: Set environment variables
  run: |
    if [ "${{ github.ref }}" = "refs/heads/main" ]; then
      echo "ENVIRONMENT=prod" >> $GITHUB_ENV
    else
      echo "ENVIRONMENT=dev" >> $GITHUB_ENV
    fi
```

### Passing to Terraform

```yaml
- name: Terraform Init/Apply
  env:
    TF_VAR_environment: ${{ env.ENVIRONMENT }}  # ← Passes environment to Terraform
  run: |
    echo "Deploying to environment: ${{ env.ENVIRONMENT }}"
    terraform apply -auto-approve
```

**Environment Variable Mapping:**
- `TF_VAR_environment` → Terraform variable `var.environment`
- Automatically picked up by Terraform without explicit `-var` flag

---

## Environment-Specific Resources

### Dev Environment (dev branch)

**Trigger:** Push to `dev` branch

**Resources Created:**
- Resource Group: `ugrant-liatrio-demo-dev-rg`
- AKS Cluster: `ugrant-liatrio-demo-dev-aks`
- ACR: `ugrantliatriodemodevacr`
- State File: `liatrio-demo-dev.tfstate`

**Tags:**
```json
{
  "environment": "dev",
  "project": "liatrio-devops-demo",
  "managed_by": "terraform",
  "deployed_by": "github-actions"
}
```

### Prod Environment (main branch)

**Trigger:** Push to `main` branch

**Resources Created:**
- Resource Group: `ugrant-liatrio-demo-prod-rg`
- AKS Cluster: `ugrant-liatrio-demo-prod-aks`
- ACR: `ugrantliatriodemodprodacr`
- State File: `liatrio-demo-prod.tfstate`

**Tags:**
```json
{
  "environment": "prod",
  "project": "liatrio-devops-demo",
  "managed_by": "terraform",
  "deployed_by": "github-actions"
}
```

---

## Benefits

### 1. Clear Environment Identification

**In Azure Portal:**
- Search for "dev" → See all dev resources
- Search for "prod" → See all prod resources
- Filter by tag: `environment=dev`

**In CLI:**
```bash
# List all dev resources
az resource list --tag environment=dev --output table

# List all prod resources
az resource list --tag environment=prod --output table
```

### 2. Cost Tracking

**Azure Cost Management:**
- Filter costs by tag: `environment=dev`
- See exactly how much each environment costs
- Create separate budgets for dev vs prod

### 3. Isolation

- Completely separate resource groups
- No risk of dev affecting prod
- Different Terraform state files
- Independent lifecycles

### 4. Compliance

- Easy to audit which environment resources belong to
- Clear separation for compliance requirements
- Simplifies access control policies

---

## Viewing Tags in Azure

### Azure Portal

1. Go to **Resource Groups**
2. Click on a resource group (e.g., `ugrant-liatrio-demo-dev-rg`)
3. Click **Tags** in left menu
4. See all tags applied

### Azure CLI

```bash
# Get tags for a resource group
az group show \
  --name ugrant-liatrio-demo-dev-rg \
  --query tags

# Output:
{
  "deployed_by": "github-actions",
  "environment": "dev",
  "managed_by": "terraform",
  "project": "liatrio-devops-demo"
}
```

### Query Resources by Tag

```bash
# Find all resources with environment=dev
az resource list \
  --tag environment=dev \
  --query "[].{Name:name, Type:type, Environment:tags.environment}" \
  --output table

# Find all resources managed by terraform
az resource list \
  --tag managed_by=terraform \
  --output table
```

---

## Resource Naming Examples

### Full Resource Inventory

#### Dev Environment

| Resource Type | Resource Name | Tags |
|--------------|---------------|------|
| Resource Group | `ugrant-liatrio-demo-dev-rg` | environment=dev |
| AKS Cluster | `ugrant-liatrio-demo-dev-aks` | environment=dev |
| ACR | `ugrantliatriodemodevacr` | environment=dev |
| Public IP | `kubernetes-*` (auto-generated) | environment=dev |
| Load Balancer | `kubernetes` (auto-generated) | environment=dev |

#### Prod Environment

| Resource Type | Resource Name | Tags |
|--------------|---------------|------|
| Resource Group | `ugrant-liatrio-demo-prod-rg` | environment=prod |
| AKS Cluster | `ugrant-liatrio-demo-prod-aks` | environment=prod |
| ACR | `ugrantliatriodemodprodacr` | environment=prod |
| Public IP | `kubernetes-*` (auto-generated) | environment=prod |
| Load Balancer | `kubernetes` (auto-generated) | environment=prod |

---

## Customizing for Your Use Case

### Adding Staging Environment

1. **Update validation in variables.tf:**
   ```hcl
   validation {
     condition     = contains(["dev", "staging", "prod"], var.environment)
     error_message = "Environment must be dev, staging, or prod."
   }
   ```

2. **Create staging branch:**
   ```bash
   git checkout -b staging
   git push origin staging
   ```

3. **Update workflow trigger:**
   ```yaml
   on:
     push:
       branches: [main, dev, staging]
   ```

4. **Add environment detection:**
   ```yaml
   - name: Set environment variables
     run: |
       if [ "${{ github.ref }}" = "refs/heads/main" ]; then
         echo "ENVIRONMENT=prod" >> $GITHUB_ENV
       elif [ "${{ github.ref }}" = "refs/heads/staging" ]; then
         echo "ENVIRONMENT=staging" >> $GITHUB_ENV
       else
         echo "ENVIRONMENT=dev" >> $GITHUB_ENV
       fi
   ```

### Adding More Tags

Add to `terraform/main.tf`:

```hcl
common_tags = {
  project     = "liatrio-devops-demo"
  managed_by  = "terraform"
  environment = var.environment
  deployed_by = "github-actions"
  cost_center = "engineering"      # ← Add custom tags
  owner       = "devops-team"      # ← Add custom tags
  created_by  = "terraform"        # ← Add custom tags
}
```

---

## Cost Management Example

### Azure Cost Analysis Query

```bash
# Get costs for dev environment
az consumption usage list \
  --start-date 2025-10-01 \
  --end-date 2025-10-31 \
  --query "[?contains(tags.environment, 'dev')]" \
  --output table

# Get costs for prod environment
az consumption usage list \
  --start-date 2025-10-01 \
  --end-date 2025-10-31 \
  --query "[?contains(tags.environment, 'prod')]" \
  --output table
```

### Azure Portal Cost Analysis

1. Go to **Cost Management + Billing**
2. Click **Cost analysis**
3. Add filter: **Tag** = `environment`
4. Select **dev** or **prod**
5. See costs broken down by environment

---

## Verification Commands

### After Deployment

```bash
# Check resource group exists with correct tags
az group show \
  --name ugrant-liatrio-demo-dev-rg \
  --query "{Name:name, Location:location, Tags:tags}" \
  --output json

# List all resources in environment
az resource list \
  --resource-group ugrant-liatrio-demo-dev-rg \
  --query "[].{Name:name, Type:type, Tags:tags.environment}" \
  --output table

# Verify AKS cluster
az aks show \
  --name ugrant-liatrio-demo-dev-aks \
  --resource-group ugrant-liatrio-demo-dev-rg \
  --query "{Name:name, Environment:tags.environment}" \
  --output json
```

---

## Summary

### What Changed

1. ✅ **Added `environment` variable** to Terraform
2. ✅ **Updated resource naming** to include environment
3. ✅ **Added environment tags** to all resources
4. ✅ **Workflow passes environment** via `TF_VAR_environment`

### Naming Pattern

```
{prefix}-liatrio-demo-{environment}-{resource-type}
```

### Tags Applied

```json
{
  "project": "liatrio-devops-demo",
  "managed_by": "terraform",
  "environment": "dev|staging|prod",
  "deployed_by": "github-actions"
}
```

### Branch → Environment Mapping

| Branch | Environment | State File |
|--------|-------------|-----------|
| `dev` | dev | `liatrio-demo-dev.tfstate` |
| `main` | prod | `liatrio-demo-prod.tfstate` |

### Result

- ✅ Clear environment separation
- ✅ Easy cost tracking
- ✅ Better compliance
- ✅ Simplified management

---

**Next Deployment:** Resources will be created with environment-specific names and tags! 🚀
