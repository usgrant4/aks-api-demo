output "resource_group_name" {
  value       = azurerm_resource_group.rg.name
  description = "The name of the resource group"
}

output "acr_login_server" {
  value       = azurerm_container_registry.acr.login_server
  description = "The login server URL for ACR"
}

output "aks_name" {
  value       = azurerm_kubernetes_cluster.aks.name
  description = "The name of the AKS cluster"
}

output "kube_config" {
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
  description = "Raw Kubernetes config"
}

output "instructions" {
  value = <<EOT
After apply:
1) az aks get-credentials -g ${azurerm_resource_group.rg.name} -n ${azurerm_kubernetes_cluster.aks.name}
2) az acr login --name ${azurerm_container_registry.acr.name}
3) kubectl apply -f kubernetes/deployment.yaml
EOT
}
