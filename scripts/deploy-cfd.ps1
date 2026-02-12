<#
.SYNOPSIS
    Deploys CFD (Tiles) to Azure Container Apps using Bicep.

.DESCRIPTION
    Deploys prebuilt container images from deploy/azure/main.bicep. Values can be
    provided via parameters or deploy/.env. Safe to re-run. Includes explicit
    confirmation and DryRun mode.
#>

param(
    [string]$ResourceGroup = "cfd-rg",
    [string]$Location = "eastus2",
    [switch]$PublicAccess,
    [string]$FrontendImage = "ghcr.io/cfd/tiles-frontend:latest",
    [string]$BackendImage = "ghcr.io/cfd/tiles-backend:latest",
    [switch]$DemoMode,
    [string]$EnvironmentName = "cfd-tiles-env",
    [string]$FrontendAppName = "cfd-tiles-frontend",
    [string]$BackendAppName = "cfd-tiles-backend",
    [string]$AzureTenantId = "",
    [string]$AzureClientId = "",
    [string]$AzureClientSecret = "",
    [string]$AzureStorageConnectionString = "",
    [string]$AzureSubscriptionId = "",
    [string]$AuthTenantId = "",
    [string]$AuthAudience = "",
    [string]$GhcrUsername = "",
    [string]$GhcrPassword = "",
    [ValidateSet('latest','major','minor','version')]
    [string]$ReleaseTrack = 'latest',
    [string]$TrackVersion,
    [switch]$ConfirmDeploy,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Read-EnvFile {
    param([string]$Path)

    $result = @{}
    if (-not (Test-Path $Path)) {
        return $result
    }

    foreach ($line in Get-Content -Path $Path) {
        if ($line -match '^\s*#' -or $line -notmatch '=') { continue }
        $parts = $line.Split('=', 2)
        if ($parts.Count -eq 2) {
            $key = $parts[0].Trim()
            $value = $parts[1].Trim()
            if ($key) { $result[$key] = $value }
        }
    }

    return $result
}

function Resolve-Value {
    param(
        [string]$ParamValue,
        [hashtable]$EnvMap,
        [string]$EnvKey,
        [string]$Default = ""
    )

    if (-not [string]::IsNullOrWhiteSpace($ParamValue)) {
        return $ParamValue
    }

    if ($EnvMap.ContainsKey($EnvKey) -and -not [string]::IsNullOrWhiteSpace($EnvMap[$EnvKey])) {
        return $EnvMap[$EnvKey]
    }

    return $Default
}

function Get-ImageBase {
    param([string]$Image)

    if ([string]::IsNullOrWhiteSpace($Image)) {
        return $Image
    }

    $lastSlash = $Image.LastIndexOf('/')
    $lastColon = $Image.LastIndexOf(':')
    if ($lastColon -gt $lastSlash) {
        return $Image.Substring(0, $lastColon)
    }

    return $Image
}

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
        [string]$TrackVersion,
        [bool]$DemoMode
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
            DemoMode = $DemoMode
            UpdatedOn = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        }

        $state | ConvertTo-Json | Set-Content -Path $statePath -Encoding UTF8
    } catch {
        Write-Host "Warning: Failed to write deploy/.install.json" -ForegroundColor Yellow
    }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$repoRoot = $repoRoot.Path

$publicTemplate = Join-Path $repoRoot "deploy\azure\main.bicep"
$legacyScript = Join-Path $repoRoot "container\infrastructure\deploy-azure.ps1"
$envFile = Join-Path $repoRoot "deploy\.env"
$envMap = Read-EnvFile -Path $envFile

$FrontendImage = Resolve-Value -ParamValue $FrontendImage -EnvMap $envMap -EnvKey "FRONTEND_IMAGE" -Default "ghcr.io/cfd/tiles-frontend:latest"
$BackendImage = Resolve-Value -ParamValue $BackendImage -EnvMap $envMap -EnvKey "BACKEND_IMAGE" -Default "ghcr.io/cfd/tiles-backend:latest"

if (-not $DemoMode -and $envMap.ContainsKey("DEMO_MODE") -and $envMap["DEMO_MODE"].ToLowerInvariant() -eq "true") {
    $DemoMode = $true
}

$AzureTenantId = Resolve-Value -ParamValue $AzureTenantId -EnvMap $envMap -EnvKey "AZURE_TENANT_ID"
$AzureClientId = Resolve-Value -ParamValue $AzureClientId -EnvMap $envMap -EnvKey "AZURE_CLIENT_ID"
$AzureClientSecret = Resolve-Value -ParamValue $AzureClientSecret -EnvMap $envMap -EnvKey "AZURE_CLIENT_SECRET"
$AzureStorageConnectionString = Resolve-Value -ParamValue $AzureStorageConnectionString -EnvMap $envMap -EnvKey "AZURE_STORAGE_CONNECTION_STRING"
$AzureSubscriptionId = Resolve-Value -ParamValue $AzureSubscriptionId -EnvMap $envMap -EnvKey "AZURE_SUBSCRIPTION_ID"
$AuthTenantId = Resolve-Value -ParamValue $AuthTenantId -EnvMap $envMap -EnvKey "AUTH_TENANT_ID"
$AuthAudience = Resolve-Value -ParamValue $AuthAudience -EnvMap $envMap -EnvKey "AUTH_AUDIENCE"
$GhcrUsername = Resolve-Value -ParamValue $GhcrUsername -EnvMap $envMap -EnvKey "GHCR_USERNAME"
$GhcrPassword = Resolve-Value -ParamValue $GhcrPassword -EnvMap $envMap -EnvKey "GHCR_PASSWORD"

