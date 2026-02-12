<#
.SYNOPSIS
    Bootstraps Azure prerequisites and writes deploy/.env for CFD public deployments.

.DESCRIPTION
    Creates or reuses the target resource group, storage account, Entra app registration,
    service principal, and Reader role assignment at subscription scope. Writes sanitized
    runtime configuration to deploy/.env without printing secret values. Safe to re-run.

.PARAMETER ResourceGroup
    Azure resource group for the deployment.

.PARAMETER Location
    Azure region for resource creation.

.PARAMETER SubscriptionId
    Subscription ID to target. Uses current az context when omitted.

.PARAMETER AppDisplayName
    Entra app registration display name used for backend credentials.

.PARAMETER StorageAccountName
    Optional storage account name. If omitted, a deterministic name is generated.

.PARAMETER EnvFilePath
    Path to the deploy env file to write. Defaults to deploy/.env in repo root.

.PARAMETER ConfirmSetup
    Required to execute changes.

.PARAMETER DryRun
    Preview planned actions only.
#>

param(
    [string]$ResourceGroup = "cfd-rg",
    [string]$Location = "eastus2",
    [string]$SubscriptionId = "",
    [string]$AppDisplayName = "cfd-tiles-backend-app",
    [string]$StorageAccountName = "",
    [string]$EnvFilePath = "",
    [switch]$ConfirmSetup,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Write-Action {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Cyan
}

function Read-EnvFile {
    param([string]$Path)

    $result = @{}
    if (-not (Test-Path $Path)) {
        return $result
    }

    $lines = Get-Content -Path $Path
    foreach ($line in $lines) {
        if ($line -match '^\s*#' -or $line -notmatch '=') {
            continue
        }
        $parts = $line.Split('=', 2)
        if ($parts.Count -eq 2) {
            $key = $parts[0].Trim()
            $value = $parts[1].Trim()
            if ($key.Length -gt 0) {
                $result[$key] = $value
            }
        }
    }

    return $result
}

function Get-MapValue {
    param(
        [hashtable]$Map,
        [string]$Key,
        [string]$Default = ""
    )

    if ($Map.ContainsKey($Key) -and -not [string]::IsNullOrWhiteSpace($Map[$Key])) {
        return $Map[$Key]
    }

    return $Default
}

function New-StorageName {
    param(
        [string]$ResourceGroup,
        [string]$SubscriptionId
    )

    $base = ("cfd" + ($ResourceGroup -replace '[^a-zA-Z0-9]', '')).ToLowerInvariant()
    if ($base.Length -gt 16) {
        $base = $base.Substring(0, 16)
    }

    $hashInput = "$ResourceGroup|$SubscriptionId"
    $hashBytes = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($hashInput))
    $suffix = ([BitConverter]::ToString($hashBytes)).Replace('-', '').ToLowerInvariant().Substring(0, 8)

    $name = "$base$suffix"
    if ($name.Length -lt 3) {
        $name = "$name" + "cfd"
    }
    if ($name.Length -gt 24) {
        $name = $name.Substring(0, 24)
    }

    return $name
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$repoRoot = $repoRoot.Path

if (-not $EnvFilePath -or $EnvFilePath.Trim().Length -eq 0) {
    $EnvFilePath = Join-Path $repoRoot "deploy\.env"
}

if ($DryRun) {
    Write-Action "[DryRun] Would bootstrap Azure prerequisites."
    Write-Action "[DryRun] Resource group: $ResourceGroup ($Location)"
    Write-Action "[DryRun] App display name: $AppDisplayName"
    if ($StorageAccountName) {
        Write-Action "[DryRun] Storage account: $StorageAccountName"
    } else {
        Write-Action "[DryRun] Storage account: generated name"
    }
    Write-Action "[DryRun] Env output path: $EnvFilePath"
    exit 0
}

if (-not $ConfirmSetup) {
    Write-Host "ERROR: Setup requires explicit confirmation." -ForegroundColor Red
    Write-Host "Re-run with -ConfirmSetup to proceed." -ForegroundColor Yellow
    exit 1
}

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Azure CLI is required. Install from https://learn.microsoft.com/cli/azure/install-azure-cli" -ForegroundColor Red
    exit 1
}

$accountRaw = az account show 2>$null
if (-not $accountRaw) {
    Write-Action "Azure login required. Running az login..."
    az login | Out-Null
    $accountRaw = az account show 2>$null
}

if (-not $accountRaw) {
    Write-Host "ERROR: Unable to resolve Azure account context." -ForegroundColor Red
    exit 1
}

$account = $accountRaw | ConvertFrom-Json

if ($SubscriptionId) {
    az account set --subscription $SubscriptionId | Out-Null
    $account = az account show | ConvertFrom-Json
} else {
    $SubscriptionId = $account.id
}

$tenantId = $account.tenantId
$scope = "/subscriptions/$SubscriptionId"

$existingEnv = Read-EnvFile -Path $EnvFilePath

$rgExists = az group exists --name $ResourceGroup
if ($rgExists -eq "false") {
    Write-Action "Creating resource group $ResourceGroup in $Location"
    az group create --name $ResourceGroup --location $Location --only-show-errors | Out-Null
} else {
    Write-Action "Resource group exists: $ResourceGroup"
}

if (-not $StorageAccountName -or $StorageAccountName.Trim().Length -eq 0) {
    $StorageAccountName = New-StorageName -ResourceGroup $ResourceGroup -SubscriptionId $SubscriptionId
}

