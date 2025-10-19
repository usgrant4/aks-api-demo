# Vertical Pod Autoscaler (VPA) Guide

## Overview

The Vertical Pod Autoscaler (VPA) is enabled in your AKS cluster to automatically adjust CPU and memory requests and limits based on actual workload usage patterns. This helps rightsize your applications, reduce over-provisioning, and maximize cluster utilization.

## What VPA Does

VPA analyzes historical resource usage and current resource consumption to:
- **Recommend** optimal CPU and memory requests/limits
- **Automatically update** pod resource specifications
- **Prevent** over-provisioning and under-provisioning
- **Improve** cluster resource utilization

## Configuration

### 1. AKS Cluster Configuration

VPA is enabled in the AKS cluster via Terraform ([terraform/main.tf:75-78](../terraform/main.tf#L75-L78)):

```hcl
workload_autoscaler_profile {
  vertical_pod_autoscaler_enabled = true
}
```

### 2. VPA Resource Configuration

The VPA configuration for the liatrio-demo application is defined in [kubernetes/vpa.yaml](../kubernetes/vpa.yaml):

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: liatrio-demo-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: liatrio-demo
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
      - containerName: api
        minAllowed:
          cpu: 50m
          memory: 64Mi
        maxAllowed:
          cpu: 1000m
          memory: 1Gi
```

## Update Modes

VPA supports different update modes:

### 1. **Auto** (Current Setting)
- VPA automatically applies recommendations
- Pods are evicted and recreated with new resource values
- **Best for:** Production workloads with proper PodDisruptionBudgets
- **Trade-off:** May cause brief downtime during pod recreation

### 2. **Recreate**
- VPA applies recommendations by evicting and recreating pods
- Similar to Auto but more explicit about the recreation process
- **Best for:** Stateless applications

### 3. **Initial**
- VPA only sets resources when pods are created
- Does not update existing pods
- **Best for:** Testing VPA without disrupting running pods

### 4. **Off**
- VPA only provides recommendations
- Does not modify pods
- **Best for:** Observing recommendations before enabling auto-updates

## Resource Limits

### Current Configuration

**Minimum Allowed:**
- CPU: 50m (0.05 cores)
- Memory: 64Mi

**Maximum Allowed:**
- CPU: 1000m (1 core)
- Memory: 1Gi

**Current Pod Settings (before VPA):**
- CPU Request: 100m, Limit: 200m
- Memory Request: 128Mi, Limit: 256Mi

## How to Check VPA Recommendations

### View VPA Status
```bash
kubectl get vpa liatrio-demo-vpa
```

### View Detailed Recommendations
```bash
kubectl describe vpa liatrio-demo-vpa
```

Example output:
```yaml
Status:
  Recommendation:
    Container Recommendations:
      Container Name: api
      Lower Bound:
        Cpu:     25m
        Memory:  104Mi
      Target:
        Cpu:     100m
        Memory:  128Mi
      Uncapped Target:
        Cpu:     150m
        Memory:  200Mi
      Upper Bound:
        Cpu:     500m
        Memory:  512Mi
```

### Understanding Recommendations

- **Lower Bound**: Minimum recommended resources
- **Target**: Recommended resource values VPA will apply
- **Uncapped Target**: Recommendation without max limits
- **Upper Bound**: Maximum recommended resources

## Monitoring VPA Activity

### Check VPA Events
```bash
kubectl get events --field-selector involvedObject.name=liatrio-demo-vpa
```

### View Pod Resource Changes
```bash
kubectl get pods -l app=liatrio-demo -o json | jq '.items[].spec.containers[].resources'
```

### Check if VPA Updated Pods
```bash
kubectl get pods -l app=liatrio-demo -o yaml | grep -A 5 "resources:"
```

## Best Practices

### 1. **Use with PodDisruptionBudget**
The deployment already has a PDB configured to ensure at least 1 pod is always available during VPA updates.

### 2. **Set Appropriate Min/Max Limits**
- Prevents VPA from setting unreasonably low or high values
- Current limits: 50m-1000m CPU, 64Mi-1Gi memory

### 3. **Monitor for 1-2 Weeks**
Allow VPA to collect usage data before trusting recommendations fully.

### 4. **Test in Non-Production First**
Start with `updateMode: "Off"` or `updateMode: "Initial"` in dev/staging.

### 5. **Combine with HPA**
- VPA scales resources (vertical)
- HPA scales replicas (horizontal)
- **Important**: Don't target the same metrics (CPU/memory) with both

## Changing VPA Mode

To change the update mode, edit [kubernetes/vpa.yaml](../kubernetes/vpa.yaml):

```yaml
updatePolicy:
  updateMode: "Off"  # Change to: Auto, Recreate, Initial, or Off
```

Then apply the change:
```bash
kubectl apply -f kubernetes/vpa.yaml
```

## Cost Impact

### Benefits
- **Reduces waste**: Removes over-provisioned resources
- **Improves efficiency**: Better cluster utilization
- **Right-sizing**: Automatic adjustment to actual needs

### Considerations
- VPA may increase resources if current limits are too low
- Monitor actual usage vs. VPA recommendations
- Review recommendations before enabling `Auto` mode

## Troubleshooting

### VPA Not Providing Recommendations
```bash
# Check if VPA is running
kubectl get pods -n kube-system | grep vpa

# Check VPA logs
kubectl logs -n kube-system -l app=vpa-recommender
```

### Pods Not Being Updated
- Verify `updateMode` is set to `Auto` or `Recreate`
- Check PodDisruptionBudget isn't blocking evictions
- Ensure min/max limits aren't preventing updates

### Recommendations Seem Off
- Allow more time for data collection (minimum 24 hours)
- Check actual pod usage: `kubectl top pods`
- Review VPA history: `kubectl describe vpa liatrio-demo-vpa`

## Disabling VPA

### For a Specific Deployment
Delete the VPA resource:
```bash
kubectl delete vpa liatrio-demo-vpa
```

### For the Entire Cluster
Update Terraform configuration:
```hcl
workload_autoscaler_profile {
  vertical_pod_autoscaler_enabled = false
}
```

Then apply:
```bash
terraform apply
```

## References

- [Azure AKS VPA Documentation](https://learn.microsoft.com/en-us/azure/aks/vertical-pod-autoscaler)
- [Kubernetes VPA Documentation](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler)
- [VPA Best Practices](https://cloud.google.com/kubernetes-engine/docs/concepts/verticalpodautoscaler)

## Next Steps

1. **Week 1**: Monitor VPA recommendations in `Off` mode
2. **Week 2**: Switch to `Initial` mode for new pods only
3. **Week 3**: Enable `Auto` mode if recommendations look reasonable
4. **Ongoing**: Review VPA adjustments monthly and adjust min/max limits as needed
