# State & Changes

## Status
- Unified Creator UI overhauled with dedicated "Apps to Uninstall" tab.
- Filter out all meta-switches and internal flags from tweak lists.
- Fast `Get-AppxPackage` detection added: live "INSTALLED" badges and "Show Only Installed Apps" filter.
- Creator UI auto-saves and auto-loads profile from `config/debloat-profile.json`.
- Standalone runner (`.exe`) recompiled with upgraded UI: pill start button, circular close button, padded transparent window (no square ghost layer), full title bar drag, and live per-item debloat/uninstall ticker.
- Engine pre-fetches installed Appx/Provisioned packages once; uninstalls only existing apps and skips uninstalled packages instantly.
- Completion UI hides "Restart Explorer" button if Explorer is running normally; shows only "Close".
- Fixed multiple Explorer restarts: Win11Debloat and WinUtil now suppress intermediate restarts; Explorer refreshes only once at the end.
- Added conflict & deadlock fixer step: removes GameBar IFEO hijack, disables conflicting/inactive SteelSeries_Sonar_VAD driver, and aligns GameDVR runtime policies.
- Standalone runner renamed to **DeSloth** (`DeSloth.exe`), compiled with single `desloth.ico` embedding (~848 KB) and floating logo without background box.
- Workspace cleaned of temporary scratch files and root profile duplicates.
- Added `.gitignore` and `run.ps1` configured for repository `iMAboud/DeSloth`.

### High-Speed Pipeline & Real-Time Debugging Overhaul
- **System Restore Point**: Set 24h frequency limit bypass (`SystemRestorePointCreationFrequency = 0`) and 15s asynchronous job ceiling so VSS service delays never freeze the runner.
- **Bloatware App Removal**: Single package scan with direct object-based package deletion (`Remove-AppxPackage` / `Remove-AppxProvisionedPackage` by package name). Removed repetitive DISM re-queries and blocking winget calls, dropping Step 2 from 8+ minutes to under 4 seconds.
- **Win11Debloat Tweaks**: Direct in-process `.reg` imports and specialized feature handlers with item-by-item live progress ticker and timing; eliminated external process launch delays and duplicate 135-app re-uninstall passes.
- **WinUtil Optimizations**: Direct `tweaks.json` registry and service application, 6s timeout protection on custom invoke scripts, duplicate restore point skip, and explorer kill suppression until the final step.
- **Services & Scheduled Tasks**: Sub-millisecond direct registry updates for 255 services, non-blocking asynchronous stop (`sc.exe stop`) for running disabled services, and robust task disabling for 89 tasks.
- **Integrated Real-Time Debugging Console**:
  - Embedded expandable monospace dark terminal drawer inside `RunnerApp.cs` WPF UI with color-coded log entries (`[INFO]`, `[SUCCESS]`, `[WARN]`, `[ERROR]`).
  - Title bar `[ Logs ]` toggle button with dynamic notice/error counter badge: `[ Logs (count) ]`.
  - CLI argument support for directly launching into debug mode (`DeSloth.exe -debug` or `DeSloth.exe -logs`).
  - Quick action toolbar: "Copy Log", "Open File", "Clear".
  - Real-time persistent log streaming to `%TEMP%\DeSloth-debug.log`.
  - Zero stderr swallowing: any warning or error is surfaced immediately in real time.

## Key Files
- `Launch-Creator.bat`: Double-click launcher for Creator Studio.
- `Compile.bat`: One-click compile script with Win32 icon embedding and `/nopause` support.
- `run.ps1`: One-liner bootstrapper for `irm | iex`.
- `.gitignore`: Git ignore definitions for binary/temp files.
- `src/desloth.ico`: Application icon.
- `src/RunnerApp.cs`: C# WPF runner with built-in real-time debug console and floating DeSloth icon.
- `src/UnifiedRunnerEngine.ps1`: High-speed item-by-item streaming engine with non-blocking timeouts and real-time protocol.
- `dist/DeSloth.exe`: Standalone 848 KB compiled executable.
- `dist/UltimateDebloatRunner.exe`: Standalone 848 KB compiled executable.
- `dist/UltimateDebloatRunner.cmd`: Self-extracting batch script runner fallback.
