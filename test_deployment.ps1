$ErrorActionPreference = "Stop"

Write-Host "╔═══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   AKS Demo - Test Suite                     ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Get service IP
Write-Host "📍 Getting service endpoint..." -ForegroundColor Yellow
$IP = kubectl get svc aks-demo-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

if (-not $IP) {
    Write-Host "❌ LoadBalancer IP not ready yet" -ForegroundColor Red
    Write-Host "Run: kubectl get svc aks-demo-svc"
    exit 1
}

Write-Host "✅ API Endpoint: http://$IP/" -ForegroundColor Green
Write-Host ""

$testsPassed = 0
$testsFailed = 0

# Test 1: Main Endpoint
Write-Host "Test 1: Main Endpoint" -ForegroundColor Yellow
Write-Host "  GET http://$IP/"
try {
    $response = Invoke-RestMethod -Uri "http://$IP/" -TimeoutSec 10
    Write-Host "  ✅ Response received" -ForegroundColor Green
    $response | ConvertTo-Json | Write-Host

    # Validate response structure
    if ($response.message -eq "Automate all the things!" -and $response.timestamp) {
        Write-Host "  ✅ Response structure correct" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "  ⚠️ Unexpected response structure" -ForegroundColor Yellow
        $testsFailed++
    }
}
catch {
    Write-Host "  ❌ Failed: $_" -ForegroundColor Red
    $testsFailed++
}
Write-Host ""

# Test 2: Health Endpoint
Write-Host "Test 2: Health Endpoint" -ForegroundColor Yellow
Write-Host "  GET http://$IP/health"
try {
    $response = Invoke-RestMethod -Uri "http://$IP/health" -TimeoutSec 10
    Write-Host "  ✅ Response received" -ForegroundColor Green
    $response | ConvertTo-Json | Write-Host

    if ($response.status -eq "healthy" -and $response.timestamp) {
        Write-Host "  ✅ Health check passed" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "  ⚠️ Unexpected health response" -ForegroundColor Yellow
        $testsFailed++
    }
}
catch {
    Write-Host "  ❌ Failed: $_" -ForegroundColor Red
    $testsFailed++
}
Write-Host ""

# Test 3: Response Time
Write-Host "Test 3: Response Time" -ForegroundColor Yellow
$measurements = @()
for ($i = 1; $i -le 5; $i++) {
    $start = Get-Date
    try {
        Invoke-RestMethod -Uri "http://$IP/" -TimeoutSec 10 | Out-Null
        $end = Get-Date
        $duration = ($end - $start).TotalMilliseconds
        $measurements += $duration
    }
    catch {
        Write-Host "  ⚠️ Request $i failed" -ForegroundColor Yellow
    }
}

if ($measurements.Count -gt 0) {
    $avgTime = ($measurements | Measure-Object -Average).Average
    $minTime = ($measurements | Measure-Object -Minimum).Minimum
    $maxTime = ($measurements | Measure-Object -Maximum).Maximum

    Write-Host "  Average: $([math]::Round($avgTime, 2))ms" -ForegroundColor Cyan
    Write-Host "  Min: $([math]::Round($minTime, 2))ms | Max: $([math]::Round($maxTime, 2))ms" -ForegroundColor Cyan

    if ($avgTime -lt 100) {
        Write-Host "  ✅ Excellent performance" -ForegroundColor Green
        $testsPassed++
    }
    elseif ($avgTime -lt 500) {
        Write-Host "  ✅ Good performance" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "  ⚠️ Response time high" -ForegroundColor Yellow
        $testsFailed++
    }
}
else {
    Write-Host "  ❌ All requests failed" -ForegroundColor Red
    $testsFailed++
}
Write-Host ""

# Test 4: Timestamp Updates
Write-Host "Test 4: Timestamp Updates" -ForegroundColor Yellow
try {
    $ts1 = (Invoke-RestMethod -Uri "http://$IP/" -TimeoutSec 10).timestamp
    Start-Sleep -Seconds 2
    $ts2 = (Invoke-RestMethod -Uri "http://$IP/" -TimeoutSec 10).timestamp

    if ($ts2 -gt $ts1) {
        Write-Host "  ✅ Timestamps updating correctly" -ForegroundColor Green
        Write-Host "    First: $ts1 | Second: $ts2" -ForegroundColor Cyan
        $testsPassed++
    }
    else {
        Write-Host "  ⚠️ Timestamps not updating" -ForegroundColor Yellow
        $testsFailed++
    }
}
catch {
    Write-Host "  ❌ Failed: $_" -ForegroundColor Red
    $testsFailed++
}
Write-Host ""

