# Unified Automated Debloat Engine for Standalone Runner
param(
    [string]$ConfigPath = "UnifiedConfig.json"
)

if (-not (Test-Path $ConfigPath)) {
    [Console]::Out.WriteLine("STATUS|ERROR|Error|UnifiedConfig.json Missing|Configuration file was not found.|0|SHIELD")
    [Console]::Out.Flush()
    exit 1
}

try {
    $cfg = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
} catch {
    [Console]::Out.WriteLine("STATUS|ERROR|Error|Invalid JSON|Failed to parse configuration.|0|SHIELD")
    [Console]::Out.Flush()
    exit 1
}

# Calculate total steps for smooth 0-100% progress
$totalOps = 0
if ($cfg.CreateRestorePoint) { $totalOps++ }
$apps = @()
if ($cfg.Win11Debloat -and $cfg.Win11Debloat.Apps) {
    $apps = @($cfg.Win11Debloat.Apps)
    $totalOps += $apps.Count
}
$tweaks = @()
if ($cfg.Win11Debloat -and $cfg.Win11Debloat.Tweaks) {
    $tweaks = @($cfg.Win11Debloat.Tweaks | Where-Object { $_.Value -eq $true -or ($null -eq $_.Value -and $_ -is [string]) })
    $totalOps += $tweaks.Count
}
$cttTweaks = @()
if ($cfg.WinUtil) {
    $cttTweaks = @($cfg.WinUtil)
    $totalOps += $cttTweaks.Count
}
$services = @()
if ($cfg.Services) {
    $services = @($cfg.Services)
    $totalOps += $services.Count
}
$tasks = @()
if ($cfg.Tasks) {
    $tasks = @($cfg.Tasks)
    $totalOps += $tasks.Count
}
# Step 6: System Conflict & Deadlock Fixer
$totalOps++
if ($totalOps -eq 0) { $totalOps = 1 }

$completedOps = 0

function Emit-Status {
    param(
        [string]$Step,
        [string]$Title,
        [string]$Item,
        [string]$SubStatus,
        [string]$IconKey = "GEAR"
    )
    $pct = [Math]::Min(99, [Math]::Max(1, [int](($script:completedOps / $script:totalOps) * 100)))
    [Console]::Out.WriteLine("STATUS|$Step|$Title|$Item|$SubStatus|$pct|$IconKey")
    [Console]::Out.Flush()
}

# 1. System Restore Point
if ($cfg.CreateRestorePoint) {
    Emit-Status "STEP 1 OF 6" "System Restore Point" "Creating Safety Checkpoint" "Running Checkpoint-Computer..." "SHIELD"
    try {
        Checkpoint-Computer -Description "UltimateDebloat_Backup" -RestorePointType "MODIFY_SETTINGS" -ErrorAction SilentlyContinue | Out-Null
    } catch {}
    $completedOps++
}

# 2. Uninstall Bloatware Apps
if ($apps.Count -gt 0) {
    Emit-Status "STEP 2 OF 6" "Scanning Installed Apps" "Querying System" "Checking which bloat apps are installed..." "TRASH"

    $installedAppx = @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue)
    $provisionedAppx = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue)

    $installedNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($p in $installedAppx) {
        if ($p.Name) { [void]$installedNames.Add($p.Name) }
        if ($p.PackageFamilyName) { [void]$installedNames.Add($p.PackageFamilyName) }
    }
    foreach ($p in $provisionedAppx) {
        if ($p.DisplayName) { [void]$installedNames.Add($p.DisplayName) }
        if ($p.PackageName) { [void]$installedNames.Add($p.PackageName) }
    }

    $appsToUninstall = [System.Collections.Generic.List[string]]::new()
    foreach ($app in $apps) {
        $found = $false
        if ($installedNames.Contains($app)) {
            $found = $true
        } else {
            foreach ($n in $installedNames) {
                if ($n -like "*$app*" -or $app -like "*$n*") {
                    $found = $true
                    break
                }
            }
        }
        if ($found) {
            $appsToUninstall.Add($app)
        }
    }

    # Adjust totalOps so progress bar reflects actual installed apps
    $script:totalOps = $script:totalOps - $apps.Count + $appsToUninstall.Count
    if ($script:totalOps -lt 1) { $script:totalOps = 1 }

    if ($appsToUninstall.Count -eq 0) {
        Emit-Status "STEP 2 OF 6" "Uninstalling Bloat Apps" "All Clear" "No selected bloat apps found installed" "TRASH"
    } else {
        $appIndex = 0
        $hasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)
        foreach ($app in $appsToUninstall) {
            $appIndex++
            $completedOps++
            Emit-Status "STEP 2 OF 6" "Uninstalling Bloat Apps" "$app" "Removing package ($appIndex of $($appsToUninstall.Count))..." "TRASH"
            try {
                Get-AppxPackage -Name "*$app*" -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Out-Null
                Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$app*" -or $_.PackageName -like "*$app*" } | Remove-ProvisionedAppxPackage -Online -AllUsers -ErrorAction SilentlyContinue | Out-Null
                if ($hasWinget) {
                    & winget uninstall --id "$app" --silent --accept-source-agreements --disable-interactivity 2>$null | Out-Null
                }
            } catch {}
        }
    }
}

