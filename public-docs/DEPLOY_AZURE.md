# Azure Container Apps Deployment (Bicep + PowerShell)

This path deploys CFD to Azure Container Apps using Bicep and a PowerShell deployment script with **prebuilt images**.

Default images:
- `ghcr.io/cfd/tiles-frontend:latest`
- `ghcr.io/cfd/tiles-backend:latest`

## Prerequisites

- Azure CLI (`az`)
- PowerShell 7 (`pwsh`)
- Permissions to create resources in the target subscription

## Quick Deploy

1. Open a PowerShell 7 terminal and move to the repo root:

```powershell
cd T:\CFD\CFD
```

2. Run the deployment script:

```powershell
pwsh -File scripts\deploy-cfd.ps1 -ResourceGroup "cfd-rg" -Location "eastus2" -ConfirmDeploy
```

3. Optional flags:

- `-PublicAccess` to expose the frontend publicly (default is internal-only).
- `-FrontendImage` and `-BackendImage` to override image tags.
- `-DryRun` to preview actions without making changes.

## Configuration

The script reads values from `deploy/.env` if present, or prompts for them. Use `deploy/.env.example` as the template and see `public-docs/CONFIGURATION.md` for required values.

## Updates

After the initial deployment, update to the latest production images:

```powershell
pwsh -File scripts\update-cfd.ps1 -Channel public -ConfirmUpdate
```

For pre-release validation, use:

```powershell
pwsh -File scripts\update-cfd.ps1 -Channel test -ConfirmUpdate
```

The deployment script writes `deploy/.install.json` so updates can re-use app names and resource group.

## Notes

- The Bicep template lives at `deploy/azure/main.bicep`.
- Images are pulled from a registry (default: `ghcr.io/cfd/tiles-*`).
- For a private deployment, keep the default internal ingress and access via VPN/Bastion.
