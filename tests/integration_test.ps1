# Integration test suite for Liatrio Demo
# PowerShell version for Windows compatibility

$ErrorActionPreference = "Stop"

# Test counters
$script:TestsRun = 0
$script:TestsPassed = 0
$script:TestsFailed = 0

# Helper functions
function Log-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Yellow
}

function Log-Success {
    param([string]$Message)
    Write-Host "[PASS] $Message" -ForegroundColor Green
    $script:TestsPassed++
}

function Log-Error {
    param([string]$Message)
    Write-Host "[FAIL] $Message" -ForegroundColor Red
    $script:TestsFailed++
}

function Run-Test {
    param([string]$Name)
    $script:TestsRun++
    Write-Host ""
    Log-Info "Test $script:TestsRun: $Name"
}

# Main test suite
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Liatrio Demo Integration Test Suite" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Get service endpoint
Log-Info "Retrieving service endpoint..."
try {
    $IP = kubectl get svc liatrio-demo-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>$null
    if ([string]::IsNullOrEmpty($IP)) {
        Log-Error "Service IP not found. Is the service deployed?"
        exit 1
    }
} catch {
    Log-Error "Failed to query Kubernetes service: $_"
    exit 1
}

$Endpoint = "http://$IP"
Log-Info "Testing endpoint: $Endpoint"
Write-Host ""

# Test 1: Basic connectivity
Run-Test "Basic HTTP connectivity"
try {
    $response = Invoke-WebRequest -Uri $Endpoint -TimeoutSec 10 -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        Log-Success "Endpoint is reachable"
    } else {
        Log-Error "Unexpected status code: $($response.StatusCode)"
    }
} catch {
    Log-Error "Cannot reach endpoint: $_"
    exit 1
}

# Test 2: Response structure validation
Run-Test "Response structure validation"
try {
    $response = Invoke-RestMethod -Uri $Endpoint -TimeoutSec 10
    $message = $response.message
    $timestamp = $response.timestamp

    if ($message -eq "Automate all the things!" -and $timestamp -gt 0) {
        Log-Success "Response structure is valid"
        Log-Info "  Message: $message"
        Log-Info "  Timestamp: $timestamp"
    } else {
        Log-Error "Invalid response structure"
        Log-Info "  Response: $($response | ConvertTo-Json)"
    }
} catch {
    Log-Error "Failed to parse response: $_"
    exit 1
}

# Test 3: Timestamp accuracy
Run-Test "Timestamp accuracy check"
$currentTime = [int]([DateTimeOffset]::Now.ToUnixTimeSeconds())
$timeDiff = $currentTime - $timestamp
$absTimeDiff = [Math]::Abs($timeDiff)

if ($absTimeDiff -lt 10) {
    Log-Success "Timestamp is accurate (within 10 seconds)"
    Log-Info "  Time difference: ${timeDiff}s"
} else {
    Log-Error "Timestamp is inaccurate (off by ${timeDiff}s)"
}

# Test 4: Health endpoint
Run-Test "Health endpoint check"
try {
    $healthResponse = Invoke-RestMethod -Uri "$Endpoint/health" -TimeoutSec 10 -ErrorAction SilentlyContinue
    if ($healthResponse.status -eq "healthy") {
        Log-Success "Health endpoint returns healthy status"
    } else {
        Log-Error "Health endpoint not responding correctly"
        Log-Info "  Response: $($healthResponse | ConvertTo-Json)"
    }
} catch {
    Log-Error "Health endpoint error: $_"
}

# Test 5: Response time performance
Run-Test "Response time performance"
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $null = Invoke-WebRequest -Uri $Endpoint -TimeoutSec 10 -UseBasicParsing
    $stopwatch.Stop()
    $responseMs = $stopwatch.ElapsedMilliseconds

    if ($responseMs -lt 500) {
        Log-Success "Response time is acceptable: ${responseMs}ms"
    } else {
        Log-Error "Response time is too slow: ${responseMs}ms (should be < 500ms)"
    }
} catch {
    Log-Error "Response time test failed: $_"
}

# Test 6: Kubernetes pod health
Run-Test "Kubernetes pod health check"
try {
    $pods = kubectl get pods -l app=liatrio-demo -o json | ConvertFrom-Json
    $readyPods = ($pods.items | Where-Object {
        $_.status.conditions | Where-Object { $_.type -eq "Ready" -and $_.status -eq "True" }
    }).Count
    $totalPods = $pods.items.Count

    if ($readyPods -ge 1 -and $readyPods -eq $totalPods) {
        Log-Success "All pods are healthy ($readyPods/$totalPods ready)"
    } else {
        Log-Error "Some pods are not healthy ($readyPods/$totalPods ready)"
        kubectl get pods -l app=liatrio-demo
    }
} catch {
    Log-Error "Failed to check pod health: $_"
}

# Test 7: Service configuration
Run-Test "Service configuration validation"
try {
    $svcType = kubectl get svc liatrio-demo-svc -o jsonpath='{.spec.type}'
    $svcPort = kubectl get svc liatrio-demo-svc -o jsonpath='{.spec.ports[0].port}'

    if ($svcType -eq "LoadBalancer" -and $svcPort -eq "80") {
        Log-Success "Service is correctly configured"
        Log-Info "  Type: $svcType"
        Log-Info "  Port: $svcPort"
    } else {
        Log-Error "Service configuration is incorrect"
    }
} catch {
    Log-Error "Failed to check service configuration: $_"
}

# Test 8: Content-Type header
Run-Test "Content-Type header validation"
try {
    $response = Invoke-WebRequest -Uri $Endpoint -TimeoutSec 10 -UseBasicParsing
    $contentType = $response.Headers["Content-Type"]

    if ($contentType -like "*application/json*") {
        Log-Success "Content-Type is correct: $contentType"
    } else {
        Log-Error "Content-Type is incorrect: $contentType"
    }
} catch {
    Log-Error "Failed to check Content-Type: $_"
}

# Summary
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "           Test Summary" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Tests Run:    $script:TestsRun"
Write-Host "Tests Passed: $script:TestsPassed" -ForegroundColor Green

if ($script:TestsFailed -gt 0) {
    Write-Host "Tests Failed: $script:TestsFailed" -ForegroundColor Red
    Write-Host ""
    Write-Host "❌ INTEGRATION TESTS FAILED" -ForegroundColor Red
    exit 1
} else {
    Write-Host "Tests Failed: 0"
    Write-Host ""
    Write-Host "✅ ALL INTEGRATION TESTS PASSED" -ForegroundColor Green
    exit 0
}
