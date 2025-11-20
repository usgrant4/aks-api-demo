$ErrorActionPreference = "Stop"

Write-Host "╔═══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   AKS Demo - Helm Deployment                    ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$startTime = Get-Date

# Parse parameters
param(
    [string]$Environment = "dev",
    [switch]$SkipInfra
)

Write-Host "Deployment Configuration:" -ForegroundColor Yellow
Write-Host "  Environment: $Environment"
Write-Host "  Skip Infrastructure: $SkipInfra"
Write-Host ""

# Validate Helm is installed
Write-Host "Checking prerequisites..." -ForegroundColor Yellow
try {
    $helmVersion = helm version --short 2>$null
    Write-Host "  ✅ Helm installed: $helmVersion" -ForegroundColor Green
}
catch {
    Write-Host "  ❌ Helm not found. Please install Helm 3.x" -ForegroundColor Red
    Write-Host "     Download from: https://helm.sh/docs/intro/install/"
    exit 1
}

try {
    kubectl version --client=true --short 2>$null | Out-Null
    Write-Host "  ✅ kubectl installed" -ForegroundColor Green
}
catch {
    Write-Host "  ❌ kubectl not found. Please install kubectl" -ForegroundColor Red
    exit 1
}
Write-Host ""

if (-not $SkipInfra) {
    # Step 1: Deploy Infrastructure
    Write-Host "1️⃣ Deploying Azure Infrastructure..." -ForegroundColor Yellow
    cd terraform

    if (-not (Test-Path "terraform.tfstate")) {
        terraform init
    }

    terraform apply -auto-approve -var="environment=$Environment"

    $RG = terraform output -raw resource_group_name
    $AKS = terraform output -raw aks_name
    $ACR_NAME = (terraform output -raw acr_login_server).Split('.')[0]
    $ACR_LOGIN = terraform output -raw acr_login_server

    Write-Host "   ✅ Infrastructure deployed" -ForegroundColor Green
    Write-Host "      ACR: $ACR_NAME"
    Write-Host "      AKS: $AKS"
    Write-Host ""

    cd ..
}
else {
    Write-Host "1️⃣ Skipping infrastructure deployment..." -ForegroundColor Yellow

    cd terraform
    $RG = terraform output -raw resource_group_name
    $AKS = terraform output -raw aks_name
    $ACR_NAME = (terraform output -raw acr_login_server).Split('.')[0]
    $ACR_LOGIN = terraform output -raw acr_login_server
    cd ..

    Write-Host "   Using existing infrastructure:" -ForegroundColor Green
    Write-Host "      ACR: $ACR_NAME"
    Write-Host "      AKS: $AKS"
    Write-Host ""
}

# Step 2: Configure kubectl
Write-Host "2️⃣ Configuring kubectl..." -ForegroundColor Yellow
az aks get-credentials -g $RG -n $AKS --overwrite-existing > $null
kubectl get nodes > $null
Write-Host "   ✅ Connected to AKS" -ForegroundColor Green
Write-Host ""

# Step 3: Attach ACR to AKS
Write-Host "3️⃣ Ensuring ACR is attached to AKS..." -ForegroundColor Yellow
az aks update `
    --resource-group $RG `
    --name $AKS `
    --attach-acr $ACR_NAME `
    --output none

Write-Host "   ✅ ACR attached" -ForegroundColor Green
Write-Host ""

# Step 4: Build Image
Write-Host "4️⃣ Building Docker image with ACR Tasks..." -ForegroundColor Yellow
$GIT_SHA = (git rev-parse --short HEAD 2>$null)
if (-not $GIT_SHA) {
    $GIT_SHA = Get-Date -Format "yyyyMMddHHmmss"
}
$VERSION = "v1.0.$GIT_SHA"

Write-Host "   Version: $VERSION"

