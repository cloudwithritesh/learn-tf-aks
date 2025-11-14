# variables.tf

variable "resource_group_name" {
  description = "The name of the resource group to create."
  type        = string
  default     = "rg-aks-terraform-nus"
}

variable "location" {
  description = "The Azure region where all resources will be created."
  type        = string
  default     = "Southeast Asia"
}

variable "cluster_name" {
  description = "The name of the AKS cluster."
  type        = string
  default     = "aks-terraform-cluster"
}

variable "vnet_address_space" {
  description = "The address space for the VNet."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "aks_subnet_address_prefix" {
  description = "The address prefix for the AKS subnet."
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "node_count" {
  description = "The number of nodes in the default node pool."
  type        = number
  default     = 2
}

variable "vm_size" {
  description = "The size of the Virtual Machine for the AKS nodes."
  type        = string
  default     = "Standard_DS2_v2"
}

variable "kubernetes_version" {
  description = "The Kubernetes version to use for the AKS cluster."
  type        = string
  default     = "1.28"
}
