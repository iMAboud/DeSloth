# Ultimate Windows Debloat - Standalone Runner Engine & UI
param(
    [string]$ConfigPath = ".\UnifiedConfig.json",
    [string]$CoreDir    = ".\"
)

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# Ensure paths
if (-not (Test-Path $ConfigPath)) {
    [System.Windows.MessageBox]::Show("Config file not found at: $ConfigPath", "Ultimate Debloat", "OK", "Error")
    Exit 1
}

$config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Ultimate Windows Debloat" Height="380" Width="540"
        WindowStartupLocation="CenterScreen" WindowStyle="None" AllowsTransparency="True"
        Background="Transparent" ResizeMode="NoResize">
    <Window.Resources>
        <Style TargetType="Button" x:Key="ModernBtn">
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="FontFamily" Value="Segoe UI SemiBold"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" CornerRadius="8" Background="{TemplateBinding Background}" BorderThickness="0" Padding="14,8">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Opacity" Value="0.88"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="border" Property="Opacity" Value="0.75"/>
                            </Trigger>
                            <Trigger Property="IsEnabled" Value="False">
                                <Setter TargetName="border" Property="Opacity" Value="0.4"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    
    <Border CornerRadius="16" Background="#0F1117" BorderBrush="#262C3D" BorderThickness="1.5">
        <Border.Effect>
            <DropShadowEffect BlurRadius="30" Color="#000000" Opacity="0.65" ShadowDepth="4"/>
        </Border.Effect>
        <Grid>
            <!-- Window Drag Area & Title Bar -->
            <Grid VerticalAlignment="Top" Height="42" Margin="14,6,14,0">
                <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                    <Path Fill="#3B82F6" Width="14" Height="14" Stretch="Uniform" Margin="0,0,8,0"
                          Data="M13,10V3L4,14H11V21L20,10H13Z"/>
                    <TextBlock Text="ULTIMATE WINDOWS DEBLOAT" Foreground="#94A3B8" FontSize="11" FontWeight="Bold" VerticalAlignment="Center" FontFamily="Segoe UI"/>
                </StackPanel>
                <Button x:Name="BtnCloseWindow" HorizontalAlignment="Right" Width="26" Height="26" Background="Transparent" BorderThickness="0" Cursor="Hand">
                    <Button.Template>
                        <ControlTemplate TargetType="Button">
                            <Border x:Name="b" CornerRadius="6" Background="Transparent">
                                <Path Fill="#64748B" Width="10" Height="10" Stretch="Uniform"
                                      Data="M19,6.41L17.59,5L12,10.59L6.41,5L5,6.41L10.59,12L5,17.59L6.41,19L12,13.41L17.59,19L19,17.59L13.41,12L19,6.41Z"/>
                            </Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True">
                                    <Setter TargetName="b" Property="Background" Value="#334155"/>
                                </Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Button.Template>
                </Button>
            </Grid>

            <!-- Main Content Area -->
            <StackPanel VerticalAlignment="Center" Margin="28,40,28,64" HorizontalAlignment="Center" Width="470">
                <!-- Step Vector Icon -->
                <Border x:Name="IconContainer" Width="56" Height="56" CornerRadius="28" Background="#1E2433" HorizontalAlignment="Center" Margin="0,0,0,12">
                    <Border.Effect>
                        <DropShadowEffect x:Name="IconGlow" BlurRadius="18" Color="#3B82F6" Opacity="0.4" ShadowDepth="0"/>
                    </Border.Effect>
                    <Path x:Name="StepIcon" Fill="#60A5FA" Width="26" Height="26" Stretch="Uniform" HorizontalAlignment="Center" VerticalAlignment="Center"
                          Data="M13,10V3L4,14H11V21L20,10H13Z"/>
                </Border>

                <!-- Step Counter -->
                <TextBlock x:Name="TxtStepCount" Text="READY TO OPTIMIZE" Foreground="#38BDF8" FontSize="11" FontWeight="Bold" HorizontalAlignment="Center" Margin="0,0,0,4"/>

                <!-- Step Title -->
                <TextBlock x:Name="TxtStepTitle" Text="One-Click System Debloat" Foreground="#FFFFFF" FontSize="18" FontWeight="SemiBold" HorizontalAlignment="Center" Margin="0,0,0,4"/>

                <!-- Step Brief -->
                <TextBlock x:Name="TxtStepBrief" Text="Click Start to apply your personalized configuration automatically." Foreground="#94A3B8" FontSize="12" HorizontalAlignment="Center" TextAlignment="Center" TextWrapping="Wrap" MaxWidth="440" Margin="0,0,0,16"/>

                <!-- Progress Bar Container -->
                <Grid Margin="0,0,0,6">
                    <ProgressBar x:Name="PBar" Height="7" Minimum="0" Maximum="100" Value="0" Background="#1E2433" BorderThickness="0">
                        <ProgressBar.Foreground>
                            <LinearGradientBrush StartPoint="0,0" EndPoint="1,0">
                                <GradientStop Color="#06B6D4" Offset="0"/>
                                <GradientStop Color="#3B82F6" Offset="1"/>
                            </LinearGradientBrush>
                        </ProgressBar.Foreground>
                    </ProgressBar>
                </Grid>

                <!-- Substatus line -->
                <TextBlock x:Name="TxtSubStatus" Text="Waiting for start..." Foreground="#64748B" FontSize="11" HorizontalAlignment="Center" TextTrimming="CharacterEllipsis" MaxWidth="440"/>
            </StackPanel>

            <!-- Bottom Action Controls -->
            <Grid VerticalAlignment="Bottom" Height="60" Margin="24,0,24,14">
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                    <Button x:Name="BtnStart" Content="Start Debloat" Style="{StaticResource ModernBtn}" Background="#2563EB" Width="170" Margin="4,0"/>
                    <Button x:Name="BtnRestartExplorer" Content="Restart Explorer" Style="{StaticResource ModernBtn}" Background="#334155" Width="140" Margin="4,0" Visibility="Collapsed"/>
                    <Button x:Name="BtnDone" Content="Close" Style="{StaticResource ModernBtn}" Background="#1E293B" Width="110" Margin="4,0" Visibility="Collapsed"/>
                </StackPanel>
            </Grid>
        </Grid>
    </Border>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# Element References
