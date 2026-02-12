<#
.SYNOPSIS
    Updates an existing Tiles deployment to the latest channel images.

.DESCRIPTION
    Supports Docker Compose and Azure Container Apps deployments. Uses the
    channel's latest tags (latest or latest-rc). No secrets are printed.

.PARAMETER Channel
    Update channel: public (latest), test (latest-rc), or demo (latest-demo).

.PARAMETER ReleaseTrack
    Optional update track: latest, major, minor, or version.

.PARAMETER TrackVersion
    Version track value (e.g., 1 for major, 1.4 for minor, or 1.4.2 for exact).

.PARAMETER UpdateFiles
    If set, pulls latest files when the install is a git clone.

.PARAMETER InstallType
    Deployment type: docker or aca. If omitted, attempts to read deploy/.install.json.

.PARAMETER ResourceGroup
    Azure resource group (ACA only).

.PARAMETER FrontendAppName
    Frontend Container App name (ACA only).

.PARAMETER BackendAppName
    Backend Container App name (ACA only).

.PARAMETER FrontendImage
    Frontend image base (without tag).

.PARAMETER BackendImage
    Backend image base (without tag).

.PARAMETER ConfirmUpdate
    Required to perform update actions.

.PARAMETER DryRun
    If set, only prints planned actions without changes.
#>

param(
    [ValidateSet('public','test','demo')]
    [string]$Channel = 'public',
    [ValidateSet('docker','aca')]
    [string]$InstallType,
    [string]$ResourceGroup,
    [string]$FrontendAppName,
    [string]$BackendAppName,
    [string]$FrontendImage = 'ghcr.io/cfd/tiles-frontend',
    [string]$BackendImage = 'ghcr.io/cfd/tiles-backend',
    [ValidateSet('latest','major','minor','version')]
    [string]$ReleaseTrack,
    [string]$TrackVersion,
    [switch]$UpdateFiles,
    [switch]$ConfirmUpdate,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Write-Action {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Cyan
}

$repoRoot = (Get-Item -Path (Join-Path $PSScriptRoot "..") -ErrorAction Stop).FullName
$statePath = Join-Path $repoRoot "deploy\.install.json"

if (-not $InstallType -and (Test-Path $statePath)) {
    try {
        $state = Get-Content -Path $statePath -Raw | ConvertFrom-Json
        if ($state.InstallType) { $InstallType = $state.InstallType }
        if (-not $ResourceGroup -and $state.ResourceGroup) { $ResourceGroup = $state.ResourceGroup }
        if (-not $FrontendAppName -and $state.FrontendAppName) { $FrontendAppName = $state.FrontendAppName }
        if (-not $BackendAppName -and $state.BackendAppName) { $BackendAppName = $state.BackendAppName }
        if ($state.FrontendImage) { $FrontendImage = $state.FrontendImage }
        if ($state.BackendImage) { $BackendImage = $state.BackendImage }
        if (-not $ReleaseTrack -and $state.ReleaseTrack) { $ReleaseTrack = $state.ReleaseTrack }
        if (-not $TrackVersion -and $state.TrackVersion) { $TrackVersion = $state.TrackVersion }
    } catch {
        Write-Host "Warning: Failed to read deploy/.install.json. Proceeding with provided parameters." -ForegroundColor Yellow
    }
}

if (-not $InstallType) {
    $deployCompose = Join-Path $repoRoot "deploy\docker-compose.yml"
    if (Test-Path $deployCompose) {
        $InstallType = 'docker'
    }
}

if (-not $InstallType) {
    Write-Host "ERROR: -InstallType is required (docker | aca)." -ForegroundColor Red
    exit 1
}

$tag = if ($Channel -eq 'test') { 'latest-rc' } elseif ($Channel -eq 'demo') { 'latest-demo' } else { 'latest' }
$releaseManifest = Join-Path $repoRoot "deploy\\release-manifest.json"
if (-not $ReleaseTrack -or $ReleaseTrack.Trim().Length -eq 0) {
    $ReleaseTrack = 'latest'
}

if ($ReleaseTrack -ne 'latest') {
    if (-not $TrackVersion -and (Test-Path $releaseManifest)) {
        try {
            $manifest = Get-Content -Path $releaseManifest -Raw | ConvertFrom-Json
            $ver = $manifest.version
            if ($ver) {
                $parts = $ver.Split('.')
                if ($ReleaseTrack -eq 'major' -and $parts.Count -ge 1) { $TrackVersion = $parts[0] }
                if ($ReleaseTrack -eq 'minor' -and $parts.Count -ge 2) { $TrackVersion = "$($parts[0]).$($parts[1])" }
                if ($ReleaseTrack -eq 'version') { $TrackVersion = $ver }
            }
        } catch {
            Write-Host "Warning: Failed to parse deploy/release-manifest.json." -ForegroundColor Yellow
        }
    }

    if (-not $TrackVersion) {
        Write-Host "ERROR: -TrackVersion is required for ReleaseTrack '$ReleaseTrack'." -ForegroundColor Red
        exit 1
    }

    $tag = $TrackVersion
}

$frontendRef = "${FrontendImage}:$tag"
$backendRef = "${BackendImage}:$tag"

Write-Host "CFD Update" -ForegroundColor Cyan
Write-Host "Channel: $Channel" -ForegroundColor Gray
Write-Host "Install Type: $InstallType" -ForegroundColor Gray
Write-Host "Frontend Image: $frontendRef" -ForegroundColor Gray
Write-Host "Backend Image: $backendRef" -ForegroundColor Gray
Write-Host "Release Track: $ReleaseTrack" -ForegroundColor Gray
Write-Host "";

if ($DryRun) {
    Write-Action "[DryRun] Would update deployment."
    exit 0
}

if (-not $ConfirmUpdate) {
    Write-Host "ERROR: Update requires explicit confirmation." -ForegroundColor Red
    Write-Host "Re-run with -ConfirmUpdate to proceed." -ForegroundColor Yellow
    exit 1
}

if ($UpdateFiles) {
    $gitDir = Join-Path $repoRoot ".git"
    if (Test-Path $gitDir) {
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            Write-Host "Warning: git not found; skipping file updates." -ForegroundColor Yellow
        } else {
            Write-Host "Updating files via git pull..." -ForegroundColor Cyan
            git -C $repoRoot pull
        }
    } else {
        Write-Host "Warning: No .git folder found; skipping file updates." -ForegroundColor Yellow
    }
}

