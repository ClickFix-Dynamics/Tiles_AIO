<#
.SYNOPSIS
    Updates an existing CFD (Tiles) deployment.

.DESCRIPTION
    Supports Docker Compose and Azure Container Apps deployments using explicit
    confirmation and DryRun mode. Safe to re-run.
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
    [string]$GhcrUsername = '',
    [string]$GhcrPassword = '',
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

function Set-OrAddEnvValue {
    param(
        [string]$Path,
        [string]$Key,
        [string]$Value
    )

    if (-not (Test-Path $Path)) {
        Set-Content -Path $Path -Value "$Key=$Value" -Encoding UTF8
        return
    }

    $lines = Get-Content -Path $Path
    $updated = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "^\s*$([Regex]::Escape($Key))=") {
            $lines[$i] = "$Key=$Value"
            $updated = $true
            break
        }
    }

    if (-not $updated) {
        $lines += "$Key=$Value"
    }

    Set-Content -Path $Path -Value $lines -Encoding UTF8
}

function Ensure-GhcrLogin {
    param([hashtable]$EnvMap)

    $ghcrUser = if ($EnvMap.ContainsKey("GHCR_USERNAME")) { $EnvMap["GHCR_USERNAME"] } else { "" }
    $ghcrPassword = if ($EnvMap.ContainsKey("GHCR_PASSWORD")) { $EnvMap["GHCR_PASSWORD"] } else { "" }

    if ([string]::IsNullOrWhiteSpace($ghcrUser) -or [string]::IsNullOrWhiteSpace($ghcrPassword)) {
        return
    }

    Write-Action "Logging into ghcr.io using credentials from deploy/.env"
    $ghcrPassword | docker login ghcr.io -u $ghcrUser --password-stdin | Out-Null
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

$repoRoot = (Get-Item -Path (Join-Path $PSScriptRoot "..") -ErrorAction Stop).FullName
$statePath = Join-Path $repoRoot "deploy\.install.json"
$envPath = Join-Path $repoRoot "deploy\.env"
$releaseManifest = Join-Path $repoRoot "deploy\release-manifest.json"

$state = $null
if (Test-Path $statePath) {
    try {
        $state = Get-Content -Path $statePath -Raw | ConvertFrom-Json
    } catch {
        Write-Host "Warning: Failed to read deploy/.install.json. Proceeding with provided parameters." -ForegroundColor Yellow
    }
}

if (-not $InstallType -and $state -and $state.InstallType) { $InstallType = $state.InstallType }
if (-not $ResourceGroup -and $state -and $state.ResourceGroup) { $ResourceGroup = $state.ResourceGroup }
if (-not $FrontendAppName -and $state -and $state.FrontendAppName) { $FrontendAppName = $state.FrontendAppName }
if (-not $BackendAppName -and $state -and $state.BackendAppName) { $BackendAppName = $state.BackendAppName }
if (-not $ReleaseTrack -and $state -and $state.ReleaseTrack) { $ReleaseTrack = $state.ReleaseTrack }
if (-not $TrackVersion -and $state -and $state.TrackVersion) { $TrackVersion = $state.TrackVersion }
if ($state -and $state.FrontendImage) { $FrontendImage = Get-ImageBase $state.FrontendImage }
if ($state -and $state.BackendImage) { $BackendImage = Get-ImageBase $state.BackendImage }

$envMap = Read-EnvFile -Path $envPath
if ($envMap.ContainsKey("FRONTEND_IMAGE") -and -not [string]::IsNullOrWhiteSpace($envMap["FRONTEND_IMAGE"])) {
    $FrontendImage = Get-ImageBase $envMap["FRONTEND_IMAGE"]
}
if ($envMap.ContainsKey("BACKEND_IMAGE") -and -not [string]::IsNullOrWhiteSpace($envMap["BACKEND_IMAGE"])) {
    $BackendImage = Get-ImageBase $envMap["BACKEND_IMAGE"]
}

if (-not $GhcrUsername -and $envMap.ContainsKey("GHCR_USERNAME")) { $GhcrUsername = $envMap["GHCR_USERNAME"] }
if (-not $GhcrPassword -and $envMap.ContainsKey("GHCR_PASSWORD")) { $GhcrPassword = $envMap["GHCR_PASSWORD"] }

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

if (-not $ReleaseTrack -or $ReleaseTrack.Trim().Length -eq 0) {
    $ReleaseTrack = 'latest'
}

$tag = if ($Channel -eq 'test') { 'latest-rc' } elseif ($Channel -eq 'demo') { 'latest-demo' } else { 'latest' }
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

$frontendRef = "$FrontendImage`:$tag"
$backendRef = "$BackendImage`:$tag"

Write-Host "CFD Update" -ForegroundColor Cyan
Write-Host "Channel: $Channel" -ForegroundColor Gray
Write-Host "Install Type: $InstallType" -ForegroundColor Gray
Write-Host "Frontend Image: $frontendRef" -ForegroundColor Gray
Write-Host "Backend Image: $backendRef" -ForegroundColor Gray
Write-Host "Release Track: $ReleaseTrack" -ForegroundColor Gray
Write-Host ""

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
            Write-Action "Updating files via git pull"
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

    $envTemplate = Join-Path $deployDir ".env.example"
    if (-not (Test-Path $envPath) -and (Test-Path $envTemplate)) {
        Copy-Item -Path $envTemplate -Destination $envPath -Force
    }

    Set-OrAddEnvValue -Path $envPath -Key "FRONTEND_IMAGE" -Value $frontendRef
    Set-OrAddEnvValue -Path $envPath -Key "BACKEND_IMAGE" -Value $backendRef
    if ($Channel -eq 'demo') {
        Set-OrAddEnvValue -Path $envPath -Key "DEMO_MODE" -Value "true"
    } else {
        Set-OrAddEnvValue -Path $envPath -Key "DEMO_MODE" -Value "false"
    }

    $envMap = Read-EnvFile -Path $envPath

    Push-Location $repoRoot
    try {
        Ensure-GhcrLogin -EnvMap $envMap
        docker compose -f deploy\docker-compose.yml --env-file deploy\.env pull | Out-Null
        docker compose -f deploy\docker-compose.yml --env-file deploy\.env up -d | Out-Null
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

    $backendArgs = @(
        'containerapp', 'update',
        '--name', $BackendAppName,
        '--resource-group', $ResourceGroup,
        '--image', $backendRef,
        '--set-env-vars', "DEMO_MODE=$demoModeValue"
    )
    $frontendArgs = @(
        'containerapp', 'update',
        '--name', $FrontendAppName,
        '--resource-group', $ResourceGroup,
        '--image', $frontendRef
    )

    $hasGhcrCreds = -not [string]::IsNullOrWhiteSpace($GhcrUsername) -and -not [string]::IsNullOrWhiteSpace($GhcrPassword)
    if ($hasGhcrCreds -and $backendRef -match '(?i)^ghcr\.io/') {
        $backendArgs += @('--registry-server', 'ghcr.io', '--registry-username', $GhcrUsername, '--registry-password', $GhcrPassword)
    }
    if ($hasGhcrCreds -and $frontendRef -match '(?i)^ghcr\.io/') {
        $frontendArgs += @('--registry-server', 'ghcr.io', '--registry-username', $GhcrUsername, '--registry-password', $GhcrPassword)
    }

    az @backendArgs | Out-Null
    az @frontendArgs | Out-Null

    Write-Host "Azure Container Apps update complete." -ForegroundColor Green
    exit 0
}

Write-Host "ERROR: Unsupported InstallType: $InstallType" -ForegroundColor Red
exit 1
