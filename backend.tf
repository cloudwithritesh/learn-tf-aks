# backend.tf

# This file defines the resources required for Terraform remote state management.
# It should be applied *before* the main configuration.

# 1. Storage Account for Terraform State
resource "azurerm_storage_account" "tfstate" {
  name                     = "tfstateaksguide${random_string.suffix.result}" # Must be globally unique
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS" # Local Redundancy is sufficient for state
  min_tls_version          = "TLS1_2"

  tags = {
    environment = "tfstate"
  }
}

# 2. Storage Container for Terraform State
resource "azurerm_storage_container" "tfstate_container" {
  name                  = "tfstate" # Container name for the state file
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"
}

# 3. Random string to ensure unique storage account name
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
  numeric = true
}

# 4. Update the azurerm provider configuration to use the remote backend
# NOTE: This block must be manually copied into the main.tf file's terraform block
/*
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-aks-terraform-example" # Must match the RG name
    storage_account_name = "tfstateaksguide<unique_suffix>" # Must match the created SA name
    container_name       = "tfstate"
    key                  = "aks-deployment.tfstate"
  }
}
*/
