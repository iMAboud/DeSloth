# DeSloth One-Liner Bootstrapper
# Usage: irm https://raw.githubusercontent.com/iMAboud/DeSloth/main/run.ps1 | iex

$ErrorActionPreference = 'Stop'

# GitHub Repository Configuration (Replace with your GitHub Username & Repository Name)
$GitHubUser = "iMAboud"
$GitHubRepo = "DeSloth"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$exeUrl = "https://github.com/$GitHubUser/$GitHubRepo/releases/latest/download/DeSloth.exe"
$destPath = Join-Path $env:TEMP "DeSloth.exe"

Write-Host ">>> Fetching latest DeSloth binary..." -ForegroundColor Cyan

try {
    Invoke-WebRequest -Uri $exeUrl -OutFile $destPath -UseBasicParsing
    Write-Host ">>> Launching DeSloth..." -ForegroundColor Green
    Start-Process -FilePath $destPath
}
catch {
    Write-Host "[ERROR] Failed to download or start DeSloth: $_" -ForegroundColor Red
}
