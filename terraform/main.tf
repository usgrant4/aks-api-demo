terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.116"
    }
  }

  backend "azurerm" {
    # Backend configuration provided via environment variables:
    # ARM_BACKEND_RESOURCE_GROUP, ARM_BACKEND_STORAGE_ACCOUNT,
    # ARM_BACKEND_CONTAINER, ARM_BACKEND_KEY
    # This eliminates hardcoded duplication across files
  }
}

provider "azurerm" {
  features {}
}

locals {
  name = "${var.prefix}-liatrio-demo"
  common_tags = {
    project     = "liatrio-devops-demo"
    managed_by  = "terraform"
    environment = "demo"
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "${local.name}-rg"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_container_registry" "acr" {
  name                = replace("${local.name}acr", "-", "")
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = false

  tags = local.common_tags
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${local.name}-aks"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "${local.name}-dns"
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name       = "system"
    node_count = var.node_count
    vm_size    = var.node_vm_size
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    network_policy    = "azure"
  }

  tags = local.common_tags

  lifecycle {
    ignore_changes = [
      default_node_pool[0].node_count
    ]
  }
}

# Grant AKS kubelet permission to pull from ACR
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

output "resource_group_name" {
  value       = azurerm_resource_group.rg.name
  description = "The name of the resource group"
}

output "acr_login_server" {
  value       = azurerm_container_registry.acr.login_server
  description = "The login server URL for the container registry"
}

output "aks_name" {
  value       = azurerm_kubernetes_cluster.aks.name
  description = "The name of the AKS cluster"
}

output "kube_config" {
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
  description = "Raw Kubernetes config for connecting to the cluster"
}

output "aks_fqdn" {
  value       = azurerm_kubernetes_cluster.aks.fqdn
  description = "The FQDN of the AKS cluster"
}

output "aks_node_resource_group" {
  value       = azurerm_kubernetes_cluster.aks.node_resource_group
  description = "The auto-generated resource group containing AKS cluster resources"
}
