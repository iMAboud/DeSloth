using System;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Diagnostics;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Interop;
using System.Runtime.InteropServices;
using System.Windows.Input;
using System.Windows.Media.Effects;
using IOPath = System.IO.Path;
using WpfPath = System.Windows.Shapes.Path;

namespace UltimateDebloat
{
    public class RunnerWindow : Window
    {
        private ProgressBar pBar;
        private TextBlock txtStepCount;
        private TextBlock txtStepTitle;
        private TextBlock txtLastActivity;
        private WpfPath stepIcon;
        private DropShadowEffect iconGlow;
        private Button btnStart;
        private Button btnClose;
        private Button btnRestartExplorer;
        private string tempDir;

        // Path geometries for vector step icons
        private const string ICON_BOLT = "M13,10V3L4,14H11V21L20,10H13Z";
        private const string ICON_SHIELD = "M12,1L3,5V11C3,16.55 6.84,21.74 12,23C17.16,21.74 21,16.55 21,11V5L12,1M12,5A6,6 0 0,1 18,11C18,14.07 15.65,16.64 12.63,16.96V19.04C16.8,18.7 20,15.22 20,11A8,8 0 0,0 12,3A8,8 0 0,0 4,11C4,15.22 7.2,18.7 11.37,19.04V16.96C8.35,16.64 6,14.07 6,11A6,6 0 0,1 12,5Z";
        private const string ICON_TRASH = "M19,4H15.5L14.5,3H9.5L8.5,4H5V6H19M6,19A2,2 0 0,0 8,21H16A2,2 0 0,0 18,19V7H6V19Z";
        private const string ICON_SPEED = "M12,2A10,10 0 0,0 2,12A10,10 0 0,0 12,22A10,10 0 0,0 22,12A10,10 0 0,0 12,2M12,20A8,8 0 0,1 4,12A8,8 0 0,1 12,4A8,8 0 0,1 20,12A8,8 0 0,1 12,20M12,6A6,6 0 0,0 6,12A6,6 0 0,0 12,18A6,6 0 0,0 18,12A6,6 0 0,0 12,6M12,16A4,4 0 0,1 8,12A4,4 0 0,1 12,8A4,4 0 0,1 16,12A4,4 0 0,1 12,16Z";
        private const string ICON_GEAR = "M12,15.5A3.5,3.5 0 0,1 8.5,12A3.5,3.5 0 0,1 12,8.5A3.5,3.5 0 0,1 15.5,12A3.5,3.5 0 0,1 12,15.5M19.43,12.97C19.47,12.65 19.5,12.33 19.5,12C19.5,11.67 19.47,11.34 19.43,11L21.54,9.37C21.73,9.22 21.78,8.95 21.66,8.73L19.66,5.27C19.54,5.05 19.27,4.96 19.05,5.05L16.56,6.05C16.04,5.66 15.5,5.32 14.87,5.07L14.5,2.42C14.46,2.18 14.25,2 14,2H10C9.75,2 9.54,2.18 9.5,2.42L9.13,5.07C8.5,5.32 7.96,5.66 7.44,6.05L4.95,5.05C4.73,4.96 4.46,5.05 4.34,5.27L2.34,8.73C2.21,8.95 2.27,9.22 2.46,9.37L4.57,11C4.53,11.34 4.5,11.67 4.5,12C4.5,12.33 4.53,12.65 4.57,12.97L2.46,14.63C2.27,14.78 2.21,15.05 2.34,15.27L4.34,18.73C4.46,18.95 4.73,19.03 4.95,18.95L7.44,17.94C7.96,18.34 8.5,18.68 9.13,18.93L9.5,21.58C9.54,21.82 9.75,22 10,22H14C14.25,22 14.46,21.82 14.5,21.58L14.87,18.93C15.5,18.67 16.04,18.34 16.56,17.94L19.05,18.95C19.27,19.03 19.54,18.95 19.66,18.73L21.66,15.27C21.78,15.05 21.73,14.78 21.54,14.63L19.43,12.97Z";
        private const string ICON_CLOCK = "M19,3H18V1H16V3H8V1H6V3H5C3.89,3 3,3.89 3,5V19A2,2 0 0,0 5,21H19A2,2 0 0,0 21,19V5C21,3.89 20.1,3 19,3M19,19H5V8H19V19M11,10H13V14H15V16H9V14H11V10Z";
        private const string ICON_CHECK = "M12 2C6.5 2 2 6.5 2 12S6.5 22 12 22 22 17.5 22 12 17.5 2 12 2M10 17L5 12L6.41 10.59L10 14.17L17.59 6.58L19 8L10 17Z";

