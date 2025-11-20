$ErrorActionPreference = "Stop"

Write-Host "╔═══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║   AKS Demo - Complete Cleanup               ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Step 1: Get Terraform outputs before destroying
Write-Host "1️⃣ Gathering resource information..." -ForegroundColor Yellow
cd ~/repos/aks-demo/terraform

if (Test-Path "terraform.tfstate") {
    $RG = terraform output -raw resource_group_name 2>$null
    $LOCATION = (az group show -n $RG --query location -o tsv 2>$null)
    Write-Host "   Resource Group: $RG" -ForegroundColor White
    Write-Host "   Location: $LOCATION" -ForegroundColor White
}
else {
    Write-Host "   ⚠️ No Terraform state found - skipping Terraform destroy" -ForegroundColor Yellow
    $RG = $null
}
Write-Host ""

# Step 2: Destroy Terraform resources
if ($RG) {
    Write-Host "2️⃣ Destroying Terraform resources..." -ForegroundColor Yellow
    terraform destroy -auto-approve
    Write-Host "   ✅ Terraform resources destroyed" -ForegroundColor Green
    Write-Host ""
}
else {
    Write-Host "2️⃣ Skipping Terraform destroy (no state)" -ForegroundColor Yellow
    Write-Host ""
}

# Step 3: Clean up Network Watcher resources
Write-Host "3️⃣ Cleaning up Network Watcher resources..." -ForegroundColor Yellow

# Check if NetworkWatcherRG exists
$nwRG = az group exists -n NetworkWatcherRG 2>$null
if ($nwRG -eq "true") {
    Write-Host "   Found NetworkWatcherRG" -ForegroundColor White

    # Get location from Network Watcher if we don't have it
    if (-not $LOCATION -and $RG) {
        $LOCATION = (az group show -n $RG --query location -o tsv 2>$null)
    }

    if ($LOCATION) {
        $nwName = "NetworkWatcher_$LOCATION"
        Write-Host "   Checking for Network Watcher: $nwName" -ForegroundColor White

        # Check if this Network Watcher exists
        $nwExists = az network watcher show -n $nwName -g NetworkWatcherRG 2>$null
        if ($nwExists) {
            Write-Host "   ⚠️ Network Watcher found: $nwName" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "   ⚠️ WARNING: Network Watcher is a shared Azure resource" -ForegroundColor Yellow
            Write-Host "   Other resources in $LOCATION might still need it." -ForegroundColor Yellow
            Write-Host ""

            $response = Read-Host "   Delete Network Watcher and NetworkWatcherRG? (y/N)"
            if ($response -eq 'y' -or $response -eq 'Y') {
                Write-Host "   Deleting Network Watcher: $nwName..." -ForegroundColor Yellow
                az network watcher delete -n $nwName -g NetworkWatcherRG 2>$null

                Write-Host "   Deleting NetworkWatcherRG..." -ForegroundColor Yellow
                az group delete -n NetworkWatcherRG --yes --no-wait
                Write-Host "   ✅ Network Watcher cleanup initiated" -ForegroundColor Green
            }
            else {
                Write-Host "   ⏭️ Skipping Network Watcher deletion" -ForegroundColor Cyan
                Write-Host "   To delete manually later, run:" -ForegroundColor White
                Write-Host "      az network watcher delete -n $nwName -g NetworkWatcherRG" -ForegroundColor Gray
                Write-Host "      az group delete -n NetworkWatcherRG --yes" -ForegroundColor Gray
            }
        }
        else {
            Write-Host "   ℹ️ Network Watcher not found for this region" -ForegroundColor Cyan
        }
    }
    else {
        Write-Host "   ℹ️ Cannot determine location - skipping Network Watcher deletion" -ForegroundColor Cyan
        Write-Host "   To delete manually, run:" -ForegroundColor White
        Write-Host "      az group delete -n NetworkWatcherRG --yes" -ForegroundColor Gray
    }
}
else {
    Write-Host "   ✅ NetworkWatcherRG does not exist" -ForegroundColor Green
}
Write-Host ""

# Step 4: Clean up local Kubernetes config
Write-Host "4️⃣ Cleaning up local Kubernetes config..." -ForegroundColor Yellow
if ($RG) {
    $AKS = "$RG-aks"
    kubectl config delete-context $AKS 2>$null
    kubectl config delete-cluster $AKS 2>$null
    Write-Host "   ✅ Kubernetes config cleaned" -ForegroundColor Green
}
else {
    Write-Host "   ⏭️ Skipping (no resource group info)" -ForegroundColor Cyan
}
Write-Host ""

# Step 5: Clean up Terraform state
Write-Host "5️⃣ Cleaning up Terraform state files..." -ForegroundColor Yellow
cd ~/repos/aks-demo/terraform
if (Test-Path "terraform.tfstate") {
    Remove-Item -Force terraform.tfstate
    Write-Host "   Deleted: terraform.tfstate" -ForegroundColor Gray
}
if (Test-Path "terraform.tfstate.backup") {
    Remove-Item -Force terraform.tfstate.backup
    Write-Host "   Deleted: terraform.tfstate.backup" -ForegroundColor Gray
}
if (Test-Path ".terraform.lock.hcl") {
    Remove-Item -Force .terraform.lock.hcl
    Write-Host "   Deleted: .terraform.lock.hcl" -ForegroundColor Gray
}
if (Test-Path ".terraform") {
    Remove-Item -Recurse -Force .terraform
    Write-Host "   Deleted: .terraform/" -ForegroundColor Gray
}
Write-Host "   ✅ Local state cleaned" -ForegroundColor Green
Write-Host ""

Write-Host "╔═══════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║          CLEANUP COMPLETE!                        ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "🧹 All resources have been cleaned up" -ForegroundColor Cyan
Write-Host ""
Write-Host "💡 Tips:" -ForegroundColor Yellow
Write-Host "   • Verify in Azure Portal: portal.azure.com" -ForegroundColor White
Write-Host "   • Check for orphaned resources:" -ForegroundColor White
Write-Host "     az group list --query \"[].name\" -o table" -ForegroundColor Gray
Write-Host "   • To redeploy: .\final_deploy.ps1" -ForegroundColor White
Write-Host ""
