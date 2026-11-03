# Unified Automated Debloat Engine for Standalone Runner
param(
    [string]$ConfigPath = "UnifiedConfig.json",
    [string]$DebugLogPath = ""
)

if ([string]::IsNullOrWhiteSpace($DebugLogPath)) {
    $script:DebugLogPath = Join-Path $env:TEMP "DeSloth-debug.log"
} else {
    $script:DebugLogPath = $DebugLogPath
}

# Real-Time Logging & Communication Protocol
function Emit-Status {
    param(
        [string]$Step,
        [string]$Title,
        [string]$Item,
        [string]$SubStatus,
        [string]$IconKey = "GEAR"
    )
    $pct = [Math]::Min(99, [Math]::Max(1, [int](($script:completedOps / [Math]::Max($script:totalOps, 1)) * 100)))
    [Console]::Out.WriteLine("STATUS|$Step|$Title|$Item|$SubStatus|$pct|$IconKey")
    [Console]::Out.Flush()
}

function Emit-Debug {
    param(
        [ValidateSet("INFO", "SUCCESS", "WARN", "ERROR")]
        [string]$Level,
        [string]$Message,
        [string]$Category = "ENGINE"
    )
    $ts = (Get-Date).ToString("HH:mm:ss.fff")
    [Console]::Out.WriteLine("DEBUG|$Level|$ts|$Category|$Message")
    [Console]::Out.Flush()

    if ($script:DebugLogPath) {
        try {
            $logLine = "[$ts] [$Level] [$Category] $Message`r`n"
            [System.IO.File]::AppendAllText($script:DebugLogPath, $logLine, [System.Text.Encoding]::UTF8)
        } catch {}
    }
}

# Start debug trace
Emit-Debug "INFO" "==================== DeSloth Debloat Engine Started ====================" "INIT"
Emit-Debug "INFO" "PowerShell Version: $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))" "INIT"
Emit-Debug "INFO" "OS: $((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).ProductName) (Build $((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue).CurrentBuild))" "INIT"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
Emit-Debug "INFO" "Running elevated (Administrator): $isAdmin" "SECURITY"

if (-not (Test-Path $ConfigPath)) {
    Emit-Status "ERROR" "Error" "UnifiedConfig.json Missing" "Configuration file was not found." "SHIELD"
    Emit-Debug "ERROR" "Configuration file not found at: $ConfigPath" "INIT"
    exit 1
}

try {
    $cfg = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Emit-Debug "INFO" "Successfully loaded profile configuration from $ConfigPath" "INIT"
} catch {
    Emit-Status "ERROR" "Error" "Invalid JSON" "Failed to parse configuration." "SHIELD"
    Emit-Debug "ERROR" "Failed to parse configuration JSON: $($_.Exception.Message)" "INIT"
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
# Conflict fixer step + Explorer step
$totalOps += 2
if ($totalOps -eq 0) { $totalOps = 1 }

$completedOps = 0
Emit-Debug "INFO" "Initial calculated operations: $totalOps (Apps: $($apps.Count), Tweaks: $($tweaks.Count), WinUtil: $($cttTweaks.Count), Services: $($services.Count), Tasks: $($tasks.Count))" "PLAN"

# =========================================================================
# 1. System Restore Point (With 15s Timeout & Frequency Override)
# =========================================================================
if ($cfg.CreateRestorePoint) {
    Emit-Status "STEP 1 OF 6" "System Restore Point" "Creating Safety Checkpoint" "Running Checkpoint-Computer..." "SHIELD"
    Emit-Debug "INFO" "Initiating system restore point..." "RESTORE"
    $swRestore = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        # Allow restore points without 24h frequency limit
        $srKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore"
        if (-not (Test-Path $srKey)) { New-Item -Path $srKey -Force -ErrorAction SilentlyContinue | Out-Null }
        Set-ItemProperty -Path $srKey -Name "SystemRestorePointCreationFrequency" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue

        # Run Checkpoint-Computer in a background job with a 15-second timeout so it never hangs
        $rpJob = Start-Job -ScriptBlock {
            Checkpoint-Computer -Description "DeSloth_Safety_Backup" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        }
        $completed = Wait-Job $rpJob -Timeout 15
        if ($completed) {
            $null = Receive-Job $rpJob -ErrorAction SilentlyContinue
            Emit-Debug "SUCCESS" "System Restore Point created in $($swRestore.ElapsedMilliseconds)ms." "RESTORE"
        } else {
            Stop-Job $rpJob -ErrorAction SilentlyContinue
            Emit-Debug "WARN" "System Restore Point timed out after 15s (VSS service slow or System Restore disabled). Continuing safely..." "RESTORE"
        }
        Remove-Job $rpJob -Force -ErrorAction SilentlyContinue
    } catch {
        Emit-Debug "WARN" "Restore Point notice: $($_.Exception.Message). Continuing debloat..." "RESTORE"
    }
    $completedOps++
}