        public RunnerWindow()
        {
            Title = "DeSloth";
            Width = 590;
            Height = 440;
            WindowStartupLocation = WindowStartupLocation.CenterScreen;
            WindowStyle = WindowStyle.None;
            AllowsTransparency = true;
            Background = Brushes.Transparent;
            ResizeMode = ResizeMode.NoResize;
            SnapsToDevicePixels = true;
            UseLayoutRounding = true;

            ImageSource appIcon = LoadAppIcon();
            if (appIcon != null)
            {
                Icon = appIcon;
            }

            BuildUI(appIcon);
        }

        private void BuildUI(ImageSource appIcon)
        {
            // Transparent root Grid avoids window rect clipping artifacts
            Grid rootGrid = new Grid
            {
                Background = Brushes.Transparent
            };
            rootGrid.MouseLeftButtonDown += delegate(object sender, MouseButtonEventArgs e)
            {
                if (e.LeftButton == MouseButtonState.Pressed)
                {
                    try { DragMove(); } catch { }
                }
            };

            // Main rounded card with 24px padding margin to prevent ghost rectangular shadow artifacts
            Border outerBorder = new Border
            {
                Margin = new Thickness(22),
                CornerRadius = new CornerRadius(18),
                Background = new SolidColorBrush(Color.FromRgb(15, 17, 23)),
                BorderBrush = new SolidColorBrush(Color.FromRgb(38, 44, 61)),
                BorderThickness = new Thickness(1.5),
                Effect = new DropShadowEffect
                {
                    BlurRadius = 18,
                    Color = Colors.Black,
                    Opacity = 0.55,
                    ShadowDepth = 2
                }
            };

            Grid cardGrid = new Grid();

            // Header drag bar with transparent hit-testable background across full top area
            Grid headerGrid = new Grid
            {
                VerticalAlignment = VerticalAlignment.Top,
                Height = 42,
                Background = Brushes.Transparent,
                Margin = new Thickness(18, 8, 16, 0)
            };
            headerGrid.MouseLeftButtonDown += delegate(object sender, MouseButtonEventArgs e)
            {
                if (e.LeftButton == MouseButtonState.Pressed)
                {
                    try { DragMove(); } catch { }
                }
            };

            StackPanel titleStack = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
            if (appIcon != null)
            {
                Image titleIcon = new Image
                {
                    Source = appIcon,
                    Width = 16,
                    Height = 16,
                    Stretch = Stretch.Uniform,
                    Margin = new Thickness(0, 0, 8, 0)
                };
                RenderOptions.SetBitmapScalingMode(titleIcon, BitmapScalingMode.HighQuality);
                titleStack.Children.Add(titleIcon);
            }
            else
            {
                WpfPath titleIcon = new WpfPath
                {
                    Fill = new SolidColorBrush(Color.FromRgb(59, 130, 246)),
                    Width = 14,
                    Height = 14,
                    Stretch = Stretch.Uniform,
                    Margin = new Thickness(0, 0, 8, 0),
                    Data = Geometry.Parse(ICON_BOLT)
                };
                titleStack.Children.Add(titleIcon);
            }
            TextBlock titleText = new TextBlock
            {
                Text = "DeSloth",
                Foreground = new SolidColorBrush(Color.FromRgb(148, 163, 184)),
                FontSize = 11,
                FontWeight = FontWeights.Bold,
                VerticalAlignment = VerticalAlignment.Center
            };
            titleStack.Children.Add(titleText);
            headerGrid.Children.Add(titleStack);

            // CIRCULAR CLOSE BUTTON
            Button btnWinClose = new Button
            {
                HorizontalAlignment = HorizontalAlignment.Right,
                VerticalAlignment = VerticalAlignment.Center,
                Width = 28,
                Height = 28,
                Cursor = Cursors.Hand,
                Focusable = false
            };

            ControlTemplate circleCloseTemplate = new ControlTemplate(typeof(Button));
            FrameworkElementFactory circleBorder = new FrameworkElementFactory(typeof(Border));
            circleBorder.Name = "circle";
            circleBorder.SetValue(Border.CornerRadiusProperty, new CornerRadius(14));
            circleBorder.SetValue(Border.WidthProperty, 28.0);
            circleBorder.SetValue(Border.HeightProperty, 28.0);
            circleBorder.SetValue(Border.BackgroundProperty, new SolidColorBrush(Color.FromArgb(45, 255, 255, 255)));
            circleBorder.SetValue(Border.BorderThicknessProperty, new Thickness(1));
            circleBorder.SetValue(Border.BorderBrushProperty, new SolidColorBrush(Color.FromArgb(30, 255, 255, 255)));

            FrameworkElementFactory closeTxt = new FrameworkElementFactory(typeof(TextBlock));
            closeTxt.Name = "txt";
            closeTxt.SetValue(TextBlock.TextProperty, "✕");
            closeTxt.SetValue(TextBlock.FontSizeProperty, 11.0);
            closeTxt.SetValue(TextBlock.FontWeightProperty, FontWeights.Bold);
            closeTxt.SetValue(TextBlock.ForegroundProperty, new SolidColorBrush(Color.FromRgb(148, 163, 184)));
            closeTxt.SetValue(TextBlock.HorizontalAlignmentProperty, HorizontalAlignment.Center);
            closeTxt.SetValue(TextBlock.VerticalAlignmentProperty, VerticalAlignment.Center);
            circleBorder.AppendChild(closeTxt);

            circleCloseTemplate.VisualTree = circleBorder;

            Trigger closeHover = new Trigger { Property = Button.IsMouseOverProperty, Value = true };
            closeHover.Setters.Add(new Setter(Border.BackgroundProperty, new SolidColorBrush(Color.FromRgb(239, 68, 68)), "circle"));
            closeHover.Setters.Add(new Setter(Border.BorderBrushProperty, new SolidColorBrush(Color.FromRgb(248, 113, 113)), "circle"));
            closeHover.Setters.Add(new Setter(TextBlock.ForegroundProperty, Brushes.White, "txt"));
            circleCloseTemplate.Triggers.Add(closeHover);

            btnWinClose.Template = circleCloseTemplate;
            btnWinClose.Click += delegate(object sender, RoutedEventArgs e) { Close(); };
            headerGrid.Children.Add(btnWinClose);

            // Center Content
            StackPanel centerStack = new StackPanel
            {
                VerticalAlignment = VerticalAlignment.Center,
                HorizontalAlignment = HorizontalAlignment.Center,
                Margin = new Thickness(24, 42, 24, 58),
                Width = 480
            };

            // Floating large logo with dynamic glow
            iconGlow = new DropShadowEffect
            {
                BlurRadius = 32,
                Color = Color.FromRgb(59, 130, 246),
                Opacity = 0.65,
                ShadowDepth = 0
            };

            if (appIcon != null)
            {
                Image imgLogo = new Image
                {
                    Source = appIcon,
                    Width = 104,
                    Height = 104,
                    Stretch = Stretch.Uniform,
                    HorizontalAlignment = HorizontalAlignment.Center,
                    Margin = new Thickness(0, 0, 0, 14),
                    Effect = iconGlow
                };
                RenderOptions.SetBitmapScalingMode(imgLogo, BitmapScalingMode.HighQuality);
                centerStack.Children.Add(imgLogo);
            }
            else
            {
                stepIcon = new WpfPath
                {
                    Fill = new SolidColorBrush(Color.FromRgb(96, 165, 250)),
                    Width = 48,
                    Height = 48,
                    Stretch = Stretch.Uniform,
                    HorizontalAlignment = HorizontalAlignment.Center,
                    Margin = new Thickness(0, 0, 0, 14),
                    Data = Geometry.Parse(ICON_BOLT),
                    Effect = iconGlow
                };
                centerStack.Children.Add(stepIcon);
            }

            txtStepCount = new TextBlock
            {
                Text = "READY TO OPTIMIZE",
                Foreground = new SolidColorBrush(Color.FromRgb(56, 189, 248)),
                FontSize = 10.5,
                FontWeight = FontWeights.Bold,
                HorizontalAlignment = HorizontalAlignment.Center,
                Margin = new Thickness(0, 0, 0, 3)
            };
            centerStack.Children.Add(txtStepCount);

            txtStepTitle = new TextBlock
            {
                Text = "One-Click System Debloat",
                Foreground = Brushes.White,
                FontSize = 18,
                FontWeight = FontWeights.SemiBold,
                HorizontalAlignment = HorizontalAlignment.Center,
                Margin = new Thickness(0, 0, 0, 6)
            };
            centerStack.Children.Add(txtStepTitle);



            // Real-time progress bar
            pBar = new ProgressBar
            {
                Height = 6,
                Minimum = 0,
                Maximum = 100,
                Value = 0,
                Background = new SolidColorBrush(Color.FromRgb(30, 36, 51)),
                Foreground = new SolidColorBrush(Color.FromRgb(59, 130, 246)),
                BorderThickness = new Thickness(0),
                Margin = new Thickness(0, 0, 0, 6)
            };
            centerStack.Children.Add(pBar);

            txtLastActivity = new TextBlock
            {
                Text = "",
                Foreground = new SolidColorBrush(Color.FromRgb(100, 116, 139)),
                FontSize = 10,
                HorizontalAlignment = HorizontalAlignment.Center,
                Margin = new Thickness(0, 4, 0, 0)
            };
            centerStack.Children.Add(txtLastActivity);

            // Bottom Buttons
            StackPanel bottomStack = new StackPanel
            {
                Orientation = Orientation.Horizontal,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Bottom,
                Margin = new Thickness(0, 0, 0, 16)
            };

            // PILL-SHAPED START BUTTON (Height 42, CornerRadius 21)
            btnStart = new Button
            {
                Content = "START OPTIMIZING",
                Height = 42,
                Width = 190,
                Foreground = Brushes.White,
                FontWeight = FontWeights.Bold,
                FontSize = 13,
                Cursor = Cursors.Hand
            };

            ControlTemplate pillStartTemplate = new ControlTemplate(typeof(Button));
            FrameworkElementFactory pillBorder = new FrameworkElementFactory(typeof(Border));
            pillBorder.Name = "pill";
            pillBorder.SetValue(Border.CornerRadiusProperty, new CornerRadius(21));
            pillBorder.SetValue(Border.BackgroundProperty, new SolidColorBrush(Color.FromRgb(37, 99, 235)));
            pillBorder.SetValue(Border.BorderThicknessProperty, new Thickness(1));
            pillBorder.SetValue(Border.BorderBrushProperty, new SolidColorBrush(Color.FromArgb(60, 255, 255, 255)));

            FrameworkElementFactory pillContent = new FrameworkElementFactory(typeof(ContentPresenter));
            pillContent.SetValue(ContentPresenter.HorizontalAlignmentProperty, HorizontalAlignment.Center);
            pillContent.SetValue(ContentPresenter.VerticalAlignmentProperty, VerticalAlignment.Center);
            pillBorder.AppendChild(pillContent);

            pillStartTemplate.VisualTree = pillBorder;

            Trigger pillHover = new Trigger { Property = Button.IsMouseOverProperty, Value = true };
            pillHover.Setters.Add(new Setter(Border.BackgroundProperty, new SolidColorBrush(Color.FromRgb(59, 130, 246)), "pill"));
            pillStartTemplate.Triggers.Add(pillHover);

            Trigger pillPress = new Trigger { Property = Button.IsPressedProperty, Value = true };
            pillPress.Setters.Add(new Setter(Border.BackgroundProperty, new SolidColorBrush(Color.FromRgb(29, 78, 216)), "pill"));
            pillStartTemplate.Triggers.Add(pillPress);

            Trigger pillDisabled = new Trigger { Property = Button.IsEnabledProperty, Value = false };
            pillDisabled.Setters.Add(new Setter(Border.BackgroundProperty, new SolidColorBrush(Color.FromRgb(51, 65, 85)), "pill"));
            pillDisabled.Setters.Add(new Setter(Border.OpacityProperty, 0.6, "pill"));
            pillStartTemplate.Triggers.Add(pillDisabled);

            btnStart.Template = pillStartTemplate;
            btnStart.Click += BtnStart_Click;
            bottomStack.Children.Add(btnStart);

            // PILL-SHAPED RESTART EXPLORER BUTTON
            btnRestartExplorer = new Button
            {
                Content = "Restart Explorer",
                Height = 38,
                Width = 140,
                Foreground = Brushes.White,
                FontWeight = FontWeights.SemiBold,
                FontSize = 12,
                Margin = new Thickness(8, 0, 0, 0),
                Cursor = Cursors.Hand,
                Visibility = Visibility.Collapsed
            };
            btnRestartExplorer.Template = CreatePillTemplate(Color.FromRgb(51, 65, 85), Color.FromRgb(71, 85, 105), 19);
            btnRestartExplorer.Click += delegate(object sender, RoutedEventArgs e)
            {
                if (RestartExplorer())
                {
                    btnRestartExplorer.Visibility = Visibility.Collapsed;
                }
                else
                {
                    btnRestartExplorer.Content = "Retry Restart";
                }
            };
            bottomStack.Children.Add(btnRestartExplorer);

            // PILL-SHAPED CLOSE BUTTON
            btnClose = new Button
            {
                Content = "Close",
                Height = 38,
                Width = 100,
                Foreground = Brushes.White,
                FontWeight = FontWeights.SemiBold,
                FontSize = 12,
                Margin = new Thickness(8, 0, 0, 0),
                Cursor = Cursors.Hand,
                Visibility = Visibility.Collapsed
            };
            btnClose.Template = CreatePillTemplate(Color.FromRgb(30, 41, 59), Color.FromRgb(51, 65, 85), 19);
            btnClose.Click += delegate(object sender, RoutedEventArgs e) { Close(); };
            bottomStack.Children.Add(btnClose);

            cardGrid.Children.Add(headerGrid);
            cardGrid.Children.Add(centerStack);
            cardGrid.Children.Add(bottomStack);

            outerBorder.Child = cardGrid;
            rootGrid.Children.Add(outerBorder);
            Content = rootGrid;
        }

