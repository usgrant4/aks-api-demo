#!/bin/bash
set -e

echo "=========================================="
echo "  AKS Demo - Complete Deployment"
echo "=========================================="
echo ""

# Prerequisite checks
echo "🔍 Checking prerequisites..."

if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker Desktop."
    exit 1
fi

if ! kubectl version --client > /dev/null 2>&1; then
    echo "❌ kubectl is not installed."
    exit 1
fi

if ! az version > /dev/null 2>&1; then
    echo "❌ Azure CLI is not installed."
    exit 1
fi

echo "✅ All prerequisites met"
echo ""

# Navigate to project root
cd ~/repos/aks-demo

# Get Terraform outputs
echo "📦 Getting infrastructure details..."
cd terraform
ACR_LOGIN=$(terraform output -raw acr_login_server)
ACR_NAME=$(echo $ACR_LOGIN | cut -d'.' -f1)
RG=$(terraform output -raw resource_group_name)
AKS=$(terraform output -raw aks_name)
cd ..

echo "  ACR: $ACR_LOGIN"
echo "  AKS: $AKS"
echo ""

# Build and push image
echo "🐳 Building Docker image..."
docker build -t $ACR_LOGIN/aks-demo:latest .

echo "📤 Pushing to ACR..."
az acr login --name $ACR_NAME
docker push $ACR_LOGIN/aks-demo:latest

echo "✅ Image pushed to ACR"
echo ""

# Deploy to Kubernetes
echo "☸️  Deploying to Kubernetes..."
sed "s#REPLACE_WITH_ACR_LOGIN#$ACR_LOGIN#" \
  kubernetes/deployment.yaml | kubectl apply -f -

echo "⏳ Waiting for rollout..."
kubectl rollout status deploy/aks-demo --timeout=180s

echo "✅ Deployment complete"
echo ""

# Wait for LoadBalancer
echo "⏳ Waiting for LoadBalancer IP (2-5 minutes)..."
for i in {1..30}; do
  IP=$(kubectl get svc aks-demo-svc \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
  if [ -n "$IP" ]; then
    echo ""
    echo "=========================================="
    echo "  ✅ DEPLOYMENT SUCCESSFUL!"
    echo "=========================================="
    echo ""
    echo "🌐 API Endpoint: http://$IP/"
    echo ""
    echo "Test commands:"
    echo "  curl http://$IP/"
    echo "  curl http://$IP/health"
    echo ""
    echo "Verify deployment:"
    echo "  kubectl get pods -l app=aks-demo"
    echo "  kubectl logs -l app=aks-demo --tail=20"
    echo ""
    exit 0
  fi
  echo "  Attempt $i/30..."
  sleep 10
done

echo ""
echo "⚠️  LoadBalancer IP not ready yet"
echo "Check status: kubectl get svc aks-demo-svc"
