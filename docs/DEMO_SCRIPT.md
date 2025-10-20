# Live Demo Script - Liatrio DevOps Demo

## Complete Step-by-Step Walkthrough

**Duration:** 7-10 minutes
**Audience:** Technical stakeholders, clients, team members
**Prerequisites:** Azure subscription, GitHub repository, deployed infrastructure

---

## PRE-DEMO CHECKLIST (DO THIS 1 HOUR BEFORE)

### ✅ Environment Verification
```powershell
# 1. Verify infrastructure is deployed
cd terraform
terraform output

# Expected output:
# acr_login_server = "ugrantliatriodemodevacr.azurecr.io"
# aks_name = "ugrant-liatrio-demo-dev-aks"
# resource_group_name = "ugrant-liatrio-demo-dev-rg"

# 2. Verify application is running
kubectl get pods -l app=liatrio-demo
# Expected: 2 pods in Running status

# 3. Get service endpoint
$IP = kubectl get svc liatrio-demo-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
curl "http://$IP/"
# Expected: {"message":"Automate all the things!","timestamp":...}

# 4. Test GitHub Actions workflow
# Go to GitHub Actions tab, verify last workflow succeeded
```

### ✅ Prepare Backup Materials
1. Take screenshots of successful deployment
2. Have Azure Portal open in a tab (logged in)
3. Have GitHub repository open in a tab
4. Have kubectl context set to correct cluster
5. Prepare a small code change ready to commit (optional)

### ✅ Technical Setup
- [ ] Close unnecessary applications
- [ ] Clear browser cache/cookies if needed
- [ ] Test screen sharing (if virtual presentation)
- [ ] Have terminal with legible font size (18-20pt recommended)
- [ ] Prepare split-screen: Browser (left) + Terminal (right)

---

## DEMO OPTION A: GITHUB ACTIONS DEPLOYMENT (7 minutes)

**Best for:** Showing full automation, CI/CD focus

### Part 1: Show Current State (90 seconds)

#### Step 1: Open GitHub Repository
**Navigate to:** `https://github.com/<your-org>/liatrio-demo`

**Speaking:**
> "Let me show you the live system. This is the GitHub repository with all our code — application, infrastructure, and CI/CD pipeline."

**Actions:**
1. Click on **Code** tab
2. Show the file structure briefly:
   ```
   .github/workflows/ci-cd.yml  ← "This is our automation"
   app/                         ← "This is the FastAPI application"
   terraform/                   ← "Infrastructure as Code"
   kubernetes/                  ← "Deployment manifests"
   ```

**Speaking:**
> "Everything is version-controlled. No manual configuration hidden in Azure Portal."

---

#### Step 2: Show Recent Deployments
**Actions:**
1. Click **Actions** tab
2. Point to recent workflow runs

**Speaking:**
> "Here's our deployment history. Every push to the `dev` or `main` branch triggers this pipeline automatically. Green checkmarks mean successful deployments."

3. Click on the most recent successful run
4. Expand the `deploy` job
5. Point to the stages:
   - Build & Test
   - Terraform Init/Apply
   - Build & Push Image
   - Deploy to Kubernetes
   - Smoke Tests

**Speaking:**
> "Each deployment goes through these stages. If any stage fails, the deployment stops. This is our quality gate."

---

#### Step 3: Show Live Application
**Actions:**
1. Open new tab
2. Navigate to `http://<your-loadbalancer-ip>/`

**Speaking:**
> "Here's the live application. It's a simple REST API, but the deployment patterns I'm using scale to complex microservices."

3. Show the JSON response:
   ```json
   {
     "message": "Automate all the things!",
     "timestamp": 1760846168
   }
   ```

**Speaking:**
> "Notice the timestamp. This is generated server-side, proving the application is running live in Azure."

4. Navigate to `/health` endpoint

**Speaking:**
> "This health endpoint is what Kubernetes uses for readiness and liveness probes. If this returns unhealthy, Kubernetes automatically restarts the pod."

---

### Part 2: Trigger Manual Deployment (4 minutes)

#### Step 4: Initiate Workflow Dispatch
**Actions:**
1. Go back to GitHub Actions tab
2. Click on **ci-cd** workflow (left sidebar)
3. Click **Run workflow** button (right side)

**Speaking:**
> "GitHub Actions supports manual deployments via workflow_dispatch. This is useful for testing or deploying to production on demand."

4. Show the input options:
   - **Action to perform:** Deploy
   - **Target environment:** Dev

