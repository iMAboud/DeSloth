# Ultimate Windows Debloat - Creator UI & Configurator
param(
    [string]$BaseDir = (Split-Path -Parent $PSScriptRoot)
)

class AppItemViewModel {
    [bool]$IsChecked = $false
    [string]$AppId = ""
    [string]$FriendlyName = ""
    [string]$AppIdDisplay = ""
    [string]$Description = ""
    [string]$Recommendation = ""
    [bool]$IsInstalled = $false
    [string]$StatusDisplay = ""
    [string]$StatusColor = ""
}

class DebloatItemViewModel {
    [bool]$IsChecked = $false
    [string]$Id = ""
    [string]$TypeDisplay = ""
    [string]$Category = ""
    [string]$Label = ""
    [string]$Name = ""
    [string]$Description = ""
}

class ServiceItemViewModel {
    [string]$Name = ""
    [string]$DisplayName = ""
    [string]$StartMode = ""
    [string]$State = ""
    [string]$Description = ""
    [bool]$IsPreset = $false
    [bool]$IsKeep = $true
    [bool]$IsManual = $false
    [bool]$IsDisabled = $false
}

class TaskItemViewModel {
    [string]$TaskPath = ""
    [string]$TaskName = ""
    [string]$FullPath = ""
    [string]$State = ""
    [string]$Description = ""
    [bool]$IsPreset = $false
    [bool]$IsDisable = $false
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

. (Join-Path $BaseDir "src\Get-DebloatData.ps1")
. (Join-Path $BaseDir "src\Export-StandaloneRunner.ps1")

# Fetch all system & tool data
$data = Get-DebloatData -BaseDir $BaseDir

# Win11Debloat default selected items
$w11dDefaultSettingsPath = Join-Path $BaseDir "Win11Debloat-master\Config\DefaultSettings.json"
$w11dDefaultTweaks = @()
if (Test-Path $w11dDefaultSettingsPath) {
    try {
        $ds = Get-Content $w11dDefaultSettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $w11dDefaultTweaks = @($ds.Settings | Where-Object { $_.Value -eq $true } | ForEach-Object { $_.Name })
    } catch {}
}

# WinUtil presets
$winutilPresetPath = Join-Path $BaseDir "winutil-main\config\preset.json"
$winutilDefaultTweaks = @()
if (Test-Path $winutilPresetPath) {
    try {
        $ps = Get-Content $winutilPresetPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($ps.Standard) { $winutilDefaultTweaks = @($ps.Standard) }
    } catch {}
}

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Ultimate Windows Debloat Studio" Height="800" Width="1180"
        WindowStartupLocation="CenterScreen" WindowStyle="SingleBorderWindow"
        Background="#0B0E14" Foreground="#F8FAFC" FontFamily="Segoe UI">
    <Window.Resources>
        <Style TargetType="TabControl">
            <Setter Property="Background" Value="#0B0E14"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TabControl">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                            </Grid.RowDefinitions>
                            <TabPanel Grid.Row="0" IsItemsHost="True" Background="#0B0E14"/>
                            <Border Grid.Row="1" Background="#0B0E14" BorderThickness="0">
                                <ContentPresenter ContentSource="SelectedContent"/>
                            </Border>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="TabItem">
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Foreground" Value="#94A3B8"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Padding" Value="16,10"/>
            <Setter Property="BorderThickness" Value="0,0,0,2"/>
            <Setter Property="BorderBrush" Value="Transparent"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TabItem">
                        <Border x:Name="border" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" Padding="{TemplateBinding Padding}">
                            <ContentPresenter ContentSource="Header" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Foreground" Value="#FFFFFF"/>
                            </Trigger>
                            <Trigger Property="IsSelected" Value="True">
                                <Setter Property="Foreground" Value="#38BDF8"/>
                                <Setter TargetName="border" Property="BorderBrush" Value="#38BDF8"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="Button" x:Key="ModernBtn">
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="b" CornerRadius="6" Background="{TemplateBinding Background}" BorderThickness="0" Padding="12,6">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="b" Property="Opacity" Value="0.88"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter TargetName="b" Property="Opacity" Value="0.75"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="TextBox" x:Key="SearchBox">
            <Setter Property="Background" Value="#151922"/>
            <Setter Property="Foreground" Value="#F8FAFC"/>
            <Setter Property="BorderBrush" Value="#242C3D"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TextBox">
                        <Border x:Name="border" CornerRadius="6" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}">
                            <Grid>
                                <ScrollViewer x:Name="PART_ContentHost" Margin="{TemplateBinding Padding}"/>
                                <TextBlock Text="{TemplateBinding Tag}" Margin="10,6" Foreground="#64748B" FontSize="12" IsHitTestVisible="False">
                                    <TextBlock.Style>
                                        <Style TargetType="TextBlock">
                                            <Setter Property="Visibility" Value="Collapsed"/>
                                            <Style.Triggers>
                                                <DataTrigger Binding="{Binding Text, RelativeSource={RelativeSource TemplatedParent}}" Value="">
                                                    <Setter Property="Visibility" Value="Visible"/>
                                                </DataTrigger>
                                            </Style.Triggers>
                                        </Style>
                                    </TextBlock.Style>
                                </TextBlock>
                            </Grid>
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Top Header Bar -->
        <Border Grid.Row="0" Background="#11151F" BorderBrush="#1E2536" BorderThickness="0,0,0,1" Padding="20,12">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <StackPanel Grid.Column="0" VerticalAlignment="Center">
                    <StackPanel Orientation="Horizontal" Margin="0,0,0,4">
                        <Path Fill="#38BDF8" Width="18" Height="18" Stretch="Uniform" Margin="0,0,10,0"
                              Data="M13,10V3L4,14H11V21L20,10H13Z"/>
                        <TextBlock Text="ULTIMATE WINDOWS DEBLOAT STUDIO" FontSize="16" FontWeight="Bold" Foreground="#FFFFFF"/>
                    </StackPanel>
                    <TextBlock Text="Configure options safely. Settings auto-save and export into a zero-console standalone runner (.exe)."
                               FontSize="12" Foreground="#94A3B8"/>
                </StackPanel>

                <!-- Top Presets & Global Actions -->
                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                    <Button x:Name="BtnPresetRecommended" Content="Recommended Preset" Style="{StaticResource ModernBtn}" Background="#2563EB" Margin="0,0,8,0"/>
                    <Button x:Name="BtnPresetPrivacy" Content="Privacy Focused" Style="{StaticResource ModernBtn}" Background="#0284C7" Margin="0,0,8,0"/>
                    <Button x:Name="BtnPresetGaming" Content="Gaming Mode" Style="{StaticResource ModernBtn}" Background="#7C3AED" Margin="0,0,8,0"/>
                    <Button x:Name="BtnClearAll" Content="Clear All" Style="{StaticResource ModernBtn}" Background="#334155" Margin="0,0,14,0"/>
                    <CheckBox x:Name="ChkCreateRestorePoint" Content="Create Restore Point" IsChecked="True" Foreground="#CBD5E1" VerticalAlignment="Center" Margin="0,0,14,0"/>
                    <CheckBox x:Name="ChkRestartExplorer" Content="Restart Explorer" IsChecked="True" Foreground="#CBD5E1" VerticalAlignment="Center"/>
                </StackPanel>
            </Grid>
        </Border>

        <!-- Main Tab Content -->
        <TabControl Grid.Row="1" Background="#0B0E14" BorderThickness="0" Margin="14,10,14,10">
            
            <!-- TAB 1: Bloat Apps to Uninstall (Dedicated Group) -->
            <TabItem Header="Apps to Uninstall">
                <Grid Margin="0,10,0,0">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    
                    <!-- App Controls Bar -->
                    <Grid Grid.Row="0" Margin="0,0,0,10">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="Auto"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        
                        <TextBox x:Name="TxtSearchApps" Style="{StaticResource SearchBox}" Text="" Tag="Search apps or package ID..." Width="260" Margin="0,0,12,0"/>
                        <CheckBox x:Name="ChkOnlyInstalledApps" Grid.Column="1" Content="Show Only Installed Apps on this PC" IsChecked="False" Foreground="#38BDF8" FontWeight="SemiBold" VerticalAlignment="Center" Margin="0,0,16,0"/>
                        
                        <TextBlock x:Name="TxtAppsInstalledCount" Grid.Column="2" Text="" Foreground="#10B981" FontSize="12" FontWeight="SemiBold" VerticalAlignment="Center"/>

                        <StackPanel Grid.Column="3" Orientation="Horizontal">
                            <Button x:Name="BtnSelectInstalledApps" Content="Select All Installed" Style="{StaticResource ModernBtn}" Background="#059669" Margin="0,0,8,0"/>
                            <Button x:Name="BtnSelectSafeApps" Content="Select Recommended Safe" Style="{StaticResource ModernBtn}" Background="#1E293B" Margin="0,0,8,0"/>
                            <Button x:Name="BtnDeselectAllApps" Content="Deselect All" Style="{StaticResource ModernBtn}" Background="#1E293B"/>
                        </StackPanel>
                    </Grid>

                    <ListView x:Name="ListApps" Grid.Row="1" Background="#11151F" BorderBrush="#1E2536" BorderThickness="1" Foreground="#F8FAFC">
                        <ListView.View>
                            <GridView>
                                <GridViewColumn Header="Uninstall" Width="70">
                                    <GridViewColumn.CellTemplate>
                                        <DataTemplate>
                                            <CheckBox IsChecked="{Binding IsChecked}" HorizontalAlignment="Center"/>
                                        </DataTemplate>
                                    </GridViewColumn.CellTemplate>
                                </GridViewColumn>
                                <GridViewColumn Header="Status" Width="110">
                                    <GridViewColumn.CellTemplate>
                                        <DataTemplate>
                                            <Border Background="#161F30" CornerRadius="4" Padding="6,2" HorizontalAlignment="Left">
                                                <TextBlock Text="{Binding StatusDisplay}" Foreground="{Binding StatusColor}" FontWeight="Bold" FontSize="11"/>
                                            </Border>
                                        </DataTemplate>
                                    </GridViewColumn.CellTemplate>
                                </GridViewColumn>
                                <GridViewColumn Header="App Name" Width="180" DisplayMemberBinding="{Binding FriendlyName}"/>
                                <GridViewColumn Header="Package ID" Width="240" DisplayMemberBinding="{Binding AppIdDisplay}"/>
                                <GridViewColumn Header="Safety" Width="90" DisplayMemberBinding="{Binding Recommendation}"/>
                                <GridViewColumn Header="Description" Width="430" DisplayMemberBinding="{Binding Description}"/>
                            </GridView>
                        </ListView.View>
                    </ListView>
                </Grid>
            </TabItem>

            <!-- TAB 2: Win11Debloat System Tweaks -->
            <TabItem Header="Win11Debloat Tweaks">
                <Grid Margin="0,10,0,0">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <Grid Grid.Row="0" Margin="0,0,0,10">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBox x:Name="TxtSearchW11D" Style="{StaticResource SearchBox}" Text="" Tag="Filter tweaks by name or category..." Width="320" HorizontalAlignment="Left"/>
                        <StackPanel Grid.Column="1" Orientation="Horizontal">
                            <Button x:Name="BtnSelectAllW11D" Content="Select All Shown" Style="{StaticResource ModernBtn}" Background="#1E293B" Margin="0,0,8,0"/>
                            <Button x:Name="BtnDeselectAllW11D" Content="Deselect All Shown" Style="{StaticResource ModernBtn}" Background="#1E293B"/>
                        </StackPanel>
                    </Grid>
                    <ListView x:Name="ListW11D" Grid.Row="1" Background="#11151F" BorderBrush="#1E2536" BorderThickness="1" Foreground="#F8FAFC">
                        <ListView.View>
                            <GridView>
                                <GridViewColumn Header="Enable" Width="60">
                                    <GridViewColumn.CellTemplate>
                                        <DataTemplate>
                                            <CheckBox IsChecked="{Binding IsChecked}" HorizontalAlignment="Center"/>
                                        </DataTemplate>
                                    </GridViewColumn.CellTemplate>
                                </GridViewColumn>
                                <GridViewColumn Header="Category" Width="160" DisplayMemberBinding="{Binding Category}"/>
                                <GridViewColumn Header="Setting Name" Width="300" DisplayMemberBinding="{Binding Label}"/>
                                <GridViewColumn Header="Description" Width="580" DisplayMemberBinding="{Binding Description}"/>
                            </GridView>
                        </ListView.View>
                    </ListView>
                </Grid>
            </TabItem>

            <!-- TAB 3: Chris Titus WinUtil -->
            <TabItem Header="Chris Titus WinUtil">
                <Grid Margin="0,10,0,0">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <Grid Grid.Row="0" Margin="0,0,0,10">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBox x:Name="TxtSearchWinUtil" Style="{StaticResource SearchBox}" Text="" Tag="Filter CTT tweaks, performance, or features..." Width="320" HorizontalAlignment="Left"/>
                        <StackPanel Grid.Column="1" Orientation="Horizontal">
                            <Button x:Name="BtnSelectAllWinUtil" Content="Select All Shown" Style="{StaticResource ModernBtn}" Background="#1E293B" Margin="0,0,8,0"/>
                            <Button x:Name="BtnDeselectAllWinUtil" Content="Deselect All Shown" Style="{StaticResource ModernBtn}" Background="#1E293B"/>
                        </StackPanel>
                    </Grid>
                    <ListView x:Name="ListWinUtil" Grid.Row="1" Background="#11151F" BorderBrush="#1E2536" BorderThickness="1" Foreground="#F8FAFC">
                        <ListView.View>
                            <GridView>
                                <GridViewColumn Header="Enable" Width="60">
                                    <GridViewColumn.CellTemplate>
                                        <DataTemplate>
                                            <CheckBox IsChecked="{Binding IsChecked}" HorizontalAlignment="Center"/>
                                        </DataTemplate>
                                    </GridViewColumn.CellTemplate>
                                </GridViewColumn>
                                <GridViewColumn Header="Type" Width="90" DisplayMemberBinding="{Binding TypeDisplay}"/>
                                <GridViewColumn Header="Category" Width="150" DisplayMemberBinding="{Binding Category}"/>
                                <GridViewColumn Header="Name" Width="280" DisplayMemberBinding="{Binding Name}"/>
                                <GridViewColumn Header="Description" Width="520" DisplayMemberBinding="{Binding Description}"/>
                            </GridView>
                        </ListView.View>
                    </ListView>
                </Grid>
            </TabItem>

            <!-- TAB 4: Windows Services -->
            <TabItem Header="Windows Services">
                <Grid Margin="0,10,0,0">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <Grid Grid.Row="0" Margin="0,0,0,10">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBox x:Name="TxtSearchServices" Style="{StaticResource SearchBox}" Text="" Tag="Filter services..." Width="320" HorizontalAlignment="Left"/>
                        <StackPanel Grid.Column="1" Orientation="Horizontal">
                            <Button x:Name="BtnDisablePresetServices" Content="Disable Bloat Services" Style="{StaticResource ModernBtn}" Background="#DC2626" Margin="0,0,8,0"/>
                            <Button x:Name="BtnManualPresetServices" Content="Set Bloat to Manual" Style="{StaticResource ModernBtn}" Background="#D97706" Margin="0,0,8,0"/>
                            <Button x:Name="BtnResetServices" Content="Reset All to Keep" Style="{StaticResource ModernBtn}" Background="#1E293B"/>
                        </StackPanel>
                    </Grid>
                    <ListView x:Name="ListServices" Grid.Row="1" Background="#11151F" BorderBrush="#1E2536" BorderThickness="1" Foreground="#F8FAFC">
                        <ListView.View>
                            <GridView>
                                <GridViewColumn Header="Action" Width="190">
                                    <GridViewColumn.CellTemplate>
                                        <DataTemplate>
                                            <StackPanel Orientation="Horizontal">
                                                <RadioButton Content="Keep" GroupName="{Binding Name}" IsChecked="{Binding IsKeep}" Margin="0,0,6,0" Foreground="#94A3B8"/>
                                                <RadioButton Content="Manual" GroupName="{Binding Name}" IsChecked="{Binding IsManual}" Margin="0,0,6,0" Foreground="#F59E0B"/>
                                                <RadioButton Content="Disable" GroupName="{Binding Name}" IsChecked="{Binding IsDisabled}" Foreground="#EF4444"/>
                                            </StackPanel>
                                        </DataTemplate>
                                    </GridViewColumn.CellTemplate>
                                </GridViewColumn>
                                <GridViewColumn Header="Service Name" Width="160" DisplayMemberBinding="{Binding Name}"/>
                                <GridViewColumn Header="Display Name" Width="260" DisplayMemberBinding="{Binding DisplayName}"/>
                                <GridViewColumn Header="Current Startup" Width="100" DisplayMemberBinding="{Binding StartMode}"/>
                                <GridViewColumn Header="State" Width="80" DisplayMemberBinding="{Binding State}"/>
                                <GridViewColumn Header="Description" Width="300" DisplayMemberBinding="{Binding Description}"/>
                            </GridView>
                        </ListView.View>
                    </ListView>
                </Grid>
            </TabItem>

            <!-- TAB 5: Task Scheduler -->
            <TabItem Header="Task Scheduler">
                <Grid Margin="0,10,0,0">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <Grid Grid.Row="0" Margin="0,0,0,10">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBox x:Name="TxtSearchTasks" Style="{StaticResource SearchBox}" Text="" Tag="Filter scheduled tasks..." Width="320" HorizontalAlignment="Left"/>
                        <StackPanel Grid.Column="1" Orientation="Horizontal">
                            <Button x:Name="BtnDisablePresetTasks" Content="Disable Telemetry Tasks" Style="{StaticResource ModernBtn}" Background="#DC2626" Margin="0,0,8,0"/>
                            <Button x:Name="BtnResetTasks" Content="Reset All Tasks" Style="{StaticResource ModernBtn}" Background="#1E293B"/>
                        </StackPanel>
                    </Grid>
                    <ListView x:Name="ListTasks" Grid.Row="1" Background="#11151F" BorderBrush="#1E2536" BorderThickness="1" Foreground="#F8FAFC">
                        <ListView.View>
                            <GridView>
                                <GridViewColumn Header="Disable" Width="70">
                                    <GridViewColumn.CellTemplate>
                                        <DataTemplate>
                                            <CheckBox IsChecked="{Binding IsDisable}" HorizontalAlignment="Center"/>
                                        </DataTemplate>
                                    </GridViewColumn.CellTemplate>
                                </GridViewColumn>
                                <GridViewColumn Header="Task Name" Width="240" DisplayMemberBinding="{Binding TaskName}"/>
                                <GridViewColumn Header="Folder Path" Width="320" DisplayMemberBinding="{Binding TaskPath}"/>
                                <GridViewColumn Header="Current State" Width="100" DisplayMemberBinding="{Binding State}"/>
                                <GridViewColumn Header="Description" Width="350" DisplayMemberBinding="{Binding Description}"/>
                            </GridView>
                        </ListView.View>
                    </ListView>
                </Grid>
            </TabItem>

            <!-- TAB 6: Export Runner & Profile -->
            <TabItem Header="Export Runner">
                <ScrollViewer VerticalScrollBarVisibility="Auto" Margin="10,16,10,0">
                    <StackPanel MaxWidth="850" HorizontalAlignment="Left">
                        <Border Background="#11151F" BorderBrush="#1E2536" BorderThickness="1" CornerRadius="10" Padding="24" Margin="0,0,0,20">
                            <StackPanel>
                                <TextBlock Text="Standalone One-Click Runner Generator" FontSize="18" FontWeight="Bold" Foreground="#FFFFFF" Margin="0,0,0,6"/>
                                <TextBlock Text="Generates an autonomous, standalone executable (.exe) written in C# .NET 4.5 WPF (compiled via csc.exe) with zero external dependencies. The generated runner shows a minimal modern window with a single START button that automates everything silently with zero console windows."
                                           Foreground="#94A3B8" FontSize="12.5" TextWrapping="Wrap" Margin="0,0,0,16"/>

                                <!-- Auto-save status indicator -->
                                <Border Background="#152132" BorderBrush="#1E3A5F" BorderThickness="1" CornerRadius="6" Padding="12,8" Margin="0,0,0,18">
                                    <TextBlock x:Name="TxtAutoSaveNotice" Text="Auto-Save Active: Selections are remembered in config\debloat-profile.json and restored automatically."
                                               Foreground="#38BDF8" FontSize="12" FontWeight="SemiBold"/>
                                </Border>

                                <!-- Selection Summary Cards -->
                                <UniformGrid Columns="5" Margin="0,0,0,20">
                                    <Border Background="#151C2C" CornerRadius="8" Padding="12" Margin="3">
                                        <StackPanel>
                                            <TextBlock Text="Apps to Remove" Foreground="#10B981" FontSize="11" FontWeight="Bold"/>
                                            <TextBlock x:Name="TxtSummaryApps" Text="0 Apps" Foreground="#FFFFFF" FontSize="17" FontWeight="Bold" Margin="0,4,0,0"/>
                                        </StackPanel>
                                    </Border>
                                    <Border Background="#151C2C" CornerRadius="8" Padding="12" Margin="3">
                                        <StackPanel>
                                            <TextBlock Text="W11D Tweaks" Foreground="#38BDF8" FontSize="11" FontWeight="Bold"/>
                                            <TextBlock x:Name="TxtSummaryW11D" Text="0 Tweaks" Foreground="#FFFFFF" FontSize="17" FontWeight="Bold" Margin="0,4,0,0"/>
                                        </StackPanel>
                                    </Border>
                                    <Border Background="#151C2C" CornerRadius="8" Padding="12" Margin="3">
                                        <StackPanel>
                                            <TextBlock Text="CTT WinUtil" Foreground="#F59E0B" FontSize="11" FontWeight="Bold"/>
                                            <TextBlock x:Name="TxtSummaryWinUtil" Text="0 Tweaks" Foreground="#FFFFFF" FontSize="17" FontWeight="Bold" Margin="0,4,0,0"/>
                                        </StackPanel>
                                    </Border>
                                    <Border Background="#151C2C" CornerRadius="8" Padding="12" Margin="3">
                                        <StackPanel>
                                            <TextBlock Text="Services" Foreground="#EC4899" FontSize="11" FontWeight="Bold"/>
                                            <TextBlock x:Name="TxtSummaryServices" Text="0 Services" Foreground="#FFFFFF" FontSize="17" FontWeight="Bold" Margin="0,4,0,0"/>
                                        </StackPanel>
                                    </Border>
                                    <Border Background="#151C2C" CornerRadius="8" Padding="12" Margin="3">
                                        <StackPanel>
                                            <TextBlock Text="Tasks" Foreground="#8B5CF6" FontSize="11" FontWeight="Bold"/>
                                            <TextBlock x:Name="TxtSummaryTasks" Text="0 Tasks" Foreground="#FFFFFF" FontSize="17" FontWeight="Bold" Margin="0,4,0,0"/>
                                        </StackPanel>
                                    </Border>
                                </UniformGrid>

                                <!-- Output Directory -->
                                <TextBlock Text="Output Executable Destination:" Foreground="#CBD5E1" FontSize="12" FontWeight="SemiBold" Margin="0,0,0,6"/>
                                <Grid Margin="0,0,0,20">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="Auto"/>
                                    </Grid.ColumnDefinitions>
                                    <TextBox x:Name="TxtOutputDir" Style="{StaticResource SearchBox}" Text="" IsReadOnly="True"/>
                                    <Button x:Name="BtnBrowseOutput" Grid.Column="1" Content="Browse..." Style="{StaticResource ModernBtn}" Background="#334155" Margin="8,0,0,0"/>
                                </Grid>

                                <!-- Action Buttons -->
                                <StackPanel Orientation="Horizontal" Margin="0,0,0,12">
                                    <Button x:Name="BtnExportRunner" Content="Compile &amp; Export Standalone Runner (.exe)" Style="{StaticResource ModernBtn}" Background="#2563EB" FontSize="13" Padding="20,12" Margin="0,0,12,0"/>
                                    <Button x:Name="BtnSaveConfigProfile" Content="Save Profile As..." Style="{StaticResource ModernBtn}" Background="#1E293B" FontSize="12" Padding="14,12" Margin="0,0,12,0"/>
                                    <Button x:Name="BtnLoadConfigProfile" Content="Load Profile..." Style="{StaticResource ModernBtn}" Background="#1E293B" FontSize="12" Padding="14,12"/>
                                </StackPanel>

                                <TextBlock x:Name="TxtExportStatus" Text="" Foreground="#10B981" FontSize="13" FontWeight="SemiBold" Margin="0,8,0,0"/>
                            </StackPanel>
                        </Border>
                    </StackPanel>
                </ScrollViewer>
            </TabItem>
        </TabControl>

        <!-- Bottom Footer Status -->
        <Border Grid.Row="2" Background="#11151F" BorderBrush="#1E2536" BorderThickness="0,1,0,0" Padding="20,8">
            <Grid>
                <TextBlock x:Name="TxtFooterStatus" Text="Ready." Foreground="#94A3B8" FontSize="12" VerticalAlignment="Center"/>
                <TextBlock Text="Zero console window runner | Pure C# WPF (.NET 4.5) | Verbatim CTT &amp; Win11Debloat engines" Foreground="#64748B" FontSize="11" HorizontalAlignment="Right" VerticalAlignment="Center"/>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# Get Controls
