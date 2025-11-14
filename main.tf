# Dynamic lookup of supported Kubernetes versions for the region.
# If var.kubernetes_version is null, we will use the latest supported (non-preview) version.
data "azurerm_kubernetes_service_versions" "current" {
  location        = var.location
  include_preview = false
}
# 3. Virtual Network and Subnet for AKS
# Best practice is to deploy AKS into a custom VNet with Azure CNI
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-aks-nus"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = "subnet-aks"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]

  # Required for AKS to delegate control to the cluster
  # This property prevents the subnet from being used for other resources
  # enforce_private_link_endpoint_network_policies = false
  # enforce_private_link_service_network_policies  = false
}

# 4. Azure Kubernetes Service (AKS) Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-terraform-cluster"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "akstfnus"

  # Use SystemAssigned Managed Identity (Best Practice)
  identity {
    type = "SystemAssigned"
  }

  # Default Node Pool Configuration
  default_node_pool {
    name           = "systempool"
    node_count     = 2
    vm_size        = "Standard_DS2_v2"
    vnet_subnet_id = azurerm_subnet.aks_subnet.id
    # Required for Azure CNI
    os_disk_size_gb = 30
  }

  # Network Profile - Using Azure CNI (Advanced Networking)
  network_profile {
    network_plugin     = "azure"
    dns_service_ip     = "10.2.0.10"
    service_cidr       = "10.2.0.0/24"
    docker_bridge_cidr = "172.17.0.1/16"
  }

  # Kubernetes Version (dynamic). If the user provides a version via variable it is used; otherwise we fall back
  # to the latest supported non-preview version for the chosen region to avoid unsupported/LTS-only errors.
  # az aks get-versions --location "Southeast Asia" --output table
  kubernetes_version = "1.34.0"
}

# 5. Grant AKS Managed Identity Contributor Role on the VNet
# This is necessary for Azure CNI to manage network resources (e.g., IPs)
resource "azurerm_role_assignment" "aks_vnet_contributor" {
  scope                = azurerm_virtual_network.vnet.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

# 6. Configure the Kubernetes Provider to use the AKS cluster credentials
# This block is crucial for Phase 2 (Workload Deployment)
# Using the cluster resource directly instead of a data source to avoid localhost connection issues
provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.aks.kube_config.0.host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
}
