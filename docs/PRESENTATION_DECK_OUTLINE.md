# Liatrio DevOps Demo - Presentation Deck Outline

## Slide Deck Structure (15-20 slides)

---

### **SECTION 1: INTRODUCTION & CONTEXT** (3 slides)

#### Slide 1: Title Slide
**Title:** Liatrio DevOps Demo - Azure AKS Deployment
**Subtitle:** Production-Ready CI/CD with Infrastructure as Code
**Presenter:** [Your Name]
**Date:** [Presentation Date]

**Visual:** Liatrio logo + Azure/Kubernetes icons

---

#### Slide 2: Agenda
**Title:** What We'll Cover Today

**Content:**
- Project Overview & Objectives
- Collaborative Design Process
- Architecture & Design Decisions
- Live Demo: Deployment Workflow
- Technical Deep Dive
- Q&A

**Speaking Notes:**
> "We'll start with the business context, walk through how I approached the design collaboratively, dive into the architecture, show you a live deployment, and wrap up with technical details. Questions are welcome throughout."

---

#### Slide 3: Alignment & Discovery
**Title:** Design Approach - Collaborative & Iterative

**Content - Left Column:**
**Questions I Asked Before Designing:**
1. ✓ Governance & compliance standards?
2. ✓ Security & access control requirements?
3. ✓ Workload criticality & availability needs?
4. ✓ Observability & monitoring expectations?
5. ✓ Future integration & reusability goals?

**Content - Right Column:**
**Working Assumptions Made:**
- Azure best practices for governance
- OIDC authentication with managed identities
- High availability, single-region deployment
- Basic observability with extensibility
- Modular, reusable architecture

**Visual:** Question mark icons → Checkmark icons (showing progression)

**Speaking Notes:**
> "Before diving into the design, I wanted to make sure I'm aligned on any existing context or constraints. I asked these five questions to understand governance, security, availability, observability, and reusability requirements. Where we didn't have predefined answers, I made these working assumptions based on industry best practices — but everything is adjustable based on your feedback."

**[THIS IS WHERE YOU ASK YOUR QUESTIONS TO THE AUDIENCE]**

---

### **SECTION 2: PROJECT OVERVIEW** (2 slides)

#### Slide 4: Project Objectives
**Title:** What We're Building & Why

**Content:**
**Primary Goal:**
> Deploy a production-ready containerized REST API to Azure AKS with fully automated CI/CD

**Success Criteria:**
- ✅ Infrastructure as Code (Terraform)
- ✅ Containerized application (Docker)
- ✅ Automated CI/CD pipeline (GitHub Actions)
- ✅ Zero-downtime deployments
- ✅ Comprehensive testing
- ✅ Cost-optimized architecture

**Business Value:**
- Demonstrates modern DevOps practices
- Reduces deployment time from hours to minutes
- Eliminates manual configuration errors
- Enables rapid iteration and scaling

**Visual:** Before/After diagram (manual vs automated)

---

#### Slide 5: Technology Stack
**Title:** Technologies & Tools

**Content - Grid Layout:**

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Cloud** | Azure (ACR, AKS) | Container registry & orchestration |
| **IaC** | Terraform 1.9.6 | Infrastructure provisioning |
| **Application** | Python 3.11 + FastAPI | REST API framework |
| **Container** | Docker (multi-stage) | Application packaging |
| **Orchestration** | Kubernetes 1.32.7 | Container management |
| **CI/CD** | GitHub Actions | Automation pipeline |
| **Authentication** | OIDC + Managed Identity | Secure, passwordless auth |
| **Testing** | pytest + integration suite | Quality assurance |

**Visual:** Icons for each technology in a layered architecture diagram

---

### **SECTION 3: ARCHITECTURE & DESIGN** (5 slides)

#### Slide 6: High-Level Architecture
**Title:** Solution Architecture Overview

**Visual:** Architecture diagram (from README.md lines 435-506)
```
Developer → GitHub Actions → Azure Infrastructure
                ↓
    ┌───────────────────────────┐
    │   Terraform (IaC)         │
    │   - Resource Group        │
    │   - ACR                   │
    │   - AKS                   │
    └───────────────────────────┘
                ↓
    ┌───────────────────────────┐
    │   CI/CD Pipeline          │
    │   - Build & Test          │
    │   - Docker Build          │
    │   - Deploy to K8s         │
    │   - Smoke Tests           │
    └───────────────────────────┘
                ↓
    ┌───────────────────────────┐
    │   AKS Cluster             │
    │   - 2 Replicas (HA)       │
    │   - LoadBalancer Service  │
    │   - Health Probes         │
    │   - VPA (Auto-scaling)    │
    └───────────────────────────┘
                ↓
            End Users
```

