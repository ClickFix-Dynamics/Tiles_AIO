# Installation Guide

This is the canonical install guide for the Tiles public deployment repo.

## Prerequisites

- PowerShell 7 (`pwsh`)
- Git
- Docker Desktop (for Docker deployment)
- Azure CLI (`az`) with permissions to create resources (for ACA deployment)

## Clone the Repository

```powershell
git clone https://github.com/DennisC3PO/Tiles_AIO.git
cd Tiles_AIO
```

## Option A (Recommended): Azure Container Apps on a New Subscription

Single command install + bootstrap + deploy:

```powershell
pwsh -File scripts\install-cfd.ps1 -InstallMethod local -DeployType aca -ProvisionAzurePrereqs -PublicAccess -ConfirmInstall
```

What this does:
- Creates `deploy/.env` from `deploy/.env.example` if missing.
- Bootstraps Azure prereqs (`setup-cfd-prereqs.ps1`):
  - Resource group
  - Storage account
  - Entra app registration + service principal
  - Reader role assignment at subscription scope
- Deploys frontend + backend to Azure Container Apps via Bicep.

### Dry-Run Preview

```powershell
pwsh -File scripts\install-cfd.ps1 -InstallMethod local -DeployType aca -ProvisionAzurePrereqs -DryRun
```

## Option B: Docker Compose (Local / Evaluation)

```powershell
pwsh -File scripts\install-cfd.ps1 -InstallMethod local -DeployType docker -ConfirmInstall
```

Access the app at:
- `http://localhost:8080`

## Private Registry Support

If images are private, set registry credentials in `deploy/.env`:

```dotenv
GHCR_USERNAME=<your-ghcr-user>
GHCR_PASSWORD=<your-ghcr-token>
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