**Speaking:**
> "I can choose to deploy or destroy infrastructure. I can also select dev or prod environment. Let's deploy to dev."

5. Click **Run workflow**

**Speaking:**
> "And we're off. This will take about 2-3 minutes since the infrastructure already exists. A cold start from nothing takes 10-12 minutes."

---

#### Step 5: Watch Deployment Progress
**Actions:**
1. Click on the running workflow
2. Click on the `deploy` job

**Speaking:**
> "Let me walk you through what's happening in real-time."

3. Watch the live logs, narrating as they scroll:

**Terraform Init:**
> "First, Terraform initializes and connects to the remote state backend in Azure Storage. This ensures we're working with the latest infrastructure state."

**Terraform Apply:**
> "Now Terraform checks if any infrastructure changes are needed. In this case, everything is up to date, so it shows 'No changes.'"

**ACR Build:**
> "Here's the interesting part. We're using ACR Tasks to build the Docker image inside Azure, not on the GitHub Actions runner. This is faster and more secure."

**kubectl apply:**
> "The image is built. Now we're deploying the Kubernetes manifests. This triggers a rolling update."

**Rollout Status:**
> "Kubernetes is starting a new pod, waiting for it to pass health checks, then terminating the old pod. This is the zero-downtime deployment in action."

**Smoke Test:**
> "Finally, the pipeline hits the live endpoint to validate the deployment. If this curl command fails, the entire workflow fails."

---

#### Step 6: Show Deployment Success
**Actions:**
1. Wait for the workflow to complete (should show green checkmark)
2. Scroll to the bottom to show the final output:
   ```
   ========================================
     ✅ DEPLOYMENT SUCCESSFUL!
   ========================================

   API Endpoint: http://<ip>/
   Health Check: http://<ip>/health
   Version: v1.0.<sha>
   ```

**Speaking:**
> "And we're done. The entire deployment — from clicking 'Run workflow' to live in production — took 3 minutes. No manual steps, no SSH-ing into servers, no hoping it works."

---

#### Step 7: Verify in Azure Portal (Optional, 60 seconds)
**Actions:**
1. Open Azure Portal
2. Navigate to Resource Groups → `ugrant-liatrio-demo-dev-rg`
3. Show the resources:
   - AKS cluster
   - Container Registry
   - Load Balancer
   - Network resources

**Speaking:**
> "Here's the actual infrastructure in Azure. All of this was created by Terraform. If I deleted this resource group and ran the pipeline again, it would recreate everything identically."

4. Click on the AKS cluster
5. Click **Workloads** (left sidebar)
6. Show the running pods

**Speaking:**
> "And here are our Kubernetes pods running inside AKS. You can see the health status, resource usage, and deployment history — all managed automatically."

---

### Part 3: Wrap-up (30 seconds)

**Speaking:**
> "So to recap: I pushed a button, and in 3 minutes, we had a fully tested, production-ready deployment running in Azure. The same pipeline handles dev, testing, and production environments. The same pipeline can also destroy infrastructure to save costs. This is modern DevOps in action."

**[RETURN TO PRESENTATION SLIDES]**

---

## DEMO OPTION B: LOCAL DEPLOYMENT WITH POWERSHELL (5 minutes)

**Best for:** Showing infrastructure details, cost management

### Part 1: Show Infrastructure Status (90 seconds)

#### Step 1: Open Terminal
**Actions:**
1. Open PowerShell terminal
2. Navigate to project directory
   ```powershell
   cd C:\Users\ugran\repos\liatrio-demo
   ```

**Speaking:**
> "Let me show you a local deployment using our PowerShell automation script. First, let's check the current infrastructure status."

---

#### Step 2: Run Status Check
**Actions:**
```powershell
bash scripts/cost_management.sh status
```

**Expected Output:**
```
=== Infrastructure Status ===

✓ Resource Group: ugrant-liatrio-demo-dev-rg (exists)
✓ AKS Cluster: ugrant-liatrio-demo-dev-aks (1 node(s), state: Running)
✓ Container Registry: ugrantliatriodemodevacr (1 images)
✓ Application Pods: 2/2 running
✓ Service Endpoint: http://4.242.115.185/

=== Cost Estimate ===
Current monthly rate: ~$45-50 (active)
```

**Speaking:**
> "This utility script shows me the health of the entire stack. Everything is running. The cost estimate is about $45-50 per month running 24/7. I can scale this down to near-zero when not in use."

