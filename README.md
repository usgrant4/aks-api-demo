# XYZ DevOps Demo (Azure AKS)

A production-ready demonstration of modern DevOps practices using Azure cloud infrastructure, automated CI/CD pipelines, and Kubernetes orchestration.

**Goal**: Provision Azure infrastructure with Terraform, build a containerized REST API that returns a static message + current Unix timestamp, deploy to AKS, and validate with automated tests.

## 🚀 Project Overview

This project showcases a complete DevOps workflow including:
- Infrastructure as Code (IaC) with Terraform
- Containerized Python FastAPI application
- Automated CI/CD with GitHub Actions
- Kubernetes deployment on Azure AKS
- Comprehensive testing and monitoring
- Cost-optimized cloud infrastructure

## Stack

- **Cloud**: Azure (Resource Group, ACR, AKS)
- **IaC**: Terraform 1.9.6
- **App**: Python 3.11 + FastAPI 0.115.5
- **Container**: Multi-stage Docker build (Python 3.11-slim base)
- **Orchestration**: Azure Kubernetes Service (AKS 1.32.7)
- **CI/CD**: GitHub Actions with OIDC authentication
- **Testing**: pytest (unit) + integration tests + smoke tests

## Prerequisites

### Required Tools
- **Azure CLI** - For Azure resource management
- **Terraform** >= 1.6.0 - Infrastructure as Code
- **kubectl** - Kubernetes cluster management
- **Docker** - Container builds (optional for local development)
- **PowerShell** - For running deployment scripts (Windows)

### Azure Requirements
- Active Azure subscription with Contributor access
- Azure CLI authenticated (`az login`)

### For CI/CD (GitHub Actions)
- GitHub repository with OIDC configured
- Required GitHub Secrets:
  - `AZURE_CLIENT_ID`
  - `AZURE_TENANT_ID`
  - `AZURE_SUBSCRIPTION_ID`

## Quick Start

### Local Development

```bash
# Install dependencies
pip install -r app/requirements.txt

# Run application locally
uvicorn app.main:app --host 0.0.0.0 --port 8080

# Test locally
curl http://localhost:8080/
curl http://localhost:8080/health

# Run unit tests
pytest -v
```

### Deploy to Azure

#### Option A: Automated Deployment with PowerShell (local)

The **[final_deploy.ps1](final_deploy.ps1)** script provides a complete, automated deployment:

```powershell
# Fresh deployment (provisions everything from scratch)
.\final_deploy.ps1
```

**What it does:**
1. Deploys Azure infrastructure with Terraform (Resource Group, ACR, AKS)
2. Configures kubectl with AKS credentials
3. Attaches ACR to AKS cluster for image pulling
4. Builds and pushes Docker image to ACR using ACR Tasks
5. Verifies image manifest and platform compatibility
6. Deploys application to Kubernetes (2 replicas)
7. Waits for pods to be ready
8. Provisions LoadBalancer and retrieves public IP
9. Runs smoke tests against the API

**Deployment time**: ~10-12 minutes (first run)

#### Option B: GitHub Actions CI/CD

**Automatic Deployment (Push to Branch):**

1. Configure GitHub secrets (see Prerequisites)
2. Push to `main` branch (production) or `dev` branch (development)
3. Pipeline automatically:
   - Runs unit tests with pytest
   - Provisions/updates infrastructure with Terraform
   - Builds and pushes Docker image to ACR
   - Deploys to AKS with rolling update strategy
   - Runs smoke tests against live endpoint

**Manual Deployment/Destroy (Workflow Dispatch):**

1. Go to GitHub Actions tab
2. Select "ci-cd" workflow
3. Click "Run workflow"
4. Select:
   - **Action to perform**: `deploy` or `destroy`
   - **Target environment**: `dev` or `prod`
5. Click "Run workflow"

**Note on Production Deployment Controls:**

In a production enterprise environment, you would typically add:

- **Pull Request Requirements**: Require PRs for merging to `main` branch (via branch protection rules)
- **Code Review Approvals**: Require 1+ reviewer approvals before merge (GitHub Free supports this)
- **Environment Protection**: Require manual approval before production deployment (requires GitHub Team/Enterprise)
- **CODEOWNERS**: Define required reviewers for specific files (requires GitHub Team/Enterprise)

