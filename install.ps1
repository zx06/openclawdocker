#
# OpenClaw Docker Installer - Windows PowerShell
# One-command setup for OpenClaw on Docker for Windows
#
# Usage:
#   irm https://raw.githubusercontent.com/zx06/openclaw-docker/master/install.ps1 | iex
#
# Or with options:
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/zx06/openclaw-docker/master/install.ps1))) -NoStart
#

param(
    [string]$InstallDir = "$env:USERPROFILE\openclaw",
    [switch]$NoStart,
    [switch]$SkipOnboard,
    [switch]$PullOnly,
    [switch]$Help
)

$Image     = "ghcr.io/zx06/openclaw:latest"
$RepoUrl   = "https://github.com/zx06/openclaw-docker"
$ComposeUrl = "https://raw.githubusercontent.com/zx06/openclaw-docker/master/docker-compose.yml"
$ErrorActionPreference = "Stop"

function Write-Step    { param([string]$M); Write-Host ""; Write-Host "▶ $M" -ForegroundColor Blue }
function Write-Success { param([string]$M); Write-Host "✓ $M" -ForegroundColor Green }
function Write-Warn    { param([string]$M); Write-Host "⚠ $M" -ForegroundColor Yellow }
function Write-Err     { param([string]$M); Write-Host "✗ $M" -ForegroundColor Red }

if ($Help) {
    Write-Host "OpenClaw Docker Installer - Windows"
    Write-Host "Usage: install.ps1 [OPTIONS]"
    Write-Host "  -InstallDir DIR   Installation directory (default: ~\openclaw)"
    Write-Host "  -NoStart          Don't start gateway after setup"
    Write-Host "  -SkipOnboard      Skip onboarding wizard"
    Write-Host "  -PullOnly         Only pull image"
    return
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          OpenClaw Docker Installer (zx06)            ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan

Write-Step "Checking prerequisites..."

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Err "Docker not found. Install: https://docs.docker.com/desktop/install/windows-install/"
    exit 1
}
Write-Success "docker found"

$ComposeCmd = ""
if (docker compose version 2>$null) {
    $ComposeCmd = "docker compose"; Write-Success "Docker Compose found (plugin)"
} elseif (Get-Command docker-compose -ErrorAction SilentlyContinue) {
    $ComposeCmd = "docker-compose"; Write-Success "Docker Compose found (standalone)"
} else {
    Write-Err "Docker Compose not found. It usually comes with Docker Desktop."
    exit 1
}

try { docker info 2>$null | Out-Null; Write-Success "Docker is running" }
catch { Write-Err "Docker is not running. Start Docker Desktop and try again."; exit 1 }

if ($PullOnly) {
    Write-Step "Pulling OpenClaw image..."
    docker pull $Image
    Write-Success "Done!"
    return
}

Write-Step "Setting up installation directory: $InstallDir"
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Set-Location $InstallDir
Invoke-WebRequest -Uri $ComposeUrl -OutFile "docker-compose.yml"
Write-Success "Downloaded docker-compose.yml"

Write-Step "Creating data directories..."
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.openclaw" | Out-Null
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.openclaw\workspace" | Out-Null
Write-Success "Created $env:USERPROFILE\.openclaw and workspace"

Write-Step "Pulling OpenClaw image..."
docker pull $Image
Write-Success "Image pulled"

if (-not $SkipOnboard) {
    Write-Step "Running onboarding wizard..."
    Write-Host "Follow the prompts to configure your AI provider and channels." -ForegroundColor Yellow
    $parts = $ComposeCmd -split " ", 2
    $exitCode = 0
    if ($parts.Count -eq 2) { & $parts[0] $parts[1] run --rm openclaw-cli onboard; $exitCode = $LASTEXITCODE }
    else { & $parts[0] run --rm openclaw-cli onboard; $exitCode = $LASTEXITCODE }
    if ($exitCode -ne 0) {
        Write-Warn "Onboarding skipped. Run later: cd $InstallDir && $ComposeCmd run --rm openclaw-cli onboard"
    } else {
        Write-Success "Onboarding complete!"
    }
}

if (-not $NoStart) {
    Write-Step "Starting OpenClaw gateway..."
    $parts = $ComposeCmd -split " ", 2
    if ($parts.Count -eq 2) { & $parts[0] $parts[1] up -d openclaw }
    else { & $parts[0] up -d openclaw }

    Write-Host "Waiting for gateway" -NoNewline
    for ($i = 0; $i -lt 30; $i++) {
        try {
            $r = Invoke-WebRequest -Uri "http://localhost:18789/healthz" -TimeoutSec 1 -EA SilentlyContinue
            if ($r.StatusCode -eq 200) { Write-Host ""; Write-Success "Gateway is running!"; break }
        } catch {}
        Write-Host "." -NoNewline; Start-Sleep -Seconds 1
    }
    try {
        $r = Invoke-WebRequest -Uri "http://localhost:18789/healthz" -TimeoutSec 1 -EA SilentlyContinue
        if ($r.StatusCode -ne 200) { throw }
    } catch { Write-Host ""; Write-Warn "Gateway may still be starting. Check: docker logs -f openclaw" }
}

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║         🎉 OpenClaw installed successfully!           ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "Access:       http://localhost:18789" -ForegroundColor White
Write-Host "Config:       $env:USERPROFILE\.openclaw\" -ForegroundColor White
Write-Host "Install dir:  $InstallDir" -ForegroundColor White
Write-Host ""
Write-Host "Commands:" -ForegroundColor White
Write-Host "  Logs:    docker logs -f openclaw" -ForegroundColor Cyan
Write-Host "  Stop:    cd $InstallDir && $ComposeCmd down" -ForegroundColor Cyan
Write-Host "  Start:   cd $InstallDir && $ComposeCmd up -d openclaw" -ForegroundColor Cyan
Write-Host "  Update:  docker pull $Image && $ComposeCmd up -d openclaw" -ForegroundColor Cyan
Write-Host "  CLI:     cd $InstallDir && $ComposeCmd run --rm openclaw-cli <cmd>" -ForegroundColor Cyan
Write-Host ""
Write-Host "Repo: $RepoUrl" -ForegroundColor White
Write-Host ""
