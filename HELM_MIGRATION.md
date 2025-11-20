# Helm Chart Migration Guide

This document describes the Helm chart implementation for the AKS Demo API and how to use it.

## What Changed

The project now supports both traditional kubectl deployments and modern Helm-based deployments:

- **Old approach**: Manual kubectl apply with sed replacements
- **New approach**: Helm charts with values-based configuration

## Helm Chart Structure

```
helm/aks-demo/
├── Chart.yaml                      # Chart metadata (v1.0.0)
├── values.yaml                     # Default values (dev environment)
├── values-prod.yaml                # Production overrides
├── .helmignore                     # Files to ignore when packaging
├── README.md                       # Chart documentation
└── templates/
    ├── _helpers.tpl                # Reusable template functions
    ├── deployment.yaml             # Deployment manifest template
    ├── service.yaml                # Service manifest template
    ├── serviceaccount.yaml         # ServiceAccount (optional)
    ├── configmap.yaml              # ConfigMap (optional)
    ├── poddisruptionbudget.yaml    # PodDisruptionBudget
    ├── vpa.yaml                    # VerticalPodAutoscaler
    └── NOTES.txt                   # Post-install instructions
```

## Key Features

### 1. Multi-Environment Support

- **Development** (`values.yaml`):
  - 2 replicas
  - Lower resource limits (100m CPU, 128Mi memory)
  - Basic availability requirements

- **Production** (`values-prod.yaml`):
  - 3 replicas
  - Higher resource limits (200m CPU, 256Mi memory)
  - Stricter availability (minAvailable: 2 pods)
  - Enhanced health check timings

### 2. Dynamic Configuration

All key values are templated and configurable:

```yaml
image:
  registry: ""              # Set via --set in CI/CD
  repository: aks-demo
  tag: latest               # Set to commit SHA in CI/CD

replicaCount: 2             # Override per environment

resources:
  requests:
    cpu: 100m
    memory: 128Mi
```

### 3. Security Hardening Preserved

All existing security features are maintained:
- Non-root execution (UID 1000)
- Read-only root filesystem
- Dropped capabilities
- seccomp profile
- No privilege escalation

### 4. High Availability

- PodDisruptionBudget ensures minimum pods available
- Rolling updates with zero downtime
- Automatic rollback on failure (--atomic flag)

## Usage

### Prerequisites

```bash
# Install Helm 3.x
# macOS
brew install helm

# Windows
choco install kubernetes-helm

# Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Quick Start

#### Development Deployment

```powershell
# PowerShell
.\helm_deploy.ps1 -Environment dev
```

```bash
# Bash
./helm_deploy.sh dev
```

#### Production Deployment

```powershell
# PowerShell
.\helm_deploy.ps1 -Environment prod
```

```bash
# Bash
./helm_deploy.sh prod
```

#### Skip Infrastructure (if already deployed)

```powershell
# PowerShell
.\helm_deploy.ps1 -Environment dev -SkipInfra
```

```bash
# Bash
./helm_deploy.sh dev true
```

### Manual Helm Commands

#### Install/Upgrade

```bash
# Development
helm upgrade --install aks-demo ./helm/aks-demo \
  --set image.registry=yourregistry.azurecr.io \
  --set image.tag=v1.0.abc123 \
  --set environment=dev \
  --values ./helm/aks-demo/values.yaml \
  --namespace aks-demo-dev \
  --create-namespace \
  --wait \
  --timeout 5m \
  --atomic

# Production
helm upgrade --install aks-demo ./helm/aks-demo \
  --set image.registry=yourregistry.azurecr.io \
  --set image.tag=v1.0.abc123 \
  --set environment=prod \
  --values ./helm/aks-demo/values-prod.yaml \
  --namespace aks-demo-prod \
  --create-namespace \
  --wait \
  --timeout 5m \
  --atomic
```

#### Validation

```bash
# Lint the chart
helm lint ./helm/aks-demo

# Dry-run (test without deploying)
helm install aks-demo ./helm/aks-demo \
  --dry-run --debug \
  --set image.registry=test.azurecr.io \
  --set image.tag=v1.0.test \
  --namespace aks-demo-dev

# Template rendering (see generated manifests)
helm template aks-demo ./helm/aks-demo \
  --set image.registry=test.azurecr.io \
  --set image.tag=v1.0.test \
  --values ./helm/aks-demo/values.yaml
```

#### Management

```bash
# Check status
helm status aks-demo -n aks-demo-dev

# View release history
helm history aks-demo -n aks-demo-dev

# Get current values
helm get values aks-demo -n aks-demo-dev

# Get all release info
helm get all aks-demo -n aks-demo-dev

# List all releases
helm list -n aks-demo-dev
```

#### Rollback

```bash
# Rollback to previous revision
helm rollback aks-demo -n aks-demo-dev

# Rollback to specific revision
helm rollback aks-demo 3 -n aks-demo-dev

# Dry-run rollback (test without executing)
helm rollback aks-demo 3 -n aks-demo-dev --dry-run
```

#### Uninstall

```bash
# Uninstall release (keeps history)
helm uninstall aks-demo -n aks-demo-dev

