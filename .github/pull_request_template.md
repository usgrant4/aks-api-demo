# Pull Request

## Type of Change
<!-- Mark the appropriate option with an 'x' -->

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Infrastructure change (Terraform, Kubernetes, CI/CD)
- [ ] Documentation update
- [ ] Dependency update
- [ ] Security patch

## Description

<!-- Provide a clear and concise description of the changes -->

### What does this PR do?


### Why are these changes needed?


### Related Issues
<!-- Link to related issues using #issue-number -->

Fixes #
Relates to #

## Changes Made

<!-- Provide a bullet-point list of changes -->

-
-
-

## Environment Impact

<!-- Mark all environments affected by this change -->

- [ ] Development environment
- [ ] Production environment
- [ ] Shared infrastructure (Terraform backend, shared resources)

## Testing

### Test Coverage

- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] Smoke tests verified
- [ ] Manual testing completed

### Testing Performed

<!-- Describe the testing you performed -->

**Local testing:**
- [ ] Tests pass locally (`pytest -v`)
- [ ] Application runs locally
- [ ] Docker build succeeds

**Development environment:**
- [ ] Deployed to dev environment successfully
- [ ] Smoke tests pass in dev
- [ ] No errors in pod logs
- [ ] LoadBalancer accessible

**Results:**
```
# Paste relevant test output or screenshots
```

## Deployment Plan

<!-- For production deployments (dev → main PRs) -->

### Pre-deployment Checklist

- [ ] All tests passing in development environment
- [ ] No known bugs or issues in development
- [ ] Infrastructure changes reviewed and approved
- [ ] Database migrations tested (if applicable)
- [ ] Rollback plan documented below
- [ ] Monitoring/alerting updated (if needed)
- [ ] Documentation updated

### Deployment Steps

<!-- Will this require any manual steps? -->

1. Standard automated deployment
   - [ ] No manual steps required
   - [ ] Deployment will be automatic after approval

OR

2. Manual steps required:
   <!-- List any manual steps needed -->
   -
   -

### Rollback Plan

<!-- How to rollback if deployment fails -->

**Automated rollback:**
```bash
# Use workflow_dispatch to deploy previous version
# Go to Actions → ci-cd → Run workflow → Select production → deploy
# Use commit SHA: <previous-commit-sha>
```

**Manual rollback:**
```bash
# If automated rollback fails:
terraform destroy -auto-approve  # Destroy broken infrastructure
# Then redeploy previous stable version via workflow_dispatch
```

## Infrastructure Changes

<!-- For Terraform, Kubernetes, or CI/CD changes -->

### Terraform State Impact

- [ ] No state file changes
- [ ] State file changes are backward compatible
- [ ] State file changes may cause resource recreation
- [ ] New resources added (no destruction)

### Resource Changes

<!-- Output from `terraform plan` -->

```
# Paste terraform plan output showing resources to be added/changed/destroyed
```

### Breaking Changes

- [ ] No breaking changes
- [ ] Breaking changes documented below

**Breaking changes description:**
<!-- Describe any breaking changes and migration path -->

## Security Considerations

- [ ] No security implications
- [ ] Security review completed
- [ ] No secrets exposed in code
- [ ] Dependencies scanned for vulnerabilities
- [ ] RBAC/permissions reviewed

**Security notes:**


## Performance Impact

- [ ] No performance impact expected
- [ ] Performance improvement expected
- [ ] Performance degradation possible (documented below)

**Performance notes:**


## Documentation

- [ ] README.md updated
- [ ] Code comments added/updated
- [ ] API documentation updated (if applicable)
- [ ] Runbook/troubleshooting guide updated

## Screenshots/Logs

<!-- If applicable, add screenshots or logs showing the changes working -->


## Reviewer Notes

<!-- Any specific areas you'd like reviewers to focus on? -->

**Please review:**
-
-

**Known limitations:**
-
-

## Post-Deployment Verification

<!-- How to verify the deployment succeeded -->

**Success criteria:**
- [ ] Application responds to health checks
- [ ] All pods are in Ready state
- [ ] No errors in application logs
- [ ] Smoke tests pass
- [ ] Performance metrics within acceptable range

**Verification commands:**
```bash
# Check pod status
kubectl get pods -l app=liatrio-demo

# Check service
kubectl get svc liatrio-demo-svc

# Test endpoint
curl http://<loadbalancer-ip>/
curl http://<loadbalancer-ip>/health
```

---

## Checklist

<!-- Ensure all items are checked before requesting review -->

- [ ] My code follows the project's code style
- [ ] I have performed a self-review of my code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes
- [ ] Any dependent changes have been merged and published

### For Production Deployments (dev → main):

- [ ] Changes have been tested in development environment for at least 24 hours
- [ ] No critical issues reported in development
- [ ] Stakeholders have been notified of planned deployment
- [ ] Deployment window scheduled (if required)
- [ ] On-call engineer available during deployment
- [ ] Rollback plan tested and ready

---

## Approvals Required

<!-- GitHub will enforce this based on branch protection rules -->

**Code Review:** 1+ approvals required
**Production Deployment:** Manual approval required via GitHub Environment gate

---

**Reviewer Guidelines:**

When reviewing this PR, please verify:
1. Code quality and adherence to best practices
2. Test coverage is adequate
3. Documentation is clear and complete
4. Security implications have been considered
5. Performance impact is acceptable
6. Rollback plan is viable
7. Infrastructure changes are safe (no accidental resource destruction)

For production deployments, additionally verify:
- Changes have been stable in dev for sufficient time
- Risk is acceptable for production deployment
- Deployment timing is appropriate