az acr build `
    --registry $ACR_NAME `
    --image "aks-demo:$VERSION" `
    --image "aks-demo:latest" `
    --platform linux/amd64 `
    --file Dockerfile `
    . `
    --output table

Write-Host "   ✅ Image built: $ACR_LOGIN/aks-demo:$VERSION" -ForegroundColor Green
Write-Host ""

# Step 5: Validate Helm Chart
Write-Host "5️⃣ Validating Helm chart..." -ForegroundColor Yellow

$valuesFile = "helm/aks-demo/values-$Environment.yaml"
if (-not (Test-Path $valuesFile)) {
    Write-Host "   ⚠️ Values file not found: $valuesFile" -ForegroundColor Yellow
    Write-Host "   Using default values.yaml" -ForegroundColor Yellow
    $valuesFile = "helm/aks-demo/values.yaml"
}

Write-Host "   Linting chart..."
helm lint ./helm/aks-demo --values $valuesFile

Write-Host "   Running dry-run..."
$NAMESPACE = "aks-demo-$Environment"
helm install aks-demo ./helm/aks-demo `
    --dry-run `
    --set image.registry=$ACR_LOGIN `
    --set image.tag=$VERSION `
    --set environment=$Environment `
    --values $valuesFile `
    --namespace $NAMESPACE `
    --create-namespace `
    > helm-dry-run.yaml

Write-Host "   ✅ Helm chart validated" -ForegroundColor Green
Write-Host "   📄 Dry-run output saved to: helm-dry-run.yaml"
Write-Host ""

# Step 6: Check for existing release
Write-Host "6️⃣ Checking for existing Helm release..." -ForegroundColor Yellow

kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f - > $null

$existingRelease = helm list -n $NAMESPACE -o json | ConvertFrom-Json | Where-Object { $_.name -eq "aks-demo" }

if ($existingRelease) {
    Write-Host "   Found existing release: $($existingRelease.name) (revision $($existingRelease.revision))" -ForegroundColor Cyan
    $PREVIOUS_REVISION = $existingRelease.revision
}
else {
    Write-Host "   No existing release found (initial deployment)" -ForegroundColor Cyan
    $PREVIOUS_REVISION = $null
}
Write-Host ""

# Step 7: Deploy with Helm
Write-Host "7️⃣ Deploying with Helm..." -ForegroundColor Yellow
Write-Host "   Environment: $Environment"
Write-Host "   Namespace: $NAMESPACE"
Write-Host "   Image: $ACR_LOGIN/aks-demo:$VERSION"
Write-Host ""

helm upgrade --install aks-demo ./helm/aks-demo `
    --set image.registry=$ACR_LOGIN `
    --set image.tag=$VERSION `
    --set environment=$Environment `
    --values $valuesFile `
    --namespace $NAMESPACE `
    --create-namespace `
    --wait `
    --timeout 5m `
    --atomic `
    --cleanup-on-fail

$releaseInfo = helm list -n $NAMESPACE -o json | ConvertFrom-Json | Where-Object { $_.name -eq "aks-demo" }
$NEW_REVISION = $releaseInfo.revision

Write-Host "   ✅ Deployed successfully (revision $NEW_REVISION)" -ForegroundColor Green
Write-Host ""

# Step 8: Verify Deployment
Write-Host "8️⃣ Verifying deployment..." -ForegroundColor Yellow

Write-Host "   Checking Helm release status..."
helm status aks-demo -n $NAMESPACE

Write-Host ""
Write-Host "   Checking pod readiness..."
$DEPLOYMENT_NAME = kubectl get deployment -n $NAMESPACE -l app.kubernetes.io/name=aks-demo -o jsonpath='{.items[0].metadata.name}'
$DESIRED = kubectl get deploy $DEPLOYMENT_NAME -n $NAMESPACE -o jsonpath='{.spec.replicas}'
$READY = kubectl get deploy $DEPLOYMENT_NAME -n $NAMESPACE -o jsonpath='{.status.readyReplicas}'

if ($READY -eq $DESIRED) {
    Write-Host "   ✅ All $READY/$DESIRED pods ready" -ForegroundColor Green
    kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=aks-demo
}
else {
    Write-Host "   ⚠️ Expected $DESIRED ready pods, got $READY" -ForegroundColor Yellow
    kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=aks-demo
}
Write-Host ""

# Step 9: Get LoadBalancer IP and Test
Write-Host "9️⃣ Getting LoadBalancer IP..." -ForegroundColor Yellow
$SVC_NAME = kubectl get svc -n $NAMESPACE -l app.kubernetes.io/name=aks-demo -o jsonpath='{.items[0].metadata.name}'

for ($i = 1; $i -le 30; $i++) {
    $IP = kubectl get svc $SVC_NAME -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
    if ($IP) {
        Write-Host "   ✅ IP assigned: $IP" -ForegroundColor Green
        break
    }
    Write-Host "   Waiting... (attempt $i/30)"
    Start-Sleep -Seconds 10
}

if (-not $IP) {
    Write-Host "   ⚠️ LoadBalancer IP not assigned" -ForegroundColor Yellow
    kubectl describe svc $SVC_NAME -n $NAMESPACE
    exit 1
}

Write-Host ""
Write-Host "🧪 Testing API..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

try {
    $response = Invoke-RestMethod -Uri "http://$IP/" -TimeoutSec 10
    Write-Host "   ✅ Main endpoint responding" -ForegroundColor Green

    $healthResponse = Invoke-RestMethod -Uri "http://$IP/health" -TimeoutSec 10
    Write-Host "   ✅ Health endpoint responding" -ForegroundColor Green
    Write-Host ""

    $endTime = Get-Date
    $duration = $endTime - $startTime

    Write-Host "╔═══════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║       HELM DEPLOYMENT SUCCESSFUL!                ║" -ForegroundColor Green
    Write-Host "╚═══════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "🎉 Deployment completed in $([math]::Round($duration.TotalMinutes, 1)) minutes" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📊 Deployment Details:" -ForegroundColor Yellow
    Write-Host "   Environment: $Environment" -ForegroundColor White
    Write-Host "   Namespace: $NAMESPACE" -ForegroundColor White
    Write-Host "   API Endpoint: http://$IP/" -ForegroundColor White
    Write-Host "   Health Check: http://$IP/health" -ForegroundColor White
    Write-Host "   Image Tag: $VERSION" -ForegroundColor White
    Write-Host "   Helm Revision: $NEW_REVISION" -ForegroundColor White
    Write-Host ""
    Write-Host "🧪 API Response:" -ForegroundColor Yellow
    $response | ConvertTo-Json
    Write-Host ""
    Write-Host "⚙️ Helm Commands:" -ForegroundColor Yellow
    Write-Host "   Status:   helm status aks-demo -n $NAMESPACE" -ForegroundColor White
    Write-Host "   History:  helm history aks-demo -n $NAMESPACE" -ForegroundColor White
    Write-Host "   Values:   helm get values aks-demo -n $NAMESPACE" -ForegroundColor White
    if ($PREVIOUS_REVISION) {
        Write-Host "   Rollback: helm rollback aks-demo $PREVIOUS_REVISION -n $NAMESPACE" -ForegroundColor White
    }
    else {
        Write-Host "   Rollback: helm rollback aks-demo [REVISION] -n $NAMESPACE" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "🎯 Next Steps:" -ForegroundColor Yellow
    Write-Host "   • Run tests: .\test_deployment.ps1" -ForegroundColor White
    Write-Host "   • View logs: kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=aks-demo" -ForegroundColor White
    Write-Host "   • Check resources: kubectl get all,vpa,pdb -n $NAMESPACE -l app.kubernetes.io/instance=aks-demo" -ForegroundColor White
    Write-Host "   • Uninstall: helm uninstall aks-demo -n $NAMESPACE" -ForegroundColor White
    Write-Host "   • Cleanup infrastructure: cd terraform && terraform destroy" -ForegroundColor White
    Write-Host ""
}
catch {
    Write-Host "   ⚠️ API not responding" -ForegroundColor Yellow
    Write-Host "   Error: $_"
    Write-Host ""
    Write-Host "   Try: curl http://$IP/"
    Write-Host "   Logs: kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=aks-demo"
    Write-Host ""
    Write-Host "   Rollback command: helm rollback aks-demo $PREVIOUS_REVISION -n $NAMESPACE"
    exit 1
}
