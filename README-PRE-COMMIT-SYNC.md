# Pre-commit Configuration Synchronization

This repository contains an automated pipeline for synchronizing pre-commit configuration across multiple repositories in the ACME-ORG organization.

## 🎯 Overview

The solution automatically propagates updates to `.pre-commit-config.yaml` from this central repository (`central-config`) to a configurable list of target repositories. It pushes changes directly to the target repositories using GitHub App authentication, bypassing the need for Pull Requests while respecting branch protection rules.

## 🏗️ Architecture

### Components

1. **Source Repository** (current) - Contains the master `.pre-commit-config.yaml`
2. **Target Repositories** - Multiple repositories that receive synchronized configurations
3. **GitHub Actions Workflow** - Automated pipeline for synchronization
4. **GitHub App** - Handles authentication and bypass permissions

## 📁 File Structure

```
.github/
├── workflows/
│   └── update-pre-commit-config.yml    # Main automation workflow
└── pre-commit-sync-config.yml          # Target repository configuration

.pre-commit-config.yaml                 # Master pre-commit configuration
README-PRE-COMMIT-SYNC.md              # This documentation
```

## 🚀 Quick Start

### 1. Configure Target Repositories

Edit `.github/pre-commit-sync-config.yml` to specify which repositories should receive updates:

```yaml
group:
  repos: |
    ACME-ORG/onboarding-loyalty
    ACME-ORG/infrastructure-loyalty
  files: 
    - source: .pre-commit-config.yaml
      dest: .pre-commit-config.yaml
```

### 2. Set Required Secrets

Ensure these secrets are configured in your repository:

- `GH_APP_ID` - GitHub App ID for authentication
- `GH_APP_SECRET` - GitHub App private key for authentication

### 3. Trigger Synchronization

The workflow automatically triggers when:
- `.pre-commit-config.yaml` is modified and pushed to `main` branch
- Manual trigger via GitHub Actions UI (`workflow_dispatch`)

## ⚙️ Configuration

### GitHub App Permissions

Your GitHub App requires these permissions:

- **Repository Permissions:**
  - `Contents: Read/Write` - For pushing directly to repositories
  - `Metadata: Read` - For repository access
  - `Administration: Read/Write` - To bypass repository branch protection rules

## 🔄 How It Works

### Sync Job
- **Generates GitHub App Token** using `peter-murray/workflow-application-token-action@v4`
- **Uses `BetaHuhn/repo-file-sync-action@v1`** to push changes directly to target repositories
- **Skips PR creation** with `SKIP_PR: true` parameter
- **Updates** `.pre-commit-config.yaml` files in the main branch of target repos

## 📊 Pre-commit Configuration

The master `.pre-commit-config.yaml` includes hooks for:

- **Terraform** - Formatting (`terraform_fmt`), validation (`terraform_validate`), and linting (`terraform_tflint`)
- **Markdown** - Linting with `markdownlint`
- **PowerShell** - Script analysis and linting via `PSScriptAnalyzer`
- **Shell Scripts** - Linting with `shellcheck` and formatting with `shfmt`
- **Pre-commit Updates** - Automated hook updates with `--dry-run` flag


## 🔧 Customization

### Adding New Target Repositories

1. **Edit** `.github/pre-commit-sync-config.yml`
2. **Run** workflow manually 

### Modifying Pre-commit Hooks

1. **Edit** `.pre-commit-config.yaml` in this repository
2. **Merge PR** to trigger sync to the target repos