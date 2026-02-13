# Tiles v1.0.0 Dev Log (Public)

This is the first public-facing dev log for Tiles before release. The short version is that the core product works, the deployment path is stable, and the platform now has feature-gate hooks in place so we can separate free, pro, and enterprise capabilities cleanly.

We deliberately kept this log plain and direct so operators, customers, and future maintainers can all use it.

## What Is In Place Today

Tiles ships as a frontend + backend deployment pattern, with auth-aware APIs, demo mode support, and automation surfaces for advanced scenarios.

Implemented and verified in code:

- Feature gates are wired as middleware for:
  - `FeatureGate('intuneRemote')`
  - `FeatureGate('automationAdvanced')`
  - `FeatureGate('multiTenant')`
- Route-level gate enforcement is active on:
  - `/api/intune/*`
  - `/api/remote/*`
  - `/api/tenant/*`
- Tenant impact endpoint is available at:
  - `GET /api/tenant/impact`
- Public demo behavior is supported via demo mode flags and mock data generation paths.

## Commands You Will Use Most

Deployment and operations:

- `pwsh -File scripts\install-cfd.ps1 -InstallMethod local -DeployType aca -ProvisionAzurePrereqs -PublicAccess -PromptGhcrCredentials -ConfirmInstall`
- `pwsh -File scripts\update-cfd.ps1 -Channel public -ConfirmUpdate`
- `pwsh -File scripts\update-cfd.ps1 -Channel test -ConfirmUpdate`

Health and diagnostics:

- `az containerapp show -n tiles-frontend -g TilesApp --query properties.configuration.ingress.fqdn -o tsv`
- `az containerapp show -n tiles-backend -g TilesApp --query properties.configuration.ingress.fqdn -o tsv`
- `az containerapp logs show -n tiles-frontend -g TilesApp --tail 100`
- `az containerapp logs show -n tiles-backend -g TilesApp --tail 100`

Tenant and feature posture:

- `GET /api/features`
- `GET /api/tenant/impact`

## Security Language and Absolutes

This section is intentionally strict.

- Tiles is built to align with zero-trust principles, but it is not a zero-trust certification by itself.
- Tiles is not automatically compliant with SOC 2, ISO 27001, HIPAA, PCI DSS, or any other framework by default deployment alone.
- Compliance is determined by your full environment, controls, data handling, and operations, not by a single dashboard product.
- Misconfiguration risk is real. Operator decisions, access policy design, and automation guardrails directly affect security outcomes.

## Feature Gates and Commercial Separation

The gate structure exists now so packaging and upsell do not require a backend rewrite later.

- `intuneRemote`: controls Intune remote operations surface.
- `automationAdvanced`: controls advanced remote automation/streaming surfaces.
- `multiTenant`: controls enterprise multi-tenant surfaces and metrics.

Current default behavior is permissive so existing environments do not break while packaging is finalized. The monetization split can be moved into environment-level gate policy without reworking route architecture.

## Tenant Impact Metrics

`GET /api/tenant/impact` returns a compact impact summary for operations and commercial planning:

- Whether multi-tenant mode is active.
- Subscription resolution source and validation state.
- Allowlist and tenant mapping counts.
- Storage partition key posture.

This gives an auditable signal for hosted differentiation and enterprise readiness.

## Readiness Check Before Consumer Release

Items that now exist:

- Feature-gate middleware in backend runtime.
- Public docs for install, deploy, and security baseline.
- Legal docs for terms and privacy.
- Open-source license with warranty/liability disclaimer.

Items to complete before broad consumer rollout:

- Publish final support and incident response SLA language.
- Publish final telemetry defaults and retention window by deployment type.
- Complete release packaging checks for public/demo vs private/dev identity behavior.