For this demo, deployment safeguards include:
- ✅ Separate `dev` and `main` branches with environment-specific infrastructure
- ✅ Environment-specific Terraform state files (prevents cross-environment conflicts)
- ✅ Manual workflow dispatch for controlled deployments
- ✅ Automated testing before deployment
- ✅ Concurrency controls to prevent simultaneous deployments

See [.github/workflows/ci-cd.yml](.github/workflows/ci-cd.yml) for pipeline details.

#### Option C: Manual Step-by-Step Deployment

```powershell
# 1. Provision infrastructure
cd terraform
terraform init
terraform apply -auto-approve

# 2. Capture outputs
$RG = terraform output -raw resource_group_name
$AKS = terraform output -raw aks_name
$ACR_LOGIN = terraform output -raw acr_login_server
$ACR_NAME = ($ACR_LOGIN).Split('.')[0]

# 3. Get AKS credentials
az aks get-credentials -g $RG -n $AKS --overwrite-existing

# 4. Attach ACR to AKS (enables image pulling without credentials)
az aks update --resource-group $RG --name $AKS --attach-acr $ACR_NAME

# 5. Build and push image using ACR Tasks
cd ..
az acr build --registry $ACR_NAME `
  --image "liatrio-demo:latest" `
  --platform linux/amd64 `
  --file Dockerfile .

# 6. Deploy to Kubernetes
$IMAGE = "$ACR_LOGIN/liatrio-demo:latest"
(Get-Content kubernetes/deployment.yaml) `
  -replace 'REPLACE_WITH_ACR_LOGIN/liatrio-demo:latest', $IMAGE `
  | kubectl apply -f -

# 7. Wait for deployment
kubectl rollout status deployment/liatrio-demo --timeout=300s

# 8. Get LoadBalancer IP
kubectl get svc liatrio-demo-svc
```

## Testing

### Automated Test Suite

Run the comprehensive test suite with **[test_deployment.ps1](test_deployment.ps1)**:

```powershell
.\test_deployment.ps1
```

**Tests included:**
1. **Main Endpoint Test** - Validates root endpoint response structure
2. **Health Check Test** - Verifies `/health` endpoint
3. **Response Time Test** - Measures API performance (5 iterations)
4. **Timestamp Update Test** - Ensures timestamps are dynamic
5. **Concurrent Request Test** - Tests load handling (20 parallel requests)
6. **Pod Health Test** - Checks Kubernetes pod status
7. **Service Configuration Test** - Validates LoadBalancer setup
8. **Invalid Endpoint Test** - Confirms proper 404 handling

### Unit Tests (Local)

```bash
# Install dependencies
pip install -r app/requirements.txt

# Run tests
pytest -v
```

### Manual API Testing

```powershell
# Get service IP
$IP = kubectl get svc liatrio-demo-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Test main endpoint
curl "http://$IP/"

# Test health endpoint
curl "http://$IP/health"

