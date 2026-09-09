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

- Standalone runner renamed to **DeSloth** (`DeSloth.exe`), compiled with single `desloth.ico` embedding (~806 KB) and floating 104px logo without background box.
- Workspace cleaned of temporary scratch files and root profile duplicates.
- Added `.gitignore` and `run.ps1` for GitHub hosting and one-liner execution.

## Key Files
- `Launch-Creator.bat`: Double-click launcher for Creator Studio.
- `Compile.bat`: One-click compile script with Win32 icon embedding.
- `run.ps1`: One-liner bootstrapper for `irm | iex`.
- `.gitignore`: Git ignore definitions for binary/temp files.
- `src/desloth.ico`: Application icon.
- `src/RunnerApp.cs`: C# WPF runner displaying floating large DeSloth icon.
- `src/UnifiedRunnerEngine.ps1`: Item-by-item debloat streaming engine with fast pre-fetch.
- `dist/DeSloth.exe`: Standalone 806 KB compiled executable.
- `dist/UltimateDebloatRunner.exe`: Standalone 806 KB compiled executable.

