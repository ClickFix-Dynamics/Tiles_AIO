# Operator Cheat Sheet

## New Subscription Install (ACA)

```powershell
pwsh -File scripts\install-cfd.ps1 -InstallMethod local -DeployType aca -ProvisionAzurePrereqs -PublicAccess -PromptGhcrCredentials -ConfirmInstall
```

## Local Docker Install

```powershell
pwsh -File scripts\install-cfd.ps1 -InstallMethod local -DeployType docker -PromptGhcrCredentials -ConfirmInstall
```

## Update Production Channel

```powershell
pwsh -File scripts\update-cfd.ps1 -Channel public -ConfirmUpdate
```

## Update Test Channel

```powershell
pwsh -File scripts\update-cfd.ps1 -Channel test -ConfirmUpdate
```

## Version-Track Update (Example)

```powershell
pwsh -File scripts\update-cfd.ps1 -Channel public -ReleaseTrack minor -TrackVersion 1.4 -ConfirmUpdate
```

## Docker Stop

```powershell
docker compose -f deploy\docker-compose.yml --env-file deploy\.env down
```

## ACA Frontend URL

```powershell
az containerapp show --name cfd-tiles-frontend --resource-group cfd-rg --query properties.configuration.ingress.fqdn -o tsv
```