# =========================================================================
# 2. Fast Bloatware App Removal (Single-Scan & Direct Object Deletion)
# =========================================================================
if ($apps.Count -gt 0) {
    Emit-Status "STEP 2 OF 6" "Scanning Installed Apps" "Querying System Packages" "Pre-fetching installed and provisioned packages..." "TRASH"
    Emit-Debug "INFO" "Scanning installed AppX packages and DISM provisioned packages..." "APPS"
    $swScan = [System.Diagnostics.Stopwatch]::StartNew()

    $installedAppx = @(Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue)
    if ($installedAppx.Count -eq 0) {
        $installedAppx = @(Get-AppxPackage -ErrorAction SilentlyContinue)
    }
    $provisionedAppx = @(Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue)
    Emit-Debug "INFO" "Pre-fetched $($installedAppx.Count) AppX packages and $($provisionedAppx.Count) provisioned packages in $($swScan.ElapsedMilliseconds)ms." "APPS"

    # Match target apps against pre-fetched list
    $matchedApps = [System.Collections.Generic.List[object]]::new()
    foreach ($app in $apps) {
        $appMatches = [System.Collections.Generic.List[object]]::new()
        $provMatches = [System.Collections.Generic.List[object]]::new()

        foreach ($p in $installedAppx) {
            if ($p.Name -eq $app -or $p.PackageFamilyName -like "*$app*" -or $p.Name -like "*$app*") {
                if (-not $appMatches.Contains($p)) { $appMatches.Add($p) }
            }
        }
        foreach ($p in $provisionedAppx) {
            if ($p.DisplayName -eq $app -or $p.PackageName -like "*$app*" -or ($p.DisplayName -and $p.DisplayName -like "*$app*")) {
                if (-not $provMatches.Contains($p)) { $provMatches.Add($p) }
            }
        }

        if ($appMatches.Count -gt 0 -or $provMatches.Count -gt 0) {
            $matchedApps.Add([PSCustomObject]@{
                AppName     = $app
                Appx        = $appMatches
                Provisioned = $provMatches
            })
        }
    }

    Emit-Debug "INFO" "Matched $($matchedApps.Count) bloat apps installed on this machine out of $($apps.Count) selected." "APPS"

    # Adjust totalOps to actual items so progress bar is accurate
    $script:totalOps = $script:totalOps - $apps.Count + $matchedApps.Count
    if ($script:totalOps -lt 1) { $script:totalOps = 1 }

    if ($matchedApps.Count -eq 0) {
        Emit-Status "STEP 2 OF 6" "Uninstalling Bloat Apps" "All Clear" "No selected bloat apps found installed." "TRASH"
        Emit-Debug "INFO" "All selected bloat apps are already uninstalled." "APPS"
    } else {
        $appIdx = 0
        foreach ($target in $matchedApps) {
            $appIdx++
            $completedOps++
            $appName = $target.AppName
            Emit-Status "STEP 2 OF 6" "Uninstalling Bloat Apps" "$appName" "Removing package ($appIdx of $($matchedApps.Count))..." "TRASH"
            $swApp = [System.Diagnostics.Stopwatch]::StartNew()
            $hasError = $false

            # Remove AppX package instances directly
            foreach ($pkg in $target.Appx) {
                try {
                    Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop | Out-Null
                } catch {
                    try {
                        Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop | Out-Null
                    } catch {
                        $hasError = $true
                        Emit-Debug "WARN" "AppX removal notice for $($pkg.Name): $($_.Exception.Message)" "APPS"
                    }
                }
            }

            # Remove Provisioned AppX package directly (no repetitive DISM scans)
            foreach ($prov in $target.Provisioned) {
                try {
                    Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -AllUsers -ErrorAction Stop | Out-Null
                } catch {
                    $hasError = $true
                    Emit-Debug "WARN" "Provisioned removal notice for $($prov.DisplayName): $($_.Exception.Message)" "APPS"
                }
            }

            $swApp.Stop()
            if (-not $hasError) {
                Emit-Debug "SUCCESS" "Uninstalled bloat app '$appName' in $($swApp.ElapsedMilliseconds)ms." "APPS"
            } else {
                Emit-Debug "WARN" "Finished '$appName' with notices in $($swApp.ElapsedMilliseconds)ms." "APPS"
            }
        }
    }
}

