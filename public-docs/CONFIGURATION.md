# Configuration

CFD is configured through environment variables. For Docker Compose, use `deploy/.env`. For Azure Container Apps, set these values as app settings or use Key Vault references.

## Required

- `AZURE_TENANT_ID` - Entra tenant ID for the app registration.
- `AZURE_CLIENT_ID` - Application (client) ID for the backend service principal.
- `AZURE_CLIENT_SECRET` - Client secret for the backend service principal.
- `AZURE_STORAGE_CONNECTION_STRING` - Azure Storage connection string for caching.

## Optional

- `AZURE_SUBSCRIPTION_ID` - Subscription ID for Azure resource discovery.
- `AUTH_TENANT_ID` - Tenant ID used to validate frontend bearer tokens.
- `AUTH_AUDIENCE` - Expected audience (`api://...`) for token validation.
- `ARM_REQUIRE_AUTH` - Set to `true` to enforce frontend auth.

## Local Setup

Use the provided template:

```powershell
cd T:\CFD\CFD
copy deploy\.env.example deploy\.env
notepad deploy\.env
```

Never commit `.env` to source control.
