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

# Destroy
terraform destroy -auto-approve
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

### Docker
```bash
# Build image
docker build -t liatrio-demo:local .

# Run locally
docker run -p 8080:8080 liatrio-demo:local

# Push to ACR
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

## Troubleshooting Quick Fixes

### Pipeline fails
```bash
# Check GitHub Actions logs
# Common issues: syntax errors in YAML, missing secrets
```

### Pods not starting
```bash
kubectl get pods -l app=liatrio-demo
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### Can't reach service
```bash
kubectl get svc liatrio-demo-svc
kubectl describe svc liatrio-demo-svc
# Wait up to 5 minutes for LoadBalancer IP
```

### Terraform errors
```bash
cd terraform
terraform fmt
terraform validate
# Check Azure quotas and permissions
```

## Important URLs
- GitHub Actions: `https://github.com/<YOUR_REPO>/actions`
- Azure Portal: `https://portal.azure.com`
- Kubernetes Dashboard: `az aks browse -g <RG> -n <AKS>`
