# Automating AKS Deployments on Azure with Terraform: From Infrastructure to Workload

By **youtube.com/@cloudwithritesh**

## I. Introduction

The adoption of **Azure Kubernetes Service (AKS)** has streamlined the process of deploying and managing containerized applications on Microsoft Azure. However, manually provisioning the underlying cloud infrastructure and then deploying the application workload remains a complex, error-prone, and time-consuming task. This guide addresses that challenge by demonstrating a complete end-to-end automation solution using **Terraform**, the industry-standard tool for Infrastructure as Code (IaC).

Our objective is to provision the entire AKS environment—including the virtual network, subnets, and the cluster itself—and subsequently deploy a sample application workload, all within a single, unified Terraform configuration. This approach ensures repeatability, consistency, and version control for both your infrastructure and your application deployment.

## II. Prerequisites and Setup

To follow this guide, you will need the following tools installed and configured:

1.  **Azure CLI:** For authenticating with Azure (`az login`).
2.  **Terraform CLI:** For executing the IaC plan.
3.  **kubectl:** For validating the final deployment.

### Project Structure

We will use a simple, modular project structure to separate the infrastructure and workload definitions:

```bash
aks_terraform_guide/
├── providers.tf    # Provider configuration
├── main.tf         # Infrastructure (Resource Group, VNet, AKS)
├── variables.tf    # Input variables for customization
├── workload.tf     # Kubernetes Workload (Deployment, Service)
└── outputs.tf      # (To be created) Outputs like the Load Balancer IP
```

## III. Phase 1: Infrastructure Provisioning (AKS Cluster)

The first phase focuses on defining the core Azure resources using the `azurerm` provider.

### A. Provider and Backend Configuration

The `main.tf` file begins by defining the required providers: `azurerm` for the cloud infrastructure and `kubernetes` for the application workload.

```terraform
# main.tf

# 1. Configure the Azure Provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

# Configure the Azure Provider
# Authentication is assumed to be handled by Azure CLI (az login) or Environment Variables
provider "azurerm" {
  features {}
}
```

> **Best Practice: State Management**
> For production environments, it is critical to configure a remote backend, such as an Azure Storage Account, to securely store the Terraform state file. This enables collaboration and prevents state corruption.

### B. Core Azure Resources: Network and Resource Group

We define the foundational resources: a Resource Group to contain all assets, and a Virtual Network (VNet) with a dedicated Subnet for the AKS nodes. Using a custom VNet is a best practice for production deployments, enabling advanced networking features like **Azure CNI** [1].

```terraform
# main.tf (continued)

# 2. Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# 3. Virtual Network and Subnet for AKS
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-aks-example"
  address_space       = var.vnet_address_space
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = "subnet-aks"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.aks_subnet_address_prefix

  # Required for AKS to delegate control to the cluster
  enforce_private_link_endpoint_network_policies = false
  enforce_private_link_service_network_policies  = false
}
```

### C. AKS Cluster Configuration

The `azurerm_kubernetes_cluster` resource is the core of the infrastructure. We configure it to use a **System-Assigned Managed Identity** for secure interaction with other Azure services and specify the custom VNet subnet for the node pool.

```terraform
# main.tf (continued)

# 4. Azure Kubernetes Service (AKS) Cluster
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "akstfexample"

  # Use SystemAssigned Managed Identity (Best Practice)
  identity {
    type = "SystemAssigned"
  }

  # Default Node Pool Configuration
  default_node_pool {
    name                 = "systempool"
    node_count           = var.node_count
    vm_size              = var.vm_size
    vnet_subnet_id       = azurerm_subnet.aks_subnet.id
    # Required for Azure CNI
    os_disk_size_gb      = 30
  }

  # Network Profile - Using Azure CNI (Advanced Networking)
  network_profile {
    network_plugin     = "azure"
    dns_service_ip     = "10.2.0.10"
    service_cidr       = "10.2.0.0/24"
    docker_bridge_cidr = "172.17.0.1/16"
  }

  # Kubernetes Version
  kubernetes_version = var.kubernetes_version
}

# 5. Grant AKS Managed Identity Contributor Role on the VNet
# This is necessary for Azure CNI to manage network resources (e.g., IPs)
resource "azurerm_role_assignment" "aks_vnet_contributor" {
  scope                = azurerm_virtual_network.vnet.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}
```

### D. Connecting the Kubernetes Provider

