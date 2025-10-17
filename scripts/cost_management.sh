#!/bin/bash
# Cost management utilities for Liatrio Demo
# Provides commands to reduce Azure costs when not using the demo

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${SCRIPT_DIR}/../terraform"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to get Terraform outputs
get_tf_output() {
    cd "$TERRAFORM_DIR"
    terraform output -raw "$1" 2>/dev/null || echo ""
}

# Function: Scale AKS to zero nodes
scale_down() {
    log_info "Scaling AKS cluster to zero nodes..."

    RG=$(get_tf_output resource_group_name)
    AKS=$(get_tf_output aks_name)

    if [ -z "$RG" ] || [ -z "$AKS" ]; then
        log_error "Cannot find resource group or AKS cluster name"
        log_info "Make sure Terraform has been applied"
        exit 1
    fi

    log_info "Resource Group: $RG"
    log_info "AKS Cluster: $AKS"

    # Get current node count
    CURRENT_COUNT=$(az aks nodepool show -g "$RG" --cluster-name "$AKS" -n system --query count -o tsv)
    log_info "Current node count: $CURRENT_COUNT"

    if [ "$CURRENT_COUNT" = "0" ]; then
        log_success "Cluster is already scaled to zero"
        return 0
    fi

    # Scale to zero
    log_info "Scaling node pool to 0..."
    az aks nodepool scale \
        --resource-group "$RG" \
        --cluster-name "$AKS" \
        --name system \
        --node-count 0

    log_success "Cluster scaled to zero nodes"
    log_info "Cost savings: ~\$35/month while scaled down"
    log_info "Run 'bash cost_management.sh scale-up' to restore"
}

# Function: Scale AKS back to one node
scale_up() {
    log_info "Scaling AKS cluster to one node..."

    RG=$(get_tf_output resource_group_name)
    AKS=$(get_tf_output aks_name)

    if [ -z "$RG" ] || [ -z "$AKS" ]; then
        log_error "Cannot find resource group or AKS cluster name"
        exit 1
    fi

    # Get current node count
    CURRENT_COUNT=$(az aks nodepool show -g "$RG" --cluster-name "$AKS" -n system --query count -o tsv)
    log_info "Current node count: $CURRENT_COUNT"

    if [ "$CURRENT_COUNT" != "0" ]; then
        log_success "Cluster already has $CURRENT_COUNT node(s)"
        return 0
    fi

    # Scale to one
    log_info "Scaling node pool to 1..."
    az aks nodepool scale \
        --resource-group "$RG" \
        --cluster-name "$AKS" \
        --name system \
        --node-count 1

    log_success "Cluster scaled to one node"
    log_info "Waiting for node to be ready..."

    # Wait for node
    az aks get-credentials -g "$RG" -n "$AKS" --overwrite-existing >/dev/null 2>&1
    kubectl wait --for=condition=Ready nodes --all --timeout=300s

    log_success "Node is ready. You can now deploy applications."
}

# Function: Show current costs
show_costs() {
    log_info "Fetching current Azure costs..."

    RG=$(get_tf_output resource_group_name)

    if [ -z "$RG" ]; then
        log_error "Cannot find resource group name"
        exit 1
    fi

    # Get resource group ID
    RG_ID=$(az group show -n "$RG" --query id -o tsv)

    # Show costs for current month
    log_info "Resource Group: $RG"
    echo ""

    az consumption usage list \
        --start-date "$(date -u -d '1 month ago' '+%Y-%m-%d')" \
        --end-date "$(date -u '+%Y-%m-%d')" \
        --query "[?contains(instanceId, '$RG')].{Resource:instanceName, Cost:pretaxCost, Currency:currency}" \
        -o table 2>/dev/null || {
            log_error "Unable to fetch cost data. This may require specific permissions."
            log_info "Estimated monthly costs:"
            echo "  - AKS Control Plane: \$0 (Free tier)"
            echo "  - AKS Node (Standard_B2s): ~\$35/month"
            echo "  - ACR (Basic): ~\$5/month"
            echo "  - Load Balancer: ~\$5/month"
            echo "  - TOTAL: ~\$45/month (if running 24/7)"
        }
}

