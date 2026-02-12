# Docker Compose Deployment

This path is best for local evaluation and developer environments using prebuilt images.

## Prerequisites

- Docker Desktop
- PowerShell 7 (`pwsh`)

## Steps

1. Open a PowerShell 7 terminal and move to the repo root:

```powershell
cd T:\CFD\CFD
```

2. Create your local environment file from the template:

```powershell
copy deploy\.env.example deploy\.env
notepad deploy\.env
```

3. Build and start the containers:

```powershell
docker compose -f deploy\docker-compose.yml --env-file deploy\.env up -d
```

4. Open the app:

- Frontend: `http://localhost:8080`

5. Stop the containers when done:

```powershell
docker compose down
```

## Updates

Pull the latest production images and restart:

```powershell
pwsh -File scripts\update-cfd.ps1 -Channel public -ConfirmUpdate
```

For pre-release validation, use:

```powershell
pwsh -File scripts\update-cfd.ps1 -Channel test -ConfirmUpdate
```

## Notes

- `deploy/docker-compose.yml` defines the frontend and backend services.
- `deploy/.env` contains secrets and must never be committed to source control.
- See `public-docs/CONFIGURATION.md` for required environment variables.
