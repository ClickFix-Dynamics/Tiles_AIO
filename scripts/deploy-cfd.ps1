<#
.SYNOPSIS
    Deploys CFD (Tiles) to Azure Container Apps using Bicep.

.DESCRIPTION
    Deploys prebuilt container images using deploy/azure/main.bicep when present.
    Falls back to container/infrastructure/deploy-azure.ps1 if the public
    deployment template is not available. Includes explicit confirmation and
    dry-run support.

.PARAMETER ResourceGroup
    Azure resource group name.

.PARAMETER Location
    Azure region for deployment.

.PARAMETER PublicAccess
    If set, deploys with external ingress. Default is internal-only.

.PARAMETER FrontendImage
    Frontend image reference (default: ghcr.io/cfd/tiles-frontend:latest).

.PARAMETER BackendImage
    Backend image reference (default: ghcr.io/cfd/tiles-backend:latest).

.PARAMETER EnvironmentName
    Container Apps environment name.

.PARAMETER FrontendAppName
    Frontend Container App name.

.PARAMETER BackendAppName
    Backend Container App name.

.PARAMETER ConfirmDeploy
    Required to perform deployment actions.

.PARAMETER DryRun
    If set, prints planned actions without executing.

.PARAMETER ReleaseTrack
    Optional update track recorded for future updates (latest, major, minor, version).

.PARAMETER TrackVersion
    Version track value for major/minor/version updates.
#>