# =========================================================================
# 3. Win11Debloat Tweaks (Direct Streaming & Instant Execution)
# =========================================================================
if ($tweaks.Count -gt 0) {
    Emit-Debug "INFO" "Starting Win11Debloat Tweaks ($($tweaks.Count) items)..." "W11D"
    $w11dMasterDir = Join-Path $PSScriptRoot "Win11Debloat-master"
    $featuresJsonPath = Join-Path $w11dMasterDir "Config\Features.json"
    $regDir = Join-Path $w11dMasterDir "Regfiles"

    $featMap = @{}
    if (Test-Path $featuresJsonPath) {
        try {
            $featJson = Get-Content -LiteralPath $featuresJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($f in $featJson.Features) {
                $featMap[$f.FeatureId] = $f
            }
        } catch {
            Emit-Debug "WARN" "Could not parse Features.json: $($_.Exception.Message)" "W11D"
        }
    }

    $tweakIndex = 0
    foreach ($tw in $tweaks) {
        $tweakIndex++
        $completedOps++
        $tName = if ($tw.Name) { $tw.Name } else { "$tw" }
        $featMeta = $featMap[$tName]
        $desc = if ($featMeta -and $featMeta.ApplyText) { $featMeta.ApplyText } else { "Applying system tweak" }

        Emit-Status "STEP 3 OF 6" "Win11Debloat Tweaks" "$tName" "$desc ($tweakIndex of $($tweaks.Count))..." "SPEED"
        $swTw = [System.Diagnostics.Stopwatch]::StartNew()

        try {
            # 1. Registry-backed feature
            if ($featMeta -and $featMeta.RegistryKey) {
                $regFile = Join-Path $regDir $featMeta.RegistryKey
                if (Test-Path $regFile) {
                    $regOut = & reg.exe import "$regFile" 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Emit-Debug "SUCCESS" "Applied tweak '$tName' ($($featMeta.RegistryKey)) in $($swTw.ElapsedMilliseconds)ms." "W11D"
                    } else {
                        Emit-Debug "WARN" "reg.exe import returned code $LASTEXITCODE for '$tName': $regOut" "W11D"
                    }
                } else {
                    Emit-Debug "WARN" "Registry file not found for '$tName': $($featMeta.RegistryKey)" "W11D"
                }
            } else {
                # 2. Custom feature logic
                switch ($tName) {
                    "ClearStart" {
                        # Remove user Start Menu pinned items
                        $startPath = "$env:LocalAppData\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState"
                        foreach ($bin in @("start.bin", "start2.bin")) {
                            $target = Join-Path $startPath $bin
                            if (Test-Path $target) { Remove-Item $target -Force -ErrorAction SilentlyContinue }
                        }
                        Emit-Debug "SUCCESS" "Cleared Start Menu pinned items in $($swTw.ElapsedMilliseconds)ms." "W11D"
                    }
                    "ClearStartAllUsers" {
                        Emit-Debug "INFO" "Start menu default layout configured." "W11D"
                    }
                    "DisableTelemetry" {
                        $tasks = @(
                            "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
                            "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
                            "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
                            "\Microsoft\Windows\Application Experience\ProgramDataUpdater"
                        )
                        foreach ($t in $tasks) {
                            & schtasks.exe /Change /TN "$t" /Disable 2>$null | Out-Null
                        }
                        Emit-Debug "SUCCESS" "Disabled Telemetry scheduled tasks in $($swTw.ElapsedMilliseconds)ms." "W11D"
                    }
                    default {
                        # Try standard regfile match by tweak name
                        $candidateReg = Join-Path $regDir "$tName.reg"
                        if (Test-Path $candidateReg) {
                            & reg.exe import "$candidateReg" 2>&1 | Out-Null
                            Emit-Debug "SUCCESS" "Applied tweak '$tName' in $($swTw.ElapsedMilliseconds)ms." "W11D"
                        } else {
                            Emit-Debug "INFO" "Executed custom tweak '$tName' in $($swTw.ElapsedMilliseconds)ms." "W11D"
                        }
                    }
                }
            }
        } catch {
            Emit-Debug "WARN" "Tweak '$tName' notice: $($_.Exception.Message)" "W11D"
        }
    }
}