# Delete namespace
kubectl delete namespace aks-demo-dev
```

## CI/CD Integration

The GitHub Actions workflow (`ci-cd.yml`) has been updated to use Helm:

### Changes Made

1. **Trigger paths**: Added `helm/**` to watch for chart changes

2. **Helm setup**: Added Helm 3.16.3 installation step

3. **Validation**:
   - Helm lint
   - Dry-run installation
   - Template rendering

4. **Deployment**:
   - Uses `helm upgrade --install` with `--atomic` flag
   - Automatic rollback on failure
   - Namespace-based isolation (e.g., `aks-demo-dev`, `aks-demo-prod`)

5. **Verification**:
   - Helm status checks
   - Pod readiness validation
   - Rollback capability testing
   - Enhanced smoke tests

### Workflow Features

```yaml
- Helm chart linting and validation
- Dry-run before actual deployment
- Atomic deployments (auto-rollback on failure)
- Namespace isolation per environment
- Comprehensive verification steps
- Rollback testing (dry-run)
```

### Environment Variables

The pipeline automatically sets:
- `image.registry`: ACR login server
- `image.tag`: Git commit SHA
- `environment`: dev or prod
- Values file: `values-{environment}.yaml`

## Validation Checklist

Before deploying, ensure:

- [ ] Helm 3.x is installed (`helm version`)
- [ ] kubectl is configured (`kubectl version`)
- [ ] Azure CLI is authenticated (`az account show`)
- [ ] Terraform state exists (if not using `-SkipInfra`)
- [ ] Values files are present for target environment
- [ ] Chart passes lint (`helm lint ./helm/aks-demo`)
- [ ] Dry-run succeeds

## Troubleshooting

### Chart Validation Errors

```bash
# Check for syntax errors
helm lint ./helm/aks-demo --strict

# Render templates to see generated YAML
helm template aks-demo ./helm/aks-demo \
  --set image.registry=test.azurecr.io \
  --set image.tag=v1.0.test \
  --debug
```

### Deployment Failures

```bash
# Check Helm release status
helm status aks-demo -n aks-demo-dev

# View release history
helm history aks-demo -n aks-demo-dev

# Check pod logs
kubectl logs -n aks-demo-dev -l app.kubernetes.io/name=aks-demo

# Describe pods for events
kubectl describe pods -n aks-demo-dev -l app.kubernetes.io/name=aks-demo

# Check all resources
kubectl get all,vpa,pdb -n aks-demo-dev -l app.kubernetes.io/instance=aks-demo
```

### Rollback Issues

```bash
# List available revisions
helm history aks-demo -n aks-demo-dev

# Test rollback with dry-run
helm rollback aks-demo 2 -n aks-demo-dev --dry-run

# Force rollback
helm rollback aks-demo 2 -n aks-demo-dev --force
```

### LoadBalancer Not Getting IP

```bash
# Check service status
kubectl describe svc -n aks-demo-dev -l app.kubernetes.io/name=aks-demo

# Check events
kubectl get events -n aks-demo-dev --sort-by='.lastTimestamp'

# Verify cloud provider integration
kubectl get svc -n aks-demo-dev --watch
```

## Comparison: kubectl vs Helm

| Feature | kubectl | Helm |
|---------|---------|------|
| Deployment method | Manual sed + apply | Templated upgrade |
| Configuration | Hardcoded in files | Values-based |
| Versioning | Manual tracking | Automatic revisions |
| Rollback | Manual | One command |
| Environment separation | None (same namespace) | Namespace per environment |
| Release history | None | Full history |
| Validation | Manual | Built-in lint |
| Complexity | Low | Moderate |
| Production-ready | Yes | **Yes (recommended)** |

## Migration Path

### Existing kubectl Deployments

If you have existing kubectl-based deployments:

1. **Keep running**: Existing deployments are not affected
2. **Deploy with Helm**: Use a new namespace for Helm deployment
3. **Test**: Verify Helm deployment works correctly
4. **Cutover**: Update DNS/LoadBalancer to point to Helm deployment
5. **Cleanup**: Remove old kubectl deployment

```bash
# 1. Deploy with Helm (new namespace)
helm upgrade --install aks-demo ./helm/aks-demo \
  --namespace aks-demo-helm \
  --create-namespace

# 2. Test the new deployment
kubectl get all -n aks-demo-helm

# 3. Compare old vs new
kubectl get svc -n default          # Old
kubectl get svc -n aks-demo-helm  # New

# 4. Cleanup old deployment
kubectl delete -f kubernetes/deployment.yaml
kubectl delete -f kubernetes/vpa.yaml
```

## Best Practices

1. **Always use dry-run first**: Test changes without applying
   ```bash
   helm upgrade aks-demo ./helm/aks-demo --dry-run --debug
   ```

2. **Use specific tags**: Never use `:latest` in production
   ```bash
   --set image.tag=v1.0.abc123  # Good
   --set image.tag=latest        # Bad for prod
   ```

3. **Review diffs before applying**: Use `helm diff` plugin
   ```bash
   helm plugin install https://github.com/databus23/helm-diff
   helm diff upgrade aks-demo ./helm/aks-demo
   ```

4. **Keep values files in version control**: Track all configuration changes

5. **Test rollback procedures**: Practice rollbacks in dev environment

6. **Monitor rollout status**: Always use `--wait` flag

7. **Use atomic deployments**: Enable `--atomic` for auto-rollback

## Additional Resources

- [Helm Documentation](https://helm.sh/docs/)
- [Helm Chart Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Azure AKS + Helm](https://learn.microsoft.com/en-us/azure/aks/kubernetes-helm)
- [Chart Testing](https://github.com/helm/chart-testing)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review Helm logs: `helm status aks-demo -n <namespace>`
3. Check Kubernetes events: `kubectl get events -n <namespace>`
4. Review application logs: `kubectl logs -n <namespace> -l app.kubernetes.io/name=aks-demo`

## Summary

The Helm chart implementation provides:
- ✅ Production-grade deployment management
- ✅ Easy environment-specific configuration
- ✅ Built-in rollback capabilities
- ✅ Automatic versioning and history
- ✅ Namespace isolation
- ✅ Comprehensive validation
- ✅ Full backward compatibility

All existing security, availability, and operational features are preserved while adding enterprise-grade deployment management capabilities.
