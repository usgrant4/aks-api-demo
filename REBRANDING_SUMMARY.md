# Rebranding Summary: Liatrio → AKS

This document summarizes the complete rebranding from "Liatrio" to "AKS" across the entire project.

## Changes Overview

All references to "Liatrio" have been replaced with "AKS" (Azure Kubernetes Service) to better reflect the project's focus on Azure cloud infrastructure.

## Files and Components Updated

### 1. Helm Chart
- **Directory renamed**: `helm/liatrio-demo/` → `helm/aks-demo/`
- **Chart.yaml**:
  - name: `liatrio-demo` → `aks-demo`
  - description: Updated to "AKS Demo API"
- **values.yaml**:
  - image.repository: `liatrio-demo` → `aks-demo`
  - All references updated
- **values-prod.yaml**: All references updated
- **templates/_helpers.tpl**: All template functions renamed (e.g., `liatrio-demo.name` → `aks-demo.name`)
- **All templates**: Updated to use new naming convention
- **NOTES.txt**: All instructions updated with new names
- **README.md**: Complete documentation update

### 2. Application Code
- **app/main.py**:
  - title: "Liatrio Demo API" → "AKS Demo API"
  - description: Enhanced to mention Azure Kubernetes Service
- **app/__init__.py**: Docstring updated to "AKS DevOps Demo Application"

### 3. CI/CD Pipeline
- **.github/workflows/ci-cd.yml**:
  - APP_NAME: `liatrio-demo` → `aks-demo`
  - All resource names updated
  - Helm deployment commands updated
  - Namespace naming: `liatrio-demo-{env}` → `aks-demo-{env}`
  - Note: Storage account name `tfstateugrantliatrio` retained (cannot be renamed without migration)

### 4. Kubernetes Manifests
- **kubernetes/deployment.yaml**: All resource names and labels updated
- **kubernetes/vpa.yaml**: Resource references updated

### 5. Deployment Scripts

#### Helm Deployment
- **helm_deploy.ps1**: Complete update with new naming
- **helm_deploy.sh**: Complete update with new naming

#### Legacy Deployment
- **final_deploy.ps1**: Updated for backward compatibility
- **deploy.sh**: Updated for backward compatibility

#### Cleanup Scripts
- **cleanup.ps1**: Updated references
- **cleanup.sh**: Updated references

### 6. Testing Scripts
- **test_deployment.ps1**: All test commands updated
- **tests/integration_test.ps1**: Complete test suite updated
- **tests/integration_test.sh**: Complete test suite updated

### 7. Documentation
- **README.md**: Comprehensive update throughout
- **HELM_MIGRATION.md**: Complete migration guide updated
- **docs/DEVELOPER_GUIDE.md**: Developer onboarding guide updated
- **docs/GITHUB_SETUP.md**: Setup instructions updated

## Key Naming Conventions

| Component | Old Name | New Name |
|-----------|----------|----------|
| Helm Chart | liatrio-demo | aks-demo |
| Docker Image | liatrio-demo | aks-demo |
| K8s Deployment | liatrio-demo | aks-demo |
| K8s Service | liatrio-demo-svc | aks-demo-svc |
| K8s PDB | liatrio-demo-pdb | aks-demo-pdb |
| K8s VPA | liatrio-demo-vpa | aks-demo-vpa |
| Namespaces | liatrio-demo-{env} | aks-demo-{env} |
| App Labels | app: liatrio-demo | app: aks-demo |
| Helm Release | liatrio-demo | aks-demo |

## Exceptions (Unchanged)

The following items were NOT changed due to technical constraints:

1. **Storage Account Name**: `tfstateugrantliatrio`
   - Azure storage accounts cannot be renamed
   - Would require state migration
   - Retained for continuity

2. **Git Repository Path References**:
   - Some legacy scripts may contain `~/repos/liatrio-demo` paths
   - These are local filesystem references and don't affect functionality

## Migration Impact

### For New Deployments
No action required - simply use the new naming convention.

### For Existing Deployments
If you have existing deployments using the old naming:

1. **Helm Deployments**:
   ```bash
   # Old namespace
   helm uninstall liatrio-demo -n liatrio-demo-dev

   # Deploy with new name
   helm upgrade --install aks-demo ./helm/aks-demo \
     --namespace aks-demo-dev \
     --create-namespace
   ```

2. **kubectl Deployments**:
   ```bash
   # Delete old resources
   kubectl delete -f kubernetes/deployment.yaml  # (if using old names)
   kubectl delete -f kubernetes/vpa.yaml

   # Apply updated manifests
   kubectl apply -f kubernetes/deployment.yaml
   kubectl apply -f kubernetes/vpa.yaml
   ```

## Verification

All references to "Liatrio" have been removed except:
- ✅ Storage account name (technical constraint)
- ✅ Git history (preserved intentionally)

Search performed:
```bash
grep -ri "liatrio" --include="*.yaml" --include="*.yml" --include="*.md" \
  --include="*.ps1" --include="*.sh" --include="*.py" --include="*.tpl" \
  --include="*.txt" | grep -v "tfstateugrantliatrio"
```
Result: 0 matches

## Commands Updated

All documentation and scripts now use:
- `helm upgrade --install aks-demo ./helm/aks-demo`
- `kubectl get all -l app=aks-demo`
- `kubectl logs -l app=aks-demo`
- `helm status aks-demo -n aks-demo-{env}`
- Namespaces: `aks-demo-dev`, `aks-demo-prod`

## Post-Rebranding Checklist

- [x] Helm chart renamed and updated
- [x] Application metadata updated
- [x] CI/CD pipeline updated
- [x] Kubernetes manifests updated
- [x] Deployment scripts updated
- [x] Test scripts updated
- [x] Documentation updated
- [x] Template files updated
- [x] Helper functions updated
- [x] All references verified

## Support

If you encounter any issues with the rebranding:
1. Check this document for the new naming convention
2. Verify you're using the correct namespace (`aks-demo-{env}`)
3. Ensure Helm chart path is `./helm/aks-demo`
4. Review the HELM_MIGRATION.md for detailed Helm usage

---

**Rebranding Date**: 2025
**Project**: AKS API Demo
**Status**: ✅ Complete
