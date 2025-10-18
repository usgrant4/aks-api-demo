# Environment Naming & Tagging - Implementation Summary

## ✅ Changes Applied

Environment-specific naming and tagging has been implemented across all infrastructure.

---

## What Changed

### 1. Terraform Variables (`terraform/variables.tf`)

**Added:**
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

### 2. Resource Naming (`terraform/main.tf`)

**Before:**
```hcl
locals {
  name = "${var.prefix}-liatrio-demo"  # No environment
}

resource "azurerm_resource_group" "rg" {
  name = "${local.name}-rg"
  # Result: ugrant-liatrio-demo-rg
}
```

**After:**
```hcl
locals {
  name = "${var.prefix}-liatrio-demo-${var.environment}"  # ← Added environment
}

resource "azurerm_resource_group" "rg" {
  name = "${local.name}-rg"
  # Result: ugrant-liatrio-demo-dev-rg (or prod)
}
```

### 3. Resource Tags (`terraform/main.tf`)

**Before:**
```hcl
common_tags = {
  project     = "liatrio-devops-demo"
  managed_by  = "terraform"
  environment = "demo"  # Static value
}
```

**After:**
```hcl
common_tags = {
  project     = "liatrio-devops-demo"
  managed_by  = "terraform"
  environment = var.environment     # ← Dynamic from variable
  deployed_by = "github-actions"    # ← Added
}
```

### 4. Workflow Configuration (`.github/workflows/ci-cd.yml`)

**Added to Terraform steps:**
```yaml
env:
  TF_VAR_environment: ${{ env.ENVIRONMENT }}  # ← Passes env to Terraform
```

---

## Resource Names by Environment

### Dev Environment (dev branch)

| Resource | Name |
|----------|------|
| **Resource Group** | `ugrant-liatrio-demo-dev-rg` |
| **AKS Cluster** | `ugrant-liatrio-demo-dev-aks` |
| **ACR** | `ugrantliatriodemodevacr` |
| **State File** | `liatrio-demo-dev.tfstate` |

### Prod Environment (main branch)

| Resource | Name |
|----------|------|
| **Resource Group** | `ugrant-liatrio-demo-prod-rg` |
| **AKS Cluster** | `ugrant-liatrio-demo-prod-aks` |
| **ACR** | `ugrantliatriodemodprodacr` |
| **State File** | `liatrio-demo-prod.tfstate` |

---

## Tags Applied to All Resources

```json
{
  "project": "liatrio-devops-demo",
  "managed_by": "terraform",
  "environment": "dev",              // ← Changes per environment
  "deployed_by": "github-actions"
}
```

---

## How It Works

### Branch → Environment Mapping

```yaml
- name: Set environment variables
  run: |
    if [ "${{ github.ref }}" = "refs/heads/main" ]; then
      echo "ENVIRONMENT=prod" >> $GITHUB_ENV     # main → prod
    else
      echo "ENVIRONMENT=dev" >> $GITHUB_ENV      # dev → dev
    fi
```

### Terraform Variable Injection

```yaml
- name: Terraform Init/Apply
  env:
    TF_VAR_environment: ${{ env.ENVIRONMENT }}  # ← Injects into Terraform
  run: terraform apply
```

**Terraform automatically picks up `TF_VAR_environment` as `var.environment`**

---

## Benefits

### ✅ Clear Separation
- Resource Group names clearly show environment
- `ugrant-liatrio-demo-dev-rg` vs `ugrant-liatrio-demo-prod-rg`

### ✅ Easy Cost Tracking
```bash
# See costs for dev only
az resource list --tag environment=dev

# See costs for prod only
az resource list --tag environment=prod
```

### ✅ Better Management
- Filter by environment in Azure Portal
- Search for "dev" → See all dev resources
- Query by tags for compliance

### ✅ No Conflicts
- Dev and prod resources have different names
- Completely isolated
- Can coexist in same subscription

---

## Query Resources by Environment

### Azure CLI

```bash
# List all dev resources
az resource list \
  --tag environment=dev \
  --query "[].{Name:name, Type:type}" \
  --output table

# List all prod resources
az resource list \
  --tag environment=prod \
  --query "[].{Name:name, Type:type}" \
  --output table
```

### Azure Portal

1. Go to **Resource groups**
2. Search: `liatrio-demo-dev` → See dev resources
3. Search: `liatrio-demo-prod` → See prod resources
4. Click **Tags** → Filter by `environment=dev` or `environment=prod`

---

## Cost Analysis

### Azure Portal

1. **Cost Management + Billing** → **Cost analysis**
2. Add filter: **Tag** = `environment`
3. Group by: **Resource group** or **Tag**
4. See exactly how much dev vs prod costs

### Azure CLI

```bash
# Costs for resources tagged with environment=dev
az consumption usage list \
  --query "[?tags.environment=='dev']"
```

---

## Example Terraform Output

When you run Terraform now:

```bash
$ terraform apply

# Creating resources:
  + azurerm_resource_group.rg
      name:     "ugrant-liatrio-demo-dev-rg"
      tags: {
        "environment" = "dev"
        "managed_by"  = "terraform"
        "project"     = "liatrio-devops-demo"
        "deployed_by" = "github-actions"
      }

  + azurerm_kubernetes_cluster.aks
      name:     "ugrant-liatrio-demo-dev-aks"
      tags: {
        "environment" = "dev"
        ...
      }
```

---

## Verification After Deployment

```bash
# Check resource group
az group show \
  --name ugrant-liatrio-demo-dev-rg \
  --query "{Name:name, Tags:tags}"

# Output:
{
  "Name": "ugrant-liatrio-demo-dev-rg",
  "Tags": {
    "deployed_by": "github-actions",
    "environment": "dev",
    "managed_by": "terraform",
    "project": "liatrio-devops-demo"
  }
}
```

---

## Next Steps

### Current Deployment

When you push to `dev` branch:
- Creates: `ugrant-liatrio-demo-dev-rg`
- Tags with: `environment=dev`
- Uses state: `liatrio-demo-dev.tfstate`

### Production Deployment

When you push to `main` branch:
- Creates: `ugrant-liatrio-demo-prod-rg`
- Tags with: `environment=prod`
- Uses state: `liatrio-demo-prod.tfstate`

### To Deploy

```bash
# Deploy to dev
git checkout dev
git push origin dev

# Deploy to prod
git checkout main
git merge dev
git push origin main
```

---

## Summary

| Aspect | Before | After |
|--------|--------|-------|
| **Resource Group** | `ugrant-liatrio-demo-rg` | `ugrant-liatrio-demo-dev-rg` |
| **Tags** | Static `environment=demo` | Dynamic `environment=dev/prod` |
| **Cost Tracking** | All costs mixed | Separate by environment |
| **Management** | Hard to distinguish | Clear environment labels |

---

**Files Modified:**
- ✅ `terraform/variables.tf` - Added environment variable
- ✅ `terraform/main.tf` - Updated naming and tags
- ✅ `.github/workflows/ci-cd.yml` - Pass environment to Terraform

**Documentation:**
- ✅ `docs/ENVIRONMENT_TAGGING_AND_NAMING.md` - Full guide
- ✅ `ENVIRONMENT_NAMING_SUMMARY.md` - This summary

**Ready to deploy with environment-specific names and tags!** 🎉