---

### Part 2: Show Kubernetes Resources (2 minutes)

#### Step 3: Show Pods
**Actions:**
```powershell
kubectl get pods -l app=liatrio-demo
```

**Expected Output:**
```
NAME                            READY   STATUS    RESTARTS   AGE
liatrio-demo-7d5b9c8f6b-abc12   1/1     Running   0          2d
liatrio-demo-7d5b9c8f6b-def34   1/1     Running   0          2d
```

**Speaking:**
> "Here are our 2 pod replicas. Both are in Running status, 1/1 ready. If I delete one of these pods, Kubernetes will automatically recreate it within seconds."

---

#### Step 4: Show Service
**Actions:**
```powershell
kubectl get svc liatrio-demo-svc
```

**Expected Output:**
```
NAME               TYPE           CLUSTER-IP    EXTERNAL-IP      PORT(S)        AGE
liatrio-demo-svc   LoadBalancer   10.0.123.45   4.242.115.185   80:31234/TCP   2d
```

**Speaking:**
> "This is the LoadBalancer service. Notice the EXTERNAL-IP — that's the public IP assigned by Azure. Any request to this IP on port 80 gets routed to one of our pods."

---

#### Step 5: Show Deployment Details
**Actions:**
```powershell
kubectl describe deployment liatrio-demo | Select-String -Pattern "Replicas|Strategy|Image"
```

**Speaking:**
> "Let me show you the deployment configuration."

**Point out:**
- **Replicas:** 2 desired, 2 current, 2 available
- **Strategy:** RollingUpdate (MaxUnavailable: 0, MaxSurge: 1)
- **Image:** Points to ACR with specific version tag

**Speaking:**
> "The rolling update strategy is key. MaxUnavailable: 0 means zero downtime during deployments. Kubernetes always keeps at least 2 pods healthy."

---

### Part 3: Test High Availability (90 seconds)

#### Step 6: Delete a Pod
**Actions:**
```powershell
# Get pod name
$POD = kubectl get pods -l app=liatrio-demo -o jsonpath='{.items[0].metadata.name}'

# Show the pod name
Write-Host "Deleting pod: $POD" -ForegroundColor Yellow

# Delete it
kubectl delete pod $POD

# Immediately watch the pods
kubectl get pods -l app=liatrio-demo -w
```

**Expected Output (live updates):**
```
NAME                            READY   STATUS        RESTARTS   AGE
liatrio-demo-7d5b9c8f6b-abc12   1/1     Terminating   0          2d
liatrio-demo-7d5b9c8f6b-def34   1/1     Running       0          2d
liatrio-demo-7d5b9c8f6b-ghi56   0/1     Pending       0          1s
liatrio-demo-7d5b9c8f6b-ghi56   0/1     ContainerCreating   0    1s
liatrio-demo-7d5b9c8f6b-ghi56   1/1     Running       0          5s
```

**Speaking:**
> "Watch what happens. I just deleted a pod. Kubernetes immediately notices the replica count is below 2 and starts a new pod. Within 5 seconds, we're back to 2 healthy pods. The service never went down because the second pod kept handling traffic."

**Actions:**
```powershell
# Stop watching (Ctrl+C)
# Test the endpoint
$IP = kubectl get svc liatrio-demo-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
curl "http://$IP/"
```

**Speaking:**
> "And the application is still responding. This is self-healing in action."

---

### Part 4: Show Cost Management (60 seconds)

#### Step 7: Demonstrate Scale-Down (Simulation)
**Actions:**
```powershell
bash scripts/cost_management.sh help
```

**Speaking:**
> "One of the questions I asked earlier was about cost optimization. This utility script lets me scale the AKS cluster to zero nodes when I'm not actively demoing."

**Show the help output:**
```
Commands:
  scale-down    Scale AKS cluster to zero nodes (saves ~$35/month)
  scale-up      Scale AKS cluster to one node (restores functionality)
  status        Show current infrastructure status and costs
  costs         Show detailed cost breakdown
  cleanup       Destroy all infrastructure (saves ~$45/month)
```

**Speaking:**
> "If I run `scale-down`, it keeps the cluster control plane but scales the node pool to zero. The infrastructure still exists, but I'm not paying for compute. This saves about $35 per month. When I need to demo again, I run `scale-up`, and within 2 minutes, the cluster is back online."

**DO NOT ACTUALLY RUN SCALE-DOWN DURING THE DEMO**

