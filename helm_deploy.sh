#!/bin/bash
set -e

echo "╔═══════════════════════════════════════════════════╗"
echo "║   AKS Demo - Helm Deployment                ║"
echo "╚═══════════════════════════════════════════════════╝"
echo ""

START_TIME=$(date +%s)

# Parse parameters
ENVIRONMENT="${1:-dev}"
SKIP_INFRA="${2:-false}"

echo "Deployment Configuration:"
echo "  Environment: $ENVIRONMENT"
echo "  Skip Infrastructure: $SKIP_INFRA"
echo ""

# Validate prerequisites
echo "Checking prerequisites..."
if ! command -v helm &> /dev/null; then
    echo "  ❌ Helm not found. Please install Helm 3.x"
    echo "     Download from: https://helm.sh/docs/intro/install/"
    exit 1
fi
HELM_VERSION=$(helm version --short)
echo "  ✅ Helm installed: $HELM_VERSION"

if ! command -v kubectl &> /dev/null; then
    echo "  ❌ kubectl not found. Please install kubectl"
    exit 1
fi
echo "  ✅ kubectl installed"
echo ""

if [ "$SKIP_INFRA" != "true" ]; then
    # Step 1: Deploy Infrastructure
    echo "1️⃣ Deploying Azure Infrastructure..."
    cd terraform

    if [ ! -f "terraform.tfstate" ]; then
        terraform init
    fi

    terraform apply -auto-approve -var="environment=$ENVIRONMENT"

    RG=$(terraform output -raw resource_group_name)
    AKS=$(terraform output -raw aks_name)
    ACR_LOGIN=$(terraform output -raw acr_login_server)
    ACR_NAME=$(echo $ACR_LOGIN | cut -d'.' -f1)

    echo "   ✅ Infrastructure deployed"
    echo "      ACR: $ACR_NAME"
    echo "      AKS: $AKS"
    echo ""

    cd ..
else
    echo "1️⃣ Skipping infrastructure deployment..."

    cd terraform
    RG=$(terraform output -raw resource_group_name)
    AKS=$(terraform output -raw aks_name)
    ACR_LOGIN=$(terraform output -raw acr_login_server)
    ACR_NAME=$(echo $ACR_LOGIN | cut -d'.' -f1)
    cd ..

    echo "   Using existing infrastructure:"
    echo "      ACR: $ACR_NAME"
    echo "      AKS: $AKS"
    echo ""
fi

# Step 2: Configure kubectl
echo "2️⃣ Configuring kubectl..."
az aks get-credentials -g $RG -n $AKS --overwrite-existing > /dev/null
kubectl get nodes > /dev/null
echo "   ✅ Connected to AKS"
echo ""

# Step 3: Attach ACR to AKS
echo "3️⃣ Ensuring ACR is attached to AKS..."
az aks update \
    --resource-group $RG \
    --name $AKS \
    --attach-acr $ACR_NAME \
    --output none

echo "   ✅ ACR attached"
echo ""

# Step 4: Build Image
echo "4️⃣ Building Docker image with ACR Tasks..."
GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "")
if [ -z "$GIT_SHA" ]; then
    GIT_SHA=$(date +%Y%m%d%H%M%S)
fi
VERSION="v1.0.$GIT_SHA"

echo "   Version: $VERSION"

az acr build \
    --registry $ACR_NAME \
    --image "aks-demo:$VERSION" \
    --image "aks-demo:latest" \
    --platform linux/amd64 \
    --file Dockerfile \
    . \
    --output table

echo "   ✅ Image built: $ACR_LOGIN/aks-demo:$VERSION"
echo ""

# Step 5: Validate Helm Chart
echo "5️⃣ Validating Helm chart..."

VALUES_FILE="helm/aks-demo/values-$ENVIRONMENT.yaml"
if [ ! -f "$VALUES_FILE" ]; then
    echo "   ⚠️ Values file not found: $VALUES_FILE"
    echo "   Using default values.yaml"
    VALUES_FILE="helm/aks-demo/values.yaml"
fi

echo "   Linting chart..."
helm lint ./helm/aks-demo --values $VALUES_FILE

echo "   Running dry-run..."
NAMESPACE="aks-demo-$ENVIRONMENT"
helm install aks-demo ./helm/aks-demo \
    --dry-run \
    --set image.registry=$ACR_LOGIN \
    --set image.tag=$VERSION \
    --set environment=$ENVIRONMENT \
    --values $VALUES_FILE \
    --namespace $NAMESPACE \
    --create-namespace \
    > helm-dry-run.yaml

echo "   ✅ Helm chart validated"
echo "   📄 Dry-run output saved to: helm-dry-run.yaml"
echo ""

# Step 6: Check for existing release
echo "6️⃣ Checking for existing Helm release..."

kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f - > /dev/null

if helm list -n $NAMESPACE | grep -q "aks-demo"; then
    RELEASE_INFO=$(helm list -n $NAMESPACE -o json | jq -r '.[] | select(.name=="aks-demo")')
    PREVIOUS_REVISION=$(echo "$RELEASE_INFO" | jq -r '.revision')
    echo "   Found existing release: aks-demo (revision $PREVIOUS_REVISION)"
else
    echo "   No existing release found (initial deployment)"
    PREVIOUS_REVISION=""
fi
echo ""