$btnPresetRecommended   = $window.FindName("BtnPresetRecommended")
$btnPresetPrivacy       = $window.FindName("BtnPresetPrivacy")
$btnPresetGaming        = $window.FindName("BtnPresetGaming")
$btnClearAll            = $window.FindName("BtnClearAll")
$chkCreateRestorePoint  = $window.FindName("ChkCreateRestorePoint")
$chkRestartExplorer     = $window.FindName("ChkRestartExplorer")

$txtSearchApps          = $window.FindName("TxtSearchApps")
$chkOnlyInstalledApps   = $window.FindName("ChkOnlyInstalledApps")
$txtAppsInstalledCount  = $window.FindName("TxtAppsInstalledCount")
$btnSelectInstalledApps = $window.FindName("BtnSelectInstalledApps")
$btnSelectSafeApps      = $window.FindName("BtnSelectSafeApps")
$btnDeselectAllApps     = $window.FindName("BtnDeselectAllApps")
$listApps               = $window.FindName("ListApps")

$txtSearchW11D          = $window.FindName("TxtSearchW11D")
$btnSelectAllW11D       = $window.FindName("BtnSelectAllW11D")
$btnDeselectAllW11D     = $window.FindName("BtnDeselectAllW11D")
$listW11D               = $window.FindName("ListW11D")

