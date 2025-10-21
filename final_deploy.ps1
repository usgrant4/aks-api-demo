$ErrorActionPreference = "Stop"

Write-Host "╔═══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   Liatrio Demo - Fresh Deployment               ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$startTime = Get-Date

# Step 1: Deploy Infrastructure
Write-Host "1️⃣ Deploying Azure Infrastructure..." -ForegroundColor Yellow
cd ~/repos/liatrio-demo/terraform

if (-not (Test-Path "terraform.tfstate")) {
    terraform init
}

terraform apply -auto-approve

$RG = terraform output -raw resource_group_name
$AKS = terraform output -raw aks_name
$ACR_NAME = (terraform output -raw acr_login_server).Split('.')[0]
$ACR_LOGIN = terraform output -raw acr_login_server

Write-Host "   ✅ Infrastructure deployed" -ForegroundColor Green
Write-Host "      ACR: $ACR_NAME"
Write-Host "      AKS: $AKS"
Write-Host ""

# Step 2: Configure kubectl
Write-Host "2️⃣ Configuring kubectl..." -ForegroundColor Yellow
az aks get-credentials -g $RG -n $AKS --overwrite-existing > $null
kubectl get nodes > $null
Write-Host "   ✅ Connected to AKS" -ForegroundColor Green
Write-Host ""

# Step 3: Attach ACR to AKS
Write-Host "3️⃣ Attaching ACR to AKS..." -ForegroundColor Yellow
az aks update `
    --resource-group $RG `
    --name $AKS `
    --attach-acr $ACR_NAME `
    --output none

Write-Host "   ✅ ACR attached" -ForegroundColor Green
Write-Host "   ⏳ Waiting 60s for propagation..."
Start-Sleep -Seconds 60
Write-Host ""

# Step 4: Build Image
cd ~/repos/liatrio-demo

Write-Host "4️⃣ Building Docker image with ACR Tasks..." -ForegroundColor Yellow
$GIT_SHA = (git rev-parse --short HEAD 2>$null)
if (-not $GIT_SHA) {
    $GIT_SHA = Get-Date -Format "yyyyMMddHHmmss"
}
$VERSION = "v1.0.$GIT_SHA"

Write-Host "   Version: $VERSION"

az acr build `
    --registry $ACR_NAME `
    --image "liatrio-demo:$VERSION" `
    --image "liatrio-demo:latest" `
    --platform linux/amd64 `
    --file Dockerfile `
    . `
    --output table

Write-Host "   ✅ Image built" -ForegroundColor Green
Write-Host ""

# Step 5: Verify Image
Write-Host "5️⃣ Verifying image platform..." -ForegroundColor Yellow
$manifest = az acr manifest show `
    --name "liatrio-demo:$VERSION" `
    --registry $ACR_NAME `
    -o json | ConvertFrom-Json

$platforms = $manifest.manifests | ForEach-Object { "$($_.platform.os)/$($_.platform.architecture)" }
Write-Host "   Platforms: $($platforms -join ', ')"

if ($platforms -notcontains "unknown/unknown") {
    Write-Host "   ✅ Clean manifest" -ForegroundColor Green
}
else {
    Write-Host "   ⚠️ Warning: Unexpected platforms found" -ForegroundColor Yellow
}
Write-Host ""

# Step 6: Deploy to Kubernetes (WITHOUT digest pinning - simpler and more reliable)
Write-Host "6️⃣ Deploying to Kubernetes..." -ForegroundColor Yellow
$IMAGE = "$ACR_LOGIN/liatrio-demo:$VERSION"
Write-Host "   Image: $IMAGE"

$deploymentContent = Get-Content kubernetes/deployment.yaml -Raw
$deploymentContent = $deploymentContent -replace 'image: REPLACE_WITH_ACR_LOGIN/liatrio-demo:latest', "image: $IMAGE"

$deploymentContent | Out-File -FilePath temp_deployment.yaml -Encoding UTF8

kubectl apply -f temp_deployment.yaml
Remove-Item temp_deployment.yaml

Write-Host "   ⏳ Waiting for rollout..."
kubectl rollout status deployment/liatrio-demo --timeout=300s

Write-Host "   ✅ Deployed" -ForegroundColor Green
Write-Host ""