param(
    [string]$ResourceGroup = "cfd-rg",
    [string]$Location = "eastus2",
    [switch]$PublicAccess,
    [string]$FrontendImage = "ghcr.io/cfd/tiles-frontend:latest",
    [string]$BackendImage = "ghcr.io/cfd/tiles-backend:latest",
    [string]$EnvironmentName = "cfd-tiles-env",
    [string]$FrontendAppName = "cfd-tiles-frontend",
    [string]$BackendAppName = "cfd-tiles-backend",
    [ValidateSet('latest','major','minor','version')]
    [string]$ReleaseTrack = 'latest',
    [string]$TrackVersion,
    [switch]$ConfirmDeploy,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$repoRoot = $repoRoot.Path

$publicTemplate = Join-Path $repoRoot "deploy\azure\main.bicep"
$legacyScript = Join-Path $repoRoot "container\infrastructure\deploy-azure.ps1"

Write-Host "CFD Azure Deployment" -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Gray
Write-Host "Location: $Location" -ForegroundColor Gray
Write-Host "Public Access: $PublicAccess" -ForegroundColor Gray
Write-Host "Frontend Image: $FrontendImage" -ForegroundColor Gray
Write-Host "Backend Image: $BackendImage" -ForegroundColor Gray
Write-Host ""

function Write-InstallState {
    param(
        [string]$RepoRoot,
        [string]$ResourceGroup,
        [string]$Location,
        [string]$EnvironmentName,
        [string]$FrontendAppName,
        [string]$BackendAppName,
        [bool]$PublicAccess,
        [string]$FrontendImage,
        [string]$BackendImage,
        [string]$ReleaseTrack,
        [string]$TrackVersion
    )

    try {
        $deployDir = Join-Path $RepoRoot "deploy"
        if (-not (Test-Path $deployDir)) {
            return
        }

        $statePath = Join-Path $deployDir ".install.json"
        $state = [PSCustomObject]@{
            InstallType = "aca"
            ResourceGroup = $ResourceGroup
            Location = $Location
            EnvironmentName = $EnvironmentName
            FrontendAppName = $FrontendAppName
            BackendAppName = $BackendAppName
            PublicAccess = $PublicAccess
            FrontendImage = $FrontendImage
            BackendImage = $BackendImage
            ReleaseTrack = $ReleaseTrack
            TrackVersion = $TrackVersion
            UpdatedOn = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }

        $state | ConvertTo-Json | Set-Content -Path $statePath -Encoding UTF8
    } catch {
        Write-Host "Warning: Failed to write deploy/.install.json" -ForegroundColor Yellow
    }
}

if ($DryRun) {
    Write-Host "[DryRun] Would deploy using:" -ForegroundColor Yellow
    if (Test-Path $publicTemplate) {
        Write-Host "  Template: $publicTemplate" -ForegroundColor Yellow
    } elseif (Test-Path $legacyScript) {
        Write-Host "  Legacy script: $legacyScript" -ForegroundColor Yellow
    } else {
        Write-Host "  ERROR: No deployment template found." -ForegroundColor Yellow
    }
    Write-Host "[DryRun] No changes were made." -ForegroundColor Yellow
    exit 0
}

if (-not $ConfirmDeploy) {
    Write-Host "ERROR: Deployment requires explicit confirmation." -ForegroundColor Red
    Write-Host "Re-run with -ConfirmDeploy to proceed." -ForegroundColor Yellow
    exit 1
}

if (Test-Path $publicTemplate) {
    # Load env from deploy/.env if present (no secrets are printed)
    $envFile = Join-Path $repoRoot "deploy\.env"
    if (Test-Path $envFile) {
        Get-Content $envFile | ForEach-Object {
            if ($_ -match "^([^#=]+)=(.*)$") {
                [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim())
            }
        }
    }

    $azureTenantId = $env:AZURE_TENANT_ID
    $azureClientId = $env:AZURE_CLIENT_ID
    $azureClientSecret = $env:AZURE_CLIENT_SECRET
    $azureStorageConnectionString = $env:AZURE_STORAGE_CONNECTION_STRING
    $azureSubscriptionId = $env:AZURE_SUBSCRIPTION_ID
    $authTenantId = $env:AUTH_TENANT_ID
    $authAudience = $env:AUTH_AUDIENCE

    if (-not $azureTenantId) { $azureTenantId = Read-Host "Enter Azure Tenant ID" }
    if (-not $azureClientId) { $azureClientId = Read-Host "Enter Azure Client ID" }
    if (-not $azureClientSecret) {
        $sec = Read-Host "Enter Azure Client Secret" -AsSecureString
        $azureClientSecret = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
    }
    if (-not $azureStorageConnectionString) {
        $azureStorageConnectionString = Read-Host "Enter Azure Storage Connection String"
    }

    # Ensure Azure CLI is available and logged in
    $azVersion = az version 2>&1 | ConvertFrom-Json
    if (-not $azVersion) {
        Write-Host "ERROR: Azure CLI not found. Install from https://learn.microsoft.com/cli/azure/install-azure-cli" -ForegroundColor Red
        exit 1
    }
    $account = az account show 2>&1 | ConvertFrom-Json
    if (-not $account) {
        az login | Out-Null
    }

    $rgExists = az group exists --name $ResourceGroup 2>&1
    if ($rgExists -eq "false") {
        az group create --name $ResourceGroup --location $Location | Out-Null
    }

    az deployment group create `
        --resource-group $ResourceGroup `
        --template-file $publicTemplate `
        --parameters location=$Location `
        --parameters environmentName=$EnvironmentName `
        --parameters frontendAppName=$FrontendAppName `
        --parameters backendAppName=$BackendAppName `
        --parameters publicAccess=$($PublicAccess.IsPresent) `
        --parameters frontendImage=$FrontendImage `
        --parameters backendImage=$BackendImage `
        --parameters azureTenantId=$azureTenantId `
        --parameters azureClientId=$azureClientId `
        --parameters azureClientSecret=$azureClientSecret `
        --parameters azureStorageConnectionString=$azureStorageConnectionString `
        --parameters azureSubscriptionId=$azureSubscriptionId `
        --parameters authTenantId=$authTenantId `
        --parameters authAudience=$authAudience | Out-Null

    Write-InstallState `
        -RepoRoot $repoRoot `
        -ResourceGroup $ResourceGroup `
        -Location $Location `
        -EnvironmentName $EnvironmentName `
        -FrontendAppName $FrontendAppName `
        -BackendAppName $BackendAppName `
        -PublicAccess:$PublicAccess `
        -FrontendImage $FrontendImage `
        -BackendImage $BackendImage `
        -ReleaseTrack $ReleaseTrack `
        -TrackVersion $TrackVersion

    Write-Host "Deployment completed." -ForegroundColor Green
    exit 0
}

if (-not (Test-Path $legacyScript)) {
    Write-Host "ERROR: No deployment template found." -ForegroundColor Red
    exit 1
}

& $legacyScript `
    -ResourceGroup $ResourceGroup `
    -Location $Location `
    -PublicAccess:$PublicAccess

if ($LASTEXITCODE -eq 0) {
    Write-InstallState `
        -RepoRoot $repoRoot `
        -ResourceGroup $ResourceGroup `
        -Location $Location `
        -EnvironmentName $EnvironmentName `
        -FrontendAppName $FrontendAppName `
        -BackendAppName $BackendAppName `
        -PublicAccess:$PublicAccess `
        -FrontendImage $FrontendImage `
        -BackendImage $BackendImage `
        -ReleaseTrack $ReleaseTrack `
        -TrackVersion $TrackVersion
}