$txtSearchWinUtil       = $window.FindName("TxtSearchWinUtil")
$btnSelectAllWinUtil    = $window.FindName("BtnSelectAllWinUtil")
$btnDeselectAllWinUtil  = $window.FindName("BtnDeselectAllWinUtil")
$listWinUtil            = $window.FindName("ListWinUtil")

$txtSearchServices      = $window.FindName("TxtSearchServices")
$btnDisablePresetServices = $window.FindName("BtnDisablePresetServices")
$btnManualPresetServices  = $window.FindName("BtnManualPresetServices")
$btnResetServices       = $window.FindName("BtnResetServices")
$listServices           = $window.FindName("ListServices")

$txtSearchTasks         = $window.FindName("TxtSearchTasks")
$btnDisablePresetTasks  = $window.FindName("BtnDisablePresetTasks")
$btnResetTasks          = $window.FindName("BtnResetTasks")
$listTasks              = $window.FindName("ListTasks")

$txtSummaryApps         = $window.FindName("TxtSummaryApps")
$txtSummaryW11D         = $window.FindName("TxtSummaryW11D")
$txtSummaryWinUtil      = $window.FindName("TxtSummaryWinUtil")
$txtSummaryServices     = $window.FindName("TxtSummaryServices")
$txtSummaryTasks        = $window.FindName("TxtSummaryTasks")
$txtOutputDir           = $window.FindName("TxtOutputDir")
$txtOutputDir.Text = (Join-Path $BaseDir "dist")
$btnBrowseOutput        = $window.FindName("BtnBrowseOutput")
$btnExportRunner        = $window.FindName("BtnExportRunner")
$btnSaveConfigProfile   = $window.FindName("BtnSaveConfigProfile")
$btnLoadConfigProfile   = $window.FindName("BtnLoadConfigProfile")
$txtExportStatus        = $window.FindName("TxtExportStatus")
$txtFooterStatus        = $window.FindName("TxtFooterStatus")
$txtAutoSaveNotice      = $window.FindName("TxtAutoSaveNotice")

