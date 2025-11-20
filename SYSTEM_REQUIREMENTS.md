# System Requirements

This document lists all system-level tools and dependencies required for the AKS Demo project.

## Required Tools

### 1. Azure CLI
**Purpose**: Azure resource management and authentication

**Installation:**
```bash
# Windows (winget)
winget install Microsoft.AzureCLI

# macOS
brew install azure-cli

# Linux (Ubuntu/Debian)
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

**Verify:**
```bash
az --version
# Required: >= 2.0.0
```

### 2. Terraform
**Purpose**: Infrastructure as Code deployment

**Installation:**
```bash
# Windows (Chocolatey)
choco install terraform

# macOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.10.5/terraform_1.10.5_linux_amd64.zip
unzip terraform_1.10.5_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

**Verify:**
```bash
terraform --version
# Required: >= 1.6.0
```

### 3. kubectl
**Purpose**: Kubernetes cluster management

**Installation:**
```bash
# Windows (Chocolatey)
choco install kubernetes-cli

# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

**Verify:**
```bash
kubectl version --client
# Required: >= 1.28
```

### 4. Helm (REQUIRED)
**Purpose**: Kubernetes package manager for application deployment

**Installation:**
```bash
# Windows (Chocolatey)
choco install kubernetes-helm

# Windows (winget)
winget install Helm.Helm

# macOS
brew install helm

# Linux (Script)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Linux (Manual)
wget https://get.helm.sh/helm-v3.16.3-linux-amd64.tar.gz
tar -zxvf helm-v3.16.3-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm
```

**Verify:**
```bash
helm version
# Required: >= 3.0.0
# Recommended: >= 3.16.0
```

### 5. Docker (Optional)
**Purpose**: Local container builds and testing

**Installation:**
```bash
# Windows
# Download from: https://www.docker.com/products/docker-desktop

# macOS
brew install --cask docker

# Linux (Ubuntu/Debian)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

**Verify:**
```bash
docker --version
# Required: >= 20.0.0
```

### 6. PowerShell (Windows) or Bash (Linux/macOS)
**Purpose**: Running deployment scripts

**Installation:**
- Windows: Pre-installed (PowerShell 5.1+) or install PowerShell 7+
- Linux/macOS: Bash is pre-installed

**Verify:**
```powershell
# PowerShell
$PSVersionTable.PSVersion

# Bash
bash --version
```

## Python Dependencies

Python package dependencies are managed separately in [app/requirements.txt](app/requirements.txt):
- fastapi==0.119.1
- uvicorn==0.38.0
- pytest==8.4.2
- httpx==0.28.1

**Installation:**
```bash
pip install -r app/requirements.txt
```

## Azure Requirements

### Azure Subscription
- Active Azure subscription with Contributor access
- Sufficient quota for:
  - Resource Groups
  - Azure Container Registry (Basic SKU)
  - AKS Cluster (1+ nodes, Standard_D2s_v3)
  - Load Balancer

### Azure Authentication
```bash
# Login to Azure
az login

# Verify subscription
az account show

# Set subscription (if multiple)
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

## GitHub Requirements (for CI/CD)

### Repository Secrets
Required for GitHub Actions workflow:
- `AZURE_CLIENT_ID`: Service Principal Client ID
- `AZURE_TENANT_ID`: Azure AD Tenant ID
- `AZURE_SUBSCRIPTION_ID`: Azure Subscription ID

### OIDC Configuration
Federated credentials configured for GitHub Actions OIDC authentication.

See [docs/GITHUB_SETUP.md](docs/GITHUB_SETUP.md) for detailed setup instructions.

## Quick Setup Verification

Run this script to verify all required tools are installed:

```bash
#!/bin/bash
echo "Checking system requirements..."

# Check Azure CLI
if command -v az &> /dev/null; then
    echo "✓ Azure CLI: $(az --version | head -n 1)"
else
    echo "✗ Azure CLI: NOT INSTALLED"
fi

# Check Terraform
if command -v terraform &> /dev/null; then
    echo "✓ Terraform: $(terraform --version | head -n 1)"
else
    echo "✗ Terraform: NOT INSTALLED"
fi

# Check kubectl
if command -v kubectl &> /dev/null; then
    echo "✓ kubectl: $(kubectl version --client --short 2>/dev/null)"
else
    echo "✗ kubectl: NOT INSTALLED"
fi

# Check Helm
if command -v helm &> /dev/null; then
    echo "✓ Helm: $(helm version --short)"
else
    echo "✗ Helm: NOT INSTALLED (REQUIRED)"
fi

# Check Docker
if command -v docker &> /dev/null; then
    echo "✓ Docker: $(docker --version)"
else
    echo "ℹ Docker: NOT INSTALLED (Optional)"
fi

# Check Python
if command -v python3 &> /dev/null; then
    echo "✓ Python: $(python3 --version)"
else
    echo "✗ Python: NOT INSTALLED"
fi

echo ""
echo "Note: Helm is REQUIRED for the new deployment method."
echo "      Install Helm 3.x from: https://helm.sh/docs/intro/install/"
```

## Platform-Specific Notes

### Windows
- PowerShell 5.1+ or PowerShell 7+ required
- Use Chocolatey or winget for easy package management
- WSL2 recommended for better Docker/Kubernetes integration

### macOS
- Homebrew recommended for package management
- Ensure Xcode Command Line Tools are installed: `xcode-select --install`

### Linux
- Most distributions include necessary build tools
- May require additional packages: `sudo apt install -y curl wget unzip`

## Minimum Hardware Requirements

- **CPU**: 2+ cores
- **RAM**: 8GB+ (16GB recommended)
- **Disk**: 20GB+ free space
- **Network**: Stable internet connection for Azure/GitHub access

## Next Steps

After installing all required tools:

1. Verify installations: Run the verification script above
2. Authenticate with Azure: `az login`
3. Clone the repository
4. Deploy: `./helm_deploy.ps1 -Environment dev` or `./helm_deploy.sh dev`

For detailed deployment instructions, see [README.md](README.md).
