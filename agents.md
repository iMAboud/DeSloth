# Architecture

## Core Pipeline

```
[Win11Debloat-master] + [winutil-main] + [Win32_Service] + [ScheduledTasks]
                         │
                         ▼
             [src/Show-CreatorUI.ps1]  <-- Launch-Creator.bat
                         │
                         ▼ (Export Action)
         [src/Export-StandaloneRunner.ps1]
                         │
        ┌────────────────┴────────────────┐
        ▼                                 ▼
[dist/DeSloth.exe]             [dist/UltimateDebloatRunner.cmd]
        │
        ▼ (One-Click Run)
[src/RunnerApp.cs] (Compiled C# .NET 4.5 WPF Window: DeSloth Icon + Pill Buttons + Live Ticker)
        │
        ▼
[src/UnifiedRunnerEngine.ps1] (Streams exact items in real time)
        ├── Step 1: System Restore Point
        ├── Step 2: Uninstall Individual Bloat Apps (Fast pre-fetch & live item streaming)
        ├── Step 3: Win11Debloat Tweaks
        ├── Step 4: CTT WinUtil Performance Optimizations
        ├── Step 5: Windows Services & Scheduled Tasks
        ├── Step 6: Diagnostics & System Conflict Fixer (IFEO Hijacks & Audio Conflicts)
        ├── Step 7: Explorer Refresh (Single Final Restart)
        └── Step 8: Complete
```
