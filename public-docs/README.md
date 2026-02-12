# Public Documentation Index

Use this documentation set for deploying and operating the Tiles public package.

## Recommended Reading Order

1. `INSTALL.md` - end-to-end install and deploy flow.
2. `CONFIGURATION.md` - environment variables and image settings.
3. `DEPLOY_AZURE.md` - ACA deployment details and troubleshooting.
4. `DEPLOY_DOCKER.md` - Docker Compose deployment details.
5. `OPERATOR_CHEATSHEET.md` - quick commands for operations and updates.

## Deployment Scope

This repository ships deployment assets only:
- `deploy/docker-compose.yml`
- `deploy/azure/main.bicep`
- `scripts/install-cfd.ps1`
- `scripts/setup-cfd-prereqs.ps1`
- `scripts/deploy-cfd.ps1`
- `scripts/update-cfd.ps1`

Tiles, Crunch mode, and 3D Asset mode are available in the deployed application images.
