# Prerequisite Verification Script for AKS Demo
# Checks all required system tools are installed

$ErrorActionPreference = "Continue"

Write-Host "╔═══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   AKS Demo - Prerequisites Check                ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$MissingRequired = 0
$MissingOptional = 0

# Function to check command
function Check-Command {
    param(
        [string]$Command,
        [string]$Name,
        [bool]$Required,
        [scriptblock]$VersionCheck
    )

    $cmdExists = Get-Command $Command -ErrorAction SilentlyContinue

    if ($cmdExists) {
        if ($VersionCheck) {
            try {
                $version = & $VersionCheck
                Write-Host "✓ $Name`: $version" -ForegroundColor Green
            }
            catch {
                Write-Host "✓ $Name`: INSTALLED" -ForegroundColor Green
            }
        }
        else {
            Write-Host "✓ $Name`: INSTALLED" -ForegroundColor Green
        }
        return $true
    }
    else {
        if ($Required) {
            Write-Host "✗ $Name`: NOT INSTALLED (REQUIRED)" -ForegroundColor Red
            $script:MissingRequired++
        }
        else {
            Write-Host "ℹ $Name`: NOT INSTALLED (Optional)" -ForegroundColor Yellow
            $script:MissingOptional++
        }
        return $false
    }
}

Write-Host "Checking required tools..." -ForegroundColor Yellow
Write-Host ""

# Check Azure CLI
Check-Command -Command "az" -Name "Azure CLI" -Required $true -VersionCheck {
    (az --version 2>$null | Select-Object -First 1)
}

# Check Terraform
Check-Command -Command "terraform" -Name "Terraform" -Required $true -VersionCheck {
    (terraform --version 2>$null | Select-Object -First 1)
}

# Check kubectl
Check-Command -Command "kubectl" -Name "kubectl" -Required $true -VersionCheck {
    (kubectl version --client=true 2>$null | Select-Object -First 1)
}

# Check Helm (REQUIRED for new deployment)
Write-Host ""
$helmInstalled = Check-Command -Command "helm" -Name "Helm" -Required $true -VersionCheck {
    (helm version --short 2>$null)
}

if ($helmInstalled) {
    try {
        $helmVersion = helm version --short 2>$null
        if ($helmVersion -match "v3\.") {
            Write-Host "  ✓ Helm version is compatible (>= 3.0.0)" -ForegroundColor Green
        }
        else {
            Write-Host "  ⚠ Warning: Helm version may be incompatible (need >= 3.0.0)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  ⚠ Could not verify Helm version" -ForegroundColor Yellow
    }
}
else {
    Write-Host "  ⚠ CRITICAL: Helm is required for the new deployment method!" -ForegroundColor Red
    Write-Host "    Install from: https://helm.sh/docs/intro/install/" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Checking optional tools..." -ForegroundColor Yellow
Write-Host ""

# Check Docker
Check-Command -Command "docker" -Name "Docker" -Required $false -VersionCheck {
    (docker --version 2>$null)
}

# Check Python
Check-Command -Command "python" -Name "Python" -Required $false -VersionCheck {
    (python --version 2>$null)
}

# Check Git
Check-Command -Command "git" -Name "Git" -Required $false -VersionCheck {
    (git --version 2>$null)
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Azure authentication check
if (Get-Command az -ErrorAction SilentlyContinue) {
    Write-Host "Checking Azure authentication..." -ForegroundColor Yellow
    try {
        $account = az account show 2>$null | ConvertFrom-Json
        if ($account) {
            Write-Host "✓ Authenticated to Azure" -ForegroundColor Green
            Write-Host "  Account: $($account.user.name)" -ForegroundColor Gray
            Write-Host "  Subscription: $($account.name)" -ForegroundColor Gray
        }
        else {
            Write-Host "✗ Not authenticated to Azure" -ForegroundColor Red
            Write-Host "  Run: az login" -ForegroundColor Yellow
            $script:MissingRequired++
        }
    }
    catch {
        Write-Host "✗ Not authenticated to Azure" -ForegroundColor Red
        Write-Host "  Run: az login" -ForegroundColor Yellow
        $script:MissingRequired++
    }
    Write-Host ""
}

# Summary
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  Required tools missing: $MissingRequired" -ForegroundColor $(if ($MissingRequired -eq 0) { "Green" } else { "Red" })
Write-Host "  Optional tools missing: $MissingOptional" -ForegroundColor $(if ($MissingOptional -eq 0) { "Green" } else { "Yellow" })
Write-Host ""

if ($MissingRequired -eq 0) {
    Write-Host "✓ All required prerequisites are installed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Deploy: .\helm_deploy.ps1 -Environment dev" -ForegroundColor White
    Write-Host "  2. Or see: cat README.md" -ForegroundColor White
    Write-Host ""
    exit 0
}
else {
    Write-Host "✗ Missing $MissingRequired required tool(s)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Installation instructions:" -ForegroundColor Yellow
    Write-Host "  See SYSTEM_REQUIREMENTS.md for detailed installation guides" -ForegroundColor White
    Write-Host "  Or visit: https://github.com/usgrant4/aks-api-demo" -ForegroundColor White
    Write-Host ""
    Write-Host "Quick install (Windows):" -ForegroundColor Yellow
    Write-Host "  # Using Chocolatey" -ForegroundColor Gray
    Write-Host "  choco install azure-cli terraform kubernetes-cli kubernetes-helm" -ForegroundColor White
    Write-Host ""
    Write-Host "  # Or using winget" -ForegroundColor Gray
    Write-Host "  winget install Microsoft.AzureCLI" -ForegroundColor White
    Write-Host "  winget install Hashicorp.Terraform" -ForegroundColor White
    Write-Host "  winget install Kubernetes.kubectl" -ForegroundColor White
    Write-Host "  winget install Helm.Helm" -ForegroundColor White
    Write-Host ""
    exit 1
}
