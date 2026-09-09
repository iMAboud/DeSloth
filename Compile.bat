@echo off
setlocal EnableExtensions
title DeSloth - Compile Runner

pushd "%~dp0"

set "CSC=C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
set "WPFLIB=C:\Windows\Microsoft.NET\Framework64\v4.0.30319\WPF"
set "SRC=src\RunnerApp.cs"
set "MANIFEST=src\app.manifest"
set "ICON=src\desloth.ico"
set "OUT=dist\DeSloth.exe"
set "ZIPPATH=%TEMP%\DebloatPayload_%RANDOM%.zip"

if not exist "%CSC%" (
    echo [ERROR] csc.exe not found at %CSC%
    goto :FAIL
)
if not exist "%SRC%" (
    echo [ERROR] RunnerApp.cs not found at %SRC%
    goto :FAIL
)
if not exist "dist" mkdir "dist"

echo [1/2] Building payload...
powershell -NoProfile -ExecutionPolicy Bypass -File "src\Build-Payload.ps1" -BaseDir "%CD%" -OutZip "%ZIPPATH%"

if not exist "%ZIPPATH%" (
    echo [ERROR] Payload zip was not created: %ZIPPATH%
    goto :FAIL
)

echo [2/2] Compiling DeSloth.exe...
if exist "%ICON%" (
    "%CSC%" /nologo /target:winexe /optimize+ /win32manifest:"%MANIFEST%" /win32icon:"%ICON%" /lib:"%WPFLIB%" /r:System.Xaml.dll /r:PresentationFramework.dll /r:PresentationCore.dll /r:WindowsBase.dll /r:System.dll /r:System.Core.dll /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll /resource:"%ZIPPATH%",Payload /out:"%OUT%" "%SRC%"
) else (
    "%CSC%" /nologo /target:winexe /optimize+ /win32manifest:"%MANIFEST%" /lib:"%WPFLIB%" /r:System.Xaml.dll /r:PresentationFramework.dll /r:PresentationCore.dll /r:WindowsBase.dll /r:System.dll /r:System.Core.dll /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll /resource:"%ZIPPATH%",Payload /out:"%OUT%" "%SRC%"
)

set EXITCODE=%ERRORLEVEL%
del "%ZIPPATH%" 2>nul

if %EXITCODE% neq 0 (
    echo.
    echo [FAILED] Compilation failed with exit code %EXITCODE%.
    goto :FAIL
)

copy /y "%OUT%" "dist\UltimateDebloatRunner.exe" >nul 2>&1

echo.
echo ==================================================
echo [SUCCESS] Compiled successfully: %OUT%
echo ==================================================
echo.
popd
pause
exit /b 0

:FAIL
echo.
echo ==================================================
echo [ERROR] Compilation failed.
echo ==================================================
echo.
popd
pause
exit /b 1
