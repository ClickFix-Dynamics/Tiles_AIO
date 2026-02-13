# Installation Guide

This is the canonical install guide for the Tiles public deployment repo.

## Prerequisites

- PowerShell 7 (`pwsh`)
- Git
- Docker Desktop (for Docker deployment)
- Azure CLI (`az`) with permissions to create resources (for ACA deployment)

## Important Working Directory Rule

Run commands from the repo root (`Tiles_AIO`), not from `scripts/`.

If you run from `scripts/`, relative paths like `deploy/.env` will resolve incorrectly.

## Clone the Repository

```powershell
git clone https://github.com/DennisC3PO/Tiles_AIO.git
cd Tiles_AIO
```

## Private GHCR Access (When Required)

If images are private:
1. Receive GitHub invite access from the service operator.
2. Accept the invite.
3. Create a GitHub PAT with `read:packages` scope.
4. Use your GitHub username + PAT during install prompts.

## Option A (Recommended): Azure Container Apps on a New Subscription

Single command install + bootstrap + deploy:

```powershell
pwsh -File scripts\install-cfd.ps1 -InstallMethod local -DeployType aca -ProvisionAzurePrereqs -PublicAccess -PromptGhcrCredentials -ConfirmInstall
```

What this does:
- Creates `deploy/.env` from `deploy/.env.example` if missing.
- Prompts for GHCR credentials when requested (`-PromptGhcrCredentials`).
- Bootstraps Azure prereqs (`setup-cfd-prereqs.ps1`):
  - Resource group
  - Storage account
  - Entra app registration + service principal
  - Reader role assignment at subscription scope
- Deploys frontend + backend to Azure Container Apps via Bicep.

### Dry-Run Preview

```powershell
pwsh -File scripts\install-cfd.ps1 -InstallMethod local -DeployType aca -ProvisionAzurePrereqs -PromptGhcrCredentials -DryRun
```

## Option B: Docker Compose (Local / Evaluation)

```powershell
pwsh -File scripts\install-cfd.ps1 -InstallMethod local -DeployType docker -PromptGhcrCredentials -ConfirmInstall
```

Access the app at:
- `http://localhost:8080`

## Private Registry (GHCR) Credentials

Private images require:
- `GHCR_USERNAME`
- `GHCR_PASSWORD` (PAT with `read:packages`)

You can provide these either:
- Interactively during install with `-PromptGhcrCredentials`
- Non-interactively with install parameters:

```powershell
pwsh -File scripts\install-cfd.ps1 -InstallMethod local -DeployType docker -GhcrUsername <user> -GhcrPassword <token> -ConfirmInstall
```

## Alternate Install Methods

### Git Method

```powershell
pwsh -File scripts\install-cfd.ps1 -InstallMethod git -DeployType docker -PromptGhcrCredentials -ConfirmInstall
```

Default destination when not provided:
- `%USERPROFILE%\CFD-public-deploy`

### Zip Method

```powershell
pwsh -File scripts\install-cfd.ps1 -InstallMethod zip -DeployType docker -PromptGhcrCredentials -ConfirmInstall
```

## Validate and Update

Update deployed images:

```powershell
pwsh -File scripts\update-cfd.ps1 -Channel public -ConfirmUpdate
```

Run pre-release update:

```powershell
pwsh -File scripts\update-cfd.ps1 -Channel test -ConfirmUpdate
```
