#!/bin/bash
set -e

echo "=========================================="
echo "  AKS Demo - Complete Cleanup"
echo "=========================================="
echo ""

# Step 1: Get Terraform outputs before destroying
echo "1️⃣ Gathering resource information..."
cd ~/repos/aks-demo/terraform

if [ -f "terraform.tfstate" ]; then
    RG=$(terraform output -raw resource_group_name 2>/dev/null || echo "")
    if [ -n "$RG" ]; then
        LOCATION=$(az group show -n "$RG" --query location -o tsv 2>/dev/null || echo "")
        echo "   Resource Group: $RG"
        echo "   Location: $LOCATION"
    fi
else
    echo "   ⚠️ No Terraform state found - skipping Terraform destroy"
    RG=""
fi
echo ""

# Step 2: Destroy Terraform resources
if [ -n "$RG" ]; then
    echo "2️⃣ Destroying Terraform resources..."
    terraform destroy -auto-approve
    echo "   ✅ Terraform resources destroyed"
    echo ""
else
    echo "2️⃣ Skipping Terraform destroy (no state)"
    echo ""
fi

# Step 3: Clean up Network Watcher resources
echo "3️⃣ Cleaning up Network Watcher resources..."

# Check if NetworkWatcherRG exists
if az group exists -n NetworkWatcherRG 2>/dev/null | grep -q "true"; then
    echo "   Found NetworkWatcherRG"

    # Get location if we don't have it
    if [ -z "$LOCATION" ] && [ -n "$RG" ]; then
        LOCATION=$(az group show -n "$RG" --query location -o tsv 2>/dev/null || echo "")
    fi

    if [ -n "$LOCATION" ]; then
        NW_NAME="NetworkWatcher_$LOCATION"
        echo "   Checking for Network Watcher: $NW_NAME"

        # Check if this Network Watcher exists
        if az network watcher show -n "$NW_NAME" -g NetworkWatcherRG &>/dev/null; then
            echo "   ⚠️ Network Watcher found: $NW_NAME"
            echo ""
            echo "   ⚠️ WARNING: Network Watcher is a shared Azure resource"
            echo "   Other resources in $LOCATION might still need it."
            echo ""

            read -p "   Delete Network Watcher and NetworkWatcherRG? (y/N): " -r
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "   Deleting Network Watcher: $NW_NAME..."
                az network watcher delete -n "$NW_NAME" -g NetworkWatcherRG 2>/dev/null || true

                echo "   Deleting NetworkWatcherRG..."
                az group delete -n NetworkWatcherRG --yes --no-wait
                echo "   ✅ Network Watcher cleanup initiated"
            else
                echo "   ⏭️ Skipping Network Watcher deletion"
                echo "   To delete manually later, run:"
                echo "      az network watcher delete -n $NW_NAME -g NetworkWatcherRG"
                echo "      az group delete -n NetworkWatcherRG --yes"
            fi
        else
            echo "   ℹ️ Network Watcher not found for this region"
        fi
    else
        echo "   ℹ️ Cannot determine location - skipping Network Watcher deletion"
        echo "   To delete manually, run:"
        echo "      az group delete -n NetworkWatcherRG --yes"
    fi
else
    echo "   ✅ NetworkWatcherRG does not exist"
fi
echo ""

# Step 4: Clean up local Kubernetes config
echo "4️⃣ Cleaning up local Kubernetes config..."
if [ -n "$RG" ]; then
    AKS="$RG-aks"
    kubectl config delete-context "$AKS" 2>/dev/null || true
    kubectl config delete-cluster "$AKS" 2>/dev/null || true
    echo "   ✅ Kubernetes config cleaned"
else
    echo "   ⏭️ Skipping (no resource group info)"
fi
echo ""

# Step 5: Clean up Terraform state
echo "5️⃣ Cleaning up Terraform state files..."
cd ~/repos/aks-demo/terraform

for file in terraform.tfstate terraform.tfstate.backup .terraform.lock.hcl; do
    if [ -f "$file" ]; then
        rm -f "$file"
        echo "   Deleted: $file"
    fi
done

if [ -d ".terraform" ]; then
    rm -rf .terraform
    echo "   Deleted: .terraform/"
fi
echo "   ✅ Local state cleaned"
echo ""

echo "=========================================="
echo "  ✅ CLEANUP COMPLETE!"
echo "=========================================="
echo ""
echo "🧹 All resources have been cleaned up"
echo ""
echo "💡 Tips:"
echo "   • Verify in Azure Portal: portal.azure.com"
echo "   • Check for orphaned resources:"
echo "     az group list --query \"[].name\" -o table"
echo "   • To redeploy: ./deploy.sh"
echo ""
