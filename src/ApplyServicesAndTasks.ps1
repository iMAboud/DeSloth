param(
    [string]$ConfigPath = "UnifiedConfig.json"
)

if (-not (Test-Path $ConfigPath)) { exit 0 }

try {
    $cfg = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
} catch { exit 0 }

# Apply Services
if ($cfg.Services) {
    foreach ($svc in $cfg.Services) {
        try {
            if ($svc.TargetMode -eq "Disabled") {
                Set-Service -Name $svc.Name -StartupType Disabled -ErrorAction SilentlyContinue
                Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
            } elseif ($svc.TargetMode -eq "Manual") {
                Set-Service -Name $svc.Name -StartupType Manual -ErrorAction SilentlyContinue
            }
        } catch {}
    }
}

# Apply Tasks
if ($cfg.Tasks) {
    foreach ($t in $cfg.Tasks) {
        try {
            Disable-ScheduledTask -TaskPath $t.TaskPath -TaskName $t.TaskName -ErrorAction SilentlyContinue | Out-Null
        } catch {}
    }
}
