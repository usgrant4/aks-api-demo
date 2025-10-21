# sync-workflow-to-main.ps1
#
# Purpose: Automatically sync GitHub workflow changes from dev to main branch
# Why: GitHub Actions only recognizes workflow_dispatch triggers in the default branch (main)
# When to use: After making changes to .github/workflows/*.yml files in dev branch
#
# Usage: .\sync-workflow-to-main.ps1

param(
    [switch]$Force,
    [string]$CommitMessage = "sync: Update GitHub workflows from dev branch"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  GitHub Workflow Sync Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verify we're in a git repository
if (-not (Test-Path ".git")) {
    Write-Host "ERROR: Not in a git repository root" -ForegroundColor Red
    exit 1
}

# Check current branch
$currentBranch = git branch --show-current
Write-Host "Current branch: $currentBranch" -ForegroundColor Yellow

# Check for uncommitted changes
$status = git status --porcelain
if ($status -and -not $Force) {
    Write-Host ""
    Write-Host "WARNING: You have uncommitted changes:" -ForegroundColor Yellow
    git status --short
    Write-Host ""
    $response = Read-Host "Commit changes first? (y/n)"
    if ($response -eq 'y') {
        Write-Host ""
        $commitMsg = Read-Host "Enter commit message"
        git add .
        git commit -m $commitMsg
        Write-Host "✓ Changes committed" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Please commit or stash changes before syncing" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "Step 1: Ensuring dev branch is up to date..." -ForegroundColor Cyan
if ($currentBranch -ne "dev") {
    git checkout dev
}
git pull origin dev
Write-Host "✓ Dev branch updated" -ForegroundColor Green

Write-Host ""
Write-Host "Step 2: Switching to main branch..." -ForegroundColor Cyan
git checkout main
git pull origin main
Write-Host "✓ Main branch updated" -ForegroundColor Green

Write-Host ""
Write-Host "Step 3: Copying workflow files from dev..." -ForegroundColor Cyan
git checkout dev -- .github/workflows/

# Check if there are changes to commit
$changes = git status --porcelain .github/workflows/
if (-not $changes) {
    Write-Host "ℹ No workflow changes to sync" -ForegroundColor Yellow
    git checkout $currentBranch
    exit 0
}

Write-Host "✓ Workflow files copied from dev" -ForegroundColor Green
Write-Host ""
Write-Host "Changes to be synced:" -ForegroundColor Yellow
git status --short .github/workflows/

Write-Host ""
Write-Host "Step 4: Committing workflow changes to main..." -ForegroundColor Cyan
git add .github/workflows/
git commit -m $CommitMessage
Write-Host "✓ Changes committed to main" -ForegroundColor Green

Write-Host ""
Write-Host "Step 5: Pushing to remote..." -ForegroundColor Cyan
git push origin main
Write-Host "✓ Changes pushed to GitHub" -ForegroundColor Green

Write-Host ""
Write-Host "Step 6: Returning to original branch ($currentBranch)..." -ForegroundColor Cyan
git checkout $currentBranch
Write-Host "✓ Back on $currentBranch branch" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  ✓ Workflow Sync Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "The workflow_dispatch UI should now be visible in GitHub Actions." -ForegroundColor Cyan
Write-Host "Go to: https://github.com/<your-org>/<your-repo>/actions" -ForegroundColor Cyan
Write-Host ""
Write-Host "What was synced:" -ForegroundColor Yellow
Write-Host "- .github/workflows/ files from dev → main" -ForegroundColor White
Write-Host ""
Write-Host "Why this is necessary:" -ForegroundColor Yellow
Write-Host "GitHub only recognizes workflow_dispatch triggers from the default branch (main)." -ForegroundColor White
Write-Host "Changes to workflows in dev branch won't show in the Actions UI until synced to main." -ForegroundColor White
Write-Host ""