Write-Host "CFD Azure Deployment" -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Gray
Write-Host "Location: $Location" -ForegroundColor Gray
Write-Host "Public Access: $($PublicAccess.IsPresent)" -ForegroundColor Gray
Write-Host "Demo Mode: $($DemoMode.IsPresent)" -ForegroundColor Gray
Write-Host "Frontend Image: $FrontendImage" -ForegroundColor Gray
Write-Host "Backend Image: $BackendImage" -ForegroundColor Gray
Write-Host ""

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
    if (-not $AzureTenantId) { $AzureTenantId = Read-Host "Enter Azure Tenant ID" }
    if (-not $AzureClientId) { $AzureClientId = Read-Host "Enter Azure Client ID" }
    if (-not $AzureClientSecret) {
        $sec = Read-Host "Enter Azure Client Secret" -AsSecureString
        $AzureClientSecret = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
    }
    if (-not $AzureStorageConnectionString) {
        $AzureStorageConnectionString = Read-Host "Enter Azure Storage Connection String"
    }

    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: Azure CLI not found. Install from https://learn.microsoft.com/cli/azure/install-azure-cli" -ForegroundColor Red
        exit 1
    }

    $accountRaw = az account show 2>$null
    if (-not $accountRaw) {
        az login | Out-Null
        $accountRaw = az account show 2>$null
    }

    if (-not $accountRaw) {
        Write-Host "ERROR: Unable to resolve Azure account context." -ForegroundColor Red
        exit 1
    }

    if ($AzureSubscriptionId) {
        az account set --subscription $AzureSubscriptionId | Out-Null
    }

    $rgExists = az group exists --name $ResourceGroup
    if ($rgExists -eq "false") {
        az group create --name $ResourceGroup --location $Location --only-show-errors | Out-Null
    }

    $deployArgs = @(
        "deployment", "group", "create",
        "--resource-group", $ResourceGroup,
        "--template-file", $publicTemplate,
        "--parameters", "location=$Location",
        "--parameters", "environmentName=$EnvironmentName",
        "--parameters", "frontendAppName=$FrontendAppName",
        "--parameters", "backendAppName=$BackendAppName",
        "--parameters", "publicAccess=$($PublicAccess.IsPresent.ToString().ToLowerInvariant())",
        "--parameters", "demoMode=$($DemoMode.IsPresent.ToString().ToLowerInvariant())",
        "--parameters", "frontendImage=$FrontendImage",
        "--parameters", "backendImage=$BackendImage",
        "--parameters", "azureTenantId=$AzureTenantId",
        "--parameters", "azureClientId=$AzureClientId",
        "--parameters", "azureClientSecret=$AzureClientSecret",
        "--parameters", "azureStorageConnectionString=$AzureStorageConnectionString",
        "--parameters", "azureSubscriptionId=$AzureSubscriptionId",
        "--parameters", "authTenantId=$AuthTenantId",
        "--parameters", "authAudience=$AuthAudience"
    )

    if (-not [string]::IsNullOrWhiteSpace($GhcrUsername) -and -not [string]::IsNullOrWhiteSpace($GhcrPassword)) {
        $deployArgs += @("--parameters", "ghcrUsername=$GhcrUsername")
        $deployArgs += @("--parameters", "ghcrPassword=$GhcrPassword")
    }

    az @deployArgs | Out-Null

    Write-InstallState `
        -RepoRoot $repoRoot `
        -ResourceGroup $ResourceGroup `
        -Location $Location `
        -EnvironmentName $EnvironmentName `
        -FrontendAppName $FrontendAppName `
        -BackendAppName $BackendAppName `
        -PublicAccess:$PublicAccess `
        -FrontendImage (Get-ImageBase $FrontendImage) `
        -BackendImage (Get-ImageBase $BackendImage) `
        -ReleaseTrack $ReleaseTrack `
        -TrackVersion $TrackVersion `
        -DemoMode:$DemoMode

    $frontendFqdn = az containerapp show --name $FrontendAppName --resource-group $ResourceGroup --query "properties.configuration.ingress.fqdn" -o tsv 2>$null
    if ($frontendFqdn) {
        Write-Host "Frontend URL: https://$frontendFqdn" -ForegroundColor Green
    }

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
        -FrontendImage (Get-ImageBase $FrontendImage) `
        -BackendImage (Get-ImageBase $BackendImage) `
        -ReleaseTrack $ReleaseTrack `
        -TrackVersion $TrackVersion `
        -DemoMode:$DemoMode
}
