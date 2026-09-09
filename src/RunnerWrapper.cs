using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;

namespace UltimateDebloat
{
    static class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            string tempDir = Path.Combine(Path.GetTempPath(), "UltimateDebloat_" + Guid.NewGuid().ToString("N"));
            try
            {
                Directory.CreateDirectory(tempDir);
                string zipPath = Path.Combine(tempDir, "payload.zip");

                var assembly = Assembly.GetExecutingAssembly();
                using (Stream stream = assembly.GetManifestResourceStream("Payload"))
                {
                    if (stream == null)
                    {
                        // Fallback check if resource name has namespace
                        foreach (string name in assembly.GetManifestResourceNames())
                        {
                            if (name.EndsWith("payload.zip") || name.Contains("Payload"))
                            {
                                using (Stream resStream = assembly.GetManifestResourceStream(name))
                                {
                                    using (FileStream fs = new FileStream(zipPath, FileMode.Create, FileAccess.Write))
                                    {
                                        resStream.CopyTo(fs);
                                    }
                                }
                                break;
                            }
                        }
                    }
                    else
                    {
                        using (FileStream fs = new FileStream(zipPath, FileMode.Create, FileAccess.Write))
                        {
                            stream.CopyTo(fs);
                        }
                    }
                }

                if (File.Exists(zipPath))
                {
                    ZipFile.ExtractToDirectory(zipPath, tempDir);
                    File.Delete(zipPath);
                }

                string runnerScript = Path.Combine(tempDir, "RunnerEngine.ps1");
                string configPath = Path.Combine(tempDir, "UnifiedConfig.json");

                ProcessStartInfo psi = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = string.Format("-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"{0}\" -ConfigPath \"{1}\" -CoreDir \"{2}\"",
                        runnerScript, configPath, tempDir),
                    WorkingDirectory = tempDir,
                    UseShellExecute = false,
                    CreateNoWindow = true
                };

                using (Process proc = Process.Start(psi))
                {
                    if (proc != null)
                    {
                        proc.WaitForExit();
                    }
                }
            }
            catch (Exception ex)
            {
                System.Windows.Forms.MessageBox.Show("Execution error: " + ex.Message, "Ultimate Debloat",
                    System.Windows.Forms.MessageBoxButtons.OK, System.Windows.Forms.MessageBoxIcon.Error);
            }
            finally
            {
                try
                {
                    if (Directory.Exists(tempDir))
                    {
                        Directory.Delete(tempDir, true);
                    }
                }
                catch { }
            }
        }
    }
}