# Step 7: Deploy with Helm
echo "7️⃣ Deploying with Helm..."
echo "   Environment: $ENVIRONMENT"
echo "   Namespace: $NAMESPACE"
echo "   Image: $ACR_LOGIN/aks-demo:$VERSION"
echo ""

helm upgrade --install aks-demo ./helm/aks-demo \
    --set image.registry=$ACR_LOGIN \
    --set image.tag=$VERSION \
    --set environment=$ENVIRONMENT \
    --values $VALUES_FILE \
    --namespace $NAMESPACE \
    --create-namespace \
    --wait \
    --timeout 5m \
    --atomic \
    --cleanup-on-fail

NEW_REVISION=$(helm list -n $NAMESPACE -o json | jq -r '.[] | select(.name=="aks-demo") | .revision')

echo "   ✅ Deployed successfully (revision $NEW_REVISION)"
echo ""

# Step 8: Verify Deployment
echo "8️⃣ Verifying deployment..."

echo "   Checking Helm release status..."
helm status aks-demo -n $NAMESPACE

echo ""
echo "   Checking pod readiness..."
DEPLOYMENT_NAME=$(kubectl get deployment -n $NAMESPACE -l app.kubernetes.io/name=aks-demo -o jsonpath='{.items[0].metadata.name}')
DESIRED=$(kubectl get deploy $DEPLOYMENT_NAME -n $NAMESPACE -o jsonpath='{.spec.replicas}')
READY=$(kubectl get deploy $DEPLOYMENT_NAME -n $NAMESPACE -o jsonpath='{.status.readyReplicas}')

if [ "$READY" = "$DESIRED" ]; then
    echo "   ✅ All $READY/$DESIRED pods ready"
    kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=aks-demo
else
    echo "   ⚠️ Expected $DESIRED ready pods, got $READY"
    kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=aks-demo
fi
echo ""

# Step 9: Get LoadBalancer IP and Test
echo "9️⃣ Getting LoadBalancer IP..."
SVC_NAME=$(kubectl get svc -n $NAMESPACE -l app.kubernetes.io/name=aks-demo -o jsonpath='{.items[0].metadata.name}')

for i in $(seq 1 30); do
    IP=$(kubectl get svc $SVC_NAME -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    if [ -n "$IP" ]; then
        echo "   ✅ IP assigned: $IP"
        break
    fi
    echo "   Waiting... (attempt $i/30)"
    sleep 10
done

if [ -z "$IP" ]; then
    echo "   ⚠️ LoadBalancer IP not assigned"
    kubectl describe svc $SVC_NAME -n $NAMESPACE
    exit 1
fi

echo ""
echo "🧪 Testing API..."
sleep 5

if curl -sS -f http://$IP/ --connect-timeout 10 --retry 3 --retry-delay 2 > /tmp/api_response.json; then
    echo "   ✅ Main endpoint responding"

    if curl -sS -f http://$IP/health --connect-timeout 10 --retry 3 --retry-delay 2 > /dev/null; then
        echo "   ✅ Health endpoint responding"
        echo ""

        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        DURATION_MINUTES=$(echo "scale=1; $DURATION / 60" | bc)

        echo "╔═══════════════════════════════════════════════════╗"
        echo "║       HELM DEPLOYMENT SUCCESSFUL!                ║"
        echo "╚═══════════════════════════════════════════════════╝"
        echo ""
        echo "🎉 Deployment completed in $DURATION_MINUTES minutes"
        echo ""
        echo "📊 Deployment Details:"
        echo "   Environment: $ENVIRONMENT"
        echo "   Namespace: $NAMESPACE"
        echo "   API Endpoint: http://$IP/"
        echo "   Health Check: http://$IP/health"
        echo "   Image Tag: $VERSION"
        echo "   Helm Revision: $NEW_REVISION"
        echo ""
        echo "🧪 API Response:"
        cat /tmp/api_response.json | jq .
        echo ""
        echo "⚙️ Helm Commands:"
        echo "   Status:   helm status aks-demo -n $NAMESPACE"
        echo "   History:  helm history aks-demo -n $NAMESPACE"
        echo "   Values:   helm get values aks-demo -n $NAMESPACE"
        if [ -n "$PREVIOUS_REVISION" ]; then
            echo "   Rollback: helm rollback aks-demo $PREVIOUS_REVISION -n $NAMESPACE"
        else
            echo "   Rollback: helm rollback aks-demo [REVISION] -n $NAMESPACE"
        fi
        echo ""
        echo "🎯 Next Steps:"
        echo "   • Run tests: ./test_deployment.sh"
        echo "   • View logs: kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=aks-demo"
        echo "   • Check resources: kubectl get all,vpa,pdb -n $NAMESPACE -l app.kubernetes.io/instance=aks-demo"
        echo "   • Uninstall: helm uninstall aks-demo -n $NAMESPACE"
        echo "   • Cleanup infrastructure: cd terraform && terraform destroy"
        echo ""
    else
        echo "   ⚠️ Health endpoint not responding"
        exit 1
    fi
else
    echo "   ⚠️ API not responding"
    echo ""
    echo "   Try: curl http://$IP/"
    echo "   Logs: kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=aks-demo"
    echo ""
    if [ -n "$PREVIOUS_REVISION" ]; then
        echo "   Rollback command: helm rollback aks-demo $PREVIOUS_REVISION -n $NAMESPACE"
    fi
    exit 1
fi