**Speaking:**
> "I won't actually run this now since we're in the middle of a demo, but you can see how this makes the architecture cost-effective for intermittent use."

---

### Part 5: Wrap-up (30 seconds)

**Speaking:**
> "So that's the local view. With a few scripts, I can deploy, monitor, test, and manage costs — all from the command line. The same patterns work in CI/CD, which is what you'd use in a real environment."

**[RETURN TO PRESENTATION SLIDES]**

---

## DEMO OPTION C: CODE CHANGE TO DEPLOYMENT (10 minutes)

**Best for:** Showing full development workflow

### Part 1: Make Code Change (2 minutes)

#### Step 1: Open IDE
**Actions:**
1. Open VSCode
2. Navigate to `app/main.py`

**Speaking:**
> "Let me show you what a typical developer workflow looks like. I'm going to make a small change to the application and push it. You'll see the entire deployment happen automatically."

---

#### Step 2: Modify Application
**Actions:**
1. Find the message line:
   ```python
   return {"message": "Automate all the things!", "timestamp": current_time}
   ```

2. Change it to:
   ```python
   return {"message": "Automate all the things! (Updated)", "timestamp": current_time}
   ```

**Speaking:**
> "I'm just adding '(Updated)' to the message so we can verify the new version deployed. In a real scenario, this might be a bug fix or feature addition."

---

#### Step 3: Run Tests Locally (Optional)
**Actions:**
```powershell
pytest -v
```

**Speaking:**
> "Before I push, let me run the tests locally to make sure I didn't break anything."

**Wait for tests to pass:**
```
test_read_root PASSED
test_health_check PASSED
```

**Speaking:**
> "Tests pass. Now I'll commit and push."

---

### Part 2: Commit and Push (90 seconds)

#### Step 4: Git Workflow
**Actions:**
```powershell
git add app/main.py
git commit -m "Update message to show deployment demo"
git push origin dev
```

**Speaking:**
> "I'm committing the change and pushing to the `dev` branch. The moment this hits GitHub, the CI/CD pipeline will trigger."

**Actions:**
1. Switch to browser
2. Navigate to GitHub repository
3. Click **Actions** tab
4. Show the new workflow run appearing (refresh if needed)

**Speaking:**
> "There it is. The pipeline just kicked off. Let's watch it run."

---

### Part 3: Watch Pipeline (4 minutes)

#### Step 5: Build & Test Stage
**Actions:**
1. Click on the running workflow
2. Click on `build-test` job
3. Watch the logs

**Speaking:**
> "First, it runs the unit tests. This ensures the code change didn't introduce bugs."

**Wait for tests to complete:**
```
test_read_root PASSED
test_health_check PASSED
✅ Build & Test job completed
```

---

#### Step 6: Deploy Stage
**Actions:**
1. Click on `deploy` job
2. Watch the stages

**Speaking:**
> "Now the deployment starts. It's doing several things:"

**Narrate as logs scroll:**

**Terraform:**
> "Terraform checks for infrastructure changes. None needed, so it moves on."

**ACR Build:**
> "Building the Docker image with the new code. This happens inside Azure using ACR Tasks."

**kubectl apply:**
> "Deploying the updated image to Kubernetes. This is the rolling update."

**Rollout Status:**
> "Waiting for the new pods to become healthy. Kubernetes is starting the new version, waiting for health checks, then terminating the old version."

**Smoke Test:**
> "Testing the live endpoint to verify the deployment succeeded."

---

#### Step 7: Verify Success
**Actions:**
1. Wait for workflow to complete (green checkmark)
2. Open new tab
3. Navigate to `http://<loadbalancer-ip>/`

**Expected Output:**
```json
{
  "message": "Automate all the things! (Updated)",
  "timestamp": 1760846500
}
```

**Speaking:**
> "And there's our change. The message now says '(Updated)'. From code commit to production deployment: 3 minutes. No manual steps, no downtime, fully tested."

---

### Part 4: Show Rollout History (2 minutes)

#### Step 8: Deployment History
**Actions:**
```powershell
kubectl rollout history deployment/liatrio-demo
```

**Expected Output:**
```
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
3         <none>
```

**Speaking:**
> "Kubernetes tracks every deployment as a revision. If something went wrong with this deployment, I could roll back to the previous version instantly."

**Actions:**
```powershell
# Show how to rollback (DO NOT ACTUALLY RUN)
# kubectl rollout undo deployment/liatrio-demo
```

