# Packages configuration, runtime engines, and native C# WPF Runner into a single standalone file
function Export-StandaloneRunner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$UnifiedConfig,

        [string]$OutputDir = "d:\Declut\dist",
        [string]$BaseDir   = "d:\Declut"
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem

    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    $tempStaging = Join-Path $env:TEMP ("DebloatStaging_" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempStaging -Force | Out-Null
    $zipPath = $null

    try {
        # 1. Generate UnifiedConfig.json
        $unifiedConfigJsonPath = Join-Path $tempStaging "UnifiedConfig.json"
        $UnifiedConfig | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $unifiedConfigJsonPath -Encoding UTF8

        # 2. Generate Win11DebloatConfig.json
        $w11dConfig = [ordered]@{
            "Version"    = "1.0"
            "Apps"       = @($UnifiedConfig.Win11Debloat.Apps)
            "Tweaks"     = @($UnifiedConfig.Win11Debloat.Tweaks | Where-Object { $_.Value -eq $true -or ($null -eq $_.Value -and $_ -is [string]) })
            "Deployment" = @(
                @{ "Name" = "CreateRestorePoint"; "Value" = [bool]$UnifiedConfig.CreateRestorePoint },
                @{ "Name" = "SkipRegistryBackup"; "Value" = $false },
                @{ "Name" = "RestartExplorer"; "Value" = $false }
            )
        }
        $w11dConfigJsonPath = Join-Path $tempStaging "Win11DebloatConfig.json"
        $w11dConfig | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $w11dConfigJsonPath -Encoding UTF8

        # 3. Generate WinUtilConfig.json (flat string array)
        $winutilConfigJsonPath = Join-Path $tempStaging "WinUtilConfig.json"
        @($UnifiedConfig.WinUtil) | ConvertTo-Json | Set-Content -LiteralPath $winutilConfigJsonPath -Encoding UTF8

        # 4. Copy ApplyServicesAndTasks.ps1 and UnifiedRunnerEngine.ps1
        $applyServicesSource = Join-Path $BaseDir "src\ApplyServicesAndTasks.ps1"
        if (Test-Path $applyServicesSource) {
            Copy-Item -LiteralPath $applyServicesSource -Destination (Join-Path $tempStaging "ApplyServicesAndTasks.ps1") -Force
        }
        $unifiedEngineSource = Join-Path $BaseDir "src\UnifiedRunnerEngine.ps1"
        if (Test-Path $unifiedEngineSource) {
            Copy-Item -LiteralPath $unifiedEngineSource -Destination (Join-Path $tempStaging "UnifiedRunnerEngine.ps1") -Force
        }

        # 5. Copy winutil.ps1
        $winutilSource = Join-Path $BaseDir "winutil-main\winutil.ps1"
        if (-not (Test-Path $winutilSource)) {
            & powershell.exe -ExecutionPolicy Bypass -File (Join-Path $BaseDir "winutil-main\Compile.ps1")
        }
        Copy-Item -LiteralPath $winutilSource -Destination (Join-Path $tempStaging "winutil.ps1") -Force

        # 6. Copy Win11Debloat-master (required subdirectories to keep payload slim and fast)
        $w11dTargetDir = Join-Path $tempStaging "Win11Debloat-master"
        New-Item -ItemType Directory -Path $w11dTargetDir -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $BaseDir "Win11Debloat-master\Win11Debloat.ps1") -Destination $w11dTargetDir -Force
        foreach ($dir in @("Config", "Scripts", "Regfiles", "Assets", "Schemas")) {
            $sourceDir = Join-Path $BaseDir "Win11Debloat-master\$dir"
            if (Test-Path $sourceDir) {
                $destSubDir = Join-Path $w11dTargetDir $dir
                Copy-Item -LiteralPath $sourceDir -Destination $destSubDir -Recurse -Force
            }
        }

        # 7. Zip the payload
        $zipPath = Join-Path $env:TEMP ("DebloatPayload_" + [guid]::NewGuid().ToString("N") + ".zip")
        if (Test-Path $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
        [System.IO.Compression.ZipFile]::CreateFromDirectory($tempStaging, $zipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)

        # 8. Compile Standalone C# .NET 4.5 WPF Executable via csc.exe
        $cscPath = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
        $wpfLibPath = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\WPF"
        $exeOutPath = Join-Path $OutputDir "UltimateDebloatRunner.exe"
        $csAppPath = Join-Path $BaseDir "src\RunnerApp.cs"
        $manifestPath = Join-Path $BaseDir "src\app.manifest"

        $compileSuccess = $false
        if (Test-Path $cscPath) {
            $cscArgs = @(
                "/nologo",
                "/target:winexe",
                "/optimize+",
                "/win32manifest:`"$manifestPath`"",
                "/lib:`"$wpfLibPath`"",
                "/r:System.Xaml.dll",
                "/r:PresentationFramework.dll",
                "/r:PresentationCore.dll",
                "/r:WindowsBase.dll",
                "/r:System.dll",
                "/r:System.Core.dll",
                "/r:System.IO.Compression.dll",
                "/r:System.IO.Compression.FileSystem.dll",
                "/resource:`"$zipPath`",Payload",
                "/out:`"$exeOutPath`"",
                "`"$csAppPath`""
            )
            $compResult = Start-Process -FilePath $cscPath -ArgumentList $cscArgs -NoNewWindow -Wait -PassThru
            if ($compResult.ExitCode -eq 0 -and (Test-Path $exeOutPath)) {
                $compileSuccess = $true
            }
        }

        # 9. Standalone Self-Extracting .cmd script fallback
        $cmdOutPath = Join-Path $OutputDir "UltimateDebloatRunner.cmd"
        $base64Payload = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($zipPath))

        $cmdContent = @"
@echo off
setlocal
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Elevating to Administrator...
    powershell -NoProfile -Command "Start-Process cmd -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

set "TEMP_DIR=%TEMP%\UltimateDebloat_%RANDOM%_%RANDOM%"
mkdir "%TEMP_DIR%" 2>nul

powershell -NoProfile -ExecutionPolicy Bypass -Command "& { `$b64 = Get-Content -LiteralPath '%~f0' | Select-String -Pattern '^::B64PAYLOAD::(.*)$' | ForEach-Object { `$_.Matches.Groups[1].Value }; `$bytes = [Convert]::FromBase64String(`$b64); `$zipPath = Join-Path '%TEMP_DIR%' 'payload.zip'; [System.IO.File]::WriteAllBytes(`$zipPath, `$bytes); Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::ExtractToDirectory(`$zipPath, '%TEMP_DIR%'); Remove-Item `$zipPath -Force; & powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File (Join-Path '%TEMP_DIR%' 'UnifiedRunnerEngine.ps1') -ConfigPath (Join-Path '%TEMP_DIR%' 'UnifiedConfig.json'); Remove-Item -LiteralPath '%TEMP_DIR%' -Recurse -Force -ErrorAction SilentlyContinue }"

exit /b

::B64PAYLOAD::$base64Payload
"@

        Set-Content -LiteralPath $cmdOutPath -Value $cmdContent -Encoding ASCII

        return [PSCustomObject]@{
            ExePath        = if ($compileSuccess) { $exeOutPath } else { $null }
            CmdPath        = $cmdOutPath
            PayloadSize    = (Get-Item $zipPath).Length
            CompileSuccess = $compileSuccess
        }
    }
    finally {
        Remove-Item -LiteralPath $tempStaging -Recurse -Force -ErrorAction SilentlyContinue
        if ($zipPath -and (Test-Path $zipPath)) {
            Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue
        }
    }
}