# Function: Show status
show_status() {
    log_info "Checking infrastructure status..."

    RG=$(get_tf_output resource_group_name)
    AKS=$(get_tf_output aks_name)
    ACR=$(get_tf_output acr_login_server | cut -d'.' -f1)

    if [ -z "$RG" ]; then
        log_error "Infrastructure not deployed"
        exit 1
    fi

    echo ""
    echo "=== Infrastructure Status ==="
    echo ""

    # Check resource group
    if az group show -n "$RG" >/dev/null 2>&1; then
        log_success "Resource Group: $RG (exists)"
    else
        log_error "Resource Group: $RG (not found)"
    fi

    # Check AKS
    if [ -n "$AKS" ]; then
        NODE_COUNT=$(az aks nodepool show -g "$RG" --cluster-name "$AKS" -n system --query count -o tsv 2>/dev/null || echo "0")
        POWER_STATE=$(az aks nodepool show -g "$RG" --cluster-name "$AKS" -n system --query powerState.code -o tsv 2>/dev/null || echo "Unknown")

        if [ "$NODE_COUNT" = "0" ]; then
            log_info "AKS Cluster: $AKS (scaled to zero - minimal cost)"
        else
            log_success "AKS Cluster: $AKS ($NODE_COUNT node(s), state: $POWER_STATE)"
        fi
    fi

    # Check ACR
    if [ -n "$ACR" ]; then
        IMAGE_COUNT=$(az acr repository list -n "$ACR" --query "length(@)" -o tsv 2>/dev/null || echo "0")
        log_success "Container Registry: $ACR ($IMAGE_COUNT images)"
    fi

    # Check pods if cluster is running
    if [ "$NODE_COUNT" != "0" ] 2>/dev/null; then
        echo ""
        log_info "Checking Kubernetes resources..."
        az aks get-credentials -g "$RG" -n "$AKS" --overwrite-existing >/dev/null 2>&1

        POD_COUNT=$(kubectl get pods -l app=liatrio-demo --no-headers 2>/dev/null | wc -l)
        RUNNING_PODS=$(kubectl get pods -l app=liatrio-demo --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)

        if [ "$POD_COUNT" -gt 0 ]; then
            log_success "Application Pods: $RUNNING_PODS/$POD_COUNT running"

            # Get service IP
            SVC_IP=$(kubectl get svc liatrio-demo-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
            if [ -n "$SVC_IP" ]; then
                log_success "Service Endpoint: http://$SVC_IP/"
            else
                log_info "Service Endpoint: Pending..."
            fi
        else
            log_info "Application: Not deployed"
        fi
    fi

    echo ""
    echo "=== Cost Estimate ==="
    if [ "$NODE_COUNT" = "0" ] 2>/dev/null; then
        echo "Current monthly rate: ~\$10-15 (scaled down)"
    else
        echo "Current monthly rate: ~\$45-50 (active)"
    fi
}

# Function: Cleanup (destroy everything)
cleanup() {
    log_info "This will destroy ALL infrastructure and delete all data"
    read -p "Are you sure? Type 'yes' to confirm: " CONFIRM

    if [ "$CONFIRM" != "yes" ]; then
        log_info "Cleanup cancelled"
        exit 0
    fi

    cd "$TERRAFORM_DIR"
    log_info "Running terraform destroy..."
    terraform destroy -auto-approve

    log_success "All infrastructure destroyed"
    log_info "You will no longer incur Azure costs for this demo"
}

# Main menu
show_help() {
    cat << EOF
Liatrio Demo - Cost Management Utility

Usage: bash cost_management.sh [COMMAND]

Commands:
  scale-down    Scale AKS cluster to zero nodes (saves ~\$35/month)
  scale-up      Scale AKS cluster to one node (restores functionality)
  status        Show current infrastructure status and costs
  costs         Show detailed cost breakdown
  cleanup       Destroy all infrastructure (saves ~\$45/month)
  help          Show this help message

Examples:
  # Scale down after demo to save money
  bash cost_management.sh scale-down

  # Scale up before next demo
  bash cost_management.sh scale-up

  # Check current status
  bash cost_management.sh status

  # Completely remove everything
  bash cost_management.sh cleanup

EOF
}

# Main script logic
case "${1:-help}" in
    scale-down)
        scale_down
        ;;
    scale-up)
        scale_up
        ;;
    status)
        show_status
        ;;
    costs)
        show_costs
        ;;
    cleanup)
        cleanup
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
