# AKS Demo Helm Chart

A production-ready Helm chart for deploying the AKS Demo API to Azure Kubernetes Service (AKS).

## Prerequisites

- Kubernetes 1.32+
- Helm 3.0+
- Azure Container Registry (ACR) with the application image
- Vertical Pod Autoscaler (VPA) enabled on the cluster (optional)

## Features

- **Multi-environment Support**: Separate values files for dev, staging, and production
- **Security Hardened**: Non-root containers, read-only filesystem, dropped capabilities
- **High Availability**: Pod Disruption Budget, multiple replicas, zero-downtime rolling updates
- **Auto-scaling**: Vertical Pod Autoscaler support
- **Health Checks**: Readiness and liveness probes
- **Flexible Configuration**: Extensive customization through values

## Installation

### Quick Start (Development)

```bash
helm install aks-demo ./helm/aks-demo \
  --set image.registry=yourregistry.azurecr.io \
  --set image.tag=latest \
  --create-namespace \
  --namespace aks-demo
```

### Production Deployment

```bash
helm install aks-demo ./helm/aks-demo \
  --set image.registry=yourregistry.azurecr.io \
  --set image.tag=v1.0.0 \
  --values ./helm/aks-demo/values-prod.yaml \
  --create-namespace \
  --namespace aks-demo-prod
```

### Using CI/CD

The chart is designed to work with automated CI/CD pipelines:

```bash
helm upgrade --install aks-demo ./helm/aks-demo \
  --set image.registry=$ACR_REGISTRY \
  --set image.tag=$GITHUB_SHA \
  --set environment=$ENVIRONMENT \
  --values ./helm/aks-demo/values-$ENVIRONMENT.yaml \
  --wait --timeout 5m \
  --namespace aks-demo-$ENVIRONMENT
```

## Configuration

### Key Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `2` |
| `environment` | Environment name (dev/staging/prod) | `dev` |
| `image.registry` | Container registry URL | `""` |
| `image.repository` | Image repository name | `aks-demo` |
| `image.tag` | Image tag | `latest` |
| `image.pullPolicy` | Image pull policy | `Always` |
| `service.type` | Kubernetes service type | `LoadBalancer` |
| `service.port` | Service port | `80` |
| `service.targetPort` | Container port | `8080` |
| `resources.requests.cpu` | CPU request | `100m` |
| `resources.requests.memory` | Memory request | `128Mi` |
| `resources.limits.cpu` | CPU limit | `200m` |
| `resources.limits.memory` | Memory limit | `256Mi` |
| `podDisruptionBudget.enabled` | Enable PDB | `true` |
| `podDisruptionBudget.minAvailable` | Minimum available pods | `1` |
| `vpa.enabled` | Enable Vertical Pod Autoscaler | `true` |
| `vpa.updateMode` | VPA update mode | `Auto` |

### Environment-Specific Values

#### Development (`values.yaml`)
- 2 replicas
- Lower resource limits
- `latest` tag acceptable
- Basic availability requirements

#### Production (`values-prod.yaml`)
- 3 replicas
- Higher resource limits (200m CPU, 256Mi memory requests)
- Specific version tags required
- Stricter availability (minAvailable: 2)
- Enhanced health check timings

## Upgrading

### Upgrade to a new version

```bash
helm upgrade aks-demo ./helm/aks-demo \
  --set image.tag=v1.1.0 \
  --values ./helm/aks-demo/values-prod.yaml \
  --namespace aks-demo-prod
```

### Rollback

```bash
# List releases
helm history aks-demo -n aks-demo-prod

# Rollback to previous version
helm rollback aks-demo -n aks-demo-prod

# Rollback to specific revision
helm rollback aks-demo 3 -n aks-demo-prod
```

## Validation and Testing

### Validate the chart

```bash
# Lint the chart
helm lint ./helm/aks-demo

# Dry-run installation
helm install aks-demo ./helm/aks-demo \
  --dry-run --debug \
  --set image.registry=test.azurecr.io \
  --set image.tag=v1.0.0

# Template rendering
helm template aks-demo ./helm/aks-demo \
  --set image.registry=test.azurecr.io \
  --set image.tag=v1.0.0
```

### Test the deployment

```bash
# Check pod status
kubectl get pods -n aks-demo

# Check service
kubectl get svc -n aks-demo

# Test the application
export SERVICE_IP=$(kubectl get svc aks-demo -n aks-demo -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl http://$SERVICE_IP/
curl http://$SERVICE_IP/health
```

## Uninstallation

```bash
helm uninstall aks-demo -n aks-demo
```

## Chart Structure

```
aks-demo/
├── Chart.yaml                  # Chart metadata
├── values.yaml                 # Default values (dev)
├── values-prod.yaml            # Production overrides
├── templates/
│   ├── _helpers.tpl            # Template helpers
│   ├── deployment.yaml         # Deployment resource
│   ├── service.yaml            # Service resource
│   ├── serviceaccount.yaml     # ServiceAccount (optional)
│   ├── configmap.yaml          # ConfigMap (optional)
│   ├── poddisruptionbudget.yaml # PodDisruptionBudget
│   ├── vpa.yaml                # VerticalPodAutoscaler
│   └── NOTES.txt               # Post-install notes
└── .helmignore                 # Patterns to ignore
```

## Security

This chart implements several security best practices:

- **Non-root execution**: Runs as UID 1000
- **Read-only root filesystem**: Prevents runtime modifications
- **Dropped capabilities**: All Linux capabilities dropped
- **seccomp profile**: RuntimeDefault profile enforced
- **No privilege escalation**: Explicitly disabled
- **Resource limits**: Prevents resource exhaustion

## Troubleshooting

### Pods not starting

```bash
# Check pod status
kubectl describe pod -l app=aks-demo -n aks-demo

# Check logs
kubectl logs -l app=aks-demo -n aks-demo
```

### LoadBalancer stuck in pending

```bash
# Check service events
kubectl describe svc aks-demo -n aks-demo

# Verify cloud provider integration
kubectl get events -n aks-demo
```

### VPA not working

```bash
# Verify VPA is installed
kubectl get crd | grep verticalpodautoscaler

# Check VPA status
kubectl describe vpa aks-demo -n aks-demo
```

## Contributing

For contributions, please refer to the main repository: https://github.com/usgrant4/aks-api-demo

## License

See the main repository for license information.
