# Automating AKS Deployments on Azure with Terraform: From Infrastructure to Workload

## I. Introduction
*   **A. The Challenge:** Manual infrastructure and application deployment complexity.
*   **B. The Solution:** Infrastructure as Code (IaC) with Terraform for Azure Kubernetes Service (AKS).
*   **C. Guide Objectives:** Provisioning the AKS cluster and deploying a sample workload.

## II. Prerequisites and Setup
*   **A. Tools Required:** Azure CLI, Terraform CLI, Kubectl.
*   **B. Azure Setup:** Service Principal or Managed Identity for Terraform authentication.
*   **C. Project Structure:** Recommended directory layout for the Terraform project.

### 1. Set Up Azure Storage for Terraform State

```bash
# Login to Azure
az login

# Set subscription ID
az account set --subscription <SUBSCRIPTION_ID>

# Create resource group
az group create --name tfstate-rg --location southeastasia

# Create storage account
az storage account create --name tfstate<UNIQUE_SUFFIX> --resource-group tfstate-rg --sku Standard_LRS --encryption-services blob

# Get storage account key
$ACCOUNT_KEY=$(az storage account keys list --resource-group tfstate-rg --account-name tfstate<UNIQUE_SUFFIX> --query '[0].value' -o tsv)
```

  *Run **`$ACCOUNT_KEY`** in terminal to confirm the key value output*

```bash
# Create blob container
az storage container create --name tfstate --account-name tfstate<UNIQUE_SUFFIX> --account-key $ACCOUNT_KEY
```
### 2. Create Service Principal for Terraform

```bash
# Create service principal and save output
az ad sp create-for-rbac --name terraform-aks-demo --role Contributor --scopes /subscriptions/<SUBSCRIPTION_ID> --output json
```

#### *copy the json Output from above to your favorite notepad or text editor and save it, we will need the key value <APP_ID> in next step*

```bash
# Add Storage Blob Data Contributor role for state management
az role assignment create --assignee-object-id <object_id_of_service_principal> --assignee-principal-type ServicePrincipal --role "Storage Blob Data Contributor" --scope /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/tfstate-rg/providers/Microsoft.Storage/storageAccounts/tfstate<UNIQUE_SUFFIX>
```

### 3. Set Environment Variables

```bash
# Use credentials from sp-credentials.json
  ## if using bash the set env as 'export'; if using cmd or powershell instead use '$' e.g. $ARM_CLIENT_ID
export ARM_CLIENT_ID="<service_principal_app_id>"
export ARM_CLIENT_SECRET="<service_principal_password>"
export ARM_TENANT_ID="<tenant_id>"
export ARM_SUBSCRIPTION_ID="<subscription_id>"
```

## III. Phase 1: Infrastructure Provisioning (AKS Cluster)
*   **A. Terraform Provider Configuration:** `azurerm` and `kubernetes`.
*   **B. Core Azure Resources:**
    *   Resource Group (`azurerm_resource_group`).
    *   Virtual Network and Subnets (`azurerm_virtual_network`, `azurerm_subnet`).
*   **C. AKS Cluster Configuration (`azurerm_kubernetes_cluster`):**
    *   Managed Identity setup.
    *   Node Pool configuration.
    *   Network configuration (e.g., CNI vs. Kubenet).
*   **D. Outputting Kubeconfig:** Extracting necessary information to connect to the cluster.

## IV. Phase 2: Workload Deployment (Sample Application)
*   **A. Connecting Terraform to AKS:** Using the `kubernetes` provider with the generated Kubeconfig.
*   **B. Sample Workload Definition (Nginx):**
    *   Kubernetes Deployment (`kubernetes_deployment`).
    *   Kubernetes Service (`kubernetes_service` - LoadBalancer type).
*   **C. Terraform Code for Workload:** HCL for Kubernetes resources.

## V. Execution and Validation
*   **A. Deployment Steps:** `terraform init`, `terraform plan`, `terraform apply`.
*   **B. Validation:** Using `kubectl` to check cluster and application status.
*   **C. Cleanup:** `terraform destroy`.

## VI. Best Practices and Next Steps
*   **A. State Management:** Using Azure Storage Backend.
*   **B. Modularity:** Using Terraform Modules.
*   **C. Security:** Secrets management (e.g., Azure Key Vault).
*   **D. Conclusion.**

## VII. References
*   (To be filled with sources from research phases)