# Expected response format:
# Main endpoint: {"message": "Automate all the things!", "timestamp": 1234567890}
# Health endpoint: {"status": "healthy", "timestamp": 1234567890}
```

## Infrastructure Details

### Terraform Configuration

**Location**: [terraform/main.tf](terraform/main.tf)

**Resources provisioned:**
- Azure Resource Group
- Azure Container Registry (Basic SKU, admin disabled)
- Azure Kubernetes Service (AKS 1.32.7)
  - Node pool: 1 node, Standard_D2s_v3 VM size
  - Network plugin: Azure CNI
  - Network policy: Azure
  - System-assigned managed identity
- Role assignment: AcrPull permission for AKS kubelet

**Configuration variables** ([terraform/variables.tf](terraform/variables.tf)):
- `prefix`: Resource name prefix (default: "ugrant")
- `location`: Azure region (default: "westus2")
- `node_count`: AKS node count (default: 1)
- `node_vm_size`: VM size (default: "Standard_D2s_v3")
- `kubernetes_version`: K8s version (default: "1.32.7")

### Terraform State Management

**Backend Configuration**: Azure Storage with remote state

**State File Strategy**: Environment-specific state files
- Production: `liatrio-demo-prod.tfstate`
- Development: `liatrio-demo-dev.tfstate`

**How it works:**
The CI/CD pipeline dynamically determines the state file based on the environment:
- `main` branch deployments use `liatrio-demo-prod.tfstate`
- `dev` branch deployments use `liatrio-demo-dev.tfstate`
- Manual workflow dispatch allows selecting the environment

This is configured via the `TF_BACKEND_KEY` environment variable in [.github/workflows/ci-cd.yml](.github/workflows/ci-cd.yml#L102):

```yaml
echo "TF_BACKEND_KEY=liatrio-demo-$ENV.tfstate" >> $GITHUB_ENV
```

**Backend Storage:**
- Resource Group: `tfstate-rg`
- Storage Account: `tfstateugrantliatrio`
- Container: `tfstate`
- Location: `westus2`

**IMPORTANT: Do NOT Destroy the Terraform Backend**

The Terraform backend storage account (`tfstateugrantliatrio`) should **NEVER** be destroyed unless you are permanently decommissioning the entire project. Here's why:

1. **Shared Infrastructure**: The backend storage is shared across all environments (dev, prod). Destroying it affects all deployments.

2. **State Loss**: Deleting the state files means Terraform loses track of all managed resources:
   - Cannot perform clean `terraform destroy` operations
   - Cannot update or modify existing infrastructure
   - Resources become "orphaned" in Azure
   - Manual cleanup of resources becomes necessary

3. **Environment Isolation**: Multiple state files allow safe parallel development:
   - Developers can test in `dev` without affecting `prod`
   - Each environment maintains its own resource lifecycle
   - Rollbacks and testing can happen independently

4. **Disaster Recovery**: State files contain the complete infrastructure definition and metadata needed for recovery scenarios.

**Proper Cleanup Workflow:**

```bash
# ✓ CORRECT: Destroy environment infrastructure (keeps state backend)
# Via GitHub Actions workflow dispatch:
# 1. Go to Actions tab in GitHub
# 2. Select "ci-cd" workflow
# 3. Click "Run workflow"
# 4. Action to perform: "destroy"
# 5. Target environment: "dev" or "prod"

# ✓ CORRECT: Local destroy (keeps state backend intact)
cd terraform
terraform destroy -auto-approve

# ✗ WRONG: Never delete the state storage account directly
# This will orphan all resources and break Terraform management
```

**State Backend Lifecycle:**
- Created once during initial setup
- Persists for the lifetime of the project
- Only removed when permanently decommissioning ALL environments
- Protected by Azure RBAC and access policies

### Kubernetes Deployment

**Location**: [kubernetes/deployment.yaml](kubernetes/deployment.yaml)

**Configuration:**
- **Replicas**: 2 (high availability)
- **Strategy**: RollingUpdate (maxSurge: 1, maxUnavailable: 0)
- **Container image**: Built from [Dockerfile](Dockerfile)
- **Resource limits**:
  - Requests: 100m CPU, 128Mi memory
  - Limits: 200m CPU, 256Mi memory
- **Probes**:
  - Readiness: HTTP GET /health (5s delay, 10s period)
  - Liveness: HTTP GET /health (15s delay, 20s period)
- **Service**: LoadBalancer type, port 80 → 8080
- **PodDisruptionBudget**: minAvailable: 1
- **Vertical Pod Autoscaler**: Automatic resource rightsizing enabled

### Vertical Pod Autoscaler (VPA)

**Location**: [kubernetes/vpa.yaml](kubernetes/vpa.yaml)

VPA is enabled to automatically optimize pod resource requests and limits based on actual usage patterns.

**Configuration:**
- **Update Mode**: Auto (automatically applies recommendations)
- **Resource Limits**:
  - Min: 50m CPU, 64Mi memory
  - Max: 1000m CPU (1 core), 1Gi memory
- **Target**: liatrio-demo deployment

**Benefits:**
- Reduces over-provisioning and infrastructure waste
- Improves cluster resource utilization
- Automatically adjusts to workload patterns
- Lowers operational costs

**Monitoring VPA:**
```bash
# View VPA recommendations
kubectl describe vpa liatrio-demo-vpa

