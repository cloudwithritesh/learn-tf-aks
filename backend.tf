# backend.tf

# This file defines the resources required for Terraform remote state management.
# It should be applied *before* the main configuration.

# main.tf
# 2. Resource Group
# resource "azurerm_resource_group" "rg" {
#   name     = "rg-aks-terraform-nus"
#   location = "Southeast Asia" # Replace with your desired region
# }

# 1. Storage Account for Terraform State
# resource "azurerm_storage_account" "tfstate" {
#   name                     = "tfstateaksguide${random_string.suffix.result}" # Must be globally unique
#   resource_group_name      = azurerm_resource_group.rg.name
#   location                 = azurerm_resource_group.rg.location
#   account_tier             = "Standard"
#   account_replication_type = "LRS" # Local Redundancy is sufficient for state
#   min_tls_version          = "TLS1_2"

#   tags = {
#     environment = "tfstate"
#   }
# }

# # 2. Storage Container for Terraform State
# resource "azurerm_storage_container" "tfstate_container" {
#   name                  = "tfstate" # Container name for the state file
#   storage_account_id    = azurerm_storage_account.tfstate.id
#   container_access_type = "private"
# }

# # 3. Random string to ensure unique storage account name
# resource "random_string" "suffix" {
#   length  = 8
#   special = false
#   upper   = false
#   numeric = true
# }

# 4. Update the azurerm provider configuration to use the remote backend
# NOTE: This block must be manually copied into the main.tf file's terraform block

terraform {
  backend "azurerm" {
    resource_group_name  = "rg-aks-terraform-nus" # Must match the RG name
    storage_account_name = "tfstateaksguidenus"   # Must match the created SA name
    container_name       = "tfstate"
    key                  = "aks-deployment.tfstate"
  }
}

# az storage account create --name tfstateaksguidenus --resource-group rg-aks-terraform-nus --sku Standard_LRS --encryption-services blob  
# $ACCOUNT_KEY=$(az storage account keys list --resource-group rg-aks-terraform-nus --account-name tfstateaksguidenus --query '[0].value' -o tsv)
# az storage container create --name tfstate --account-name tfstateaksguidenus --account-key $ACCOUNT_KEY

# az ad sp create-for-rbac --name terraform-aks-demo-nus --role Contributor --scopes /subscriptions/151761fe-10ae-4c1c-9241-2e45cc18bd68 --output json