# Privacy Policy

Effective date: 2026-02-13

This policy describes what Tiles processes by default in deployment form.

## 1. What Tiles Processes

By default, Tiles processes operational data needed to render dashboards and execute configured actions in your own environment.

Depending on your configuration, this may include:

- device and endpoint metadata
- user/account identifiers from your tenant
- vulnerability and application inventory data
- Azure resource metadata
- request metadata for API operations

## 2. Telemetry and Logging

By default runtime behavior includes service logs and request diagnostics needed for operations and troubleshooting.

Typical log content may include:

- timestamps
- endpoint paths
- HTTP status codes
- request IDs
- service health and sync status

Secrets are not intentionally logged. You should still run your own logging review and redaction controls.

## 3. Authentication Data

Tiles integrates with Microsoft identity flows when enabled.

Default behavior:

- login requests are handled through configured identity providers and app middleware
- tokens are validated for access control
- tokens/secrets are not intended for persistent storage in application logs

Session/account data handling in the frontend depends on deployment configuration and browser runtime behavior.

## 4. Data Storage and Retention

Retention depends on your own infrastructure choices (for example: Azure Table Storage, log sinks, and cloud monitoring policies). Tiles does not enforce a universal retention period across all installations.

## 5. Third-Party Services

If you enable Microsoft Graph, Intune, Azure APIs, or other integrations, those providers may process data under their own terms and privacy policies.

## 6. Your Responsibilities

You are responsible for:

- lawful basis for data processing
- required notices and consent in your organization
- retention and deletion policy
- access control and least-privilege design
- regional and regulatory compliance obligations

## 7. Policy Changes

This policy may be updated as product behavior evolves. Use release notes/dev logs to track operationally relevant changes.
