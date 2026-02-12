<#
.SYNOPSIS
    Installs and optionally deploys the CFD (Tiles) public bundle.

.DESCRIPTION
    Supports local, git, and zip-based installation sources. Optionally deploys to
    Docker Compose or Azure Container Apps. Safe to re-run. Use -DryRun to preview.

.PARAMETER InstallMethod
    local (default) uses the current cloned repo, git clones/pulls a remote repo,
    zip downloads a release asset.

.PARAMETER DeployType
    none (default), docker, or aca.

.PARAMETER ProvisionAzurePrereqs
    For ACA installs, run setup-cfd-prereqs.ps1 before deployment.

.PARAMETER ConfirmInstall
    Required to perform actions.

.PARAMETER DryRun
    Prints planned actions only.
#>

param(
    [string]$RepoOwner = "DennisC3PO",
    [string]$RepoName = "Tiles_AIO",
    [string]$RepoUrl = "",
    [ValidateSet('public','test','demo')]
    [string]$Channel = 'public',
    [string]$Version = "",
    [ValidateSet('local','git','zip')]
    [string]$InstallMethod = 'local',
    [string]$Destination = "",
    [ValidateSet('none','docker','aca')]
    [string]$DeployType = 'none',
    [ValidateSet('latest','major','minor','version')]
    [string]$ReleaseTrack = 'latest',
    [string]$TrackVersion = "",
    [string]$ResourceGroup = "cfd-rg",
    [string]$Location = "eastus2",
    [switch]$PublicAccess,
    [switch]$ProvisionAzurePrereqs,
    [string]$AppDisplayName = "cfd-tiles-backend-app",
    [string]$StorageAccountName = "",
    [string]$FrontendImage = "",
    [string]$BackendImage = "",
    [switch]$DemoMode,
    [switch]$ConfirmInstall,
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
    param([string]$EnvPath)

    $envMap = Read-EnvFile -Path $EnvPath
    $ghcrUser = if ($envMap.ContainsKey("GHCR_USERNAME")) { $envMap["GHCR_USERNAME"] } else { "" }
    $ghcrPassword = if ($envMap.ContainsKey("GHCR_PASSWORD")) { $envMap["GHCR_PASSWORD"] } else { "" }

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

function Write-InstallState {
    param(
        [string]$RepoRoot,
        [string]$InstallType,
        [string]$Channel,
        [string]$ReleaseTrack,
        [string]$TrackVersion,
        [string]$FrontendImage,
        [string]$BackendImage
    )

    $deployDir = Join-Path $RepoRoot "deploy"
    if (-not (Test-Path $deployDir)) { return }

    $statePath = Join-Path $deployDir ".install.json"
    $state = [PSCustomObject]@{
        InstallType = $InstallType
        Channel = $Channel
        ReleaseTrack = $ReleaseTrack
        TrackVersion = $TrackVersion
        FrontendImage = $FrontendImage
        BackendImage = $BackendImage
        UpdatedOn = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }

    $state | ConvertTo-Json | Set-Content -Path $statePath -Encoding UTF8
}

$localRepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$localRepoRoot = $localRepoRoot.Path

if (-not $Destination -or $Destination.Trim().Length -eq 0) {
    if ($InstallMethod -eq 'local') {
        $Destination = $localRepoRoot
    } else {
        $Destination = Join-Path $env:USERPROFILE "CFD-public-deploy"
    }
}

if ($DryRun) {
    Write-Action "[DryRun] Install method: $InstallMethod"
    Write-Action "[DryRun] Destination: $Destination"
    Write-Action "[DryRun] Deploy type: $DeployType"
    if ($DeployType -eq 'aca') {
        Write-Action "[DryRun] ACA resource group/location: $ResourceGroup / $Location"
        Write-Action "[DryRun] Provision prereqs: $($ProvisionAzurePrereqs.IsPresent)"
    }
    exit 0
}

if (-not $ConfirmInstall) {
    Write-Host "ERROR: Install requires explicit confirmation." -ForegroundColor Red
    Write-Host "Re-run with -ConfirmInstall to proceed." -ForegroundColor Yellow
    exit 1
}

switch ($InstallMethod) {
    'local' {
        if (-not (Test-Path (Join-Path $Destination "deploy\docker-compose.yml"))) {
            Write-Host "ERROR: Local install requires a cloned CFD public repo at destination." -ForegroundColor Red
            exit 1
        }
        Write-Action "Using local repo: $Destination"
    }
    'git' {
        if (-not $RepoUrl -and $RepoOwner -and $RepoName) {
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
            Write-Action "Cloning $RepoUrl"
            git clone $RepoUrl $Destination
        } else {
            Write-Action "Existing git repo detected. Pulling latest."
            git -C $Destination pull
        }
    }
    'zip' {
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
        $tempDir = Join-Path $env:TEMP "CFD-public-deploy"

        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tempZip -Headers $headers
        if (Test-Path $tempDir) { Remove-Item -Recurse -Force $tempDir }
        Expand-Archive -Path $tempZip -DestinationPath $tempDir -Force

        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
        Copy-Item -Path (Join-Path $tempDir '*') -Destination $Destination -Recurse -Force
    }
}

$envTemplate = Join-Path $Destination "deploy\.env.example"
$envPath = Join-Path $Destination "deploy\.env"
if (-not (Test-Path $envTemplate)) {
    Write-Host "ERROR: Missing deploy/.env.example in destination bundle." -ForegroundColor Red
    exit 1
}
if (-not (Test-Path $envPath)) {
    Write-Action "Creating deploy/.env from template"
    Copy-Item -Path $envTemplate -Destination $envPath -Force
}

if ($FrontendImage) {
    Set-OrAddEnvValue -Path $envPath -Key "FRONTEND_IMAGE" -Value $FrontendImage
}
if ($BackendImage) {
    Set-OrAddEnvValue -Path $envPath -Key "BACKEND_IMAGE" -Value $BackendImage
}
if ($DemoMode -or $Channel -eq 'demo') {
    Set-OrAddEnvValue -Path $envPath -Key "DEMO_MODE" -Value "true"
}

if ($DeployType -eq 'none') {
    Write-Host "Install complete: $Destination" -ForegroundColor Green
    exit 0
}

if ($DeployType -eq 'docker') {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: docker is required for Docker installs." -ForegroundColor Red
        exit 1
    }

    Push-Location $Destination
    try {
        Ensure-GhcrLogin -EnvPath $envPath
        docker compose -f deploy\docker-compose.yml --env-file deploy\.env up -d
    } finally {
        Pop-Location
    }

    $envMap = Read-EnvFile -Path $envPath
    $stateFrontend = if ($envMap.ContainsKey("FRONTEND_IMAGE")) { Get-ImageBase $envMap["FRONTEND_IMAGE"] } else { "" }
    $stateBackend = if ($envMap.ContainsKey("BACKEND_IMAGE")) { Get-ImageBase $envMap["BACKEND_IMAGE"] } else { "" }
    Write-InstallState `
        -RepoRoot $Destination `
        -InstallType "docker" `
        -Channel $Channel `
        -ReleaseTrack $ReleaseTrack `
        -TrackVersion $TrackVersion `
        -FrontendImage $stateFrontend `
        -BackendImage $stateBackend

    Write-Host "Install + Docker deployment complete: $Destination" -ForegroundColor Green
    exit 0
}

if ($DeployType -eq 'aca') {
    $setupScript = Join-Path $Destination "scripts\setup-cfd-prereqs.ps1"
    $deployScript = Join-Path $Destination "scripts\deploy-cfd.ps1"

    if (-not (Test-Path $deployScript)) {
        Write-Host "ERROR: deploy script not found in destination." -ForegroundColor Red
        exit 1
    }

    if ($ProvisionAzurePrereqs) {
        if (-not (Test-Path $setupScript)) {
            Write-Host "ERROR: setup-cfd-prereqs.ps1 not found in destination." -ForegroundColor Red
            exit 1
        }

        $setupArgs = @(
            '-File', $setupScript,
            '-ResourceGroup', $ResourceGroup,
            '-Location', $Location,
            '-AppDisplayName', $AppDisplayName,
            '-ConfirmSetup'
        )
        if ($StorageAccountName) { $setupArgs += @('-StorageAccountName', $StorageAccountName) }

        Write-Action "Provisioning Azure prerequisites"
        pwsh @setupArgs
    }

    $deployArgs = @(
        '-File', $deployScript,
        '-ResourceGroup', $ResourceGroup,
        '-Location', $Location,
        '-ConfirmDeploy'
    )
    if ($PublicAccess) { $deployArgs += '-PublicAccess' }
    if ($ReleaseTrack) { $deployArgs += @('-ReleaseTrack', $ReleaseTrack) }
    if ($TrackVersion) { $deployArgs += @('-TrackVersion', $TrackVersion) }
    if ($FrontendImage) { $deployArgs += @('-FrontendImage', $FrontendImage) }
    if ($BackendImage) { $deployArgs += @('-BackendImage', $BackendImage) }
    if ($DemoMode -or $Channel -eq 'demo') { $deployArgs += '-DemoMode' }

    Write-Action "Deploying to Azure Container Apps"
    pwsh @deployArgs

    Write-Host "Install + ACA deployment complete: $Destination" -ForegroundColor Green
    exit 0
}

Write-Host "ERROR: Unsupported DeployType: $DeployType" -ForegroundColor Red
exit 1
