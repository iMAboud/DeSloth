# DeSloth One-Liner Bootstrapper
# Usage: irm https://raw.githubusercontent.com/iMAboud/DeSloth/main/run.ps1 | iex

$ErrorActionPreference = 'Stop'

# GitHub Repository Configuration
$GitHubUser = "iMAboud"
$GitHubRepo = "DeSloth"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$destPath = Join-Path $env:TEMP "DeSloth.exe"

# Stop any running instances to prevent file lock
Get-Process -Name "DeSloth", "UltimateDebloatRunner" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 200

if (Test-Path $destPath) {
    Remove-Item -LiteralPath $destPath -Force -ErrorAction SilentlyContinue
}

$cacheBuster = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$rawUrl = "https://raw.githubusercontent.com/$GitHubUser/$GitHubRepo/main/dist/DeSloth.exe?v=$cacheBuster"
$releaseUrl = "https://github.com/$GitHubUser/$GitHubRepo/releases/latest/download/DeSloth.exe"

Write-Host ">>> Fetching latest DeSloth binary..." -ForegroundColor Cyan

$downloaded = $false
try {
    Invoke-WebRequest -Uri $rawUrl -OutFile $destPath -UseBasicParsing
    $downloaded = $true
} catch {
    try {
        Invoke-WebRequest -Uri $releaseUrl -OutFile $destPath -UseBasicParsing
        $downloaded = $true
    } catch {
        Write-Host "[ERROR] Failed to download DeSloth from repository and release: $_" -ForegroundColor Red
    }
}

if ($downloaded -and (Test-Path $destPath)) {
    Write-Host ">>> Launching DeSloth..." -ForegroundColor Green
    Start-Process -FilePath $destPath
}