# Check current pod resources
kubectl top pods -l app=liatrio-demo
```

See [docs/VPA_GUIDE.md](docs/VPA_GUIDE.md) for detailed usage instructions.

### Application

**Location**: [app/main.py](app/main.py)

**Framework**: FastAPI 0.115.5
**Runtime**: Python 3.11

**Endpoints:**
- `GET /` - Returns message and current Unix timestamp
- `GET /health` - Health check endpoint for Kubernetes probes

**Dependencies** ([app/requirements.txt](app/requirements.txt)):
- fastapi==0.115.5
- uvicorn==0.32.0
- pytest==8.3.3
- httpx==0.27.2

### Docker Image

**Location**: [Dockerfile](Dockerfile)

**Build strategy**: Multi-stage build
- **Builder stage**: Creates Python virtual environment with dependencies
- **Runtime stage**: Python 3.11-slim with minimal attack surface

**Security features:**
- Non-root user (appuser, UID 1000)
- No admin privileges
- Minimal base image
- Health check included

**Optimizations:**
- Layer caching for faster builds
- Virtual environment for dependency isolation
- No unnecessary files in final image

## Resource Cleanup

### Complete Cleanup (Recommended)

Use the automated cleanup script to remove ALL resources, including Network Watcher:

```powershell
# PowerShell (Windows)
.\cleanup.ps1