# Populate Apps Collection
$allAppItems = [System.Collections.ObjectModel.ObservableCollection[AppItemViewModel]]::new()
$installedCount = 0
foreach ($a in $data.Win11DebloatApps) {
    $item = [AppItemViewModel]::new()
    $item.AppId = $a.AppId
    $item.FriendlyName = $a.FriendlyName
    $item.AppIdDisplay = $a.AppIdDisplay
    $item.Description = $a.Description
    $item.Recommendation = $a.Recommendation
    $item.IsInstalled = [bool]$a.IsInstalled
    $item.StatusDisplay = $a.StatusDisplay
    $item.StatusColor = $a.StatusColor
    $item.IsChecked = $false
    if ($item.IsInstalled) { $installedCount++ }
    $allAppItems.Add($item)
}
$listApps.ItemsSource = $allAppItems
$chkOnlyInstalledApps.Content = "Show Only Installed Apps on this PC ($installedCount detected)"
$txtAppsInstalledCount.Text = "$installedCount bloat apps detected on this system"

# Populate Win11Debloat Tweaks Collection
$allW11dItems = [System.Collections.ObjectModel.ObservableCollection[DebloatItemViewModel]]::new()
foreach ($f in $data.Win11DebloatFeatures) {
    $item = [DebloatItemViewModel]::new()
    $item.Id = $f.FeatureId
    $item.TypeDisplay = "Tweak"
    $item.Category = if ($f.Category) { $f.Category } else { "Tweaks" }
    $item.Label = $f.Label
    $item.Name = $f.Label
    $item.Description = if ($f.ToolTip) { $f.ToolTip } elseif ($f.ApplyText) { $f.ApplyText } else { $f.Label }
    $item.IsChecked = $w11dDefaultTweaks -contains $f.FeatureId
    $allW11dItems.Add($item)
}
$listW11D.ItemsSource = $allW11dItems