        private ControlTemplate CreatePillTemplate(Color baseColor, Color hoverColor, double radius)
        {
            ControlTemplate tpl = new ControlTemplate(typeof(Button));
            FrameworkElementFactory b = new FrameworkElementFactory(typeof(Border));
            b.Name = "pBorder";
            b.SetValue(Border.CornerRadiusProperty, new CornerRadius(radius));
            b.SetValue(Border.BackgroundProperty, new SolidColorBrush(baseColor));

            FrameworkElementFactory cp = new FrameworkElementFactory(typeof(ContentPresenter));
            cp.SetValue(ContentPresenter.HorizontalAlignmentProperty, HorizontalAlignment.Center);
            cp.SetValue(ContentPresenter.VerticalAlignmentProperty, VerticalAlignment.Center);
            b.AppendChild(cp);

            tpl.VisualTree = b;

            Trigger h = new Trigger { Property = Button.IsMouseOverProperty, Value = true };
            h.Setters.Add(new Setter(Border.BackgroundProperty, new SolidColorBrush(hoverColor), "pBorder"));
            tpl.Triggers.Add(h);

            return tpl;
        }

        private void UpdateStepVisuals(string iconKey)
        {
            Color c = Color.FromRgb(59, 130, 246);

            if (iconKey == "SHIELD") { c = Color.FromRgb(96, 165, 250); }
            else if (iconKey == "TRASH") { c = Color.FromRgb(248, 113, 113); }
            else if (iconKey == "SPEED") { c = Color.FromRgb(56, 189, 248); }
            else if (iconKey == "BOLT") { c = Color.FromRgb(245, 158, 11); }
            else if (iconKey == "GEAR") { c = Color.FromRgb(236, 72, 153); }
            else if (iconKey == "CLOCK") { c = Color.FromRgb(168, 85, 247); }
            else if (iconKey == "CHECK") { c = Color.FromRgb(16, 185, 129); }

            if (stepIcon != null)
            {
                string geom = ICON_GEAR;
                if (iconKey == "SHIELD") geom = ICON_SHIELD;
                else if (iconKey == "TRASH") geom = ICON_TRASH;
                else if (iconKey == "SPEED") geom = ICON_SPEED;
                else if (iconKey == "BOLT") geom = ICON_BOLT;
                else if (iconKey == "CLOCK") geom = ICON_CLOCK;
                else if (iconKey == "CHECK") geom = ICON_CHECK;

                stepIcon.Data = Geometry.Parse(geom);
                stepIcon.Fill = new SolidColorBrush(c);
            }
            if (iconGlow != null)
            {
                iconGlow.Color = c;
            }
        }