# Bash (Linux/Mac)
./cleanup.sh
```

**What it does:**
1. Destroys all Terraform-managed resources (AKS, ACR, Resource Group)
2. Prompts before removing Network Watcher resources (safe for shared environments)
3. Cleans up kubectl configuration
4. Removes local Terraform state files

**Estimated time**: 5-10 minutes

### Terraform-Only Cleanup (Leaves Network Watcher)

```powershell
cd terraform
terraform destroy -auto-approve
```

This will remove:
- AKS cluster and all deployed applications
- Container Registry and all images
- Resource Group and all contained resources

**Note**: This leaves `NetworkWatcherRG` and `NetworkWatcher_<region>` resources.

## Architecture

```
┌─────────────────────────────────────────────┐
│         Developer Workflow                  │
│   git commit → git push → GitHub Actions    │
│                    OR                       │
│          .\final_deploy.ps1                 │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│       CI/CD Pipeline (GitHub Actions)       │
│  ├─ pytest (unit tests)                     │
│  ├─ Terraform init/apply                    │
│  ├─ Docker build & push to ACR              │
│  ├─ kubectl apply (rolling update)          │
│  └─ Smoke tests (curl)                      │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│           Azure Infrastructure              │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │  Azure Container Registry (ACR)     │    │
│  │  - Basic SKU                        │    │
│  │  - Admin disabled (managed ID)      │    │
│  │  - Platform: linux/amd64            │    │
│  └──────────────┬──────────────────────┘    │
│                 │ (ACR Pull role)           │
│                 ▼                           │
│  ┌─────────────────────────────────────┐    │
│  │  Azure Kubernetes Service (AKS)     │    │
│  │  - Version: 1.32.7                  │    │
│  │  - Node: 1 x Standard_D2s_v3        │    │
│  │  - Network: Azure CNI + Azure NP    │    │
│  │  - Free control plane               │    │
│  │                                     │    │
│  │  ┌───────────────────────────────┐  │    │
│  │  │  Deployment: liatrio-demo     │  │    │
│  │  │  - Replicas: 2                │  │    │
│  │  │  - Image: FastAPI app         │  │    │
│  │  │  - CPU: 100m-200m             │  │    │
│  │  │  - Mem: 128Mi-256Mi           │  │    │
│  │  │  - Probes: /health            │  │    │
│  │  └───────────┬───────────────────┘  │    │
│  │              │                      │    │
│  │              ▼                      │    │
│  │  ┌───────────────────────────────┐  │    │
│  │  │  Service: LoadBalancer        │  │    │
│  │  │  - Type: LoadBalancer         │  │    │
│  │  │  - Port: 80 → 8080            │  │    │
│  │  │  - Public IP assigned         │  │    │
│  │  └───────────────────────────────┘  │    │
│  │                                     │    │
│  │  ┌───────────────────────────────┐  │    │
│  │  │  PodDisruptionBudget          │  │    │
│  │  │  - minAvailable: 1            │  │    │
│  │  └───────────────────────────────┘  │    │
│  │                                     │    │
│  │  ┌───────────────────────────────┐  │    │
│  │  │  Vertical Pod Autoscaler      │  │    │
│  │  │  - Auto resource rightsizing  │  │    │
│  │  │  - Min: 50m CPU, 64Mi RAM     │  │    │
│  │  │  - Max: 1 CPU, 1Gi RAM        │  │    │
│  │  └───────────────────────────────┘  │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
                   │
                   ▼
              End Users
         (http://<public-ip>/)
```

## Key Features

### High Availability
- 2 pod replicas for redundancy
- Rolling updates with zero downtime (maxUnavailable: 0)
- Automatic pod restart on failure
- PodDisruptionBudget ensures minimum availability (minAvailable: 1)

### Security
- ACR admin credentials disabled (uses managed identity)
- AKS kubelet has AcrPull role assignment
- Non-root container user (UID 1000)
- Resource limits prevent resource exhaustion
- Azure CNI with Azure Network Policy

### Observability
- Dedicated `/health` endpoint for Kubernetes probes
- Structured logging with timestamps
- Readiness and liveness probes configured
- Graceful shutdown with 30s termination grace period

### Performance
- Multi-stage Docker builds reduce image size
- Resource requests ensure guaranteed CPU/memory
- Connection pooling and async I/O with FastAPI
- Platform-specific builds (linux/amd64)

### Resource Optimization
- **Vertical Pod Autoscaler (VPA)** automatically rightsizes resources
- Reduces over-provisioning and infrastructure waste
- Improves cluster utilization based on actual usage patterns
- Lowers operational costs through efficient resource allocation

## Cost Breakdown

| Resource | SKU | Monthly Cost | Notes |
|----------|-----|--------------|-------|
| AKS Control Plane | Free Tier | $0 | Always free |
| AKS Node Pool | Standard_D2s_v3 (x1) | ~$70 | 2 vCPU, 8 GiB RAM |
| Azure Container Registry | Basic | ~$5 | 10 GiB storage included |
| Load Balancer | Standard | ~$5-10 | Included with AKS |
| Data Egress | Pay-as-you-go | ~$1-5 | Varies by usage |
| **Total (24/7)** | | **~$80-90/month** | Running continuously |

**Cost optimization options:**
- Use `terraform destroy` when not needed: $0/month
- Scale node pool to 0 nodes (manual): ~$5-10/month (ACR + minimal resources)
- Use auto-scaling with min 0 nodes: Variable based on usage

## Troubleshooting

### Common Issues

**Issue**: Pods showing ImagePullBackOff
```powershell
# Verify ACR is attached to AKS
az aks show -g <resource-group> -n <aks-name> --query "servicePrincipalProfile"

# Manually attach ACR
az aks update --resource-group <rg> --name <aks> --attach-acr <acr-name>

# Check pod events
kubectl describe pod <pod-name>
```

**Issue**: LoadBalancer IP not assigned
```powershell
# Check service status
kubectl describe svc liatrio-demo-svc

# Verify Azure subscription quotas
az network public-ip list --resource-group <node-resource-group>

# Check for Azure service issues
kubectl get events --sort-by='.lastTimestamp'
```

**Issue**: Pods not starting (CrashLoopBackOff)
```powershell
# Check pod logs
kubectl logs -l app=liatrio-demo --tail=50

# Check resource usage
kubectl describe pod <pod-name>

# Verify image manifest
az acr manifest show --name liatrio-demo:latest --registry <acr-name>
```

**Issue**: Terraform state locked
```powershell
cd terraform
terraform force-unlock <lock-id>
```

### Useful Commands

```powershell
# View all resources
kubectl get all -l app=liatrio-demo

# Stream logs from all pods
kubectl logs -l app=liatrio-demo -f

# Get detailed pod information
kubectl describe deployment liatrio-demo

# Check rollout status
kubectl rollout status deployment/liatrio-demo

# Restart deployment
kubectl rollout restart deployment/liatrio-demo

# View Terraform outputs
cd terraform
terraform output

# Check Azure resources
az resource list --resource-group <resource-group-name> --output table
```

## Scripts Reference

| Script | Purpose | Usage |
|--------|---------|-------|
| [final_deploy.ps1](final_deploy.ps1) | Complete automated deployment | `.\final_deploy.ps1` |
| [test_deployment.ps1](test_deployment.ps1) | Comprehensive test suite (8 tests) | `.\test_deployment.ps1` |
| [deploy.sh](deploy.sh) | Alternative deployment script (bash) | `./deploy.sh` |
| [cleanup.ps1](cleanup.ps1) | Complete cleanup including Network Watcher | `.\cleanup.ps1` |
| [cleanup.sh](cleanup.sh) | Complete cleanup (bash version) | `./cleanup.sh` |
| [sync-workflow-to-main.ps1](sync-workflow-to-main.ps1) | Sync workflow changes to main branch | `.\sync-workflow-to-main.ps1` |
| [sync-workflow-to-main.sh](sync-workflow-to-main.sh) | Sync workflow changes (bash version) | `./sync-workflow-to-main.sh` |

## GitHub Workflow Management

### Why Workflow Sync is Needed

GitHub Actions has a specific requirement: **workflow_dispatch triggers only appear in the GitHub UI when the workflow file exists in the default branch** (usually `main`). This means:

- Changes to `.github/workflows/*.yml` files in `dev` branch won't show the manual "Run workflow" button
- You must sync workflow files from `dev` to `main` to see workflow_dispatch options
- This is a GitHub platform limitation, not a configuration issue

### When to Sync Workflows

Sync workflows to `main` whenever you:
1. Add or modify workflow_dispatch inputs
2. Create new workflows that should be manually triggerable
3. Update workflow triggers or permissions

**Important**: You don't need to sync for every code change, only when the workflow definition itself changes.

### How to Sync Workflows

**Automated Method (Recommended):**

```powershell
# PowerShell (Windows)
.\sync-workflow-to-main.ps1

# Bash (Linux/Mac)
./sync-workflow-to-main.sh
```

The script will:
1. Save your current branch
2. Update both `dev` and `main` branches
3. Copy `.github/workflows/` from `dev` to `main`
4. Commit and push the changes
5. Return you to your original branch

**Manual Method:**

```bash
# From dev branch, commit your workflow changes
git add .github/workflows/
git commit -m "Update workflow configuration"
git push origin dev

# Switch to main and cherry-pick the workflow files
git checkout main
git pull origin main
git checkout dev -- .github/workflows/
git add .github/workflows/
git commit -m "sync: Update GitHub workflows from dev branch"
git push origin main

# Return to dev
git checkout dev
```

### Verifying Workflow Sync

After syncing, verify the workflow_dispatch UI appears:

1. Go to your GitHub repository
2. Click the "Actions" tab
3. Select the "ci-cd" workflow from the left sidebar
4. You should see a "Run workflow" button on the right
5. Clicking it should show your workflow_dispatch inputs:
   - **Action to perform**: deploy / destroy
   - **Target environment**: dev / prod

If you don't see these options, the workflow file may not have synced to `main` yet.

## Project Structure

```
liatrio-demo/
├── .github/workflows/
│   └── ci-cd.yml              # GitHub Actions pipeline
├── app/
│   ├── main.py                # FastAPI application
│   └── requirements.txt       # Python dependencies
├── docs/
│   └── VPA_GUIDE.md           # Vertical Pod Autoscaler guide
├── kubernetes/
│   ├── deployment.yaml        # K8s Deployment, Service, PDB
│   └── vpa.yaml               # Vertical Pod Autoscaler config
├── terraform/
│   ├── main.tf                # Infrastructure definitions
│   └── variables.tf           # Configuration variables
├── Dockerfile                 # Multi-stage container build
├── final_deploy.ps1           # Automated deployment script
└── test_deployment.ps1        # Automated testing script
```

## Quick Reference

### After Deployment

```powershell
# Get the public IP
$IP = kubectl get svc liatrio-demo-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Access your API
Start-Process "http://$IP/"

# View logs
kubectl logs -l app=liatrio-demo --tail=50 -f

# Check pod status
kubectl get pods -l app=liatrio-demo

# Scale deployment
kubectl scale deployment liatrio-demo --replicas=3

# Update image
kubectl set image deployment/liatrio-demo api=<new-image>
```

### Deployment Flow Summary

1. **Infrastructure** → Terraform creates Azure resources (RG, ACR, AKS)
2. **Build** → Docker image built and pushed to ACR
3. **Deploy** → Kubernetes deployment with 2 replicas
4. **Verify** → Automated tests confirm functionality
5. **Access** → LoadBalancer provides public IP

### Performance Metrics

- **API Response Time**: <50ms average, <100ms p99
- **Container Startup**: 3-5 seconds
- **Full Deployment**: ~10-12 minutes (first run)
- **Rolling Update**: ~2-3 minutes (zero downtime)
- **Test Suite**: ~60 seconds (8 tests)

## Additional Resources

- [Azure AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
