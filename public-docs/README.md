# CFD (ClickFix Dynamics) — Tiles

This public repository contains **deployment artifacts only** for the Tiles product. Source code and internal design details are not included.

The helpdesk module is in active development and will ship as part of Tiles.

## Quick Start

- Simple install (short guide): `public-docs/INSTALL_SIMPLE.md`.
- Operator cheat sheet: `public-docs/OPERATOR_CHEATSHEET.md`.
- Local or evaluation: see `public-docs/DEPLOY_DOCKER.md`.
- Azure Container Apps (Bicep + PowerShell): see `public-docs/DEPLOY_AZURE.md`.

## Updates

- Production updates: `pwsh -File scripts\update-cfd.ps1 -Channel public -ConfirmUpdate`
- Pre-release updates: `pwsh -File scripts\update-cfd.ps1 -Channel test -ConfirmUpdate`
- Major/minor track updates: `pwsh -File scripts\update-cfd.ps1 -Channel public -ReleaseTrack minor -TrackVersion 1.4 -ConfirmUpdate`

## Repo Map

- `deploy/` - deployment assets (Docker Compose + Bicep).
- `public-docs/` - public-facing documentation.
- `scripts/` - deployment utilities.

## Security and Configuration

- Secrets are never committed; configure via environment variables or managed services.
- See `public-docs/CONFIGURATION.md` and `public-docs/SECURITY.md` for setup and reporting guidance.

## Release and Legal

- v1.0.0 public dev log: `public-docs/DEVLOG_v1.0.0.md`
- Terms of Service: `public-docs/TERMS_OF_SERVICE.md`
- Privacy Policy: `public-docs/PRIVACY_POLICY.md`
- License: `LICENSE`

## Architecture Overview

See `public-docs/ARCHITECTURE.md` for a high-level view of runtime components and integrations.
