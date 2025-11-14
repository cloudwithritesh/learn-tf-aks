#!/bin/bash

# ============================================================================
# AKS Terraform Deployment Script
# ============================================================================
# This script automates the deployment of the AKS cluster using Terraform.
# Usage: ./deploy.sh [init|plan|apply|destroy|clean]
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed"
        exit 1
    fi
    print_success "Terraform found: $(terraform version -json | grep terraform_version | cut -d'"' -f4)"
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed"
        exit 1
    fi
    print_success "Azure CLI found: $(az version -o json | grep '"azure-cli"' | cut -d'"' -f4)"
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_warning "kubectl is not installed (optional for deployment)"
    else
        print_success "kubectl found: $(kubectl version --client -o json | grep gitVersion | cut -d'"' -f4)"
    fi
    
    # Check Azure login
    if ! az account show &> /dev/null; then
        print_warning "Not logged into Azure. Running 'az login'..."
        az login
    fi
    print_success "Azure authentication verified"
}

# Initialize Terraform
terraform_init() {
    print_header "Initializing Terraform"
    terraform init
    print_success "Terraform initialized"
}

# Plan deployment
terraform_plan() {
    print_header "Planning Terraform Deployment"
    terraform plan -out=tfplan
    print_success "Terraform plan created: tfplan"
}

# Apply deployment
terraform_apply() {
    print_header "Applying Terraform Configuration"
    
    if [ ! -f tfplan ]; then
        print_warning "No tfplan file found. Running terraform plan first..."
        terraform_plan
    fi
    
    terraform apply tfplan
    print_success "Terraform apply completed"
    
    # Display outputs
    print_header "Deployment Outputs"
    terraform output
    
    # Configure kubectl
    print_info "Configuring kubectl..."
    RESOURCE_GROUP=$(terraform output -raw resource_group_name)
    CLUSTER_NAME=$(terraform output -raw aks_cluster_name)
    
    az aks get-credentials \
        --resource-group "$RESOURCE_GROUP" \
        --name "$CLUSTER_NAME" \
        --overwrite-existing
    
    print_success "kubectl configured successfully"
    
    # Verify cluster
    print_info "Verifying cluster..."
    kubectl cluster-info
    kubectl get nodes
}

# Destroy deployment
terraform_destroy() {
    print_header "Destroying Terraform Resources"
    print_warning "This will delete all resources created by Terraform!"
    
    read -p "Are you sure you want to destroy? (yes/no): " -r
    echo
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        terraform destroy
        print_success "Terraform destroy completed"
    else
        print_info "Destroy cancelled"
    fi
}

# Clean up local files
terraform_clean() {
    print_header "Cleaning Up Local Files"
    
    rm -rf .terraform
    rm -f .terraform.lock.hcl
    rm -f tfplan
    rm -f terraform.tfstate*
    
    print_success "Local files cleaned up"
    print_warning "State files have been deleted. Remote state (if configured) is not affected."
}

# Show usage
show_usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  init       Initialize Terraform"
    echo "  plan       Plan the deployment"
    echo "  apply      Apply the deployment (runs plan first if needed)"
    echo "  destroy    Destroy all resources"
    echo "  clean      Clean up local Terraform files"
    echo "  help       Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 init       # Initialize Terraform"
    echo "  $0 plan       # Plan the deployment"
    echo "  $0 apply      # Apply the deployment"
    echo "  $0 destroy    # Destroy all resources"
}

# Main script logic
main() {
    case "${1:-help}" in
        init)
            check_prerequisites
            terraform_init
            ;;
        plan)
            check_prerequisites
            terraform_plan
            ;;
        apply)
            check_prerequisites
            terraform_apply
            ;;
        destroy)
            check_prerequisites
            terraform_destroy
            ;;
        clean)
            terraform_clean
            ;;
        help)
            show_usage
            ;;
        *)
            print_error "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
