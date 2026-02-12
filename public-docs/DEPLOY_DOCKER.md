# Docker Compose Deployment

Use this mode for local evaluation.

## Prerequisites

- Docker Desktop
- PowerShell 7 (`pwsh`)

## Deploy

From repo root:

```powershell
pwsh -File scripts\install-cfd.ps1 -InstallMethod local -DeployType docker -ConfirmInstall
```

This command ensures `deploy/.env` exists and starts containers.

## Access

- Frontend: `http://localhost:8080`

## Stop

```powershell
docker compose -f deploy\docker-compose.yml --env-file deploy\.env down
```

## Notes

- If registry images are private, set `GHCR_USERNAME` and `GHCR_PASSWORD` in `deploy/.env`.
- Image refs are controlled by `FRONTEND_IMAGE` and `BACKEND_IMAGE` in `deploy/.env`.
- Tiles, Crunch mode, and 3D Asset mode are available through the deployed app images.
