# Developer Guide: Getting Started

This guide will help you get set up and start deploying to the liatrio-demo project in minutes.

## Table of Contents

- [Prerequisites](#prerequisites)
- [One-Time Setup](#one-time-setup)
- [Daily Workflow](#daily-workflow)
- [Testing Your Changes](#testing-your-changes)
- [Deploying to Production](#deploying-to-production)
- [Common Tasks](#common-tasks)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Tools (One-Time Install)

You need these installed on your machine:

| Tool | Purpose | Installation |
|------|---------|--------------|
| **Git** | Version control | [git-scm.com](https://git-scm.com/downloads) |
| **Python 3.11+** | Local development and testing | [python.org](https://www.python.org/downloads/) |
| **GitHub Account** | Access to repository | [github.com/signup](https://github.com/signup) |

### Optional Tools (Recommended)

| Tool | Purpose | Installation |
|------|---------|--------------|
| **VS Code** | Code editor | [code.visualstudio.com](https://code.visualstudio.com/) |
| **Azure CLI** | Troubleshooting deployments | [docs.microsoft.com/cli/azure/install-azure-cli](https://docs.microsoft.com/cli/azure/install-azure-cli) |
| **kubectl** | Kubernetes debugging | [kubernetes.io/docs/tasks/tools/](https://kubernetes.io/docs/tasks/tools/) |
| **Docker Desktop** | Local container testing | [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/) |

**Note:** Azure CLI, kubectl, and Docker are NOT required for daily development. The CI/CD pipeline handles all deployment tasks automatically.

## One-Time Setup

### Step 1: Clone the Repository

```bash
# Clone the repo
git clone https://github.com/<your-org>/liatrio-demo.git
cd liatrio-demo

# Checkout the dev branch (where you'll work)
git checkout dev
```

### Step 2: Set Up Python Environment

```bash
# Create a virtual environment (recommended)
python -m venv venv

# Activate it
# On Windows:
venv\Scripts\activate
# On Mac/Linux:
source venv/bin/activate

# Install dependencies
pip install -r app/requirements.txt
```

### Step 3: Verify Local Setup

```bash
# Run the app locally
cd app
uvicorn main:app --reload --host 0.0.0.0 --port 8080

# In another terminal, test it:
curl http://localhost:8080/
# Should return: {"message": "Automate all the things!", "timestamp": 1234567890}

# Test health endpoint:
curl http://localhost:8080/health
# Should return: {"status": "healthy", "timestamp": 1234567890}
```

### Step 4: Run Tests Locally

```bash
# From project root
pytest -v

# You should see:
# test_api.py::test_read_main PASSED
# test_api.py::test_health_check PASSED
# test_api.py::test_timestamp_is_current PASSED
```

**✅ If tests pass, you're ready to develop!**

## Daily Workflow

### Simple 3-Step Process

```bash
# 1. Make your changes
vim app/main.py  # Edit the code

# 2. Test locally
pytest -v  # Ensure tests pass

# 3. Commit and push
git add app/main.py
git commit -m "feat: add new feature"
git push origin dev
```

**That's it!** The CI/CD pipeline automatically:
- Runs tests
- Builds Docker image
- Deploys to development environment
- Runs smoke tests
- Reports success/failure

### Monitoring Your Deployment

After pushing, watch the deployment:

1. **GitHub Actions Tab**
   - Go to: `https://github.com/<your-org>/liatrio-demo/actions`
   - Click on your commit message
   - Watch the pipeline run in real-time

2. **Deployment Time**
   - First deployment: ~10-12 minutes
   - Subsequent deployments: ~5-8 minutes

3. **Finding Your Deployed App**
   - Look for "Deployment successful" in the logs
   - Copy the IP address shown: `API Endpoint: http://X.X.X.X/`
   - Test: `curl http://X.X.X.X/`

## Testing Your Changes

### Local Testing (Before Pushing)

Always test locally first to catch issues early:

```bash
# 1. Run the app locally
uvicorn app.main:app --reload --port 8080

# 2. Test your endpoints
curl http://localhost:8080/          # Main endpoint
curl http://localhost:8080/health    # Health check
curl http://localhost:8080/new-endpoint  # Your new endpoint

# 3. Run automated tests
pytest -v

# 4. Check code style (optional)
flake8 app/
```

### Testing in Development Environment

After the CI/CD pipeline deploys:

```bash
# Get the LoadBalancer IP from the GitHub Actions logs
# Or use Azure CLI (if you have it installed):
az aks get-credentials -g ugrant-liatrio-demo-dev-rg -n ugrant-liatrio-demo-dev-aks
kubectl get svc liatrio-demo-svc

# Test the deployed app
DEV_IP="<your-loadbalancer-ip>"
curl http://$DEV_IP/
curl http://$DEV_IP/health

# Check pod logs
kubectl logs -l app=liatrio-demo --tail=50

# Check pod status
kubectl get pods -l app=liatrio-demo
```

## Deploying to Production

### Option 1: Via Pull Request (Recommended)

```bash
# 1. Ensure your changes are stable in dev
git checkout dev
git pull origin dev

# 2. Create a Pull Request in GitHub UI
# Go to: https://github.com/<your-org>/liatrio-demo
# Click: "Pull requests" → "New pull request"
# Base: main ← Compare: dev
# Fill out description
# Click: "Create pull request"

# 3. Get code review and approval
# (Request review from team member)

# 4. Merge the PR
# Click: "Squash and merge" or "Merge pull request"

# 5. Monitor production deployment
# Go to Actions tab and watch deployment to production
```

**Note:** If GitHub Environment protection is configured (requires GitHub Team), you'll need to approve the production deployment manually.

### Option 2: Manual Workflow Dispatch

```bash
# 1. Go to GitHub Actions tab
# 2. Click "ci-cd" workflow
# 3. Click "Run workflow" button
# 4. Select:
#    - Action to perform: "deploy"
#    - Target environment: "prod"
# 5. Click "Run workflow"
# 6. Monitor deployment in Actions tab
```

## Common Tasks

### Adding a New Endpoint

```python
# app/main.py

@app.get("/newfeature")
async def new_feature():
    """Description of what this endpoint does"""
    return {
        "feature": "my awesome feature",
        "timestamp": get_current_timestamp()
    }
```

**Test it:**
```bash
# Locally
uvicorn app.main:app --reload --port 8080
curl http://localhost:8080/newfeature

# Commit and push
git add app/main.py
git commit -m "feat: add newfeature endpoint"
git push origin dev
```

### Changing the Message

```python
# app/main.py

@app.get("/")
async def read_root():
    return {
        "message": "Your new message here!",  # ← Change this
        "timestamp": get_current_timestamp()
    }
```

### Adding Dependencies

```bash
# 1. Add to requirements.txt
echo "requests==2.31.0" >> app/requirements.txt

# 2. Install locally
pip install -r app/requirements.txt

# 3. Use in your code
# app/main.py
import requests

# 4. Commit and push
git add app/requirements.txt app/main.py
git commit -m "feat: add requests library for HTTP calls"
git push origin dev
```

### Writing Tests for Your Code

```python
# test_api.py

from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_new_endpoint():
    """Test the new endpoint you added"""
    response = client.get("/newfeature")
    assert response.status_code == 200
    data = response.json()
    assert "feature" in data
    assert data["feature"] == "my awesome feature"
```

**Run tests:**
```bash
pytest -v
```

### Viewing Logs

```bash
# If you have kubectl configured:
kubectl logs -l app=liatrio-demo --tail=100 -f

# Or view logs in Azure Portal:
# 1. Go to portal.azure.com
# 2. Navigate to your AKS cluster
# 3. Kubernetes resources → Workloads → Pods
# 4. Click on a pod → Logs
```

### Checking Deployment Status

```bash
# Check pods
kubectl get pods -l app=liatrio-demo

# Check service
kubectl get svc liatrio-demo-svc

# Check deployment
kubectl get deployment liatrio-demo

# Describe pod for details
kubectl describe pod <pod-name>
```

### Rolling Back a Deployment

If something goes wrong in production:

```bash
# Option 1: Revert the commit
git checkout main
git revert <bad-commit-sha>
git push origin main
# This triggers automatic redeployment

# Option 2: Use workflow dispatch with old commit
# Go to Actions → ci-cd → Run workflow
# Select "deploy" and "prod"
# Use a previous stable commit SHA

# Option 3: Emergency destroy and redeploy
# Go to Actions → ci-cd → Run workflow
# Select "destroy" and "prod"
# Wait for destroy to complete
# Then select "deploy" and "prod"
```

## Troubleshooting

### Tests Fail Locally

```bash
# Problem: pytest fails
# Solution: Ensure you have all dependencies
pip install -r app/requirements.txt

# Problem: Import errors
# Solution: Run pytest from project root, not app/ directory
cd /path/to/liatrio-demo
pytest -v
```

### App Doesn't Start Locally

```bash
# Problem: Port 8080 already in use
# Solution: Use a different port
uvicorn app.main:app --reload --port 8000

# Problem: Module not found
# Solution: Ensure you're in the right directory
cd /path/to/liatrio-demo
python -m uvicorn app.main:app --reload
```

### GitHub Actions Deployment Fails

**Check the logs:**
1. Go to Actions tab
2. Click on the failed workflow
3. Expand the failed step
4. Read the error message

**Common issues:**

| Error | Solution |
|-------|----------|
| `pytest failed` | Fix your code, tests must pass |
| `Docker build failed` | Check Dockerfile syntax, review build logs |
| `Terraform error` | Usually infrastructure issue, notify DevOps team |
| `Pods not ready` | Check pod logs for application errors |
| `Smoke tests failed` | App not responding, check pod logs |

### Deployment Succeeds But App Not Working

```bash
# 1. Check pod status
kubectl get pods -l app=liatrio-demo

# 2. Check pod logs
kubectl logs -l app=liatrio-demo --tail=50

# 3. Describe pod for events
kubectl describe pod <pod-name>

# 4. Check if service has IP
kubectl get svc liatrio-demo-svc

# Common issues:
# - ImagePullBackOff: Docker image not in registry
# - CrashLoopBackOff: App is crashing, check logs
# - Pending: Not enough resources, check node status
```

### Can't Access Deployed App

```bash
# 1. Get the LoadBalancer IP
kubectl get svc liatrio-demo-svc

# 2. Verify it's assigned
# Status should show EXTERNAL-IP (not <pending>)

# 3. Test connectivity
curl http://<external-ip>/health

# 4. Check firewall/security groups
# Azure should allow traffic by default, but verify in portal
```

### Git Issues

```bash
# Problem: Can't push to dev
# Solution: Ensure you're on dev branch
git checkout dev
git pull origin dev
git push origin dev

# Problem: Merge conflicts
# Solution: Pull latest and resolve
git pull origin dev
# Fix conflicts in your editor
git add .
git commit -m "fix: resolve merge conflicts"
git push origin dev

# Problem: Accidentally pushed to wrong branch
# Solution: Contact team lead to help revert
```

## Quick Reference

### Essential Commands

```bash
# Daily development
git checkout dev
git pull origin dev
# ... make changes ...
pytest -v
git add .
git commit -m "feat: description"
git push origin dev

# Local testing
uvicorn app.main:app --reload --port 8080
curl http://localhost:8080/
pytest -v

# Check deployment status (requires kubectl)
kubectl get pods -l app=liatrio-demo
kubectl get svc liatrio-demo-svc
kubectl logs -l app=liatrio-demo --tail=50
```

### Important URLs

- **Repository**: `https://github.com/<your-org>/liatrio-demo`
- **GitHub Actions**: `https://github.com/<your-org>/liatrio-demo/actions`
- **Azure Portal**: `https://portal.azure.com`

### Getting Help

1. **Check GitHub Actions logs** - Most deployment issues show up here
2. **Check pod logs** - Application errors show up here
3. **Review this guide** - Most common tasks are covered
4. **Ask team members** - They've likely seen the issue before
5. **Check README.md** - Detailed infrastructure documentation

## Summary: Your Typical Day

```bash
# Morning: Get latest code
git checkout dev
git pull origin dev

# Work: Make changes
vim app/main.py
pytest -v  # Test locally

# Deploy: Push to dev
git add .
git commit -m "feat: new feature"
git push origin dev

# Monitor: Watch GitHub Actions
# Open browser → GitHub → Actions tab
# Wait ~10 minutes
# See "Deployment successful"

# Test: Verify in dev environment
curl http://<dev-ip>/

# Afternoon: Push to production (when ready)
# Create PR: dev → main
# Get review → Merge
# Monitor production deployment

# Done! 🎉
```

## Best Practices

1. **Always test locally first** - Catch issues before pushing
2. **Run pytest before pushing** - Don't break the build
3. **Use descriptive commit messages** - `feat:`, `fix:`, `docs:`
4. **Push small, frequent changes** - Easier to debug
5. **Monitor your deployments** - Check GitHub Actions after pushing
6. **Test in dev before production** - Ensure stability
7. **Keep your branch updated** - `git pull origin dev` frequently
8. **Don't commit secrets** - Never push API keys or passwords

## Next Steps

Now that you're set up:

1. ✅ Clone the repository
2. ✅ Install Python dependencies
3. ✅ Run tests locally (`pytest -v`)
4. ✅ Make a small change to `app/main.py`
5. ✅ Push to dev and watch it deploy
6. ✅ Test your deployed app
7. ✅ Celebrate! You're a DevOps developer now! 🚀

For more detailed information, see:
- [README.md](README.md) - Full project documentation
- [.github/workflows/ci-cd.yml](.github/workflows/ci-cd.yml) - CI/CD pipeline details
- [app/main.py](app/main.py) - Application code
- [test_api.py](test_api.py) - Test examples
