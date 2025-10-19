#!/bin/bash
#
# sync-workflow-to-main.sh
#
# Purpose: Automatically sync GitHub workflow changes from dev to main branch
# Why: GitHub Actions only recognizes workflow_dispatch triggers in the default branch (main)
# When to use: After making changes to .github/workflows/*.yml files in dev branch
#
# Usage: ./sync-workflow-to-main.sh

set -e

COMMIT_MESSAGE="${1:-sync: Update GitHub workflows from dev branch}"

echo "========================================"
echo "  GitHub Workflow Sync Script"
echo "========================================"
echo ""

# Verify we're in a git repository
if [ ! -d ".git" ]; then
    echo "ERROR: Not in a git repository root"
    exit 1
fi

# Check current branch
CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"

# Check for uncommitted changes
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    echo ""
    echo "WARNING: You have uncommitted changes:"
    git status --short
    echo ""
    read -p "Commit changes first? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        read -p "Enter commit message: " commit_msg
        git add .
        git commit -m "$commit_msg"
        echo "✓ Changes committed"
    else
        echo "ERROR: Please commit or stash changes before syncing"
        exit 1
    fi
fi

echo ""
echo "Step 1: Ensuring dev branch is up to date..."
if [ "$CURRENT_BRANCH" != "dev" ]; then
    git checkout dev
fi
git pull origin dev
echo "✓ Dev branch updated"

echo ""
echo "Step 2: Switching to main branch..."
git checkout main
git pull origin main
echo "✓ Main branch updated"

echo ""
echo "Step 3: Copying workflow files from dev..."
git checkout dev -- .github/workflows/

# Check if there are changes to commit
if git diff-index --quiet HEAD -- .github/workflows/ 2>/dev/null; then
    echo "ℹ No workflow changes to sync"
    git checkout "$CURRENT_BRANCH"
    exit 0
fi

echo "✓ Workflow files copied from dev"
echo ""
echo "Changes to be synced:"
git status --short .github/workflows/

echo ""
echo "Step 4: Committing workflow changes to main..."
git add .github/workflows/
git commit -m "$COMMIT_MESSAGE"
echo "✓ Changes committed to main"

echo ""
echo "Step 5: Pushing to remote..."
git push origin main
echo "✓ Changes pushed to GitHub"

echo ""
echo "Step 6: Returning to original branch ($CURRENT_BRANCH)..."
git checkout "$CURRENT_BRANCH"
echo "✓ Back on $CURRENT_BRANCH branch"

echo ""
echo "========================================"
echo "  ✓ Workflow Sync Complete!"
echo "========================================"
echo ""
echo "The workflow_dispatch UI should now be visible in GitHub Actions."
echo "Go to: https://github.com/<your-org>/<your-repo>/actions"
echo ""
echo "What was synced:"
echo "- .github/workflows/ files from dev → main"
echo ""
echo "Why this is necessary:"
echo "GitHub only recognizes workflow_dispatch triggers from the default branch (main)."
echo "Changes to workflows in dev branch won't show in the Actions UI until synced to main."
echo ""