**Speaking Notes:**
> "This is the end-to-end architecture. Developers push code, GitHub Actions orchestrates the entire deployment, Terraform manages infrastructure, and the app runs in AKS with high availability."

---

#### Slide 7: Design Decision 1 - Security & Authentication
**Title:** Security Architecture - Zero Trust Approach

**Content:**

**Challenge:**
How do we securely authenticate GitHub Actions to Azure without storing long-lived credentials?

**Decision:**
Implement OIDC-based federated authentication with Azure Entra ID

**Implementation:**
```yaml
✓ OIDC Federation (GitHub ↔ Azure Entra ID)
✓ Managed Identities (AKS → ACR via AcrPull role)
✓ ACR Admin Disabled (no static credentials)
✓ GitHub Secrets (client ID, tenant ID, subscription ID only)
✓ Non-root Containers (UID 1000, minimal privileges)
✓ Azure Network Policy (pod-level segmentation)
```

**Benefits:**
- ✅ No long-lived secrets in GitHub
- ✅ Automatic credential rotation
- ✅ Least-privilege access model
- ✅ Meets enterprise security standards

**Visual:** Flow diagram showing OIDC token exchange

---

#### Slide 8: Design Decision 2 - High Availability
**Title:** High Availability & Zero-Downtime Deployments

**Challenge:**
How do we ensure the application remains available during updates and failures?

**Decision:**
Multi-replica deployment with rolling updates and pod disruption budgets

**Implementation:**
```yaml
Deployment Configuration:
  ✓ Replicas: 2 (active-active)
  ✓ Rolling Update Strategy:
    - maxSurge: 1 (allows 3 pods during rollout)
    - maxUnavailable: 0 (zero downtime)
  ✓ PodDisruptionBudget: minAvailable: 1
  ✓ Readiness Probes: /health (5s delay, 10s period)
  ✓ Liveness Probes: /health (15s delay, 20s period)
```

**Testing Results:**
- ✅ Pod deletion test: Service remained available (8/10 requests succeeded)
- ✅ Rolling update: Zero dropped requests
- ✅ Graceful shutdown: 30s termination grace period

**Visual:** Timeline diagram showing rolling update with no downtime

---

#### Slide 9: Design Decision 3 - Cost Optimization
**Title:** Cost Optimization Strategy

**Challenge:**
How do we balance production-readiness with cost efficiency for a demo?

**Decision:**
Right-sized infrastructure with Vertical Pod Autoscaler and scale-down capabilities

**Implementation:**

**Infrastructure Costs:**
| Resource | SKU | Monthly Cost |
|----------|-----|--------------|
| AKS Control Plane | Free Tier | $0 |
| AKS Node Pool | Standard_D2s_v3 (x1) | ~$70 |
| Azure Container Registry | Basic | ~$5 |
| Load Balancer | Standard | ~$5-10 |
| **Total (24/7)** | | **~$80-90/month** |

**Cost Optimization Features:**
- ✅ VPA (Vertical Pod Autoscaler) - Auto-rightsizes resources
- ✅ Scale-to-zero capability - `cost_management.sh scale-down` (~$35/month savings)
- ✅ Single-region deployment - Avoids cross-region traffic costs
- ✅ Free AKS control plane - No management fees

**Visual:** Cost breakdown pie chart

---

#### Slide 10: Design Decision 4 - Observability
**Title:** Observability & Testing Strategy

**Challenge:**
How do we ensure deployment quality and enable rapid troubleshooting?

**Decision:**
Multi-layered testing with health probes and automated validation

**Implementation:**

**Testing Layers:**
1. **Unit Tests** (pytest)
   - Run on every commit
   - Validate application logic

2. **Integration Tests** (10 comprehensive tests)
   - API connectivity & response structure
   - Health endpoint validation
   - Performance benchmarks (response time <500ms)
   - High availability testing
   - Concurrent load handling (50 parallel requests)

