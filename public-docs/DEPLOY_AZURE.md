# Azure Container Apps Deployment

This deployment path uses:
- `deploy/azure/main.bicep`
- `scripts/setup-cfd-prereqs.ps1`
- `scripts/deploy-cfd.ps1`
- `scripts/install-cfd.ps1`

## Recommended One-Command Flow

From repo root:

```powershell
pwsh -File scripts\install-cfd.ps1 -InstallMethod local -DeployType aca -ProvisionAzurePrereqs -PublicAccess -PromptGhcrCredentials -ConfirmInstall
```

## Manual Two-Step Flow

1. Bootstrap Azure prerequisites and write `deploy/.env`:

```powershell
pwsh -File scripts\setup-cfd-prereqs.ps1 -ResourceGroup cfd-rg -Location eastus2 -ConfirmSetup
```

2. Deploy Container Apps:

```powershell
pwsh -File scripts\deploy-cfd.ps1 -ResourceGroup cfd-rg -Location eastus2 -PublicAccess -ConfirmDeploy
```

## Dry-Run

Preview setup:

```powershell
pwsh -File scripts\setup-cfd-prereqs.ps1 -ResourceGroup cfd-rg -Location eastus2 -DryRun
```

Preview deployment:

```powershell
pwsh -File scripts\deploy-cfd.ps1 -ResourceGroup cfd-rg -Location eastus2 -DryRun
```

## Optional Parameters

- `-FrontendImage` and `-BackendImage` to override image tags.
- `-DemoMode` for demo data mode.
- `-GhcrUsername` and `-GhcrPassword` when images are private.

## Post-Deploy

Get the frontend URL:

```powershell
az containerapp show --name cfd-tiles-frontend --resource-group cfd-rg --query properties.configuration.ingress.fqdn -o tsv
```

Open:
- `https://<frontend-fqdn>`

Tiles, Crunch mode, and 3D Asset mode are provided by the deployed app images.
