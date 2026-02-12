# CFD (ClickFix Dynamics) - Tiles Public Deployment

This repository contains deployment artifacts and automation scripts for Tiles.
Source code is not included in this public bundle.

## Fastest Path (New Azure Subscription)

1. Clone the repo:

```powershell
git clone https://github.com/DennisC3PO/Tiles_AIO.git
cd Tiles_AIO
```

2. Run the installer with Azure bootstrap + deployment:

```powershell
pwsh -File scripts\install-cfd.ps1 -InstallMethod local -DeployType aca -ProvisionAzurePrereqs -PublicAccess -ConfirmInstall
```

This flow will:
- Create `deploy/.env` from `deploy/.env.example` if needed.
- Bootstrap Azure prerequisites (`scripts/setup-cfd-prereqs.ps1`) when requested.
- Deploy Container Apps (`scripts/deploy-cfd.ps1`).

## Docker Local/Evaluation

```powershell
pwsh -File scripts\install-cfd.ps1 -InstallMethod local -DeployType docker -ConfirmInstall
```

## Updates

```powershell
pwsh -File scripts\update-cfd.ps1 -Channel public -ConfirmUpdate
```

## Important Notes

- If your image registry is private, set `GHCR_USERNAME` and `GHCR_PASSWORD` in `deploy/.env`.
- Tiles, Crunch mode, and 3D Asset mode are delivered by the deployed app images.
- Detailed docs are in `public-docs/`.