# Populate WinUtil Collection
$allWinUtilItems = [System.Collections.ObjectModel.ObservableCollection[DebloatItemViewModel]]::new()
foreach ($t in $data.WinUtilTweaks) {
    $item = [DebloatItemViewModel]::new()
    $item.Id = $t.Id
    $item.TypeDisplay = "Tweak"
    $item.Category = $t.Category
    $item.Label = $t.Name
    $item.Name = $t.Name
    $item.Description = $t.Description
    $item.IsChecked = $winutilDefaultTweaks -contains $t.Id
    $allWinUtilItems.Add($item)
}
foreach ($f in $data.WinUtilFeatures) {
    $item = [DebloatItemViewModel]::new()
    $item.Id = $f.Id
    $item.TypeDisplay = "Feature"
    $item.Category = $f.Category
    $item.Label = $f.Name
    $item.Name = $f.Name
    $item.Description = $f.Description
    $item.IsChecked = $false
    $allWinUtilItems.Add($item)
}
$listWinUtil.ItemsSource = $allWinUtilItems

# Populate Services Collection
$allServices = [System.Collections.ObjectModel.ObservableCollection[ServiceItemViewModel]]::new()
foreach ($s in $data.Services) {
    $item = [ServiceItemViewModel]::new()
    $item.Name = $s.Name
    $item.DisplayName = $s.DisplayName
    $item.StartMode = $s.StartMode
    $item.State = $s.State
    $item.Description = $s.Description
    $item.IsPreset = $s.IsPreset
    $item.IsKeep = $true
    $allServices.Add($item)
}
$listServices.ItemsSource = $allServices