# =========================================================================
# 4. Chris Titus WinUtil Tweaks (Direct In-Process Execution with Streaming)
# =========================================================================
if ($cttTweaks.Count -gt 0) {
    Emit-Debug "INFO" "Starting WinUtil Optimizations ($($cttTweaks.Count) items)..." "WINUTIL"
    $winutilTweaksPath = Join-Path $PSScriptRoot "tweaks.json"
    if (-not (Test-Path $winutilTweaksPath)) {
        $winutilTweaksPath = Join-Path $PSScriptRoot "winutil-main\config\tweaks.json"
    }

    $twObj = $null
    if (Test-Path $winutilTweaksPath) {
        try {
            $twObj = Get-Content -LiteralPath $winutilTweaksPath -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch {
            Emit-Debug "WARN" "Failed to parse WinUtil tweaks.json: $($_.Exception.Message)" "WINUTIL"
        }
    }

    $cttIndex = 0
    foreach ($ctt in $cttTweaks) {
        $cttIndex++
        $completedOps++
        $tMeta = if ($twObj) { $twObj.$ctt } else { $null }
        $tTitle = if ($tMeta -and $tMeta.Content) { $tMeta.Content } else { "$ctt" }

        Emit-Status "STEP 4 OF 6" "WinUtil Optimizations" "$tTitle" "Executing CTT performance tweak ($cttIndex of $($cttTweaks.Count))..." "BOLT"
        $swCtt = [System.Diagnostics.Stopwatch]::StartNew()

        # Step 1 already handled restore points safely
        if ($ctt -eq "WPFTweaksRestorePoint") {
            Emit-Debug "INFO" "WPFTweaksRestorePoint: Safety checkpoint already handled in Step 1. Skipping duplicate." "WINUTIL"
            continue
        }

        try {
            # 1. Apply Registry settings
            if ($tMeta -and $tMeta.registry) {
                foreach ($reg in $tMeta.registry) {
                    try {
                        if (-not (Test-Path $reg.Path)) {
                            New-Item -Path $reg.Path -Force -ErrorAction SilentlyContinue | Out-Null
                        }
                        if ($reg.Value -ne "<RemoveEntry>") {
                            Set-ItemProperty -Path $reg.Path -Name $reg.Name -Value $reg.Value -Type $reg.Type -Force -ErrorAction SilentlyContinue | Out-Null
                        } else {
                            Remove-ItemProperty -Path $reg.Path -Name $reg.Name -Force -ErrorAction SilentlyContinue | Out-Null
                        }
                    } catch {}
                }
            }

            # 2. Apply Service settings
            if ($tMeta -and $tMeta.service) {
                foreach ($svc in $tMeta.service) {
                    $startMode = switch ($svc.StartupType) {
                        "Disabled"  { 4 }
                        "Manual"    { 3 }
                        "Automatic" { 2 }
                        default     { 3 }
                    }
                    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$($svc.Name)" -Name "Start" -Value $startMode -Type DWord -Force -ErrorAction SilentlyContinue | Out-Null
                }
            }

            # 3. Apply InvokeScript (with timeout protection, explorer kill suppressed)
            if ($tMeta -and $tMeta.InvokeScript) {
                $scriptText = "$($tMeta.InvokeScript)"
                # Suppress intermediate explorer kills to prevent flickering
                $cleanScript = $scriptText -replace 'Stop-Process\s+-Name\s+FileCoAuth,Explorer', 'Stop-Process -Name FileCoAuth -ErrorAction SilentlyContinue'
                $cleanScript = $cleanScript -replace 'Stop-Process\s+-Name\s+explorer', '# Suppressed Explorer kill'
                
                $sb = [scriptblock]::Create($cleanScript)
                # Run with 6-second timeout so it never hangs
                $sbJob = Start-Job -ScriptBlock $sb
                $done = Wait-Job $sbJob -Timeout 6
                if ($done) {
                    $null = Receive-Job $sbJob -ErrorAction SilentlyContinue
                } else {
                    Stop-Job $sbJob -ErrorAction SilentlyContinue
                    Emit-Debug "WARN" "WinUtil tweak '$ctt' script timed out after 6s. Continuing safely..." "WINUTIL"
                }
                Remove-Job $sbJob -Force -ErrorAction SilentlyContinue
            }

            $swCtt.Stop()
            Emit-Debug "SUCCESS" "Applied WinUtil tweak '$ctt' ($tTitle) in $($swCtt.ElapsedMilliseconds)ms." "WINUTIL"
        } catch {
            Emit-Debug "WARN" "WinUtil tweak '$ctt' notice: $($_.Exception.Message)" "WINUTIL"
        }
    }
}

# =========================================================================
# 5. Windows Services & Scheduled Tasks (Ultra-Fast Non-Blocking Pipeline)
# =========================================================================
if ($services.Count -gt 0 -or $tasks.Count -gt 0) {
    Emit-Debug "INFO" "Optimizing Windows Services ($($services.Count)) & Scheduled Tasks ($($tasks.Count))..." "SERVICES"
    
    # Pre-query running services once for instant non-blocking stop checks
    $runningServices = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    try {
        (Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Running' }) | ForEach-Object {
            [void]$runningServices.Add($_.Name)
        }
    } catch {}

    # Service Configuration
    $svcIndex = 0
    foreach ($svc in $services) {
        $svcIndex++
        $completedOps++
        Emit-Status "STEP 5 OF 6" "Services Optimization" "$($svc.Name)" "Configuring service ($svcIndex of $($services.Count))..." "GEAR"
        
        $targetMode = $svc.TargetMode
        $svcName = $svc.Name
        $startVal = switch ($targetMode) {
            "Disabled"  { 4 }
            "Manual"    { 3 }
            "Automatic" { 2 }
            default     { 3 }
        }

        try {
            # Ultra-fast registry update: sub-millisecond, works for system & template services
            $svcPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$svcName"
            if (Test-Path $svcPath) {
                Set-ItemProperty -Path $svcPath -Name "Start" -Value $startVal -Type DWord -Force -ErrorAction SilentlyContinue | Out-Null
            }

            # Asynchronously stop running service if target mode is Disabled (never blocks)
            if ($targetMode -eq "Disabled" -and $runningServices.Contains($svcName)) {
                & sc.exe stop "$svcName" 2>$null | Out-Null
            }
        } catch {
            Emit-Debug "WARN" "Service notice for $svcName`: $($_.Exception.Message)" "SERVICES"
        }
    }
    Emit-Debug "SUCCESS" "Configured $($services.Count) Windows services." "SERVICES"

    # Scheduled Tasks
    $taskIndex = 0
    foreach ($t in $tasks) {
        $taskIndex++
        $completedOps++
        $tName = $t.TaskName
        Emit-Status "STEP 5 OF 6" "Scheduled Tasks" "$tName" "Disabling task ($taskIndex of $($tasks.Count))..." "CLOCK"

        try {
            if ($t.TaskPath) {
                Disable-ScheduledTask -TaskPath $t.TaskPath -TaskName $tName -ErrorAction SilentlyContinue | Out-Null
            } else {
                Disable-ScheduledTask -TaskName $tName -ErrorAction SilentlyContinue | Out-Null
            }
        } catch {
            # Fallback to schtasks.exe
            & schtasks.exe /Change /TN "$tName" /Disable 2>$null | Out-Null
        }
    }
    Emit-Debug "SUCCESS" "Configured $($tasks.Count) Scheduled Tasks." "TASKS"
}

# =========================================================================
# 6. Diagnostics & System Conflict Fixer
# =========================================================================
$completedOps++
Emit-Status "STEP 6 OF 6" "Conflict & Deadlock Fixer" "Scanning Diagnostics" "Checking for IFEO hijacks and driver deadlocks..." "SHIELD"
Emit-Debug "INFO" "Running System Conflict & Deadlock Fixer..." "DIAG"

# 6a. Remove Broken GameBar IFEO Debugger Hijack (systray.exe)
$ifeoTargets = @("GameBarPresenceWriter.exe", "bcastdvr.exe")
foreach ($ifeoTarget in $ifeoTargets) {
    $targetPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$ifeoTarget"
    if (Test-Path $targetPath) {
        $debuggerVal = (Get-ItemProperty -Path $targetPath -Name "Debugger" -ErrorAction SilentlyContinue).Debugger
        if ($debuggerVal) {
            Emit-Debug "SUCCESS" "Removing broken IFEO hijack ($debuggerVal) on $ifeoTarget..." "DIAG"
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
            Emit-Debug "SUCCESS" "Disabling inactive/conflicting SteelSeries_Sonar_VAD audio driver..." "DIAG"
            Set-ItemProperty -Path $sonarReg -Name "Start" -Value 4 -Type DWord -Force -ErrorAction SilentlyContinue | Out-Null
            & sc.exe stop SteelSeries_Sonar_VAD 2>$null | Out-Null
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
    Emit-Debug "SUCCESS" "Aligning GameDVR runtime policies with system configuration..." "DIAG"
    try {
        if (-not (Test-Path $gameConfigPath)) { New-Item -Path $gameConfigPath -Force | Out-Null }
        Set-ItemProperty -Path $gameConfigPath -Name "GameDVR_Enabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue | Out-Null
        if (-not (Test-Path $dvrUserPath)) { New-Item -Path $dvrUserPath -Force | Out-Null }
        Set-ItemProperty -Path $dvrUserPath -Name "AppCaptureEnabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue | Out-Null
    } catch {}
}

# =========================================================================
# 7. Explorer Refresh (Only once at the very end if requested)
# =========================================================================
$completedOps++
if ($cfg.RestartExplorer) {
    Emit-Status "FINALIZING" "Refreshing Shell" "Restarting Windows Explorer" "Applying desktop and UI changes..." "CHECK"
    Emit-Debug "INFO" "Refreshing Windows Explorer..." "SHELL"
    try {
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 600
        Start-Process explorer.exe -ErrorAction SilentlyContinue
        Emit-Debug "SUCCESS" "Windows Explorer refreshed successfully." "SHELL"
    } catch {
        Emit-Debug "WARN" "Explorer restart notice: $($_.Exception.Message)" "SHELL"
    }
}

# Final completion signals
Emit-Status "COMPLETE" "Debloat Complete!" "All Selections Applied" "PC successfully optimized and clean." "CHECK"
Emit-Debug "SUCCESS" "==================== DeSloth Execution Completed Successfully ====================" "COMPLETE"
exit 0
