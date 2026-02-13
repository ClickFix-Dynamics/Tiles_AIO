# CFD (ClickFix Dynamics) - Tiles Public Deployment

This repository contains deployment artifacts and automation scripts for Tiles.
Source code is not included in this public bundle.

## End-User Workflow (No T: Drive Required)

1. Clone locally (any folder):

```powershell
git clone https://github.com/DennisC3PO/Tiles_AIO.git
cd Tiles_AIO
```

2. Run from the repo root (`Tiles_AIO`).

The deployment runs from the local clone on the user's machine. It does not migrate code through GitHub into Azure. Azure resources are provisioned directly by Azure CLI + Bicep.

## Fastest Path (New Azure Subscription)

```powershell
pwsh -File scripts\install-cfd.ps1 -InstallMethod local -DeployType aca -ProvisionAzurePrereqs -PublicAccess -PromptGhcrCredentials -ConfirmInstall
```

This flow will:
- Create `deploy/.env` from `deploy/.env.example` if needed.
- Optionally prompt for GHCR credentials for private image pulls.
- Bootstrap Azure prerequisites (`scripts/setup-cfd-prereqs.ps1`).
- Deploy Container Apps (`scripts/deploy-cfd.ps1`).

## Docker Local/Evaluation

```powershell
pwsh -File scripts\install-cfd.ps1 -InstallMethod local -DeployType docker -PromptGhcrCredentials -ConfirmInstall
```

## Default Install Location for Non-Local Methods

If `-InstallMethod git` or `-InstallMethod zip` is used and `-Destination` is not provided, files install to:

- `%USERPROFILE%\CFD-public-deploy`

## Private Access Onboarding

If your deployment uses private GHCR images:
- You must receive GitHub access from the service operator first.
- After accepting invite access, create a GitHub PAT with `read:packages`.
- During setup, provide:
  - `GHCR_USERNAME` = your GitHub username
  - `GHCR_PASSWORD` = your PAT

## Updates

```powershell
pwsh -File scripts\update-cfd.ps1 -Channel public -ConfirmUpdate
```

## Important Notes

- If images are private, set or prompt for `GHCR_USERNAME` and `GHCR_PASSWORD`.
- Tiles, Crunch mode, and 3D Asset mode are delivered by the deployed images.
- Detailed docs are in `public-docs/`.