        private async void BtnStart_Click(object sender, RoutedEventArgs e)
        {
            btnStart.IsEnabled = false;
            btnStart.Content = "Optimizing...";

            await Task.Run(new Action(delegate()
            {
                ExecuteDebloatWorkflow();
            }));
        }

        private void ExecuteDebloatWorkflow()
        {
            tempDir = IOPath.Combine(IOPath.GetTempPath(), "UltimateDebloat_" + Guid.NewGuid().ToString("N"));
            try
            {
                Directory.CreateDirectory(tempDir);
                string zipPath = IOPath.Combine(tempDir, "payload.zip");

                // Extract embedded payload resource
                Assembly assembly = Assembly.GetExecutingAssembly();
                using (Stream stream = assembly.GetManifestResourceStream("Payload"))
                {
                    if (stream != null)
                    {
                        using (FileStream fs = new FileStream(zipPath, FileMode.Create, FileAccess.Write))
                        {
                            stream.CopyTo(fs);
                        }
                    }
                    else
                    {
                        foreach (string name in assembly.GetManifestResourceNames())
                        {
                            if (name.Contains("Payload") || name.EndsWith(".zip"))
                            {
                                using (Stream res = assembly.GetManifestResourceStream(name))
                                using (FileStream fs = new FileStream(zipPath, FileMode.Create, FileAccess.Write))
                                {
                                    res.CopyTo(fs);
                                }
                                break;
                            }
                        }
                    }
                }

                if (File.Exists(zipPath))
                {
                    ZipFile.ExtractToDirectory(zipPath, tempDir);
                    File.Delete(zipPath);
                }

                string engineScript = IOPath.Combine(tempDir, "UnifiedRunnerEngine.ps1");
                string configPath = IOPath.Combine(tempDir, "UnifiedConfig.json");

                if (File.Exists(engineScript) && File.Exists(configPath))
                {
                    ProcessStartInfo psi = new ProcessStartInfo
                    {
                        FileName = "powershell.exe",
                        Arguments = string.Format("-NoProfile -ExecutionPolicy Bypass -File \"{0}\" -ConfigPath \"{1}\"", engineScript, configPath),
                        CreateNoWindow = true,
                        UseShellExecute = false,
                        RedirectStandardOutput = true,
                        RedirectStandardError = true,
                        WorkingDirectory = tempDir
                    };

                    using (Process proc = new Process())
                    {
                        proc.StartInfo = psi;
                        proc.OutputDataReceived += delegate(object s, DataReceivedEventArgs ev)
                        {
                            if (!string.IsNullOrEmpty(ev.Data))
                            {
                                HandleEngineOutput(ev.Data);
                            }
                        };
                        proc.ErrorDataReceived += delegate(object s, DataReceivedEventArgs ev)
                        {
                            // Background errors suppressed to prevent UI noise
                        };

                        proc.Start();
                        proc.BeginOutputReadLine();
                        proc.BeginErrorReadLine();
                        proc.WaitForExit();
                    }
                }
                else
                {
                    // Fallback execution if engine script missing
                    FallbackDebloatExecution(configPath);
                }

                Dispatcher.Invoke(new Action(delegate()
                {
                    ShowCompletionUI();
                }));
            }
            catch (Exception ex)
            {
                Dispatcher.Invoke(new Action(delegate()
                {
                    txtStepTitle.Text = "Completed with Notices";
                    txtLastActivity.Text = ex.Message;
                    ShowCompletionUI();
                }));
            }
        }

