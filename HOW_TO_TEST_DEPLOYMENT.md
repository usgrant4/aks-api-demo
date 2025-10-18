# How to Test Your Deployment in Browser

## 🎉 Deployment Successful! Now Let's Test It

---

## Quick Method: Get URL from Workflow Output

### 1. Find the LoadBalancer IP in GitHub Actions

1. Go to **GitHub** → **Actions** tab
2. Click on your successful workflow run
3. Expand the **"Smoke test"** step
4. Look for the output that shows:
   ```
   ========================================
     ✅ DEPLOYMENT SUCCESSFUL!
   ========================================

   API Endpoint: http://XX.XX.XX.XX/
   Health Check: http://XX.XX.XX.XX/health
   Version: v1.0.<commit-sha>
   ```

5. **Copy the IP address** and open it in your browser!

---

## Alternative: Get URL via Azure CLI

If you want to check the IP manually:

```bash
# Make sure you're logged in
az login

# Set your subscription
az account set --subscription <YOUR_SUBSCRIPTION_ID>

# Get AKS credentials (for dev or prod)
az aks get-credentials \
  --resource-group ugrant-liatrio-demo-rg \
  --name ugrant-liatrio-demo-aks \
  --overwrite-existing

# Get the LoadBalancer IP
kubectl get service liatrio-demo-svc

# Look for EXTERNAL-IP column
# Example output:
# NAME                TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)
# liatrio-demo-svc    LoadBalancer   10.0.123.45    20.102.34.56     80:30123/TCP
```

The **EXTERNAL-IP** is your LoadBalancer IP!

---

## Alternative: Use kubectl with Port Forwarding

If you prefer not to wait for LoadBalancer:

```bash
# Forward port 8080 locally
kubectl port-forward service/liatrio-demo-svc 8080:80

# Then open in browser:
# http://localhost:8080
```

---

## What to Test

### 1. Main Endpoint
**URL:** `http://<LOADBALANCER-IP>/`

**Expected Response:**
```json
{
  "message": "Automate all the things!",
  "timestamp": 1729279846
}
```

### 2. Health Check Endpoint
**URL:** `http://<LOADBALANCER-IP>/health`

**Expected Response:**
```json
{
  "status": "healthy",
  "timestamp": 1729279846
}
```

### 3. API Documentation (Swagger UI)
**URL:** `http://<LOADBALANCER-IP>/docs`

**Expected:** Interactive Swagger UI showing all API endpoints

---

## Testing with cURL

```bash
# Get the LoadBalancer IP
LOADBALANCER_IP="<your-ip-here>"

# Test main endpoint
curl http://$LOADBALANCER_IP/

# Test health endpoint
curl http://$LOADBALANCER_IP/health

# Pretty print JSON
curl http://$LOADBALANCER_IP/ | jq

# Check response headers
curl -I http://$LOADBALANCER_IP/
```

---

## Testing with Browser Developer Tools

1. Open browser to `http://<LOADBALANCER-IP>/`
2. Press **F12** to open Developer Tools
3. Go to **Network** tab
4. Refresh the page
5. Click on the request to see:
   - Status: `200 OK`
   - Response headers
   - Response body (JSON)

---

## Verify Deployment Version

Check which version is deployed:

```bash
# Get the deployment image
kubectl get deployment liatrio-demo -o jsonpath='{.spec.template.spec.containers[0].image}'

# Should show something like:
# youracr.azurecr.io/liatrio-demo:v1.0.<commit-sha>
```

---

## Find Your Resources in Azure Portal

### Option 1: Via Resource Group

1. Go to **portal.azure.com**
2. Search for **"ugrant-liatrio-demo-rg"** (or your resource group name)
3. Click on the resource group
4. You'll see:
   - AKS cluster
   - Container registry
   - Networking resources
   - Public IP address

### Option 2: Via Kubernetes Service

1. Go to **portal.azure.com**
2. Navigate to **Kubernetes services**
3. Click on **ugrant-liatrio-demo-aks** (or your AKS cluster name)
4. Click **Services and ingresses** in left menu
5. Find **liatrio-demo-svc**
6. See the **External IP** listed there

---

## Quick Test Script

Save this as `test-deployment.sh`:

```bash
#!/bin/bash

echo "=== Testing Liatrio Demo Deployment ==="
echo ""

# Get LoadBalancer IP
echo "1. Getting LoadBalancer IP..."
LOADBALANCER_IP=$(kubectl get svc liatrio-demo-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$LOADBALANCER_IP" ]; then
    echo "ERROR: LoadBalancer IP not found"
    echo "Checking service status..."
    kubectl get svc liatrio-demo-svc
    exit 1
fi

echo "✓ LoadBalancer IP: $LOADBALANCER_IP"
echo ""

# Test main endpoint
echo "2. Testing main endpoint..."
RESPONSE=$(curl -s http://$LOADBALANCER_IP/)
echo "$RESPONSE" | jq
echo ""

# Test health endpoint
echo "3. Testing health endpoint..."
HEALTH=$(curl -s http://$LOADBALANCER_IP/health)
echo "$HEALTH" | jq
echo ""

# Check if healthy
STATUS=$(echo $HEALTH | jq -r '.status')
if [ "$STATUS" = "healthy" ]; then
    echo "✓ Application is healthy!"
else
    echo "⚠ Application health status: $STATUS"
fi

echo ""
echo "=== Test URLs ==="
echo "Main API:     http://$LOADBALANCER_IP/"
echo "Health Check: http://$LOADBALANCER_IP/health"
echo "API Docs:     http://$LOADBALANCER_IP/docs"
echo ""
echo "Open any of these URLs in your browser!"
```

Run it:
```bash
chmod +x test-deployment.sh
./test-deployment.sh
```

---

## PowerShell Version (Windows)

```powershell
# Get LoadBalancer IP
$LOADBALANCER_IP = kubectl get svc liatrio-demo-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

Write-Host "LoadBalancer IP: $LOADBALANCER_IP"

# Test endpoints
Write-Host "`nTesting main endpoint..."
curl "http://${LOADBALANCER_IP}/"

Write-Host "`nTesting health endpoint..."
curl "http://${LOADBALANCER_IP}/health"

Write-Host "`nAPI URLs:"
Write-Host "Main API:     http://${LOADBALANCER_IP}/"
Write-Host "Health Check: http://${LOADBALANCER_IP}/health"
Write-Host "API Docs:     http://${LOADBALANCER_IP}/docs"
```

---

## Troubleshooting

### LoadBalancer IP is "<pending>"

**Cause:** Azure is still provisioning the public IP

**Solution:** Wait 2-5 minutes and check again:
```bash
kubectl get svc liatrio-demo-svc --watch
```

### Cannot Connect to IP

**Check 1: Pods are running**
```bash
kubectl get pods -l app=liatrio-demo
# Should show 2/2 pods Running
```

**Check 2: Service exists**
```bash
kubectl get svc liatrio-demo-svc
# Should show LoadBalancer type with EXTERNAL-IP
```

**Check 3: Firewall rules**
```bash
# Check if Azure NSG is blocking traffic
az network nsg list --output table
```

### 404 Not Found

**Cause:** Wrong path

**Solution:** Make sure you're using:
- `http://IP/` (with trailing slash)
- Not `https://` (only HTTP is configured)

### Connection Timeout

**Check service endpoints:**
```bash
kubectl describe svc liatrio-demo-svc
kubectl get endpoints liatrio-demo-svc
```

---

## Expected Performance

### Response Time
- **Main endpoint:** < 100ms
- **Health endpoint:** < 50ms
- **First request:** May be slower (pod warmup)

### Concurrent Requests
The deployment is configured to handle:
- **2 replicas** (pods)
- **10 concurrent requests per pod** (uvicorn default)
- **~20 concurrent requests total**

---

## Next Steps

### Monitor Application
```bash
# Watch pod logs
kubectl logs -f -l app=liatrio-demo

# Watch pod status
kubectl get pods -l app=liatrio-demo --watch

# Check resource usage
kubectl top pods -l app=liatrio-demo
```

### Scale if Needed
```bash
# Scale to 3 replicas
kubectl scale deployment liatrio-demo --replicas=3

# Verify
kubectl get pods -l app=liatrio-demo
```

### Make Changes
```bash
# Edit code
vim app/main.py

# Commit and push
git add app/main.py
git commit -m "Update message"
git push origin dev

# Watch new deployment
# GitHub Actions will automatically deploy!
```

---

## Share Your Success! 🎉

Once you verify it works:

1. **Screenshot the browser** showing the JSON response
2. **Note the LoadBalancer IP** for reference
3. **Share with your team** - deployment is live!

---

## Summary

**Fastest way to test:**

1. Go to GitHub Actions → Your workflow run
2. Look for "Smoke test" step output
3. Copy the IP address shown
4. Open `http://<IP>/` in browser
5. See the JSON response! 🎉

**Your API is now live and accessible from anywhere on the internet!**

---

## Quick Reference Card

```bash
# Get IP
kubectl get svc liatrio-demo-svc

# Test with curl
curl http://<IP>/
curl http://<IP>/health

# View in browser
http://<IP>/        # Main API
http://<IP>/docs    # Swagger UI
http://<IP>/health  # Health check
```

That's it! Enjoy your deployed application! 🚀