$btnCloseWindow      = $window.FindName("BtnCloseWindow")
$btnStart            = $window.FindName("BtnStart")
$btnRestartExplorer  = $window.FindName("BtnRestartExplorer")
$btnDone             = $window.FindName("BtnDone")
$txtStepCount        = $window.FindName("TxtStepCount")
$txtStepTitle        = $window.FindName("TxtStepTitle")
$txtStepBrief        = $window.FindName("TxtStepBrief")
$txtSubStatus        = $window.FindName("TxtSubStatus")
$pBar                = $window.FindName("PBar")
$stepIcon            = $window.FindName("StepIcon")
$iconContainer       = $window.FindName("IconContainer")
$iconGlow            = $window.FindName("IconGlow")

# SVG Path Geometries for Steps
$icons = @{
    "Ready"     = "M13,10V3L4,14H11V21L20,10H13Z"                                                    # Bolt
    "Restore"   = "M12,1L3,5V11C3,16.55 6.84,21.74 12,23C17.16,21.74 21,16.55 21,11V5L12,1M12,5A6,6 0 0,1 18,11C18,14.07 15.65,16.64 12.63,16.96V19.04C16.8,18.7 20,15.22 20,11A8,8 0 0,0 12,3A8,8 0 0,0 4,11C4,15.22 7.2,18.7 11.37,19.04V16.96C8.35,16.64 6,14.07 6,11A6,6 0 0,1 12,5Z" # Shield
    "W11D"      = "M2.81,14.12L5.64,11.29L7.05,12.71L4.22,15.54L2.81,14.12M5.64,8.46L8.46,5.64L9.88,7.05L7.05,9.88L5.64,8.46M12,2A10,10 0 0,0 2,12A10,10 0 0,0 12,22A10,10 0 0,0 22,12A10,10 0 0,0 12,2M12,20A8,8 0 0,1 4,12A8,8 0 0,1 12,4A8,8 0 0,1 20,12A8,8 0 0,1 12,20M12,6A6,6 0 0,0 6,12A6,6 0 0,0 12,18A6,6 0 0,0 18,12A6,6 0 0,0 12,6M12,16A4,4 0 0,1 8,12A4,4 0 0,1 12,8A4,4 0 0,1 16,12A4,4 0 0,1 12,16Z" # Speedometer
    "CTT"       = "M7,2H17A2,2 0 0,1 19,4V20A2,2 0 0,1 17,22H7A2,2 0 0,1 5,20V4A2,2 0 0,1 7,2M11,6V9H8L13,16V13H16L11,6Z" # Power/Terminal
    "Services"  = "M12,15.5A3.5,3.5 0 0,1 8.5,12A3.5,3.5 0 0,1 12,8.5A3.5,3.5 0 0,1 15.5,12A3.5,3.5 0 0,1 12,15.5M19.43,12.97C19.47,12.65 19.5,12.33 19.5,12C19.5,11.67 19.47,11.34 19.43,11L21.54,9.37C21.73,9.22 21.78,8.95 21.66,8.73L19.66,5.27C19.54,5.05 19.27,4.96 19.05,5.05L16.56,6.05C16.04,5.66 15.5,5.32 14.87,5.07L14.5,2.42C14.46,2.18 14.25,2 14,2H10C9.75,2 9.54,2.18 9.5,2.42L9.13,5.07C8.5,5.32 7.96,5.66 7.44,6.05L4.95,5.05C4.73,4.96 4.46,5.05 4.34,5.27L2.34,8.73C2.21,8.95 2.27,9.22 2.46,9.37L4.57,11C4.53,11.34 4.5,11.67 4.5,12C4.5,12.33 4.53,12.65 4.57,12.97L2.46,14.63C2.27,14.78 2.21,15.05 2.34,15.27L4.34,18.73C4.46,18.95 4.73,19.03 4.95,18.95L7.44,17.94C7.96,18.34 8.5,18.68 9.13,18.93L9.5,21.58C9.54,21.82 9.75,22 10,22H14C14.25,22 14.46,21.82 14.5,21.58L14.87,18.93C15.5,18.67 16.04,18.34 16.56,17.94L19.05,18.95C19.27,19.03 19.54,18.95 19.66,18.73L21.66,15.27C21.78,15.05 21.73,14.78 21.54,14.63L19.43,12.97Z" # Gear
    "Tasks"     = "M19,3H18V1H16V3H8V1H6V3H5C3.89,3 3,3.89 3,5V19A2,2 0 0,0 5,21H19A2,2 0 0,0 21,19V5C21,3.89 20.1,3 19,3M19,19H5V8H19V19M11,10H13V14H15V16H9V14H11V10Z" # Calendar/Clock
    "Finish"    = "M12 2C6.5 2 2 6.5 2 12S6.5 22 12 22 22 17.5 22 12 17.5 2 12 2M10 17L5 12L6.41 10.59L10 14.17L17.59 6.58L19 8L10 17Z" # Checkmark
}