3. **Smoke Tests** (CI/CD pipeline)
   - Post-deployment validation
   - LoadBalancer IP verification
   - Live endpoint testing

4. **Health Probes** (Kubernetes)
   - Readiness: Is the pod ready to serve traffic?
   - Liveness: Is the application healthy?

**Extensibility:**
Ready to integrate Azure Monitor, Application Insights, or Prometheus/Grafana

**Visual:** Testing pyramid diagram

---

### **SECTION 4: LIVE DEMO** (1 slide + demo)

#### Slide 11: Live Demo - What We'll Show
**Title:** Live Demonstration - End-to-End Deployment

**What We'll Demonstrate:**

**Option A: GitHub Actions Deployment**
1. Trigger manual workflow dispatch
2. Watch infrastructure provisioning (Terraform)
3. Observe container build and push to ACR
4. Monitor Kubernetes deployment
5. Validate with smoke tests
6. Access live API endpoint

**Option B: Local Deployment**
1. Run `final_deploy.ps1`
2. Show Terraform apply
3. Watch ACR build
4. Monitor pod rollout
5. Run integration tests
6. Demonstrate live endpoint

**Duration:** 5-7 minutes

**Speaking Notes:**
> "Let me show you this in action. I'm going to trigger a deployment and walk you through each phase. You'll see infrastructure provisioning, container builds, Kubernetes orchestration, and automated testing — all happening automatically."

**[SWITCH TO LIVE DEMO]**

---

### **SECTION 5: TECHNICAL DEEP DIVE** (5 slides)

#### Slide 12: CI/CD Pipeline Architecture
**Title:** GitHub Actions Workflow Breakdown

**Content:**

**Workflow Triggers:**
```yaml
on:
  push:
    branches: [main, dev]
    paths:
      - "app/**"           # Application code
      - "Dockerfile"       # Container config
      - "kubernetes/**"    # K8s manifests
      - "terraform/**"     # Infrastructure
      - ".github/workflows/ci-cd.yml"

  workflow_dispatch:       # Manual triggers
    inputs:
      action: [deploy, destroy]
      environment: [dev, prod]
```

**Pipeline Stages:**
1. **Build & Test** (pytest unit tests)
2. **Deploy** (Terraform init/apply)
3. **Fetch Outputs** (ACR, AKS, Resource Group)
4. **Build Image** (ACR build task)
5. **Deploy to K8s** (kubectl apply)
6. **Wait for Rollout** (kubectl rollout status)
7. **Verify Deployment** (smoke tests)

**Smart Path Filtering:**
- Only triggers on functional changes (app, Docker, K8s, Terraform)
- Skips deployment for README/docs updates
- Saves costs and pipeline execution time

**Visual:** Pipeline flow diagram with stages

---

#### Slide 13: Infrastructure as Code - Terraform
**Title:** Terraform Configuration & State Management

**Content:**

**Resources Provisioned:**
```hcl
module "liatrio_demo" {
  source = "./terraform"

  # Core Infrastructure
  - azurerm_resource_group
  - azurerm_container_registry (Basic SKU, admin disabled)
  - azurerm_kubernetes_cluster (AKS 1.32.7)
    - Node pool: 1x Standard_D2s_v3
    - Network: Azure CNI + Azure Network Policy
    - Identity: System-assigned managed identity
  - azurerm_role_assignment (AcrPull: AKS → ACR)
}
```

**State Management Strategy:**
```
Backend: Azure Storage (remote state)
├── tfstate-rg (Resource Group)
├── tfstateugrantliatrio (Storage Account)
└── tfstate (Container)
    ├── liatrio-demo-dev.tfstate    # Dev environment
    └── liatrio-demo-prod.tfstate   # Prod environment
```

**Key Benefits:**
- ✅ Environment isolation (separate state files)
- ✅ Shared backend for collaboration
- ✅ State locking prevents conflicts
- ✅ Disaster recovery (state versioning)

**Visual:** Terraform state diagram

---

#### Slide 14: Kubernetes Deployment Configuration
**Title:** Kubernetes Resource Manifests

**Content:**