To deploy the workload in the next phase, the `kubernetes` provider needs the cluster's credentials (kubeconfig). We use a `data` source to retrieve this information after the cluster is created and configure the `kubernetes` provider dynamically.

```terraform
# main.tf (continued)

# 6. Configure the Kubernetes Provider to use the AKS cluster credentials
data "azurerm_kubernetes_cluster" "aks" {
  name                = azurerm_kubernetes_cluster.aks.name
  resource_group_name = azurerm_resource_group.rg.name
  depends_on          = [azurerm_kubernetes_cluster.aks]
}

provider "kubernetes" {
  host                   = data.azurerm_kubernetes_cluster.aks.kube_config.0.host
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
}
```

## IV. Phase 2: Workload Deployment (Sample Application)

With the `kubernetes` provider configured, we can now define Kubernetes resources directly in HCL using the `workload.tf` file.

### A. Nginx Deployment

We define a simple Nginx deployment with two replicas.

```terraform
# workload.tf

# 1. Kubernetes Deployment for Nginx
resource "kubernetes_deployment" "nginx" {
  metadata {
    name = "nginx-deployment"
    labels = {
      app = "nginx"
    }
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "nginx"
      }
    }
    template {
      metadata {
        labels = {
          app = "nginx"
        }
      }
      spec {
        container {
          name  = "nginx"
          image = "nginx:latest"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}
```

### B. LoadBalancer Service

To expose the Nginx application to the internet, we create a Kubernetes Service of type `LoadBalancer`. Azure will automatically provision an Azure Load Balancer and assign a public IP address to it.

```terraform
# workload.tf (continued)

# 2. Kubernetes Service (LoadBalancer) to expose Nginx
resource "kubernetes_service" "nginx_service" {
  metadata {
    name = "nginx-service"
  }
  spec {
    selector = {
      app = kubernetes_deployment.nginx.metadata[0].labels.app
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "LoadBalancer"
  }
}
```

## V. Execution and Validation

### A. Deployment Steps

Assuming you have authenticated with Azure CLI (`az login`), the deployment process is standard:

1.  **Initialize Terraform:** Downloads providers and initializes the working directory.
    ```bash
    terraform init
    ```
2.  **Review the Plan:** Shows all resources that will be created, updated, or destroyed.
    ```bash
    terraform plan
    ```
3.  **Apply the Configuration:** Executes the plan, provisioning the infrastructure and deploying the workload.
    ```bash
    terraform apply --auto-approve
    ```

### B. Validation

After the apply is complete, you can validate the deployment using `kubectl`. First, retrieve the kubeconfig file:

```bash
az aks get-credentials --resource-group rg-aks-terraform-example --name aks-terraform-cluster --overwrite-existing
```

Then, check the status of the deployment and service:

```bash
# Check the Nginx pods
kubectl get pods

# Check the LoadBalancer service and get the External IP
kubectl get service nginx-service
```

The output of the service command will show the external IP address. Navigating to this IP in a web browser will display the Nginx welcome page, confirming the end-to-end automation was successful.

### C. Cleanup

To destroy all resources created by this guide, run:

```bash
terraform destroy --auto-approve
```

## VI. Best Practices and Next Steps

| Area | Best Practice | Terraform Implementation |
| :--- | :--- | :--- |
| **State Management** | Use a remote backend (e.g., Azure Storage) for state locking and collaboration. | Configure the `backend "azurerm"` block in `main.tf`. |
| **Modularity** | Encapsulate complex resource definitions into reusable modules. | Create a dedicated `modules/aks` directory for the cluster definition. |
| **Security** | Use Azure Key Vault to manage sensitive data (e.g., database connection strings) and integrate it with AKS via the CSI Secret Store driver. | Use the `azurerm_key_vault` and `azurerm_key_vault_secret` resources. |
| **Workload Management** | For complex applications, prefer Helm or Kustomize for workload deployment over raw `kubernetes_*` resources in Terraform. | Use the `helm_release` resource in Terraform. |

## VII. References

[1] Microsoft Azure. *Azure CNI networking in Azure Kubernetes Service (AKS)*. [https://learn.microsoft.com/en-us/azure/aks/concepts-network#azure-cni-advanced-networking](https://learn.microsoft.com/en-us/azure/aks/concepts-network#azure-cni-advanced-networking)
[2] HashiCorp. *azurerm_kubernetes_cluster*. [https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster)
[3] HashiCorp. *kubernetes_deployment*. [https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/deployment](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/deployment)
[4] HashiCorp. *kubernetes_service*. [https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service)
