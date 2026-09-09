# Build-Payload.ps1 - Creates the payload zip for compilation
param(
    [string]$BaseDir = (Split-Path -Parent $PSScriptRoot),
    [string]$OutZip
)

Add-Type -AssemblyName System.IO.Compression.FileSystem

$staging = Join-Path $env:TEMP ("DebloatStaging_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $staging -Force | Out-Null

try {
    # Load config
    $cfgSrc = Join-Path $BaseDir "config\debloat-profile.json"
    if (-not (Test-Path $cfgSrc)) { $cfgSrc = Join-Path $BaseDir "DebloatProfile.json" }
    if (Test-Path $cfgSrc) {
        $cfg = Get-Content -LiteralPath $cfgSrc -Raw -Encoding UTF8 | ConvertFrom-Json
        $cfg | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $staging "UnifiedConfig.json") -Encoding UTF8

        $w11d = [ordered]@{
            Version    = "1.0"
            Apps       = @($cfg.Win11Debloat.Apps)
            Tweaks     = @($cfg.Win11Debloat.Tweaks | Where-Object { $_.Value -eq $true -or ($null -eq $_.Value -and $_ -is [string]) })
            Deployment = @(
                @{ Name = "CreateRestorePoint"; Value = [bool]$cfg.CreateRestorePoint }
                @{ Name = "SkipRegistryBackup"; Value = $false }
                @{ Name = "RestartExplorer"; Value = $false }
            )
        }
        $w11d | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $staging "Win11DebloatConfig.json") -Encoding UTF8
        @($cfg.WinUtil) | ConvertTo-Json | Set-Content (Join-Path $staging "WinUtilConfig.json") -Encoding UTF8
    }

    # Copy engine scripts
    foreach ($f in @("src\ApplyServicesAndTasks.ps1", "src\UnifiedRunnerEngine.ps1")) {
        $s = Join-Path $BaseDir $f
        if (Test-Path $s) { Copy-Item $s -Destination $staging -Force }
    }

    # Copy winutil
    $ws = Join-Path $BaseDir "winutil-main\winutil.ps1"
    if (Test-Path $ws) { Copy-Item $ws -Destination (Join-Path $staging "winutil.ps1") -Force }

    # Copy Win11Debloat-master
    $wd = Join-Path $staging "Win11Debloat-master"
    New-Item -ItemType Directory -Path $wd -Force | Out-Null
    $wf = Join-Path $BaseDir "Win11Debloat-master\Win11Debloat.ps1"
    if (Test-Path $wf) { Copy-Item $wf -Destination $wd -Force }
    foreach ($d in @("Config", "Scripts", "Regfiles", "Assets", "Schemas")) {
        $sd = Join-Path $BaseDir "Win11Debloat-master\$d"
        if (Test-Path $sd) { Copy-Item $sd -Destination (Join-Path $wd $d) -Recurse -Force }
    }

    # Zip
    if (-not $OutZip) {
        $OutZip = Join-Path $env:TEMP ("DebloatPayload_" + [guid]::NewGuid().ToString("N") + ".zip")
    }
    if (Test-Path $OutZip) { Remove-Item $OutZip -Force }
    [System.IO.Compression.ZipFile]::CreateFromDirectory($staging, $OutZip, [System.IO.Compression.CompressionLevel]::Optimal, $false)
    Write-Output $OutZip
} finally {
    Remove-Item $staging -Recurse -Force -ErrorAction SilentlyContinue
}
