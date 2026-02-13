<#
.SYNOPSIS
    Installs the deploy-only bundle for Tiles from a public repository.

.DESCRIPTION
    Downloads the latest release asset (or clones the public repo) and places
    it into a destination folder. Optionally runs deployment using Docker or
    Azure Container Apps. This script is idempotent and safe to re-run. Use
    -DryRun to preview actions.

.PARAMETER RepoOwner
    GitHub repo owner (e.g., ClickFixDynamics).

.PARAMETER RepoName
    GitHub repo name (e.g., CFD-public).

.PARAMETER RepoUrl
    Full Git URL to clone when using -InstallMethod git.

.PARAMETER Channel
    Release channel: public, test, or demo.

.PARAMETER Version
    Specific version to install (e.g., 1.4.0 or 1.4.0-rc.1). Optional.

.PARAMETER InstallMethod
    zip (default) downloads release asset; git clones the public repo.

.PARAMETER Destination
    Folder where the bundle will be placed.

.PARAMETER DeployType
    none (default), docker, or aca. If set, runs the deploy step.

.PARAMETER ReleaseTrack
    Optional update track recorded for future updates: latest, major, minor, version.

.PARAMETER TrackVersion
    Optional version track value (e.g., 1 or 1.4).

.PARAMETER ConfirmInstall
    Required to perform install actions.

.PARAMETER DryRun
    If set, prints planned actions without changes.
#>

param(
    [string]$RepoOwner = "ClickFixDynamics",
    [string]$RepoName = "Tiles_AIO",
    [string]$RepoUrl = "",
    [ValidateSet('public','test','demo')]
    [string]$Channel = 'public',
    [string]$Version = "",
    [ValidateSet('zip','git')]
    [string]$InstallMethod = 'zip',
    [string]$Destination = "",
    [ValidateSet('none','docker','aca')]
    [string]$DeployType = 'none',
    [ValidateSet('latest','major','minor','version')]
    [string]$ReleaseTrack = 'latest',
    [string]$TrackVersion = "",
    [switch]$ConfirmInstall,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

function Write-Action {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Cyan
}

if (-not $Destination -or $Destination.Trim().Length -eq 0) {
    $Destination = Join-Path $env:USERPROFILE "CFD-public-deploy"
}

if ($DryRun) {
    Write-Action "[DryRun] Would install channel '$Channel' using $InstallMethod to: $Destination"
    exit 0
}

if (-not $ConfirmInstall) {
    Write-Host "ERROR: Install requires explicit confirmation." -ForegroundColor Red
    Write-Host "Re-run with -ConfirmInstall to proceed." -ForegroundColor Yellow
    exit 1
}

if ($InstallMethod -eq 'git') {
    if (-not $RepoUrl -and ($RepoOwner -and $RepoName)) {
        $RepoUrl = "https://github.com/$RepoOwner/$RepoName.git"
    }
    if (-not $RepoUrl) {
        Write-Host "ERROR: -RepoUrl (or -RepoOwner and -RepoName) is required for git installs." -ForegroundColor Red
        exit 1
    }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: git is required for InstallMethod=git." -ForegroundColor Red
        exit 1
    }

    if (-not (Test-Path $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }

    if (-not (Test-Path (Join-Path $Destination '.git'))) {
        git clone $RepoUrl $Destination
    } else {
        Write-Host "Existing git repo detected. Pulling latest." -ForegroundColor Yellow
        git -C $Destination pull
    }
} else {
    if (-not $RepoOwner -or -not $RepoName) {
        Write-Host "ERROR: -RepoOwner and -RepoName are required for zip installs." -ForegroundColor Red
        exit 1
    }

    $api = "https://api.github.com/repos/$RepoOwner/$RepoName/releases"
    $headers = @{ 'User-Agent' = 'CFD-Installer' }
    $releases = Invoke-RestMethod -Uri $api -Headers $headers

    $filtered = @()
    foreach ($r in $releases) {
        $tag = $r.tag_name
        if ($Channel -eq 'public') {
            if (-not $r.prerelease -and $tag -notlike '*-rc.*' -and $tag -notlike '*-demo.*') { $filtered += $r }
        } elseif ($Channel -eq 'test') {
            if ($tag -like '*-rc.*') { $filtered += $r }
        } else {
            if ($tag -like '*-demo.*') { $filtered += $r }
        }
    }

    if ($Version) {
        $normalized = $Version.Trim()
        if (-not $normalized.StartsWith('v')) { $normalized = "v$normalized" }
        $filtered = $filtered | Where-Object { $_.tag_name -eq $normalized }
    }

    if (-not $filtered -or $filtered.Count -eq 0) {
        Write-Host "ERROR: No matching releases found." -ForegroundColor Red
        exit 1
    }

    $release = $filtered | Sort-Object published_at -Descending | Select-Object -First 1
    $asset = $release.assets | Where-Object { $_.name -eq 'CFD-public-deploy.zip' } | Select-Object -First 1
    if (-not $asset) {
        Write-Host "ERROR: CFD-public-deploy.zip not found in release assets." -ForegroundColor Red
        exit 1
    }

    $tempZip = Join-Path $env:TEMP "CFD-public-deploy.zip"
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tempZip -Headers $headers

    $tempDir = Join-Path $env:TEMP "CFD-public-deploy"
    if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir }
    Expand-Archive -Path $tempZip -DestinationPath $tempDir -Force

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Copy-Item -Path (Join-Path $tempDir '*') -Destination $Destination -Recurse -Force
}

# Record install state for future updates
$deployDir = Join-Path $Destination "deploy"
if (-not (Test-Path $deployDir)) { New-Item -ItemType Directory -Path $deployDir -Force | Out-Null }
$statePath = Join-Path $deployDir ".install.json"
$state = [PSCustomObject]@{
    InstallType = $DeployType
    Channel = $Channel
    ReleaseTrack = $ReleaseTrack
    TrackVersion = $TrackVersion
    UpdatedOn = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
}
$state | ConvertTo-Json | Set-Content -Path $statePath -Encoding UTF8

# Optional deploy
if ($DeployType -eq 'docker') {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: docker is required for Docker installs." -ForegroundColor Red
        exit 1
    }
    Push-Location $Destination
    try {
        docker compose -f deploy\docker-compose.yml --env-file deploy\.env up -d
    } finally {
        Pop-Location
    }
} elseif ($DeployType -eq 'aca') {
    $deployScript = Join-Path $Destination "scripts\deploy-cfd.ps1"
    if (-not (Test-Path $deployScript)) {
        Write-Host "ERROR: deploy script not found in destination." -ForegroundColor Red
        exit 1
    }
    $trackArgs = @()
    if ($ReleaseTrack) { $trackArgs += @('-ReleaseTrack', $ReleaseTrack) }
    if ($TrackVersion) { $trackArgs += @('-TrackVersion', $TrackVersion) }
    pwsh -File $deployScript -ConfirmDeploy @trackArgs
}

Write-Host "Install complete: $Destination" -ForegroundColor Green
