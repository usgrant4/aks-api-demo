# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a DevOps demonstration project that provisions Azure infrastructure with Terraform, builds a FastAPI REST API, and deploys to Azure Kubernetes Service (AKS). The API returns a static message with a Unix timestamp.

**Stack**: Python 3.11 (FastAPI), Docker, Terraform, Azure (ACR + AKS), GitHub Actions, Kubernetes

## Development Commands

### Local Development
```bash
# Install dependencies
pip install -r app/requirements.txt

# Run application locally
uvicorn app.main:app --host 0.0.0.0 --port 8080 --reload

# Test endpoints
curl http://localhost:8080/        # Main endpoint
curl http://localhost:8080/health  # Health check
```

### Testing
```bash
# Run unit tests (comprehensive test suite in app/test_api.py)
pytest -v

# Run with detailed output
pytest -v --tb=short

# Run single test
pytest app/test_api.py::test_health_endpoint -v

# Integration tests (requires deployed infrastructure)
bash tests/integration_test.sh

# Pre-demo verification
bash tests/verify_all.sh
```

### Docker
```bash
# Build image locally
docker build -t liatrio-demo:local .

# Run container
docker run -p 8080:8080 liatrio-demo:local

# Test health check
docker run --rm liatrio-demo:local python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')"
```

### Terraform (Infrastructure)
```bash
cd terraform

# Initialize Terraform
terraform init

# Validate configuration
terraform fmt -check
terraform validate

# Plan changes
terraform plan

# Apply infrastructure
terraform apply -auto-approve

# Get outputs
terraform output -raw acr_login_server
terraform output -raw aks_name
terraform output -raw resource_group_name

# Destroy infrastructure
terraform destroy -auto-approve
```

### Kubernetes Operations
```bash
# Get AKS credentials
az aks get-credentials \
  -g $(cd terraform && terraform output -raw resource_group_name) \
  -n $(cd terraform && terraform output -raw aks_name) \
  --overwrite-existing

# Deploy to Kubernetes (replace ACR_LOGIN with actual value)
ACR_LOGIN=$(cd terraform && terraform output -raw acr_login_server)
sed "s#REPLACE_WITH_ACR_LOGIN#$ACR_LOGIN#" kubernetes/deployment.yaml | kubectl apply -f -

# Check deployment status
kubectl get pods -l app=liatrio-demo
kubectl get svc liatrio-demo-svc
kubectl rollout status deploy/liatrio-demo

# View logs
kubectl logs -l app=liatrio-demo --tail=50 -f

# Debug pod issues
kubectl describe pod <pod-name>
kubectl logs <pod-name>

# Scale deployment
kubectl scale deploy/liatrio-demo --replicas=3

# Check resource usage
kubectl top pods
```

### Cost Management
```bash
# Check current cluster status
bash scripts/cost_management.sh status

# Scale down to save costs (~$35/month savings)
bash scripts/cost_management.sh scale-down

# Scale up to restore functionality
bash scripts/cost_management.sh scale-up
```

## Architecture

### Application Layer
- **FastAPI app** (app/main.py): Lightweight REST API with two endpoints:
  - `GET /`: Returns `{"message": "Automate all the things!", "timestamp": <unix_timestamp>}`
  - `GET /health`: Health check endpoint for Kubernetes probes
- **Multi-stage Dockerfile**: Builder pattern for smaller images (40-50% size reduction)
- **Non-root user**: Container runs as `appuser` (UID 1000) for security

### Infrastructure (Terraform)
- **Resource Group**: Contains all Azure resources
- **Azure Container Registry (ACR)**: Basic SKU, admin disabled (uses managed identity)
- **AKS Cluster**:
  - Single node pool (Standard_B2s)
  - System-assigned managed identity
  - Azure CNI networking with network policies enabled
  - Kubernetes version configurable via variables.tf
- **Role Assignment**: AKS kubelet has AcrPull permission for ACR

### Kubernetes Deployment
- **2 replicas** for high availability with PodDisruptionBudget (minAvailable: 1)
- **Rolling updates** with maxSurge: 1, maxUnavailable: 0 (zero-downtime deployments)
- **Resource limits**: 100m/128Mi requests, 200m/256Mi limits (prevents cluster instability)
- **Health probes**: Readiness (5s delay) and liveness (15s delay) on /health endpoint
- **LoadBalancer Service**: Exposes API on port 80

