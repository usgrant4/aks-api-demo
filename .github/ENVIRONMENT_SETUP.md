# GitHub Environment and Branch Protection Setup

This document provides step-by-step instructions for setting up production-grade approval gates and environment protection for the liatrio-demo project.

## Table of Contents
- [Overview](#overview)
- [GitHub Environments Setup](#github-environments-setup)
- [Branch Protection Rules](#branch-protection-rules)
- [Pull Request Workflow](#pull-request-workflow)
- [Testing the Setup](#testing-the-setup)

## Overview

### Current State vs Production-Ready State

**Without Protection (Current Risk):**
- Direct push to `main` → Immediate production deployment
- No approval required for production changes
- No code review enforcement
- Single person can deploy to production

**With Protection (Production-Ready):**
- Pull Requests required for `main` branch
- Code review required before merge
- Manual approval required before production deployment
- Environment-specific secrets and protection rules
- Audit trail of all production deployments

## GitHub Environments Setup

GitHub Environments allow you to configure protection rules and secrets for specific deployment targets.

### Step 1: Create Development Environment

1. Go to your GitHub repository
2. Click **Settings** → **Environments**
3. Click **New environment**
4. Name: `development`
5. Click **Configure environment**
6. **Protection rules** (Optional for dev):
   - ☐ Required reviewers (can leave unchecked for dev)
   - ☐ Wait timer: 0 minutes (no delay for dev)
7. **Deployment branches**:
   - Select: **Selected branches**
   - Add rule: `dev`
8. Click **Save protection rules**

### Step 2: Create Production Environment

1. Click **New environment** again
2. Name: `production`
3. Click **Configure environment**
4. **Protection rules** (Required for prod):
   - ✅ **Required reviewers**:
     - Click **Add reviewers**
     - Select team leads, senior engineers, or yourself
     - Require at least 1-2 approvals
   - ✅ **Wait timer**: Optional (e.g., 5 minutes to allow for last-minute cancellation)
   - ✅ **Prevent self-review**: Recommended if multiple team members
5. **Deployment branches**:
   - Select: **Protected branches only**
   - This ensures only code that passed branch protection can deploy to production
6. Click **Save protection rules**

### Step 3: Add Environment Secrets (Optional)

If you need environment-specific secrets (e.g., different Azure subscriptions for dev/prod):

**For `development` environment:**
1. In the `development` environment settings
2. Scroll to **Environment secrets**
3. Add secrets like:
   - `AZURE_SUBSCRIPTION_ID` (dev subscription)
   - `AZURE_CLIENT_ID` (dev service principal)

**For `production` environment:**
1. In the `production` environment settings
2. Add production-specific secrets:
   - `AZURE_SUBSCRIPTION_ID` (prod subscription)
   - `AZURE_CLIENT_ID` (prod service principal)

**Note**: Repository secrets will be used if environment secrets are not defined.

## Branch Protection Rules

### Step 1: Protect the Main Branch

1. Go to **Settings** → **Branches**
2. Under **Branch protection rules**, click **Add rule**
3. Branch name pattern: `main`
4. Configure protection rules:

#### Required Settings:
- ✅ **Require a pull request before merging**
  - ✅ **Require approvals**: 1 (or more for stricter control)
  - ✅ **Dismiss stale pull request approvals when new commits are pushed**
  - ✅ **Require review from Code Owners** (optional, requires CODEOWNERS file)

- ✅ **Require status checks to pass before merging**
  - ✅ **Require branches to be up to date before merging**
  - Add required status checks:
    - `build-test` (ensures tests pass)
    - Any other CI checks you want to enforce

- ✅ **Require conversation resolution before merging**
  - Ensures all PR comments are addressed

- ✅ **Require signed commits** (optional, for additional security)

- ✅ **Require linear history** (optional, prevents merge commits)

- ✅ **Do not allow bypassing the above settings**
  - Even admins must follow these rules

- ✅ **Restrict who can push to matching branches** (optional)
  - Select specific teams or users who can push

5. Click **Create** or **Save changes**

### Step 2: Protect the Dev Branch (Optional)

1. Add another branch protection rule for `dev`
2. Branch name pattern: `dev`
3. Lighter protection (optional):
   - ☐ Require pull requests (optional for dev)
   - ✅ **Require status checks to pass** (recommended)
   - ☐ Other rules (up to your team's preference)

## Pull Request Workflow

### Development to Production Flow

```
┌─────────────────────────────────────────────────────┐
│  Developer Workflow                                 │
└─────────────────────────────────────────────────────┘

1. Feature Development:
   ┌─────────────┐
   │ feature/*   │ ──► Create PR ──► dev branch
   └─────────────┘
         │
         │ (Automated CI/CD)
         ▼
   ┌─────────────────────────────┐
   │ Deploy to development env   │
   │ - Auto-deploys on PR merge  │
   │ - No approval required      │
   └─────────────────────────────┘

2. Production Promotion:
   ┌─────────────┐
   │ dev branch  │ ──► Create PR ──► main branch
   └─────────────┘
         │
         │ (Required: Code Review + Approval)
         ▼
   ┌─────────────────────────────┐
   │ PR Review Process           │
   │ - Status checks must pass   │
   │ - Requires 1+ approvals     │
   │ - Conversations resolved    │
   └─────────────────────────────┘
         │
         │ (After PR merge)
         ▼
   ┌─────────────────────────────┐
   │ GitHub Environment Gate     │
   │ - Requires manual approval  │
   │ - Notifies reviewers        │
   │ - Wait for approval         │
   └─────────────────────────────┘
         │
         │ (After approval)
         ▼
   ┌─────────────────────────────┐
   │ Deploy to production env    │
   │ - Infrastructure updated    │
   │ - Application deployed      │
   │ - Smoke tests run           │
   └─────────────────────────────┘
```

### Creating a Pull Request to Production

1. **Ensure dev is stable and tested**
   ```bash
   git checkout dev
   git pull origin dev
   ```

2. **Create Pull Request from dev → main**
   - Go to GitHub repository
   - Click **Pull requests** → **New pull request**
   - Base: `main` ← Compare: `dev`
   - Click **Create pull request**
   - Fill out the PR template (see below)

3. **PR Review Process**
   - CI/CD runs `build-test` job
   - Reviewers receive notification
   - Reviewers examine changes, leave comments
   - Developer addresses feedback
   - Reviewers approve PR

4. **Merge to Main**
   - Once approved and checks pass, click **Merge pull request**
   - Choose merge strategy (Squash, Merge commit, or Rebase)
   - Delete the source branch if it's a feature branch

5. **Deployment Approval**
   - GitHub Actions workflow starts
   - Workflow pauses at `production` environment
   - Designated reviewers receive notification
   - Reviewer goes to **Actions** tab → Click on the pending workflow
   - Click **Review deployments**
   - Select `production` environment
   - Add approval comment (optional)
   - Click **Approve and deploy**

6. **Monitor Deployment**
   - Deployment proceeds automatically after approval
   - Monitor logs in GitHub Actions
   - Verify deployment success
   - Test production endpoint

## Pull Request Template

Create [`.github/pull_request_template.md`](.github/pull_request_template.md) for consistent PR descriptions.

## Testing the Setup

### Test 1: Verify Branch Protection

Try to push directly to `main`:
```bash
git checkout main
echo "test" >> README.md
git add README.md
git commit -m "test direct push"
git push origin main
```

**Expected result**: Push should be rejected with message about branch protection.

### Test 2: Verify PR Requirement

1. Create a feature branch and push changes
2. Try to merge without PR: Should not be possible
3. Create PR: Should succeed
4. Try to merge without approval: Should be blocked
5. Get approval: Merge should be allowed

### Test 3: Verify Environment Protection

1. Merge PR to `main` branch
2. Check GitHub Actions tab
3. Deployment should pause at `production` environment
4. Should show "Waiting for approval"
5. Only designated reviewers can approve

### Test 4: Verify Deployment Flow

1. Push to `dev` branch → Should auto-deploy to development
2. Create PR from `dev` → `main` → Should require review
3. Merge PR → Should trigger production deployment (paused for approval)
4. Approve deployment → Should deploy to production

## Recommended Team Roles

For optimal security and workflow:

| Role | Responsibilities | Permissions |
|------|-----------------|-------------|
| **Developers** | Write code, create PRs | Push to `dev`, create PRs to `main` |
| **Senior Engineers** | Code review, approve PRs | Approve PRs, approve production deployments |
| **Team Leads** | Final approval for production | Approve PRs, approve production deployments, manage environments |
| **Admin** | Configure environments and rules | Full repository access |

## Best Practices

1. **Separation of Duties**: Different people should review code and approve production deployments
2. **Automated Testing**: Always require CI checks to pass before merging
3. **Staging Environment**: Test in `development` before promoting to `production`
4. **Rollback Plan**: Document how to rollback production deployments (use workflow_dispatch with previous commit)
5. **Change Windows**: Consider restricting production deployments to specific times (use wait timers)
6. **Audit Trail**: GitHub automatically logs all approvals and deployments
7. **Secret Rotation**: Regularly rotate environment secrets
8. **Monitoring**: Set up alerts for failed deployments

## Troubleshooting

### Issue: Can't create PR because branch is not up to date

**Solution**:
```bash
git checkout dev
git pull origin main  # Update dev with main changes
git push origin dev
```

### Issue: Status checks never complete

**Solution**: Check GitHub Actions tab for failed workflows. Fix issues and push new commit to trigger checks again.

### Issue: Reviewer can't approve environment deployment

**Solution**: Ensure the reviewer is added to the environment's "Required reviewers" list in Settings → Environments → production.

### Issue: Want to bypass protection in emergency

**Solution**:
1. Use workflow_dispatch to manually trigger deployment (still requires environment approval)
2. For true emergencies, temporarily disable branch protection (requires admin), deploy, then re-enable
3. Better: Have an "emergency deploy" process with expedited approval

## Summary

With these protections in place:

✅ No direct pushes to production (main branch)
✅ All production changes require code review via PR
✅ Automated tests must pass before merge
✅ Manual approval required before production deployment
✅ Clear audit trail of who approved what and when
✅ Environment-specific secrets and configuration
✅ Ability to test in dev before promoting to prod

This setup follows industry best practices and ensures production stability while maintaining development velocity.