$storage = az storage account show --name $StorageAccountName --resource-group $ResourceGroup --only-show-errors 2>$null
if (-not $storage) {
    Write-Action "Creating storage account: $StorageAccountName"
    az storage account create `
        --name $StorageAccountName `
        --resource-group $ResourceGroup `
        --location $Location `
        --sku Standard_LRS `
        --kind StorageV2 `
        --allow-blob-public-access false `
        --only-show-errors | Out-Null
} else {
    Write-Action "Storage account exists: $StorageAccountName"
}

$storageConnection = az storage account show-connection-string `
    --name $StorageAccountName `
    --resource-group $ResourceGroup `
    --query connectionString -o tsv

$appListRaw = az ad app list --display-name $AppDisplayName --query "[?displayName=='$AppDisplayName']" -o json
$appList = $appListRaw | ConvertFrom-Json
$app = $null
if ($appList -and $appList.Count -gt 0) {
    $app = $appList | Select-Object -First 1
    Write-Action "Using existing app registration: $AppDisplayName"
} else {
    Write-Action "Creating app registration: $AppDisplayName"
    $app = az ad app create --display-name $AppDisplayName --sign-in-audience AzureADMyOrg --output json | ConvertFrom-Json
}

$appId = $app.appId

$spListRaw = az ad sp list --filter "appId eq '$appId'" -o json
$spList = $spListRaw | ConvertFrom-Json
if ($spList -and $spList.Count -gt 0) {
    Write-Action "Service principal exists for appId $appId"
} else {
    Write-Action "Creating service principal for appId $appId"
    az ad sp create --id $appId --only-show-errors | Out-Null
    Start-Sleep -Seconds 5
}

$readerAssignmentsRaw = az role assignment list --assignee $appId --scope $scope --role Reader --query "[].id" -o json
$readerAssignments = $readerAssignmentsRaw | ConvertFrom-Json
if (-not $readerAssignments -or $readerAssignments.Count -eq 0) {
    Write-Action "Assigning Reader role at $scope"
    az role assignment create --assignee $appId --role Reader --scope $scope --only-show-errors | Out-Null
} else {
    Write-Action "Reader role already assigned at subscription scope"
}

$clientSecret = ""
$existingClientId = Get-MapValue -Map $existingEnv -Key "AZURE_CLIENT_ID"
$existingClientSecret = Get-MapValue -Map $existingEnv -Key "AZURE_CLIENT_SECRET"
if ($existingClientId -eq $appId -and -not [string]::IsNullOrWhiteSpace($existingClientSecret)) {
    $clientSecret = $existingClientSecret
    Write-Action "Reusing existing AZURE_CLIENT_SECRET from env file"
} else {
    Write-Action "Creating app client secret credential"
    $credential = az ad app credential reset --id $appId --display-name "cfd-public-deploy" --years 2 --output json | ConvertFrom-Json
    $clientSecret = $credential.password
}

$authTenantId = Get-MapValue -Map $existingEnv -Key "AUTH_TENANT_ID" -Default $tenantId
$authAudience = Get-MapValue -Map $existingEnv -Key "AUTH_AUDIENCE" -Default "api://$appId"
$frontendImage = Get-MapValue -Map $existingEnv -Key "FRONTEND_IMAGE" -Default "ghcr.io/cfd/tiles-frontend:latest"
$backendImage = Get-MapValue -Map $existingEnv -Key "BACKEND_IMAGE" -Default "ghcr.io/cfd/tiles-backend:latest"
$demoMode = Get-MapValue -Map $existingEnv -Key "DEMO_MODE" -Default "false"
$armRequireAuth = Get-MapValue -Map $existingEnv -Key "ARM_REQUIRE_AUTH" -Default "true"
$ghcrUser = Get-MapValue -Map $existingEnv -Key "GHCR_USERNAME"
$ghcrPassword = Get-MapValue -Map $existingEnv -Key "GHCR_PASSWORD"

$envDir = Split-Path -Path $EnvFilePath -Parent
if (-not (Test-Path $envDir)) {
    New-Item -ItemType Directory -Path $envDir -Force | Out-Null
}

$lines = @(
    "# Generated by scripts/setup-cfd-prereqs.ps1 on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "# Safe to re-run. Secrets are written only to this local file.",
    "",
    "AZURE_TENANT_ID=$tenantId",
    "AZURE_CLIENT_ID=$appId",
    "AZURE_CLIENT_SECRET=$clientSecret",
    "AZURE_STORAGE_CONNECTION_STRING=$storageConnection",
    "AZURE_SUBSCRIPTION_ID=$SubscriptionId",
    "",
    "AUTH_TENANT_ID=$authTenantId",
    "AUTH_AUDIENCE=$authAudience",
    "ARM_REQUIRE_AUTH=$armRequireAuth",
    "",
    "FRONTEND_IMAGE=$frontendImage",
    "BACKEND_IMAGE=$backendImage",
    "DEMO_MODE=$demoMode",
    "",
    "GHCR_USERNAME=$ghcrUser",
    "GHCR_PASSWORD=$ghcrPassword"
)

Set-Content -Path $EnvFilePath -Value $lines -Encoding UTF8

Write-Host "Azure prerequisite setup complete." -ForegroundColor Green
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Gray
Write-Host "Storage Account: $StorageAccountName" -ForegroundColor Gray
Write-Host "App Registration: $AppDisplayName" -ForegroundColor Gray
Write-Host "Client ID: $appId" -ForegroundColor Gray
Write-Host "Env file written: $EnvFilePath" -ForegroundColor Gray