# Test 5: Concurrent Requests
Write-Host "Test 5: Concurrent Requests (20 requests)" -ForegroundColor Yellow
$jobs = 1..20 | ForEach-Object {
    Start-Job -ScriptBlock {
        param($url)
        try {
            Invoke-RestMethod -Uri $url -TimeoutSec 10 | Out-Null
            return $true
        }
        catch {
            return $false
        }
    } -ArgumentList "http://$IP/"
}

$results = $jobs | Wait-Job | Receive-Job
$successCount = ($results | Where-Object { $_ -eq $true }).Count
$jobs | Remove-Job

Write-Host "  ✅ $successCount/20 requests succeeded" -ForegroundColor Green
if ($successCount -ge 18) {
    Write-Host "  ✅ Excellent concurrency handling" -ForegroundColor Green
    $testsPassed++
}
elseif ($successCount -ge 15) {
    Write-Host "  ✅ Good concurrency handling" -ForegroundColor Green
    $testsPassed++
}
else {
    Write-Host "  ⚠️ Some concurrent requests failed" -ForegroundColor Yellow
    $testsFailed++
}
Write-Host ""

# Test 6: Pod Health
Write-Host "Test 6: Pod Health" -ForegroundColor Yellow
$pods = kubectl get pods -l app=aks-demo -o json | ConvertFrom-Json
$readyPods = $pods.items | Where-Object {
    $_.status.phase -eq "Running" -and
    ($_.status.conditions | Where-Object { $_.type -eq "Ready" -and $_.status -eq "True" })
}
$readyCount = ($readyPods | Measure-Object).Count
$totalPods = $pods.items.Count

Write-Host "  Pods: $readyCount/$totalPods ready" -ForegroundColor Cyan
if ($readyCount -eq $totalPods -and $totalPods -ge 2) {
    Write-Host "  ✅ All pods healthy" -ForegroundColor Green
    $testsPassed++
}
else {
    Write-Host "  ⚠️ Some pods not healthy" -ForegroundColor Yellow
    kubectl get pods -l app=aks-demo
    $testsFailed++
}
Write-Host ""

# Test 7: Service Configuration
Write-Host "Test 7: Service Configuration" -ForegroundColor Yellow
$svc = kubectl get svc aks-demo-svc -o json | ConvertFrom-Json
$svcType = $svc.spec.type
$svcPort = $svc.spec.ports[0].port

Write-Host "  Type: $svcType | Port: $svcPort" -ForegroundColor Cyan
if ($svcType -eq "LoadBalancer" -and $svcPort -eq 80) {
    Write-Host "  ✅ Service configured correctly" -ForegroundColor Green
    $testsPassed++
}
else {
    Write-Host "  ⚠️ Unexpected service configuration" -ForegroundColor Yellow
    $testsFailed++
}
Write-Host ""

# Test 8: Invalid Endpoint (404 Test)
Write-Host "Test 8: Invalid Endpoint Handling" -ForegroundColor Yellow
Write-Host "  GET http://$IP/invalid"
try {
    Invoke-RestMethod -Uri "http://$IP/invalid" -TimeoutSec 10 | Out-Null
    Write-Host "  ⚠️ Should have returned 404" -ForegroundColor Yellow
    $testsFailed++
}
catch {
    if ($_.Exception.Response.StatusCode -eq 404) {
        Write-Host "  ✅ Correctly returns 404" -ForegroundColor Green
        $testsPassed++
    }
    else {
        Write-Host "  ⚠️ Unexpected error: $_" -ForegroundColor Yellow
        $testsFailed++
    }
}
Write-Host ""

# Summary
$totalTests = $testsPassed + $testsFailed
Write-Host "╔═══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║              Test Summary                        ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Tests: $totalTests" -ForegroundColor White
Write-Host "Passed: $testsPassed" -ForegroundColor Green
Write-Host "Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($testsFailed -eq 0) {
    Write-Host "╔═══════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║          ✅ ALL TESTS PASSED!                    ║" -ForegroundColor Green
    Write-Host "╚═══════════════════════════════════════════════════╝" -ForegroundColor Green
}
else {
    Write-Host "╔═══════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║          ⚠️  SOME TESTS FAILED                   ║" -ForegroundColor Yellow
    Write-Host "╚═══════════════════════════════════════════════════╝" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🌐 Your API: http://$IP/" -ForegroundColor Cyan
Write-Host "🏥 Health Check: http://$IP/health" -ForegroundColor Cyan
Write-Host ""
Write-Host "📊 Additional Commands:" -ForegroundColor Yellow
Write-Host "  kubectl get all -l app=aks-demo" -ForegroundColor White
Write-Host "  kubectl logs -l app=aks-demo --tail=50" -ForegroundColor White
Write-Host "  kubectl describe svc aks-demo-svc" -ForegroundColor White
Write-Host ""