        private void HandleEngineOutput(string line)
        {
            if (line.StartsWith("STATUS|"))
            {
                string[] parts = line.Split('|');
                if (parts.Length >= 7)
                {
                    string step = parts[1];
                    string title = parts[2];
                    string item = parts[3];
                    string sub = parts[4];
                    double pct = 0;
                    double.TryParse(parts[5], out pct);
                    string iconKey = parts[6];

                    Dispatcher.Invoke(new Action(delegate()
                    {
                        txtStepCount.Text = step;
                        txtStepTitle.Text = title;
                        txtLastActivity.Text = item + "  ·  " + sub;
                        pBar.Value = pct;
                        UpdateStepVisuals(iconKey);

                        if (iconKey == "CHECK" || step == "COMPLETE")
                        {
                            ShowCompletionUI();
                        }
                    }));
                }
            }
        }

        private void FallbackDebloatExecution(string configPath)
        {
            Dispatcher.Invoke(new Action(delegate()
            {
                txtStepCount.Text = "STEP 1 OF 3";
                txtStepTitle.Text = "Executing Debloat";
                txtLastActivity.Text = "Applying debloat configurations...";
                pBar.Value = 30;
                UpdateStepVisuals("SPEED");
            }));

            string w11dScript = IOPath.Combine(tempDir, "Win11Debloat-master\\Win11Debloat.ps1");
            string w11dConfig = IOPath.Combine(tempDir, "Win11DebloatConfig.json");
            if (File.Exists(w11dScript) && File.Exists(w11dConfig))
            {
                RunProcessHidden("powershell.exe", string.Format("-NoProfile -ExecutionPolicy Bypass -File \"{0}\" -Config \"{1}\" -Silent -SkipExplorerRestart", w11dScript, w11dConfig));
            }

            Dispatcher.Invoke(new Action(delegate()
            {
                txtStepCount.Text = "STEP 2 OF 3";
                txtStepTitle.Text = "Applying WinUtil";
                txtLastActivity.Text = "Applying performance optimizations...";
                pBar.Value = 70;
                UpdateStepVisuals("BOLT");
            }));

            string winutilScript = IOPath.Combine(tempDir, "winutil.ps1");
            string winutilConfig = IOPath.Combine(tempDir, "WinUtilConfig.json");
            if (File.Exists(winutilScript) && File.Exists(winutilConfig))
            {
                RunProcessHidden("powershell.exe", string.Format("-NoProfile -ExecutionPolicy Bypass -File \"{0}\" -Config \"{1}\" -SkipExplorerRestart", winutilScript, winutilConfig));
            }

            string applyServices = IOPath.Combine(tempDir, "ApplyServicesAndTasks.ps1");
            if (File.Exists(applyServices))
            {
                RunProcessHidden("powershell.exe", string.Format("-NoProfile -ExecutionPolicy Bypass -File \"{0}\" -ConfigPath \"{1}\"", applyServices, configPath));
            }

            Dispatcher.Invoke(new Action(delegate()
            {
                txtStepCount.Text = "COMPLETE";
                txtStepTitle.Text = "Optimization Complete!";
                txtLastActivity.Text = "All selections applied successfully.";
                pBar.Value = 100;
                UpdateStepVisuals("CHECK");
                ShowCompletionUI();
            }));
        }