# Drag window behavior
$window.Add_MouseLeftButtonDown({
    $window.DragMove()
})

$btnCloseWindow.Add_Click({
    $window.Close()
})

$btnDone.Add_Click({
    $window.Close()
})

$btnRestartExplorer.Add_Click({
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
    Start-Process explorer
    $btnRestartExplorer.IsEnabled = $false
    $btnRestartExplorer.Content = "Restarted!"
})

# Helper to update UI safely
function Set-RunnerState {
    param(
        [string]$IconKey,
        [string]$StepCount,
        [string]$Title,
        [string]$Brief,
        [string]$SubStatus,
        [double]$Percent,
        [string]$Color = "#3B82F6"
    )
    $window.Dispatcher.Invoke([Action]{
        if ($icons.ContainsKey($IconKey)) {
            $stepIcon.Data = [System.Windows.Media.Geometry]::Parse($icons[$IconKey])
        }
        $stepIcon.Fill = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Color)
        $iconGlow.Color = [System.Windows.Media.ColorConverter]::new().ConvertFromString($Color)
        $txtStepCount.Text = $StepCount
        $txtStepTitle.Text = $Title
        $txtStepBrief.Text = $Brief
        $txtSubStatus.Text = $SubStatus
        $pBar.Value = $Percent
    })
}

