# outputs.tf

output "resource_group_name" {
  description = "The name of the Resource Group where resources were deployed."
  value       = azurerm_resource_group.rg.name
}

output "aks_cluster_name" {
  description = "The name of the AKS cluster."
  value       = azurerm_kubernetes_cluster.aks.name
}

output "nginx_external_ip" {
  description = "The external IP address of the Nginx LoadBalancer service."
  value       = kubernetes_service.nginx_service.status[0].load_balancer[0].ingress[0].ip
}