# Populate Tasks Collection
$allTasks = [System.Collections.ObjectModel.ObservableCollection[TaskItemViewModel]]::new()
foreach ($t in $data.Tasks) {
    $item = [TaskItemViewModel]::new()
    $item.TaskName = $t.TaskName
    $item.TaskPath = $t.TaskPath
    $item.FullPath = $t.FullPath
    $item.State = $t.State
    $item.Description = $t.Description
    $item.IsPreset = $t.IsPreset
    $item.IsDisable = $false
    $allTasks.Add($item)
}
$listTasks.ItemsSource = $allTasks

# Filtering Logic for Apps
function Apply-AppsFilter {
    $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($allAppItems)
    $onlyInstalled = [bool]$chkOnlyInstalledApps.IsChecked
    $q = if ($txtSearchApps.Text) { $txtSearchApps.Text.Trim().ToLower() } else { "" }

    if (-not $onlyInstalled -and [string]::IsNullOrWhiteSpace($q)) {
        $view.Filter = $null
    } else {
        $view.Filter = [Predicate[Object]]{
            param($obj)
            $app = [AppItemViewModel]$obj
            if ($onlyInstalled -and -not $app.IsInstalled) {
                return $false
            }
            if (-not [string]::IsNullOrWhiteSpace($q)) {
                return ($app.FriendlyName -and $app.FriendlyName.ToLower().Contains($q)) -or
                       ($app.AppId -and $app.AppId.ToLower().Contains($q)) -or
                       ($app.Description -and $app.Description.ToLower().Contains($q)) -or
                       ($app.Recommendation -and $app.Recommendation.ToLower().Contains($q))
            }
            return $true
        }
    }
}

$txtSearchApps.Add_TextChanged({ Apply-AppsFilter })
$chkOnlyInstalledApps.Add_Click({ Apply-AppsFilter })

# Generic Filtering for other tabs
function Apply-GenericFilter($collection, $query, [string]$kind) {
    $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($collection)
    if ([string]::IsNullOrWhiteSpace($query)) {
        $view.Filter = $null
    } else {
        $q = $query.Trim().ToLower()
        $view.Filter = [Predicate[Object]]{
            param($obj)
            if ($kind -eq "Debloat") {
                $d = [DebloatItemViewModel]$obj
                return ($d.Label -and $d.Label.ToLower().Contains($q)) -or
                       ($d.Category -and $d.Category.ToLower().Contains($q)) -or
                       ($d.Description -and $d.Description.ToLower().Contains($q))
            } elseif ($kind -eq "Service") {
                $s = [ServiceItemViewModel]$obj
                return ($s.Name -and $s.Name.ToLower().Contains($q)) -or
                       ($s.DisplayName -and $s.DisplayName.ToLower().Contains($q)) -or
                       ($s.Description -and $s.Description.ToLower().Contains($q))
            } elseif ($kind -eq "Task") {
                $t = [TaskItemViewModel]$obj
                return ($t.TaskName -and $t.TaskName.ToLower().Contains($q)) -or
                       ($t.TaskPath -and $t.TaskPath.ToLower().Contains($q))
            }
            return $true
        }
    }
}

$txtSearchW11D.Add_TextChanged({ Apply-GenericFilter $allW11dItems $txtSearchW11D.Text "Debloat" })
$txtSearchWinUtil.Add_TextChanged({ Apply-GenericFilter $allWinUtilItems $txtSearchWinUtil.Text "Debloat" })
$txtSearchServices.Add_TextChanged({ Apply-GenericFilter $allServices $txtSearchServices.Text "Service" })
$txtSearchTasks.Add_TextChanged({ Apply-GenericFilter $allTasks $txtSearchTasks.Text "Task" })

# Unified Config Builder
function Build-UnifiedConfig {
    $selectedApps = @($allAppItems | Where-Object { $_.IsChecked } | ForEach-Object { $_.AppId })
    $selectedW11dFeatures = @($allW11dItems | Where-Object { $_.IsChecked } | ForEach-Object { @{ Name = $_.Id; Value = $true } })
    $selectedWinUtil = @($allWinUtilItems | Where-Object { $_.IsChecked } | ForEach-Object { $_.Id })
    $selectedServices = @($allServices | Where-Object { $_.IsManual -or $_.IsDisabled } | ForEach-Object {
        @{
            Name        = $_.Name
            DisplayName = $_.DisplayName
            TargetMode  = if ($_.IsDisabled) { "Disabled" } else { "Manual" }
        }
    })
    $selectedTasks = @($allTasks | Where-Object { $_.IsDisable } | ForEach-Object {
        @{
            TaskPath = $_.TaskPath
            TaskName = $_.TaskName
            FullPath = $_.FullPath
        }
    })

    return [PSCustomObject]@{
        CreateRestorePoint = [bool]$chkCreateRestorePoint.IsChecked
        RestartExplorer    = [bool]$chkRestartExplorer.IsChecked
        Win11Debloat       = [PSCustomObject]@{
            Apps   = $selectedApps
            Tweaks = $selectedW11dFeatures
        }
        WinUtil            = $selectedWinUtil
        Services           = $selectedServices
        Tasks              = $selectedTasks
    }
}