**Deployment Spec:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: liatrio-demo
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    spec:
      containers:
      - name: api
        image: {ACR}/liatrio-demo:v1.0.{sha}
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 20
```

**Additional Resources:**
- Service (LoadBalancer, port 80 → 8080)
- PodDisruptionBudget (minAvailable: 1)
- VerticalPodAutoscaler (auto-rightsizing)

**Visual:** Kubernetes object diagram

---

#### Slide 15: Application Architecture
**Title:** FastAPI Application Design

**Content:**

**Application Stack:**
```
Python 3.11 + FastAPI 0.115.5
├── Multi-stage Dockerfile
│   ├── Builder stage: Create virtual environment
│   └── Runtime stage: Python 3.11-slim (minimal attack surface)
├── Non-root user (UID 1000)
└── Health check included
```

**API Endpoints:**
```python
GET /
Response: {
  "message": "Automate all the things!",
  "timestamp": 1760846168
}

GET /health
Response: {
  "status": "healthy",
  "timestamp": 1760846168
}
```

**Performance Metrics:**
- Response Time: <50ms average, <100ms p99
- Container Startup: 3-5 seconds
- Concurrent Requests: 50+ parallel requests (tested)

**Visual:** Application architecture diagram

---

#### Slide 16: Deployment Workflow & Automation
**Title:** End-to-End Deployment Flow

**Visual:** Sequence diagram showing:

```
Developer → GitHub → GitHub Actions → Azure
    │          │           │              │
    │  Push    │           │              │
    │─────────>│           │              │
    │          │ Trigger   │              │
    │          │──────────>│              │
    │          │           │  Terraform   │
    │          │           │─────────────>│
    │          │           │  ACR Build   │
    │          │           │─────────────>│
    │          │           │  Deploy K8s  │
    │          │           │─────────────>│
    │          │           │  Smoke Test  │
    │          │           │─────────────>│
    │          │           │  Success ✓   │
    │          │           │<─────────────│
    │          │  Notify   │              │
    │<─────────│───────────│              │
```

**Automation Features:**
- ✅ Automatic backend setup (creates storage if missing)
- ✅ Terraform state locking (prevents concurrent runs)
- ✅ Rollback on failure (restores previous deployment)
- ✅ Concurrency control (per-environment locks)
- ✅ Manual destroy capability (workflow_dispatch)

---

### **SECTION 6: OPERATIONAL EXCELLENCE** (2 slides)

#### Slide 17: Operational Tools & Scripts
**Title:** Supporting Tools & Utilities

**Content:**

**Cost Management (`scripts/cost_management.sh`):**
```bash
bash cost_management.sh scale-down  # Save ~$35/month
bash cost_management.sh scale-up    # Restore functionality
bash cost_management.sh status      # Check infrastructure
bash cost_management.sh cleanup     # Destroy everything
```

**Deployment Scripts:**
- `final_deploy.ps1` - Complete automated deployment (PowerShell)
- `deploy.sh` - Alternative bash deployment
- `cleanup.ps1` / `cleanup.sh` - Complete cleanup with Network Watcher handling

**Testing Scripts:**
- `test_deployment.ps1` - Comprehensive test suite (8 tests)
- `tests/integration_test.sh` - 10 integration tests

**Development Workflow:**
- `sync-workflow-to-main.sh` - Sync workflow changes dev → main

**Visual:** Toolbox icon with script categories

---

#### Slide 18: Monitoring & Troubleshooting
**Title:** Day 2 Operations

**Content:**

**Common Operations:**
```bash
# View all resources
kubectl get all -l app=liatrio-demo

# Stream logs
kubectl logs -l app=liatrio-demo -f

# Check rollout status
kubectl rollout status deployment/liatrio-demo

# Restart deployment
kubectl rollout restart deployment/liatrio-demo

# Scale manually
kubectl scale deployment liatrio-demo --replicas=3

