# Network Watcher Resources - Why They Persist

## The Issue

When you run `terraform destroy`, you'll notice that two resources remain:
- **Resource Group**: `NetworkWatcherRG`
- **Network Watcher**: `NetworkWatcher_<region>` (e.g., `NetworkWatcher_eastus`)

## Why This Happens

### 1. **Automatic Creation by Azure**
Network Watcher resources are **automatically created by Azure** when you deploy certain networking resources, particularly:
- AKS clusters with Azure CNI networking
- Virtual Networks with monitoring enabled
- Azure Firewall
- VPN Gateways

In this project, the AKS cluster configuration triggers this:

```hcl
# From terraform/main.tf
network_profile {
  network_plugin    = "azure"      # ← Triggers Network Watcher creation
  load_balancer_sku = "standard"
  network_policy    = "azure"
}
```

### 2. **Not Managed by Terraform**
- Network Watcher is created by Azure's control plane, **not** by your Terraform code
- It never appears in your `terraform.tfstate` file
- Terraform has no knowledge of these resources
- Therefore, `terraform destroy` cannot remove them

### 3. **Singleton per Region**
Network Watcher is designed as a **singleton** resource:
- One Network Watcher per region, per subscription
- Shared by all networking resources in that region
- Acts as a shared service for monitoring and diagnostics

### 4. **Azure's Design Philosophy**
Azure intentionally keeps Network Watcher around because:
- **Shared Resource**: Other resources in the region might still need it
- **Minimal Cost**: Near-zero cost when not actively monitoring (only storage costs for logs if enabled)
- **Avoid Conflicts**: Deleting and recreating can cause conflicts if multiple resources use it
- **Persistence**: Azure assumes you want monitoring capability available

## Cost Implications

### Network Watcher Costs
- **The resource itself**: FREE (no charge for the Network Watcher instance)
- **Traffic Analytics**: Only if enabled (not used in this project)
- **NSG Flow Logs**: Only if configured (not used in this project)
- **Connection Monitor**: Only if actively monitoring (not used in this project)

**Bottom line**: Leaving NetworkWatcherRG has **~$0/month cost** for this project.

## Solutions

### Option 1: Use the Cleanup Script (Recommended)
We've provided cleanup scripts that handle this properly:

**PowerShell:**
```powershell
.\cleanup.ps1
```

**Bash:**
```bash
./cleanup.sh
```

These scripts:
1. Run `terraform destroy`
2. Detect the Network Watcher resources
3. **Prompt you** before deletion (safe for shared environments)
4. Clean up Terraform state files
5. Remove kubectl config entries

### Option 2: Manual Cleanup
If you prefer manual cleanup:

```bash
# 1. Destroy Terraform resources first
cd terraform
terraform destroy -auto-approve

# 2. Delete Network Watcher (replace <region> with your region, e.g., eastus)
az network watcher delete \
  --name NetworkWatcher_<region> \
  --resource-group NetworkWatcherRG

# 3. Delete the resource group
az group delete \
  --name NetworkWatcherRG \
  --yes \
  --no-wait
```

### Option 3: Leave It (Safe for Personal Subscriptions)
If this is your personal Azure subscription:
- **It's safe to leave it**
- Near-zero cost
- Will be reused if you deploy AKS again
- No security concerns

### Option 4: Import into Terraform (Advanced)
For production environments where you want Terraform to manage everything:

```hcl
# Add to terraform/main.tf
resource "azurerm_network_watcher" "main" {
  name                = "NetworkWatcher_${var.location}"
  location            = var.location
  resource_group_name = azurerm_resource_group.network_watcher.name
}

resource "azurerm_resource_group" "network_watcher" {
  name     = "NetworkWatcherRG"
  location = var.location
}
```

Then import the existing resources:
```bash
terraform import azurerm_resource_group.network_watcher /subscriptions/<sub-id>/resourceGroups/NetworkWatcherRG
terraform import azurerm_network_watcher.main /subscriptions/<sub-id>/resourceGroups/NetworkWatcherRG/providers/Microsoft.Network/networkWatchers/NetworkWatcher_eastus
```

**Warning**: This approach has downsides:
- Network Watcher might be used by other projects
- Deleting it could break other resources in the region
- Adds complexity to Terraform state management

## Best Practices

### For Demo/Learning Environments
✅ Use the cleanup scripts (`cleanup.ps1` or `cleanup.sh`)
✅ They prompt before deleting shared resources
✅ Complete cleanup for a fresh slate

### For Shared/Team Environments
⚠️ **Do NOT delete Network Watcher**
- Other team members' resources might depend on it
- Check with team before deleting
- Use `terraform destroy` only

### For Production Environments
⚠️ **Carefully consider**
- Network Watcher might be used by multiple applications
- Deleting could impact monitoring and diagnostics
- Consider importing into Terraform for lifecycle management
- Coordinate with your platform/infrastructure team

## Verification

After cleanup, verify all resources are gone:

```bash
# List all resource groups
az group list --query "[].name" -o table

# Should NOT see:
# - NetworkWatcherRG
# - <your-project>-liatrio-demo-rg
```

## Alternative: Prevent Network Watcher Creation

If you want to avoid Network Watcher creation entirely, you'd need to:
1. Use **kubenet** instead of Azure CNI (less feature-rich)
2. Manually create and manage Network Watcher
3. Use a different cloud provider 😄

**Not recommended** - Azure CNI provides better networking capabilities for Kubernetes.

## Summary

| Question | Answer |
|----------|--------|
| Why doesn't `terraform destroy` remove it? | It's created by Azure, not Terraform |
| Is it safe to delete? | Yes, if no other resources need it |
| Does it cost money? | ~$0 for this project |
| Should I delete it? | Use cleanup scripts for demos; check with team for shared environments |
| Will it come back? | Yes, when you deploy AKS with Azure CNI again |

## Related Resources

- [Azure Network Watcher Documentation](https://learn.microsoft.com/en-us/azure/network-watcher/)
- [Azure Network Watcher Pricing](https://azure.microsoft.com/en-us/pricing/details/network-watcher/)
- [Terraform azurerm_network_watcher](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_watcher)