### CI/CD Pipeline (.github/workflows/ci-cd.yml)
The pipeline runs on push to main and follows this sequence:
1. **build-test**: Install deps, run pytest
2. **deploy** (on main branch only):
   - Azure OIDC authentication (requires AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID secrets)
   - Terraform init/apply
   - Fetch Terraform outputs
   - Get AKS credentials
   - Build Docker image with layer caching (40-50% faster builds)
   - Push to ACR with git SHA and latest tags
   - Deploy to Kubernetes
   - Wait for rollout
   - Smoke test (validates LoadBalancer IP and endpoint response)
3. **destroy**: Manual workflow_dispatch job for cleanup

**Critical**: The smoke test uses proper YAML multiline syntax with `|` and has been fixed from the original version to prevent CI failures.

## Important Configuration Details

### Terraform Variables (terraform/variables.tf)
- `prefix`: Resource name prefix (default: "ugrant") - customize this per deployment
- `location`: Azure region (default: "eastus")
- `node_count`: AKS nodes (default: 1)
- `node_vm_size`: Node size (default: "Standard_B2s")
- `kubernetes_version`: K8s version (default: "1.29.7")

### ACR Image Replacement
The kubernetes/deployment.yaml contains a placeholder `REPLACE_WITH_ACR_LOGIN` that must be replaced with the actual ACR login server URL. This is handled automatically by the CI/CD pipeline and manual deployment scripts using `sed`.

### Security Features
- ACR admin credentials disabled (uses managed identity via AcrPull role)
- Container runs as non-root user (appuser:1000)
- Network policies enabled on AKS
- Resource limits prevent resource exhaustion attacks
- Sensitive outputs (kube_config) marked as sensitive in Terraform

### Cost Optimization
- Monthly cost: ~$46 running 24/7, ~$10 with scale-to-zero
- Main cost: AKS node pool (~$35/month for Standard_B2s)
- ACR Basic SKU: ~$5/month
- Use `scripts/cost_management.sh scale-down` to reduce node count to 0 when not in use

## Common Development Workflows

### Making Code Changes
1. Modify `app/main.py` or add new endpoints
2. Add corresponding tests in `app/test_api.py`
3. Run tests locally: `pytest -v`
4. Test locally with uvicorn: `uvicorn app.main:app --reload`
5. Push to GitHub - CI/CD automatically builds and deploys

### Updating Infrastructure
1. Modify `terraform/main.tf` or variables
2. Test with `terraform plan`
3. Push to main branch - CI/CD automatically applies changes
4. Monitor pipeline for smoke test results

### Troubleshooting Deployment Issues
1. Check pod status: `kubectl get pods -l app=liatrio-demo`
2. View logs: `kubectl logs -l app=liatrio-demo --tail=50`
3. Check events: `kubectl describe deploy/liatrio-demo`
4. Verify ACR pull permissions: `kubectl describe pod <pod-name> | grep -A5 "Failed to pull"`
5. Check LoadBalancer: `kubectl describe svc liatrio-demo-svc`

## Files to Modify vs. Files to Preserve

### Modify These:
- `app/main.py`: Add new endpoints or modify API logic
- `app/test_api.py`: Add tests for new functionality
- `terraform/variables.tf`: Customize deployment parameters
- `kubernetes/deployment.yaml`: Adjust replicas, resources, or probe settings

### Preserve These (CI/CD dependencies):
- `.github/workflows/ci-cd.yml`: Pipeline logic (especially smoke test syntax)
- `Dockerfile`: Multi-stage build optimized for caching
- `terraform/main.tf`: Core infrastructure (especially ACR admin_enabled=false)

## Performance Expectations
- API response time: <10ms (p99)
- Container startup: 3-5 seconds
- Full deployment (cold start): 10-12 minutes
- Cached deployment: 4-6 minutes
- Rolling update: 2-3 minutes (zero downtime)

## Additional Documentation
- `README.md`: Quick start and deployment guide
- `docs/COMPREHENSIVE_REVIEW.md`: Detailed analysis and troubleshooting
- `docs/IMPLEMENTATION_GUIDE.md`: Step-by-step implementation instructions
- `docs/PRESENTATION_GUIDE.md`: Demo script and presentation materials
- `CHANGES.md`: Changelog and version history