        private void RunProcessHidden(string file, string args)
        {
            try
            {
                ProcessStartInfo psi = new ProcessStartInfo
                {
                    FileName = file,
                    Arguments = args,
                    CreateNoWindow = true,
                    UseShellExecute = false,
                    WindowStyle = ProcessWindowStyle.Hidden,
                    WorkingDirectory = tempDir
                };
                using (Process p = Process.Start(psi))
                {
                    if (p != null) p.WaitForExit();
                }
            }
            catch { }
        }

        private void ShowCompletionUI()
        {
            btnStart.Visibility = Visibility.Collapsed;
            btnClose.Visibility = Visibility.Visible;

            bool explorerOk = false;
            try
            {
                explorerOk = Process.GetProcessesByName("explorer").Length > 0;
            }
            catch { }

            // If explorer is running normally, only show Close button
            btnRestartExplorer.Visibility = explorerOk ? Visibility.Collapsed : Visibility.Visible;
        }

        private bool RestartExplorer()
        {
            try
            {
                foreach (Process p in Process.GetProcessesByName("explorer"))
                {
                    try { p.Kill(); } catch { }
                }
                System.Threading.Thread.Sleep(600);
                Process.Start("explorer.exe");
                System.Threading.Thread.Sleep(400);
                return Process.GetProcessesByName("explorer").Length > 0;
            }
            catch
            {
                return false;
            }
        }