# Check VPA recommendations
kubectl describe vpa liatrio-demo-vpa
```

**Troubleshooting Guide:**
- ImagePullBackOff → Verify ACR attachment
- LoadBalancer IP not assigned → Check Azure quotas
- CrashLoopBackOff → Check pod logs and resource limits
- Terraform state locked → Force unlock with lock ID

**Visual:** Operations workflow diagram

---

### **SECTION 7: WRAP-UP** (2 slides)

#### Slide 19: Key Takeaways & Best Practices
**Title:** What We've Demonstrated

**Content:**

**DevOps Best Practices Showcased:**

1. **Infrastructure as Code**
   - Declarative configuration with Terraform
   - Environment isolation with separate state files
   - Version-controlled infrastructure

2. **Security First**
   - OIDC-based passwordless authentication
   - Managed identities (no static credentials)
   - Network policies and non-root containers

3. **High Availability**
   - Multi-replica deployments
   - Zero-downtime rolling updates
   - Pod disruption budgets

4. **Cost Optimization**
   - Vertical Pod Autoscaler
   - Scale-to-zero capability
   - Right-sized infrastructure

5. **Quality Assurance**
   - Multi-layered testing (unit, integration, smoke)
   - Automated validation in CI/CD
   - Health probes for self-healing

6. **Operational Excellence**
   - Comprehensive documentation
   - Utility scripts for common tasks
   - Modular, reusable architecture

**Visual:** Checkmark icons for each practice

---

#### Slide 20: Next Steps & Q&A
**Title:** Where Do We Go From Here?

**Content:**

**Potential Enhancements:**
- 🔄 Multi-region deployment with Traffic Manager
- 📊 Azure Monitor + Application Insights integration
- 🔐 Azure Key Vault for application secrets
- 🚀 Horizontal Pod Autoscaler (HPA) based on metrics
- 🌐 Custom domain with Azure Front Door
- 📦 Helm charts for package management
- 🔄 GitOps with Flux or Argo CD

**Reusability:**
- Extract Terraform module for registry
- Template GitHub Actions workflow
- Document as reference architecture
- Create client-specific variants

**Questions?**

**Contact:**
- GitHub Repository: [link]
- Documentation: See README.md
- Demo Environment: [Azure Portal link]

---

## Presentation Flow Summary

**Total Time: 45-60 minutes**

| Section | Slides | Duration | Notes |
|---------|--------|----------|-------|
| Introduction | 1-3 | 5 min | Ask alignment questions on slide 3 |
| Project Overview | 4-5 | 5 min | Set context |
| Architecture | 6-10 | 15 min | Deep dive on design decisions |
| Live Demo | 11 | 10 min | Hands-on demonstration |
| Technical Deep Dive | 12-16 | 15 min | Implementation details |
| Operations | 17-18 | 5 min | Day 2 operations |
| Wrap-up | 19-20 | 5 min | Summary & Q&A |

---

## Presenter Notes

### Before the Presentation:
1. ✅ Test live demo environment (ensure it's deployed)
2. ✅ Have backup screenshots in case of network issues
3. ✅ Prepare speaker notes for each slide
4. ✅ Test slide transitions and animations
5. ✅ Prepare answers to common questions (see FAQ section)

### During the Presentation:
1. **Slide 3 is critical** - This is where you demonstrate collaborative thinking
2. Pause after each design decision slide to gauge understanding
3. Keep live demo to 7 minutes max (practice beforehand)
4. Encourage questions throughout, not just at the end
5. Use the architecture diagrams to tell a story, not just list features

### Common Questions to Prepare For:
- **Q:** Why Azure instead of AWS or GCP?
  - **A:** Client preference, but architecture is cloud-agnostic

- **Q:** How long does a deployment take?
  - **A:** ~10-12 minutes first run, ~2-3 minutes for updates

- **Q:** What's the monthly cost?
  - **A:** ~$80-90 running 24/7, ~$10-15 when scaled down

- **Q:** Can this scale to production workloads?
  - **A:** Yes, designed with production patterns (HA, security, monitoring)

- **Q:** How do you handle secrets?
  - **A:** OIDC + managed identities (zero static credentials)

---

## Visual Design Recommendations

**Color Scheme:**
- Primary: Liatrio brand colors
- Accent: Azure blue (#0078D4)
- Success: Green (#107C10)
- Warning: Orange (#FF8C00)

**Fonts:**
- Headers: Bold, sans-serif (Arial, Calibri)
- Body: Regular, sans-serif
- Code: Monospace (Consolas, Courier New)

**Icons:**
- Use Azure official icons for services
- Kubernetes icons for container concepts
- Font Awesome for general icons (✓, ✗, ⚠️)

---

## Appendix: Backup Slides (Optional)

### Backup Slide A: Detailed Cost Breakdown
### Backup Slide B: Terraform Variables Reference
### Backup Slide C: GitHub Actions Workflow YAML
### Backup Slide D: Network Architecture Diagram
### Backup Slide E: Disaster Recovery Strategy

---

**End of Presentation Deck Outline**
