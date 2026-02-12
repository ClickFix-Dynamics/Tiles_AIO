# Configuration

CFD public deployment configuration is driven by `deploy/.env`.

Create it from template:

```powershell
copy deploy\.env.example deploy\.env
```

## Required Variables

- `AZURE_TENANT_ID`
- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`
- `AZURE_STORAGE_CONNECTION_STRING`
- `AZURE_SUBSCRIPTION_ID`

## Auth Variables (Recommended)

- `AUTH_TENANT_ID`
- `AUTH_AUDIENCE`
- `ARM_REQUIRE_AUTH`

## Image and Runtime Variables

- `FRONTEND_IMAGE`
- `BACKEND_IMAGE`
- `DEMO_MODE`

## Registry Credentials (Only if Needed)

- `GHCR_USERNAME`
- `GHCR_PASSWORD`

## Notes

- Never commit `deploy/.env`.
- `scripts/setup-cfd-prereqs.ps1` can generate `deploy/.env` automatically.
- Tiles, Crunch mode, and 3D Asset mode are part of the application images; no extra mode flags are required for normal operation.
