# Simple Install

Use this quick command from a cloned repo root:

```powershell
pwsh -File scripts\install-cfd.ps1 -InstallMethod local -DeployType aca -ProvisionAzurePrereqs -PublicAccess -PromptGhcrCredentials -ConfirmInstall
```

For full details, prerequisites, and alternative Docker flow, see `public-docs/INSTALL.md`.