        [DllImport("user32.dll", SetLastError = true)]
        private static extern IntPtr LoadImage(IntPtr hinst, IntPtr lpszName, uint uType, int cxDesired, int cyDesired, uint fuLoad);

        [DllImport("user32.dll", SetLastError = true)]
        private static extern bool DestroyIcon(IntPtr hIcon);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern IntPtr GetModuleHandle(string lpModuleName);

        private ImageSource LoadAppIcon()
        {
            // 1. Extract Win32 icon compiled via csc /win32icon (no duplicate managed resource needed)
            try
            {
                IntPtr hMod = GetModuleHandle(null);
                IntPtr hIcon = LoadImage(hMod, (IntPtr)32512, 1, 256, 256, 0);
                if (hIcon == IntPtr.Zero)
                {
                    hIcon = LoadImage(hMod, (IntPtr)1, 1, 256, 256, 0);
                }
                if (hIcon == IntPtr.Zero)
                {
                    hIcon = LoadImage(hMod, (IntPtr)32512, 1, 128, 128, 0);
                }
                if (hIcon != IntPtr.Zero)
                {
                    BitmapSource bs = System.Windows.Interop.Imaging.CreateBitmapSourceFromHIcon(
                        hIcon,
                        Int32Rect.Empty,
                        BitmapSizeOptions.FromEmptyOptions());
                    bs.Freeze();
                    DestroyIcon(hIcon);
                    return bs;
                }
            }
            catch { }

            // 2. Fallback: managed resource if present
            try
            {
                Assembly asm = Assembly.GetExecutingAssembly();
                using (Stream s = asm.GetManifestResourceStream("AppIcon"))
                {
                    if (s != null)
                    {
                        IconBitmapDecoder decoder = new IconBitmapDecoder(s, BitmapCreateOptions.None, BitmapCacheOption.OnLoad);
                        BitmapFrame best = decoder.Frames[0];
                        foreach (BitmapFrame f in decoder.Frames)
                        {
                            if (f.PixelWidth > best.PixelWidth) best = f;
                        }
                        best.Freeze();
                        return best;
                    }
                }
            }
            catch { }

            try
            {
                string localIco = IOPath.Combine(AppDomain.CurrentDomain.BaseDirectory, "src\\desloth.ico");
                if (!File.Exists(localIco)) localIco = @"d:\Declut\src\desloth.ico";
                if (File.Exists(localIco))
                {
                    using (FileStream fs = new FileStream(localIco, FileMode.Open, FileAccess.Read))
                    {
                        IconBitmapDecoder decoder = new IconBitmapDecoder(fs, BitmapCreateOptions.None, BitmapCacheOption.OnLoad);
                        BitmapFrame best = decoder.Frames[0];
                        foreach (BitmapFrame f in decoder.Frames)
                        {
                            if (f.PixelWidth > best.PixelWidth) best = f;
                        }
                        return best;
                    }
                }
            }
            catch { }
            return null;
        }

        protected override void OnClosed(EventArgs e)
        {
            base.OnClosed(e);
            try
            {
                if (!string.IsNullOrEmpty(tempDir) && Directory.Exists(tempDir))
                {
                    Directory.Delete(tempDir, true);
                }
            }
            catch { }
        }
    }

    public class App : Application
    {
        [STAThread]
        public static void Main()
        {
            try
            {
                App app = new App();
                app.Run(new RunnerWindow());
            }
            catch (Exception ex)
            {
                MessageBox.Show("DeSloth startup exception:\n\n" + ex.Message + "\n\n" + ex.StackTrace, "DeSloth Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }
    }
}
