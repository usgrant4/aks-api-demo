# Quick Reference

## Directory Structure
```
liatrio-demo-optimized/
├── .github/workflows/    # CI/CD pipelines
├── app/                  # Python FastAPI application
├── kubernetes/           # K8s deployment manifests
├── terraform/            # Infrastructure as Code
├── scripts/              # Utility scripts
├── tests/                # Test scripts
├── docs/                 # Documentation
└── .vscode/              # VSCode configuration
```

## Common Commands

### Local Development
```bash
# Run app locally
uvicorn app.main:app --reload --port 8080

# Run tests
pytest -v

# Test endpoints
curl http://localhost:8080/
curl http://localhost:8080/health
```

### Terraform
```bash
cd terraform

# Initialize
terraform init

# Plan changes
terraform plan

# Apply changes
terraform apply -auto-approve

# Get outputs
terraform output

# Destroy (basic - leaves Network Watcher)
terraform destroy -auto-approve

# Complete cleanup (including Network Watcher)
cd ..
.\cleanup.ps1  # PowerShell
./cleanup.sh   # Bash
```

### Kubernetes
```bash
# Get credentials
az aks get-credentials -g <RG> -n <AKS> --overwrite-existing

# View resources
kubectl get all
kubectl get pods -l app=liatrio-demo
kubectl get svc liatrio-demo-svc

# Check logs
kubectl logs -l app=liatrio-demo --tail=50

# Describe resources
kubectl describe pod <pod-name>
kubectl describe svc liatrio-demo-svc

# Watch rollout
kubectl rollout status deploy/liatrio-demo
```

### Docker & ACR

#### Local Docker Build
```bash
# Build image locally
docker build -t liatrio-demo:local .

# Run locally
docker run -p 8080:8080 liatrio-demo:local
```

#### ACR Build (Recommended - Production Method)
```bash
# Build directly in ACR with platform specification
az acr build \
  --registry <ACR_NAME> \
  --image liatrio-demo:v1.0.$(git rev-parse --short HEAD) \
  --image liatrio-demo:latest \
  --platform linux/amd64 \
  --file Dockerfile \
  .

# Verify image manifest (check for platform issues)
az acr manifest show \
  --name liatrio-demo:latest \
  --registry <ACR_NAME> \
  -o json | jq -r '.manifests[]? | "\(.platform.os)/\(.platform.architecture)"'
```

#### Traditional Docker Push (Alternative)
```bash
# Push to ACR (if building locally)
az acr login --name <ACR_NAME>
docker tag liatrio-demo:local <ACR_LOGIN_SERVER>/liatrio-demo:latest
docker push <ACR_LOGIN_SERVER>/liatrio-demo:latest
```

### Cost Management
```bash
# Check status
bash scripts/cost_management.sh status

# Scale down (save money)
bash scripts/cost_management.sh scale-down

# Scale up (restore)
bash scripts/cost_management.sh scale-up
```

### Testing
```bash
# Unit tests
pytest -v

# Integration tests
bash tests/integration_test.sh

# Pre-demo verification
bash tests/verify_all.sh
```

## Environment Variables
```bash
# Get service endpoint
export API_URL=$(kubectl get svc liatrio-demo-svc -o jsonpath='http://{.status.loadBalancer.ingress[0].ip}')

# Get Terraform outputs
export RG=$(cd terraform && terraform output -raw resource_group_name)
export AKS=$(cd terraform && terraform output -raw aks_name)
export ACR=$(cd terraform && terraform output -raw acr_login_server)
```

## Deployment Scripts

### PowerShell (Windows - Recommended)
```powershell
# Full deployment with comprehensive checks
.\final_deploy.ps1

# Test existing deployment
.\test_deployment.ps1
```

### Bash (Linux/Mac)
```bash
# Full deployment
./deploy.sh
```

## Troubleshooting Quick Fixes

### Pipeline fails
```bash
# Check GitHub Actions logs
# Common issues:
# - Missing GitHub secrets (AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID)
# - Branch name mismatch (main vs master)
# - Syntax errors in YAML
```

### ImagePullBackOff errors
```bash
# Check if ACR is attached to AKS
az aks show -g <RG> -n <AKS> --query "servicePrincipalProfile.clientId" -o tsv

# Manually attach ACR (if needed)
az aks update -g <RG> -n <AKS> --attach-acr <ACR_NAME>

# Wait 30-60 seconds for propagation
```

### Image platform issues
```bash
# Check image manifest for unknown platforms
az acr manifest show \
  --name liatrio-demo:latest \
  --registry <ACR_NAME> \
  -o json | jq '.manifests[]? | .platform'

# Rebuild with platform specification
az acr build \
  --registry <ACR_NAME> \
  --image liatrio-demo:latest \
  --platform linux/amd64 \
  .
```

### Pods not starting
```bash
# Check pod status
kubectl get pods -l app=liatrio-demo

# Detailed pod information
kubectl describe pod <pod-name>

# View container logs
kubectl logs <pod-name>

# Check recent events
kubectl get events --sort-by='.lastTimestamp' | grep liatrio-demo
```

### Can't reach service
```bash
# Check service status
kubectl get svc liatrio-demo-svc

# Verify LoadBalancer IP assigned
kubectl describe svc liatrio-demo-svc

# Wait up to 5 minutes for LoadBalancer IP (Azure can be slow)
for i in {1..30}; do
  IP=$(kubectl get svc liatrio-demo-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  [[ -n "$IP" ]] && echo "IP: $IP" && break
  echo "Waiting... ($i/30)"
  sleep 10
done
```

### Terraform errors
```bash
cd terraform

# Format and validate
terraform fmt
terraform validate

# Common issues:
# - ACR name not globally unique
# - Azure quota limits reached
# - Service principal lacks permissions
# - State file corruption (delete terraform.tfstate and re-init)
```

### Network Watcher not destroyed
```bash
# Network Watcher is auto-created by Azure and shared across resources
# terraform destroy doesn't remove it because it's not in Terraform state

# Option 1: Use the cleanup script (recommended)
.\cleanup.ps1  # PowerShell - prompts before deletion
./cleanup.sh   # Bash - prompts before deletion

# Option 2: Manual cleanup
az network watcher delete -n NetworkWatcher_<region> -g NetworkWatcherRG
az group delete -n NetworkWatcherRG --yes

# Why it exists:
# - Auto-created when AKS uses Azure CNI networking
# - Shared by all resources in the region
# - Near-zero cost when not actively used
# - Safe to leave (other resources may need it)
```

### Deployment rollback
```bash
# View deployment history
kubectl rollout history deployment/liatrio-demo

# Rollback to previous version
kubectl rollout undo deployment/liatrio-demo

# Rollback to specific revision
kubectl rollout undo deployment/liatrio-demo --to-revision=2
```

## Important URLs
- GitHub Actions: `https://github.com/<YOUR_REPO>/actions`
- Azure Portal: `https://portal.azure.com`
- Kubernetes Dashboard: `az aks browse -g <RG> -n <AKS>`