**Speaking:**
> "If I ran `kubectl rollout undo`, it would revert to the previous version within seconds. That's your disaster recovery built right into the platform."

---

#### Step 9: Show Pod Details
**Actions:**
```powershell
kubectl get pods -l app=liatrio-demo -o wide
```

**Speaking:**
> "Notice the AGE column. These pods are only a few minutes old — they're the ones that were just deployed with the updated code."

**Actions:**
```powershell
kubectl logs -l app=liatrio-demo --tail=10
```

**Speaking:**
> "And here are the live application logs. You can see the FastAPI startup messages and any requests that have hit the API."

---

### Part 5: Wrap-up (30 seconds)

**Speaking:**
> "So that's the full developer experience. Make a code change, push it, and watch it deploy automatically. Tests run, images build, Kubernetes orchestrates the rollout, smoke tests validate. The entire workflow is automated, repeatable, and auditable."

**[RETURN TO PRESENTATION SLIDES]**

---

## HANDLING DEMO FAILURES

### If GitHub Actions Fails:

**Symptom:** Workflow shows red X

**Response:**
> "Looks like we hit an issue. Let me show you how we'd troubleshoot this in a real scenario."

**Actions:**
1. Click on the failed step
2. Show the error message
3. Explain what the error means

**Common Failures:**
- **Terraform lock:** "Someone else is deploying. Terraform prevents concurrent runs to avoid conflicts."
- **Test failure:** "A test failed, which prevented deployment. This is the safety net working as designed."
- **Image build failure:** "The Docker build failed, usually due to syntax errors or missing dependencies."

**Fallback:**
> "In the interest of time, let me show you screenshots from a successful deployment I ran earlier."

---

### If kubectl Commands Hang:

**Symptom:** kubectl commands don't return

**Response:**
> "Looks like there's a connectivity issue with the cluster. Let me verify the context."

**Actions:**
```powershell
kubectl config current-context
az aks get-credentials -g <rg> -n <aks> --overwrite-existing
```

**Fallback:**
> "I'll use the Azure Portal to show you the running resources instead."

---

### If Application Returns 503/504:

**Symptom:** curl returns errors

**Response:**
> "The LoadBalancer is having trouble routing traffic. Let me check the pod status."

**Actions:**
```powershell
kubectl get pods -l app=liatrio-demo
kubectl describe pods -l app=liatrio-demo
```

**Likely Cause:**
- Pods are restarting due to health check failures
- Image pull errors

**Fallback:**
> "This is a transient issue. In a production environment, our monitoring would alert us, and we'd investigate the pod logs. For this demo, let me show you the architecture instead."

---

## POST-DEMO ACTIVITIES

### Immediately After:
1. ✅ Verify application is still running
2. ✅ Check for any error alerts in Azure
3. ✅ Review audience questions you couldn't answer
4. ✅ Send follow-up email with:
   - GitHub repository link
   - Documentation links
   - Answers to unanswered questions

### Within 24 Hours:
1. ✅ Revert any demo-specific code changes
2. ✅ Scale down infrastructure if not needed (`bash scripts/cost_management.sh scale-down`)
3. ✅ Document any issues encountered
4. ✅ Update demo script based on what worked/didn't work

---

## DEMO CHEAT SHEET

### Quick Commands (Keep This Open During Demo)

```powershell
# Get LoadBalancer IP
$IP = kubectl get svc liatrio-demo-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Test endpoint
curl "http://$IP/"

# Get pods
kubectl get pods -l app=liatrio-demo

# Get pod logs
kubectl logs -l app=liatrio-demo --tail=20

# Watch pods (Ctrl+C to stop)
kubectl get pods -l app=liatrio-demo -w

# Get deployment status
kubectl rollout status deployment/liatrio-demo

# Infrastructure status
bash scripts/cost_management.sh status

# Terraform outputs
cd terraform; terraform output; cd ..

# GitHub Actions URL
# https://github.com/<org>/liatrio-demo/actions
```

---

## TIMING GUIDE

| Demo Option | Total Time | Best For |
|-------------|-----------|----------|
| **Option A: GitHub Actions** | 7 min | Automation focus, CI/CD |
| **Option B: Local PowerShell** | 5 min | Infrastructure details, cost |
| **Option C: Code Change** | 10 min | Full developer workflow |

**Recommended:** Start with Option A (GitHub Actions), then if time permits and audience is engaged, show Option B (local tools) as a bonus.

---

**End of Demo Script**
