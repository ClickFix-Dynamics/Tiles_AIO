# Operator Cheat Sheet (Public)

This is a one-page, minimal guide for installing and updating the deploy-only bundle.

## File Placement

Keep this structure intact after download/unzip:

- `deploy/`
- `public-docs/`
- `scripts/`
- `README.md`

You may place the folder anywhere (example: `C:\Tiles\CFD-public-deploy`).

## Install (Docker)

One-command installer:

```powershell
pwsh -File scripts\install-cfd.ps1 -ConfirmInstall
```

```powershell
cd C:\Tiles\CFD-public-deploy
copy deploy\.env.example deploy\.env
notepad deploy\.env
docker compose -f deploy\docker-compose.yml --env-file deploy\.env up -d
```

Access: `http://localhost:8080`

## Install (Azure Container Apps)

One-command installer:

```powershell
pwsh -File scripts\install-cfd.ps1 -DeployType aca -ConfirmInstall
```

```powershell
cd C:\Tiles\CFD-public-deploy
copy deploy\.env.example deploy\.env
notepad deploy\.env
pwsh -File scripts\deploy-cfd.ps1 -ResourceGroup "cfd-rg" -Location "eastus2" -ConfirmDeploy
```

Access: `https://<frontend-fqdn>`

## Update (Stable Command)

```powershell
pwsh -File scripts\update-cfd.ps1 -Channel public -ConfirmUpdate
```

Major/minor track updates (example: latest 1.4.x):

```powershell
pwsh -File scripts\update-cfd.ps1 -Channel public -ReleaseTrack minor -TrackVersion 1.4 -ConfirmUpdate
```

If installed via git clone, update files with:

```powershell
git pull
```
