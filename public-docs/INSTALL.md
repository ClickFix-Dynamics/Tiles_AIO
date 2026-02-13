# Installation

Choose the installation style that fits your environment.

## Option A: Docker Compose (Local / Evaluation)

Best for local testing, demos, and quick evaluation.

- Guide: `public-docs/DEPLOY_DOCKER.md`
- Uses: `deploy/docker-compose.yml`

## Option B: Azure Container Apps (Bicep + PowerShell)

Best for production-like Azure deployments.

- Guide: `public-docs/DEPLOY_AZURE.md`
- Uses: `deploy/azure/main.bicep`
- Deploy script: `scripts/deploy-cfd.ps1`

## Prerequisites

- PowerShell 7 (`pwsh`)
- Git
- Docker Desktop (for Docker Compose)
- Azure CLI (for Azure Container Apps)
