# Load and aggregate data from Win11Debloat, WinUtil, Services, and Task Scheduler
param(
    [string]$RootDir = (Split-Path -Parent $PSScriptRoot)
)

function Get-DebloatData {
    param([string]$BaseDir = $RootDir)

    $result = [PSCustomObject]@{
        Win11DebloatFeatures = @()
        Win11DebloatApps     = @()
        WinUtilTweaks        = @()
        WinUtilFeatures      = @()
        WinUtilAppx          = @()
        Services             = @()
        Tasks                = @()
        PresetServices       = @()
        PresetTasks          = @()
    }

    # 0. Query installed AppX packages for detection
    $installedAppx = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    try {
        foreach ($pkg in (Get-AppxPackage -ErrorAction SilentlyContinue)) {
            if ($pkg.Name) { $installedAppx.Add($pkg.Name) | Out-Null }
        }
    } catch {}

    # 1. Win11Debloat Features (Filter out meta-switches and parameter flags)
    $w11dFeaturesPath = Join-Path $BaseDir "Win11Debloat-master\Config\Features.json"
    if (Test-Path $w11dFeaturesPath) {
        $featuresJson = Get-Content $w11dFeaturesPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $metaFeatureIds = @('RemoveApps', 'Apps', 'RemoveGamingApps', 'RemoveHPApps', 'CreateRestorePoint')
        $filteredFeatures = @(
            $featuresJson.Features | Where-Object {
                (-not [string]::IsNullOrWhiteSpace($_.Category)) -and
                ($metaFeatureIds -notcontains $_.FeatureId)
            }
        )
        $result.Win11DebloatFeatures = $filteredFeatures
    }

    # Win11Debloat Apps (With installed status detection)
    $w11dAppsPath = Join-Path $BaseDir "Win11Debloat-master\Config\Apps.json"
    if (Test-Path $w11dAppsPath) {
        $appsJson = Get-Content $w11dAppsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $appList = [System.Collections.Generic.List[PSObject]]::new()
        foreach ($a in $appsJson.Apps) {
            $ids = @(
                foreach ($raw in @($a.AppId)) {
                    if ($raw -is [string] -and $raw.Trim().Length -gt 0) { $raw.Trim() }
                }
            )
            if ($ids.Count -eq 0) { continue }
            $isInst = $false
            foreach ($id in $ids) {
                if ($installedAppx.Contains($id)) {
                    $isInst = $true
                    break
                }
            }
            $primaryId = $ids[0]
            $displayId = $ids -join ', '
            $friendlyName = if ($a.FriendlyName) { $a.FriendlyName } else { $primaryId }
            $appList.Add([PSCustomObject]@{
                AppId             = $primaryId
                AllAppIds         = $ids
                AppIdDisplay      = $displayId
                FriendlyName      = $friendlyName
                Description       = if ($a.Description) { $a.Description } else { "Package: $displayId" }
                Recommendation    = if ($a.Recommendation) { $a.Recommendation } else { "safe" }
                SelectedByDefault = [bool]$a.SelectedByDefault
                IsInstalled       = $isInst
                StatusDisplay     = if ($isInst) { "INSTALLED" } else { "Not Installed" }
                StatusColor       = if ($isInst) { "#10B981" } else { "#64748B" }
            })
        }
        $result.Win11DebloatApps = @($appList)
    }

    # 2. WinUtil Tweaks
    $winutilTweaksPath = Join-Path $BaseDir "winutil-main\config\tweaks.json"
    if (Test-Path $winutilTweaksPath) {
        $tweaksJson = Get-Content $winutilTweaksPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $tweaksList = [System.Collections.Generic.List[PSObject]]::new()
        foreach ($prop in $tweaksJson.PSObject.Properties) {
            $val = $prop.Value
            $tweaksList.Add([PSCustomObject]@{
                Id          = $prop.Name
                Name        = $val.Content
                Description = $val.Description
                Category    = if ($val.category) { $val.category } else { "General Tweaks" }
            })
        }
        $result.WinUtilTweaks = @($tweaksList)
    }

    # WinUtil Features
    $winutilFeaturePath = Join-Path $BaseDir "winutil-main\config\feature.json"
    if (Test-Path $winutilFeaturePath) {
        $fJson = Get-Content $winutilFeaturePath -Raw -Encoding UTF8 | ConvertFrom-Json
        $fList = [System.Collections.Generic.List[PSObject]]::new()
        foreach ($prop in $fJson.PSObject.Properties) {
            $val = $prop.Value
            $fList.Add([PSCustomObject]@{
                Id          = $prop.Name
                Name        = $val.Content
                Description = $val.Description
                Category    = if ($val.category) { $val.category } else { "Optional Features" }
            })
        }
        $result.WinUtilFeatures = @($fList)
    }

    # WinUtil Appx
    $winutilAppxPath = Join-Path $BaseDir "winutil-main\config\appx.json"
    if (Test-Path $winutilAppxPath) {
        $appxJson = Get-Content $winutilAppxPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $aList = [System.Collections.Generic.List[PSObject]]::new()
        foreach ($prop in $appxJson.PSObject.Properties) {
            $val = $prop.Value
            $aList.Add([PSCustomObject]@{
                Id          = $prop.Name
                Name        = $val.Content
                Description = $val.Description
                Category    = if ($val.category) { $val.category } else { "AppX Packages" }
            })
        }
        $result.WinUtilAppx = @($aList)
    }

    # 3. Recommended Telemetry & Bloat Services List
    $result.PresetServices = @(
        'DiagTrack',           # Connected User Experiences and Telemetry
        'dmwappushservice',    # Device Management Wireless Application Protocol
        'MapsBroker',          # Downloaded Maps Manager
        'RetailDemo',          # Retail Demo Service
        'WbioSrvc',            # Windows Biometric Service
        'wisvc',               # Windows Insider Service
        'TroubleshootingSvc',  # Recommended Troubleshooting Service
        'WerSvc',              # Windows Error Reporting Service
        'SysMain',             # SuperFetch / SysMain
        'XblAuthManager',      # Xbox Live Auth Manager
        'XblGameSave',         # Xbox Live Game Save
        'XboxNetApiSvc',       # Xbox Live Networking Service
        'XboxGipSvc',          # Xbox Accessory Management Service
        'SensorService',       # Sensor Service
        'SensrSvc',            # Sensor Monitoring Service
        'SensorDataService',   # Sensor Data Service
        'SharedRealitySvc',    # Spatial Data Service (Mixed Reality)
        'MixedRealityOpenXRSvc',# Mixed Reality OpenXR Service
        'WpcMonSvc',           # Parental Controls
        'PhoneSvc',            # Phone Service
        'CaptureService',      # CaptureService
        'OneSyncSvc',          # Sync Host
        'MessagingService',    # MessagingService
        'PimIndexMaintenanceSvc' # Contact Data
    )

    # 4. Recommended Telemetry & Bloat Scheduled Tasks List
    $result.PresetTasks = @(
        '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
        '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
        '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
        '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
        '\Microsoft\Windows\Application Experience\StartupAppTask',
        '\Microsoft\Windows\Autochk\Proxy',
        '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector',
        '\Microsoft\Windows\Feedback\Siuf\DmClient',
        '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload',
        '\Microsoft\Windows\Maps\MapsUpdateTask',
        '\Microsoft\Windows\Maps\MapsToastTask',
        '\Microsoft\Windows\Shell\FamilySafetyMonitor',
        '\Microsoft\Windows\Shell\FamilySafetyRefreshTask',
        '\Microsoft\Windows\Windows Error Reporting\QueueReporting',
        '\Microsoft\EdgeUpdate\EdgeUpdateTaskMachineCore',
        '\Microsoft\EdgeUpdate\EdgeUpdateTaskMachineUA'
    )

    # 5. Live Windows Services
    try {
        $services = Get-CimInstance Win32_Service -ErrorAction SilentlyContinue | Select-Object Name, DisplayName, StartMode, State, Description
        $svcList = [System.Collections.Generic.List[PSObject]]::new()
        foreach ($s in ($services | Sort-Object DisplayName)) {
            $isPreset = $result.PresetServices -contains $s.Name
            $svcList.Add([PSCustomObject]@{
                Name        = $s.Name
                DisplayName = if ($s.DisplayName) { $s.DisplayName } else { $s.Name }
                StartMode   = $s.StartMode
                State       = $s.State
                Description = if ($s.Description) { $s.Description } else { "No description available." }
                IsPreset    = $isPreset
                TargetMode  = "Keep" # Default Keep, or Manual, or Disabled
            })
        }
        $result.Services = @($svcList)
    } catch {
        Write-Warning "Failed to query Win32_Service: $_"
    }

    # 6. Live Scheduled Tasks
    try {
        $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Select-Object TaskPath, TaskName, State, Description
        $taskList = [System.Collections.Generic.List[PSObject]]::new()
        foreach ($t in ($tasks | Sort-Object TaskPath, TaskName)) {
            $fullPath = "$($t.TaskPath)$($t.TaskName)"
            $isPreset = ($result.PresetTasks -contains $fullPath) -or ($result.PresetTasks -contains "$($t.TaskName)")
            $taskList.Add([PSCustomObject]@{
                FullPath    = $fullPath
                TaskPath    = $t.TaskPath
                TaskName    = $t.TaskName
                State       = "$($t.State)"
                Description = if ($t.Description) { $t.Description } else { "No description available." }
                IsPreset    = $isPreset
                TargetState = "Keep" # Default Keep, or Disable
            })
        }
        $result.Tasks = @($taskList)
    } catch {
        Write-Warning "Failed to query Scheduled Tasks: $_"
    }

    return $result
}

