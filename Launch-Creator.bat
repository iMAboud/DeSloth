@echo off
setlocal
cd /d "%~dp0"

:: Check for Administrator elevation
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Elevating to Administrator for system services and scheduler access...
    powershell -NoProfile -Command "Start-Process cmd -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    exit /b
)

echo Launching Ultimate Windows Debloat Studio...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "src\Show-CreatorUI.ps1" -BaseDir "%~dp0."
exit /b