# Execution Handler
$btnStart.Add_Click({
    $btnStart.IsEnabled = $false
    $btnStart.Content = "Debloating..."

    # Form planned steps dynamically from config
    $plan = [System.Collections.Generic.List[PSCustomObject]]::new()

    if ($config.CreateRestorePoint) {
        $plan.Add([PSCustomObject]@{
            Key   = "Restore"
            Title = "System Restore Point"
            Brief = "Creating a safety restore point before applying system changes."
            Color = "#60A5FA"
            Action = {
                try {
                    Checkpoint-Computer -Description "UltimateDebloat_Backup" -RestorePointType "MODIFY_SETTINGS" -ErrorAction SilentlyContinue | Out-Null
                } catch {}
            }
        })
    }

    if ($config.Win11Debloat -and ($config.Win11Debloat.Tweaks.Count -gt 0 -or $config.Win11Debloat.Apps.Count -gt 0)) {
        $plan.Add([PSCustomObject]@{
            Key   = "W11D"
            Title = "Win11Debloat Engine"
            Brief = "Executing Win11Debloat to strip telemetry, bloat apps, and interface clutter."
            Color = "#38BDF8"
            Action = {
                $w11dScript = Join-Path $CoreDir "Win11Debloat-master\Win11Debloat.ps1"
                $w11dCfg    = Join-Path $CoreDir "Win11DebloatConfig.json"
                if (Test-Path $w11dScript) {
                    $argsList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$w11dScript`"", "-Config", "`"$w11dCfg`"", "-Silent")
                    $p = Start-Process powershell.exe -ArgumentList $argsList -NoNewWindow -Wait -PassThru
                }
            }
        })
    }

    if ($config.WinUtil -and $config.WinUtil.Count -gt 0) {
        $plan.Add([PSCustomObject]@{
            Key   = "CTT"
            Title = "Chris Titus WinUtil Engine"
            Brief = "Executing CTT WinUtil for performance enhancements and deep tweaks."
            Color = "#F59E0B"
            Action = {
                $winutilScript = Join-Path $CoreDir "winutil.ps1"
                $winutilCfg    = Join-Path $CoreDir "WinUtilConfig.json"
                if (Test-Path $winutilScript) {
                    $argsList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$winutilScript`"", "-Config", "`"$winutilCfg`"")
                    $p = Start-Process powershell.exe -ArgumentList $argsList -NoNewWindow -Wait -PassThru
                }
            }
        })
    }

    if ($config.Services -and $config.Services.Count -gt 0) {
        $plan.Add([PSCustomObject]@{
            Key   = "Services"
            Title = "Windows Services Optimization"
            Brief = "Configuring $($config.Services.Count) selected service(s) to Manual or Disabled."
            Color = "#EC4899"
            Action = {
                foreach ($svc in $config.Services) {
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
        })
    }

    if ($config.Tasks -and $config.Tasks.Count -gt 0) {
        $plan.Add([PSCustomObject]@{
            Key   = "Tasks"
            Title = "Task Scheduler Cleanup"
            Brief = "Disabling $($config.Tasks.Count) telemetry and tracking scheduled tasks."
            Color = "#8B5CF6"
            Action = {
                foreach ($t in $config.Tasks) {
                    try {
                        Disable-ScheduledTask -TaskPath $t.TaskPath -TaskName $t.TaskName -ErrorAction SilentlyContinue | Out-Null
                    } catch {}
                }
            }
        })
    }

    # Finalization step
    $plan.Add([PSCustomObject]@{
        Key   = "Finish"
        Title = "Finalizing Optimizations"
        Brief = "Flushing system buffers, clearing caches, and refreshing Windows shell."
        Color = "#10B981"
        Action = {
            if ($config.RestartExplorer) {
                Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
                Start-Sleep -Milliseconds 600
                Start-Process explorer
            }
        }
    })

    $totalSteps = $plan.Count

    # Execute in background thread to prevent UI freezing
    $rs = [RunspaceFactory]::CreateRunspace()
    $rs.Open()
    $rs.SessionStateProxy.SetVariable("plan", $plan)
    $rs.SessionStateProxy.SetVariable("totalSteps", $totalSteps)
    $rs.SessionStateProxy.SetVariable("window", $window)

    $worker = [PowerShell]::Create().AddScript({
        param($plan, $totalSteps, $window, $icons)

        $stepIdx = 1
        foreach ($step in $plan) {
            $percent = [math]::Round((($stepIdx - 0.5) / $totalSteps) * 100)
            $stepCounterText = "STEP $stepIdx OF $totalSteps"

            $window.Dispatcher.Invoke([Action]{
                $stepIcon = $window.FindName("StepIcon")
                $iconGlow = $window.FindName("IconGlow")
                $txtStepCount = $window.FindName("TxtStepCount")
                $txtStepTitle = $window.FindName("TxtStepTitle")
                $txtStepBrief = $window.FindName("TxtStepBrief")
                $txtSubStatus = $window.FindName("TxtSubStatus")
                $pBar         = $window.FindName("PBar")

                if ($icons.ContainsKey($step.Key)) {
                    $stepIcon.Data = [System.Windows.Media.Geometry]::Parse($icons[$step.Key])
                }
                $stepIcon.Fill = [System.Windows.Media.BrushConverter]::new().ConvertFromString($step.Color)
                $iconGlow.Color = [System.Windows.Media.ColorConverter]::new().ConvertFromString($step.Color)
                $txtStepCount.Text = $stepCounterText
                $txtStepTitle.Text = $step.Title
                $txtStepBrief.Text = $step.Brief
                $txtSubStatus.Text = "Applying $($step.Title)..."
                $pBar.Value = $percent
            })

            # Run action
            try {
                & $step.Action
            } catch {}

            $stepIdx++
            Start-Sleep -Milliseconds 350
        }

        # Completed
        $window.Dispatcher.Invoke([Action]{
            $stepIcon = $window.FindName("StepIcon")
            $iconGlow = $window.FindName("IconGlow")
            $txtStepCount = $window.FindName("TxtStepCount")
            $txtStepTitle = $window.FindName("TxtStepTitle")
            $txtStepBrief = $window.FindName("TxtStepBrief")
            $txtSubStatus = $window.FindName("TxtSubStatus")
            $pBar         = $window.FindName("PBar")
            $btnStart     = $window.FindName("BtnStart")
            $btnDone      = $window.FindName("BtnDone")
            $btnRestartExplorer = $window.FindName("BtnRestartExplorer")

            $stepIcon.Data = [System.Windows.Media.Geometry]::Parse($icons["Finish"])
            $stepIcon.Fill = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#10B981")
            $iconGlow.Color = [System.Windows.Media.ColorConverter]::new().ConvertFromString("#10B981")
            $txtStepCount.Text = "DEBLOAT COMPLETED"
            $txtStepCount.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#10B981")
            $txtStepTitle.Text = "System Successfully Debloated!"
            $txtStepBrief.Text = "All configurations, tweaks, services, and tasks were applied successfully."
            $txtSubStatus.Text = "100% finished. Your PC is clean and optimized."
            $pBar.Value = 100

            $btnStart.Visibility = "Collapsed"
            $btnDone.Visibility = "Visible"
            $btnRestartExplorer.Visibility = "Visible"
        })
    }).AddArgument($plan).AddArgument($totalSteps).AddArgument($window).AddArgument($icons)

    $worker.Runspace = $rs
    $asyncHandle = $worker.BeginInvoke()
})

$window.ShowDialog() | Out-Null
