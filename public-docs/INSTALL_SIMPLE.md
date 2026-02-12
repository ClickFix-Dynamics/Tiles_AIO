# Simple Install Guide (Public)

This guide is the shortest path to get Tiles running using the deploy-only bundle.

## File Placement

Keep the following structure intact after downloading or extracting the bundle:

- `deploy/`
- `public-docs/`
- `scripts/`
- `README.md`

You may place the folder anywhere (for example: `C:\Tiles\CFD-public-deploy`).

## Install (Docker Compose)

### Option A: One-command installer (recommended)

```powershell
pwsh -File scripts\install-cfd.ps1 -ConfirmInstall
```

### Option B: Manual (zip already downloaded)

1. Open PowerShell 7 and go to the bundle root:

```powershell
cd C:\Tiles\CFD-public-deploy
```

2. Create your environment file:

```powershell
copy deploy\.env.example deploy\.env
notepad deploy\.env
```

3. Start containers:

```powershell
docker compose -f deploy\docker-compose.yml --env-file deploy\.env up -d
```

4. Access Tiles:

- `http://localhost:8080`

## Install (Azure Container Apps)

### Option A: One-command installer (recommended)

```powershell
pwsh -File scripts\install-cfd.ps1 -DeployType aca -ConfirmInstall
```

### Option B: Manual (zip already downloaded)

1. Open PowerShell 7 and go to the bundle root:

```powershell
cd C:\Tiles\CFD-public-deploy
```

2. Configure environment:

```powershell
copy deploy\.env.example deploy\.env
notepad deploy\.env
```

3. Deploy:

```powershell
pwsh -File scripts\deploy-cfd.ps1 -ResourceGroup "cfd-rg" -Location "eastus2" -ConfirmDeploy
```

## Updates

Production updates:

```powershell
pwsh -File scripts\update-cfd.ps1 -Channel public -ConfirmUpdate
```

Pre-release updates:

```powershell
pwsh -File scripts\update-cfd.ps1 -Channel test -ConfirmUpdate
```

Major/minor track updates (example: latest 1.4.x):

```powershell
pwsh -File scripts\update-cfd.ps1 -Channel public -ReleaseTrack minor -TrackVersion 1.4 -ConfirmUpdate
```

If you installed via git clone, you can update files with:

```powershell
git pull
```