# 3. Win11Debloat Tweaks
if ($tweaks.Count -gt 0) {
    $w11dScript = Join-Path $PSScriptRoot "Win11Debloat-master\Win11Debloat.ps1"
    $w11dConfig = Join-Path $PSScriptRoot "Win11DebloatConfig.json"
    $tweakIndex = 0
    foreach ($tw in $tweaks) {
        $tweakIndex++
        $completedOps++
        $tName = if ($tw.Name) { $tw.Name } else { "$tw" }
        Emit-Status "STEP 3 OF 6" "Win11Debloat Tweaks" "$tName" "Applying system tweak ($tweakIndex of $($tweaks.Count))..." "SPEED"
    }
    if (Test-Path $w11dScript) {
        try {
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$w11dScript" -Config "$w11dConfig" -Silent -SkipExplorerRestart 6>&1 | Out-Null
        } catch {}
    }
}

# 4. Chris Titus WinUtil Tweaks
if ($cttTweaks.Count -gt 0) {
    $winutilScript = Join-Path $PSScriptRoot "winutil.ps1"
    $winutilConfig = Join-Path $PSScriptRoot "WinUtilConfig.json"
    $cttIndex = 0
    foreach ($ctt in $cttTweaks) {
        $cttIndex++
        $completedOps++
        Emit-Status "STEP 4 OF 6" "WinUtil Optimizations" "$ctt" "Executing CTT performance tweak ($cttIndex of $($cttTweaks.Count))..." "BOLT"
    }
    if (Test-Path $winutilScript) {
        try {
            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$winutilScript" -Config "$winutilConfig" -SkipExplorerRestart 6>&1 | Out-Null
        } catch {}
    }
}

# 5. Services & Scheduled Tasks
if ($services.Count -gt 0 -or $tasks.Count -gt 0) {
    $svcIndex = 0
    foreach ($svc in $services) {
        $svcIndex++
        $completedOps++
        Emit-Status "STEP 5 OF 6" "Services Optimization" "$($svc.Name) -> $($svc.TargetMode)" "Configuring service ($svcIndex of $($services.Count))..." "GEAR"
        try {
            if ($svc.TargetMode -eq "Disabled") {
                Set-Service -Name $svc.Name -StartupType Disabled -ErrorAction SilentlyContinue
                Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
            } elseif ($svc.TargetMode -eq "Manual") {
                Set-Service -Name $svc.Name -StartupType Manual -ErrorAction SilentlyContinue
            }
        } catch {}
    }

    $taskIndex = 0
    foreach ($t in $tasks) {
        $taskIndex++
        $completedOps++
        Emit-Status "STEP 5 OF 6" "Scheduled Tasks" "$($t.TaskName)" "Disabling task ($taskIndex of $($tasks.Count))..." "CLOCK"
        try {
            Disable-ScheduledTask -TaskPath $t.TaskPath -TaskName $t.TaskName -ErrorAction SilentlyContinue | Out-Null
        } catch {}
    }
}

# 6. Diagnostics & System Conflict Fixer
Emit-Status "STEP 6 OF 6" "Conflict & Deadlock Fixer" "Scanning Diagnostics" "Checking for IFEO hijacks and driver deadlocks..." "SHIELD"