if ($InstallType -eq 'docker') {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: docker is required for Docker updates." -ForegroundColor Red
        exit 1
    }

    $deployDir = Join-Path $repoRoot "deploy"
    if (-not (Test-Path $deployDir)) {
        Write-Host "ERROR: deploy/ not found. Ensure the deploy bundle is present." -ForegroundColor Red
        exit 1
    }

    $env:FRONTEND_IMAGE = $frontendRef
    $env:BACKEND_IMAGE = $backendRef
    if ($Channel -eq 'demo') {
        $env:DEMO_MODE = 'true'
    }

    Push-Location $deployDir
    try {
        docker compose pull | Out-Null
        docker compose up -d | Out-Null
    } finally {
        Pop-Location
    }

    Write-Host "Docker update complete." -ForegroundColor Green
    exit 0
}

if ($InstallType -eq 'aca') {
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: Azure CLI is required for ACA updates." -ForegroundColor Red
        exit 1
    }

    if (-not $ResourceGroup) { $ResourceGroup = Read-Host "Enter Resource Group" }
    if (-not $FrontendAppName) { $FrontendAppName = Read-Host "Enter Frontend App Name" }
    if (-not $BackendAppName) { $BackendAppName = Read-Host "Enter Backend App Name" }

    $account = az account show 2>$null | ConvertFrom-Json
    if (-not $account) {
        az login | Out-Null
    }

    $demoModeValue = if ($Channel -eq 'demo') { 'true' } else { 'false' }
    az containerapp update --name $BackendAppName --resource-group $ResourceGroup --image $backendRef --set-env-vars DEMO_MODE=$demoModeValue | Out-Null
    az containerapp update --name $FrontendAppName --resource-group $ResourceGroup --image $frontendRef | Out-Null

    Write-Host "Azure Container Apps update complete." -ForegroundColor Green
    exit 0
}

Write-Host "ERROR: Unsupported InstallType: $InstallType" -ForegroundColor Red
exit 1