# Step 7: Wait for Pods
Write-Host "7️⃣ Waiting for pods to be ready..." -ForegroundColor Yellow
for ($i = 1; $i -le 30; $i++) {
    $pods = kubectl get pods -l app=liatrio-demo -o json | ConvertFrom-Json
    $readyPods = $pods.items | Where-Object {
        $_.status.phase -eq "Running" -and
        ($_.status.conditions | Where-Object { $_.type -eq "Ready" -and $_.status -eq "True" })
    }
    $failedPods = $pods.items | Where-Object {
        $_.status.containerStatuses -and
        $_.status.containerStatuses[0].state.waiting -and
        $_.status.containerStatuses[0].state.waiting.reason -match "Invalid|ImagePull|Err"
    }

    $readyCount = ($readyPods | Measure-Object).Count
    $failedCount = ($failedPods | Measure-Object).Count

    Write-Host "   Ready: $readyCount/2 | Failed: $failedCount (attempt $i/30)"

    if ($readyCount -eq 2) {
        Write-Host "   ✅ All pods ready" -ForegroundColor Green
        break
    }

    if ($failedCount -gt 0 -and $i -gt 10) {
        Write-Host "   ⚠️ Pods failing:" -ForegroundColor Yellow
        kubectl describe pod ($failedPods[0].metadata.name) | Select-String -Pattern "Events:" -Context 0, 10
        kubectl get pods -l app=liatrio-demo
        exit 1
    }

    Start-Sleep -Seconds 10
}

if ($readyCount -ne 2) {
    Write-Host "   ⚠️ Pods not ready" -ForegroundColor Yellow
    kubectl get pods -l app=liatrio-demo
    exit 1
}

kubectl get pods -l app=liatrio-demo
Write-Host ""

# Step 8: Get LoadBalancer IP
Write-Host "8️⃣ Getting LoadBalancer IP..." -ForegroundColor Yellow
for ($i = 1; $i -le 30; $i++) {
    $IP = kubectl get svc liatrio-demo-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
    if ($IP) {
        Write-Host "   ✅ IP assigned: $IP" -ForegroundColor Green
        break
    }
    Write-Host "   Waiting... (attempt $i/30)"
    Start-Sleep -Seconds 10
}

if (-not $IP) {
    Write-Host "   ⚠️ LoadBalancer IP not assigned" -ForegroundColor Yellow
    kubectl get svc liatrio-demo-svc
    exit 1
}

Write-Host ""

# Step 9: Test API
Write-Host "9️⃣ Testing API..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

try {
    $response = Invoke-RestMethod -Uri "http://$IP/" -TimeoutSec 10
    Write-Host "   ✅ API responding" -ForegroundColor Green
    Write-Host ""

    $endTime = Get-Date
    $duration = $endTime - $startTime

    Write-Host "╔═══════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║          DEPLOYMENT SUCCESSFUL!                   ║" -ForegroundColor Green
    Write-Host "╚═══════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "🎉 Deployment completed in $([math]::Round($duration.TotalMinutes, 1)) minutes" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📊 Deployment Details:" -ForegroundColor Yellow
    Write-Host "   API Endpoint: http://$IP/" -ForegroundColor White
    Write-Host "   Health Check: http://$IP/health" -ForegroundColor White
    Write-Host "   Version: $VERSION" -ForegroundColor White
    Write-Host "   Image: $ACR_LOGIN/liatrio-demo:$VERSION" -ForegroundColor White
    Write-Host ""
    Write-Host "🧪 API Response:" -ForegroundColor Yellow
    $response | ConvertTo-Json
    Write-Host ""
    Write-Host "🎯 Next Steps:" -ForegroundColor Yellow
    Write-Host "   • Run tests: .\test_deployment.ps1"
    Write-Host "   • View logs: kubectl logs -l app=liatrio-demo"
    Write-Host "   • Check status: kubectl get all -l app=liatrio-demo"
    Write-Host "   • Cleanup when done: cd terraform && terraform destroy"
    Write-Host ""
}
catch {
    Write-Host "   ⚠️ API not responding" -ForegroundColor Yellow
    Write-Host "   Error: $_"
    Write-Host ""
    Write-Host "   Try: curl http://$IP/"
    Write-Host "   Logs: kubectl logs -l app=liatrio-demo"
}