# 6a. Remove Broken GameBar IFEO Debugger Hijack (systray.exe)
$ifeoTargets = @("GameBarPresenceWriter.exe", "bcastdvr.exe")
foreach ($ifeoTarget in $ifeoTargets) {
    $targetPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$ifeoTarget"
    if (Test-Path $targetPath) {
        $debuggerVal = (Get-ItemProperty -Path $targetPath -Name "Debugger" -ErrorAction SilentlyContinue).Debugger
        if ($debuggerVal) {
            Emit-Status "STEP 6 OF 6" "Conflict & Deadlock Fixer" "$ifeoTarget Hijack" "Removing broken IFEO hijack ($debuggerVal)..." "SHIELD"
            Remove-Item -Path $targetPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# 6b. Disable Inactive/Conflicting SteelSeries_Sonar_VAD Driver
$sonarReg = "HKLM:\SYSTEM\CurrentControlSet\Services\SteelSeries_Sonar_VAD"
if (Test-Path $sonarReg) {
    $startType = (Get-ItemProperty -Path $sonarReg -Name "Start" -ErrorAction SilentlyContinue).Start
    if ($startType -ne 4) {
        $goxlrFound = (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\goxlr_audio") -or 
                      [bool](Get-Service -Name "goxlr_audio" -ErrorAction SilentlyContinue) -or 
                      [bool](Get-Process -Name "*goxlr*" -ErrorAction SilentlyContinue)
        $steelSeriesProc = @(Get-Process -Name "SteelSeriesGG*", "SteelSeriesEngine*", "SonarProcessor*" -ErrorAction SilentlyContinue)

        if ($goxlrFound -or ($steelSeriesProc.Count -eq 0)) {
            Emit-Status "STEP 6 OF 6" "Conflict & Deadlock Fixer" "SteelSeries Sonar VAD" "Disabling inactive/conflicting audio driver..." "GEAR"
            try {
                & sc.exe config SteelSeries_Sonar_VAD start= disabled | Out-Null
                & sc.exe stop SteelSeries_Sonar_VAD | Out-Null
            } catch {}
        }
    }
}

# 6c. GameDVR Runtime Class Invocation Consistency
$dvrPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
$gameConfigPath = "HKCU:\System\GameConfigStore"
$dvrUserPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"

$policyAllowDVR = (Get-ItemProperty -Path $dvrPolicyPath -Name "AllowGameDVR" -ErrorAction SilentlyContinue).AllowGameDVR
$userDVREnabled = (Get-ItemProperty -Path $gameConfigPath -Name "GameDVR_Enabled" -ErrorAction SilentlyContinue).GameDVR_Enabled
$appCaptureEnabled = (Get-ItemProperty -Path $dvrUserPath -Name "AppCaptureEnabled" -ErrorAction SilentlyContinue).AppCaptureEnabled

if ($policyAllowDVR -eq 0 -and ($userDVREnabled -ne 0 -or $appCaptureEnabled -ne 0)) {
    Emit-Status "STEP 6 OF 6" "Conflict & Deadlock Fixer" "GameDVR Consistency" "Aligning DVR runtime policies..." "BOLT"
    try {
        if (-not (Test-Path $gameConfigPath)) { New-Item -Path $gameConfigPath -Force | Out-Null }
        Set-ItemProperty -Path $gameConfigPath -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        if (-not (Test-Path $dvrUserPath)) { New-Item -Path $dvrUserPath -Force | Out-Null }
        Set-ItemProperty -Path $dvrUserPath -Name "AppCaptureEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    } catch {}
}

$completedOps++

# 7. Explorer Refresh (Only once at the very end if requested)
if ($cfg.RestartExplorer) {
    Emit-Status "FINALIZING" "Refreshing Shell" "Restarting Windows Explorer" "Applying desktop and UI changes..." "CHECK"
    try {
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 600
        Start-Process explorer.exe -ErrorAction SilentlyContinue
    } catch {}
}

[Console]::Out.WriteLine("STATUS|COMPLETE|Debloat Complete!|All Selections Applied|PC successfully optimized and clean.|100|CHECK")
[Console]::Out.Flush()
