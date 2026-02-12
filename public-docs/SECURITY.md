# Security

This repository is deployment-only. Secrets are never committed to source control and should be provided via environment variables or a managed secrets store (e.g., Azure Key Vault).

## Reporting a Vulnerability

If you discover a security issue, please open a private GitHub security advisory or contact the project owners through your standard security channel. Do not disclose vulnerabilities publicly until they have been triaged.

## Guidance

- Never commit `.env` or other secret files.
- Use separate service principals per environment.
- Restrict app permissions to the minimum required for your use case.
