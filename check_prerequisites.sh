#!/bin/bash
# Prerequisite Verification Script for AKS Demo
# Checks all required system tools are installed

set -e

echo "╔═══════════════════════════════════════════════════╗"
echo "║   AKS Demo - Prerequisites Check                ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""

MISSING_REQUIRED=0
MISSING_OPTIONAL=0

# Function to check command
check_command() {
    local cmd=$1
    local name=$2
    local required=$3
    local get_version=$4

    if command -v "$cmd" &> /dev/null; then
        if [ -n "$get_version" ]; then
            VERSION=$($get_version 2>&1 | head -n 1)
            echo "✓ $name: $VERSION"
        else
            echo "✓ $name: INSTALLED"
        fi
        return 0
    else
        if [ "$required" = "true" ]; then
            echo "✗ $name: NOT INSTALLED (REQUIRED)"
            ((MISSING_REQUIRED++))
        else
            echo "ℹ $name: NOT INSTALLED (Optional)"
            ((MISSING_OPTIONAL++))
        fi
        return 1
    fi
}

echo "Checking required tools..."
echo ""

# Check Azure CLI
check_command "az" "Azure CLI" "true" "az --version | head -n 1"

# Check Terraform
check_command "terraform" "Terraform" "true" "terraform --version | head -n 1"

# Check kubectl
check_command "kubectl" "kubectl" "true" "kubectl version --client --short 2>/dev/null || kubectl version --client=true 2>&1 | head -n 1"

# Check Helm (REQUIRED for new deployment)
echo ""
if check_command "helm" "Helm" "true" "helm version --short"; then
    HELM_VERSION=$(helm version --short 2>&1 | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
    if [[ "$HELM_VERSION" =~ ^v3\. ]] || [[ "$HELM_VERSION" > "v3.0.0" ]]; then
        echo "  ✓ Helm version is compatible (>= 3.0.0)"
    else
        echo "  ⚠ Warning: Helm version may be incompatible (need >= 3.0.0)"
    fi
else
    echo "  ⚠ CRITICAL: Helm is required for the new deployment method!"
    echo "    Install from: https://helm.sh/docs/intro/install/"
fi

echo ""
echo "Checking optional tools..."
echo ""

# Check Docker
check_command "docker" "Docker" "false" "docker --version"

# Check Python
check_command "python3" "Python" "false" "python3 --version"

# Check Git
check_command "git" "Git" "false" "git --version"

# Check jq (useful for scripts)
check_command "jq" "jq (JSON processor)" "false" "jq --version"

echo ""
echo "═══════════════════════════════════════════════════"
echo ""

# Azure authentication check
if command -v az &> /dev/null; then
    echo "Checking Azure authentication..."
    if az account show &> /dev/null; then
        SUBSCRIPTION=$(az account show --query name -o tsv)
        ACCOUNT=$(az account show --query user.name -o tsv)
        echo "✓ Authenticated to Azure"
        echo "  Account: $ACCOUNT"
        echo "  Subscription: $SUBSCRIPTION"
    else
        echo "✗ Not authenticated to Azure"
        echo "  Run: az login"
        ((MISSING_REQUIRED++))
    fi
    echo ""
fi

# Summary
echo "═══════════════════════════════════════════════════"
echo ""
echo "Summary:"
echo "  Required tools missing: $MISSING_REQUIRED"
echo "  Optional tools missing: $MISSING_OPTIONAL"
echo ""

if [ $MISSING_REQUIRED -eq 0 ]; then
    echo "✓ All required prerequisites are installed!"
    echo ""
    echo "Next steps:"
    echo "  1. Deploy: ./helm_deploy.sh dev"
    echo "  2. Or see: cat README.md"
    echo ""
    exit 0
else
    echo "✗ Missing $MISSING_REQUIRED required tool(s)"
    echo ""
    echo "Installation instructions:"
    echo "  See SYSTEM_REQUIREMENTS.md for detailed installation guides"
    echo "  Or visit: https://github.com/usgrant4/aks-api-demo"
    echo ""
    echo "Quick install (most tools):"
    echo "  # macOS"
    echo "  brew install azure-cli terraform kubectl helm"
    echo ""
    echo "  # Linux (Ubuntu/Debian)"
    echo "  sudo apt-get update"
    echo "  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
    echo "  # Then install Terraform, kubectl, Helm (see SYSTEM_REQUIREMENTS.md)"
    echo ""
    exit 1
fi