# Auto-Persistence Settings
$configDir = Join-Path $BaseDir "config"
if (-not (Test-Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}
$autoProfilePath = Join-Path $configDir "debloat-profile.json"

function Save-AutoProfile {
    try {
        $cfg = Build-UnifiedConfig
        $cfg | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $autoProfilePath -Encoding UTF8
    } catch {}
}

function Load-ProfileFromFile([string]$filePath) {
    if (-not (Test-Path $filePath)) { return $false }
    try {
        $cfg = Get-Content -LiteralPath $filePath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($cfg.CreateRestorePoint -ne $null) { $chkCreateRestorePoint.IsChecked = [bool]$cfg.CreateRestorePoint }
        if ($cfg.RestartExplorer -ne $null) { $chkRestartExplorer.IsChecked = [bool]$cfg.RestartExplorer }

        $savedApps = @($cfg.Win11Debloat.Apps)
        foreach ($a in $allAppItems) {
            $a.IsChecked = ($savedApps -contains $a.AppId)
        }

        $savedW11dTweaks = @($cfg.Win11Debloat.Tweaks | Where-Object { $_.Value -eq $true -or ($null -eq $_.Value -and $_ -is [string]) } | ForEach-Object { if ($_.Name) { $_.Name } else { "$_" } })
        foreach ($w in $allW11dItems) {
            $w.IsChecked = ($savedW11dTweaks -contains $w.Id)
        }

        $savedWinUtil = @($cfg.WinUtil)
        foreach ($u in $allWinUtilItems) {
            $u.IsChecked = ($savedWinUtil -contains $u.Id)
        }

        $svcDisabled = @($cfg.Services | Where-Object { $_.TargetMode -eq "Disabled" } | ForEach-Object { $_.Name })
        $svcManual   = @($cfg.Services | Where-Object { $_.TargetMode -eq "Manual" } | ForEach-Object { $_.Name })
        foreach ($s in $allServices) {
            if ($svcDisabled -contains $s.Name) {
                $s.IsDisabled = $true
            } elseif ($svcManual -contains $s.Name) {
                $s.IsManual = $true
            } else {
                $s.IsKeep = $true
            }
        }

        $taskDisabledPaths = @($cfg.Tasks | ForEach-Object { $_.FullPath })
        foreach ($t in $allTasks) {
            $t.IsDisable = ($taskDisabledPaths -contains $t.FullPath)
        }

        return $true
    } catch {
        return $false
    }
}

# Summary update function
function Update-Summary {
    $appsCount = ($allAppItems | Where-Object { $_.IsChecked }).Count
    $w11dCount = ($allW11dItems | Where-Object { $_.IsChecked }).Count
    $winutilCount = ($allWinUtilItems | Where-Object { $_.IsChecked }).Count
    $svcCount = ($allServices | Where-Object { $_.IsManual -or $_.IsDisabled }).Count
    $taskCount = ($allTasks | Where-Object { $_.IsDisable }).Count

    $txtSummaryApps.Text = "$appsCount Apps"
    $txtSummaryW11D.Text = "$w11dCount Tweaks"
    $txtSummaryWinUtil.Text = "$winutilCount Tweaks"
    $txtSummaryServices.Text = "$svcCount Services"
    $txtSummaryTasks.Text = "$taskCount Tasks"

    $txtFooterStatus.Text = "Selected: $appsCount Apps to Uninstall | $w11dCount W11D Tweaks | $winutilCount CTT Tweaks | $svcCount Services Modified | $taskCount Tasks Disabled"
    Save-AutoProfile
}

# Apps Tab Action Buttons
$btnSelectInstalledApps.Add_Click({
    foreach ($a in $allAppItems) {
        if ($a.IsInstalled) { $a.IsChecked = $true }
    }
    Update-Summary
})
$btnSelectSafeApps.Add_Click({
    foreach ($a in $allAppItems) {
        if ($a.Recommendation -eq 'safe') { $a.IsChecked = $true }
    }
    Update-Summary
})
$btnDeselectAllApps.Add_Click({
    foreach ($a in $allAppItems) { $a.IsChecked = $false }
    Update-Summary
})

# Win11Debloat Tweaks Actions
$btnSelectAllW11D.Add_Click({
    $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($allW11dItems)
    foreach ($item in $view) { $item.IsChecked = $true }
    Update-Summary
})
$btnDeselectAllW11D.Add_Click({
    $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($allW11dItems)
    foreach ($item in $view) { $item.IsChecked = $false }
    Update-Summary
})

# WinUtil Actions
$btnSelectAllWinUtil.Add_Click({
    $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($allWinUtilItems)
    foreach ($item in $view) { $item.IsChecked = $true }
    Update-Summary
})
$btnDeselectAllWinUtil.Add_Click({
    $view = [System.Windows.Data.CollectionViewSource]::GetDefaultView($allWinUtilItems)
    foreach ($item in $view) { $item.IsChecked = $false }
    Update-Summary
})

# Services Actions
$btnDisablePresetServices.Add_Click({
    foreach ($s in $allServices) {
        if ($s.IsPreset) { $s.IsDisabled = $true }
    }
    Update-Summary
})
$btnManualPresetServices.Add_Click({
    foreach ($s in $allServices) {
        if ($s.IsPreset) { $s.IsManual = $true }
    }
    Update-Summary
})
$btnResetServices.Add_Click({
    foreach ($s in $allServices) { $s.IsKeep = $true }
    Update-Summary
})

# Tasks Actions
$btnDisablePresetTasks.Add_Click({
    foreach ($t in $allTasks) {
        if ($t.IsPreset) { $t.IsDisable = $true }
    }
    Update-Summary
})
$btnResetTasks.Add_Click({
    foreach ($t in $allTasks) { $t.IsDisable = $false }
    Update-Summary
})

# Global Presets
$btnPresetRecommended.Add_Click({
    foreach ($a in $allAppItems) { $a.IsChecked = $a.IsInstalled }
    foreach ($w in $allW11dItems) { $w.IsChecked = ($w11dDefaultTweaks -contains $w.Id) }
    foreach ($u in $allWinUtilItems) { $u.IsChecked = ($winutilDefaultTweaks -contains $u.Id) }
    foreach ($s in $allServices) { if ($s.IsPreset) { $s.IsDisabled = $true } else { $s.IsKeep = $true } }
    foreach ($t in $allTasks) { $t.IsDisable = $t.IsPreset }
    Update-Summary
})

$btnPresetPrivacy.Add_Click({
    foreach ($a in $allAppItems) {
        $a.IsChecked = ($a.IsInstalled -and ($a.FriendlyName -match 'Cortana|News|Weather|Bing|Teams|Feedback|People'))
    }
    foreach ($w in $allW11dItems) {
        $w.IsChecked = ($w.Id -match 'Telemetry|Privacy|Suggestions|Bing|EdgeAds|Recall|Copilot|Advertising|Activity')
    }
    foreach ($u in $allWinUtilItems) {
        $u.IsChecked = ($u.Category -match 'Privacy|Essential' -or $u.Name -match 'Telemetry|Diagnostic|Activity')
    }
    foreach ($s in $allServices) {
        if ($s.Name -in @('DiagTrack', 'dmwappushservice', 'wisvc', 'WerSvc', 'MapsBroker')) { $s.IsDisabled = $true }
    }
    foreach ($t in $allTasks) {
        $t.IsDisable = ($t.FullPath -match 'Customer Experience|Application Experience|Feedback|Siuf')
    }
    Update-Summary
})

$btnPresetGaming.Add_Click({
    foreach ($a in $allAppItems) {
        $a.IsChecked = ($a.IsInstalled -and ($a.FriendlyName -match 'Cortana|News|Weather|Bing|Feedback|People'))
    }
    foreach ($w in $allW11dItems) {
        $w.IsChecked = ($w.Id -match 'DisableDVR|DisableGameBarIntegration|DisableTransparency|DisableAnimations|DisableModernStandbyNetworking|DisableTelemetry')
    }
    foreach ($u in $allWinUtilItems) {
        $u.IsChecked = ($u.Id -in @('WPFTweaksGameDVR', 'WPFTweaksHiber', 'WPFTweaksUltimatePerformance', 'WPFTweaksVisualFX'))
    }
    foreach ($s in $allServices) {
        if ($s.Name -in @('DiagTrack', 'SysMain', 'RetailDemo', 'SharedRealitySvc', 'MixedRealityOpenXRSvc')) { $s.IsDisabled = $true }
    }
    foreach ($t in $allTasks) {
        $t.IsDisable = ($t.FullPath -match 'Customer Experience|DiskDiagnostic')
    }
    Update-Summary
})

$btnClearAll.Add_Click({
    foreach ($a in $allAppItems) { $a.IsChecked = $false }
    foreach ($w in $allW11dItems) { $w.IsChecked = $false }
    foreach ($u in $allWinUtilItems) { $u.IsChecked = $false }
    foreach ($s in $allServices) { $s.IsKeep = $true }
    foreach ($t in $allTasks) { $t.IsDisable = $false }
    Update-Summary
})

# Output Folder Browse
$btnBrowseOutput.Add_Click({
    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
    $fbd.SelectedPath = $txtOutputDir.Text
    if ($fbd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtOutputDir.Text = $fbd.SelectedPath
    }
})

# Export Standalone Runner Button
$btnExportRunner.Add_Click({
    $btnExportRunner.IsEnabled = $false
    $txtExportStatus.Text = "Compiling standalone C# .NET 4.5 WPF runner via csc.exe..."
    $txtExportStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#38BDF8")

    $configObj = Build-UnifiedConfig
    $outDir = $txtOutputDir.Text

    try {
        Save-AutoProfile
        $result = Export-StandaloneRunner -UnifiedConfig $configObj -OutputDir $outDir -BaseDir $BaseDir
        if ($result.CompileSuccess) {
            $txtExportStatus.Text = "Success! Standalone Runner created: $($result.ExePath)"
            $txtExportStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#10B981")
            [System.Windows.MessageBox]::Show(
                "Export complete!`n`nStandalone Executable:`n$($result.ExePath)`n`nStandalone Script Backup:`n$($result.CmdPath)`n`nThis standalone runner requires NO dependencies and displays only a single START button with zero console windows!",
                "Standalone Runner Exported", "OK", "Information"
            )
        } else {
            $txtExportStatus.Text = "Runner script created: $($result.CmdPath)"
            $txtExportStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#F59E0B")
            [System.Windows.MessageBox]::Show("Standalone runner script generated: $($result.CmdPath)", "Export Notice", "OK", "Information")
        }
    } catch {
        $txtExportStatus.Text = "Export error: $($_.Exception.Message)"
        $txtExportStatus.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#EF4444")
    } finally {
        $btnExportRunner.IsEnabled = $true
    }
})

# Save / Load Profile JSON
$btnSaveConfigProfile.Add_Click({
    $sfd = New-Object System.Windows.Forms.SaveFileDialog
    $sfd.Filter = "JSON Profile (*.json)|*.json"
    $sfd.FileName = "DebloatProfile.json"
    if ($sfd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $cfg = Build-UnifiedConfig
        $cfg | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $sfd.FileName -Encoding UTF8
        [System.Windows.MessageBox]::Show("Profile saved to: $($sfd.FileName)", "Profile Saved", "OK", "Information")
    }
})

$btnLoadConfigProfile.Add_Click({
    $ofd = New-Object System.Windows.Forms.OpenFileDialog
    $ofd.Filter = "JSON Profile (*.json)|*.json"
    if ($ofd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        if (Load-ProfileFromFile $ofd.FileName) {
            Update-Summary
            [System.Windows.MessageBox]::Show("Profile loaded successfully from: $($ofd.FileName)", "Profile Loaded", "OK", "Information")
        } else {
            [System.Windows.MessageBox]::Show("Failed to load profile.", "Error", "OK", "Error")
        }
    }
})

# Auto-Load existing profile if present, else initialize defaults
if (Test-Path $autoProfilePath) {
    if (Load-ProfileFromFile $autoProfilePath) {
        $txtAutoSaveNotice.Text = "Auto-Loaded previously saved profile from config\debloat-profile.json"
    }
}
Update-Summary

# Show Window
$window.ShowDialog() | Out-Null


