@echo off
setlocal enabledelayedexpansion

echo ========================================================
echo  My Mouse My Choice - Unified Build Pipeline
echo ========================================================
echo.

cd /d "%~dp0"

set "AHK_COMPILER=%~dp0tools\Compiler\Ahk2Exe.exe"
set "AHK_BASE=C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"

REM --- Close running instances so file is not locked ---
taskkill /f /im MyMouseMyChoice.exe >nul 2>&1
taskkill /f /im Ahk2Exe.exe >nul 2>&1
ping 127.0.0.1 -n 2 >nul

REM --- Unlock destination binary if process is elevated / write-locked ---
if exist "%~dp0MyMouseMyChoice.exe" (
    del /f /q "%~dp0MyMouseMyChoice.old.exe" >nul 2>&1
    move /y "%~dp0MyMouseMyChoice.exe" "%~dp0MyMouseMyChoice.old.exe" >nul 2>&1
)

REM --- Step 1: Compile Standalone Executable ---
echo [1/3] Compiling MyMouseMyChoice.exe with Ahk2Exe...

if not exist "%AHK_COMPILER%" (
    echo Error: Ahk2Exe compiler not found at "%AHK_COMPILER%"
    pause
    exit /b 1
)

if not exist "%AHK_BASE%" (
    echo Error: AutoHotkey v2 64-bit base not found at "%AHK_BASE%"
    pause
    exit /b 1
)

"%AHK_COMPILER%" /in "%~dp0MyMouseMyChoice.ahk" /out "%~dp0MyMouseMyChoice.exe" /icon "%~dp0assets\app.ico" /base "%AHK_BASE%" /silent

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Error: Ahk2Exe compilation failed with code %ERRORLEVEL%.
    if "%~1" NEQ "/nopause" pause
    exit /b %ERRORLEVEL%
)
echo       Standalone binary created: MyMouseMyChoice.exe
echo.

REM --- Step 2: Stage Clean Release (Filter git-ignored files) ---
echo [2/3] Staging clean release files (excluding all git-ignored files)...

set "STAGING_DIR=%~dp0build\staging"
if exist "%STAGING_DIR%" rd /s /q "%STAGING_DIR%" >nul 2>&1
mkdir "%STAGING_DIR%" >nul 2>&1

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$staging = '%STAGING_DIR%';" ^
    "$nonIgnored = git ls-files --cached --others --exclude-standard 2>$null;" ^
    "if (-not $nonIgnored) { exit 1 };" ^
    "foreach ($f in $nonIgnored) {" ^
    "    if ($f -match '^(web|assets|lib|tools[/\\]install-interception\.exe|WebView2Loader\.dll|settings\.default\.ini|JetBrainsMono|ShareTech)') {" ^
    "        $dest = Join-Path $staging $f;" ^
    "        $destDir = Split-Path $dest -Parent;" ^
    "        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null };" ^
    "        Copy-Item $f -Destination $dest -Force;" ^
    "    }" ^
    "};" ^
    "Copy-Item 'MyMouseMyChoice.exe' -Destination (Join-Path $staging 'MyMouseMyChoice.exe') -Force;"

if not exist "%STAGING_DIR%\MyMouseMyChoice.exe" (
    echo Warning: Staging using git was not possible; falling back to direct source directory.
    set "USE_STAGING=0"
) else (
    echo       Clean release staged successfully in build\staging (0 git-ignored files included)
    set "USE_STAGING=1"
)
echo.

REM --- Step 3: Build Windows Setup Installer ---
echo [3/3] Building Windows Setup Installer with Inno Setup...

set "ISCC="
if exist "%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe" (
    set "ISCC=%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe"
) else if exist "%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe" (
    set "ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
) else if exist "%ProgramFiles%\Inno Setup 6\ISCC.exe" (
    set "ISCC=%ProgramFiles%\Inno Setup 6\ISCC.exe"
)

if not defined ISCC (
    echo Warning: Inno Setup compiler ISCC.exe was not found.
    echo Standalone executable MyMouseMyChoice.exe was built successfully,
    echo but setup.exe could not be compiled.
    echo.
    if "%~1" NEQ "/nopause" pause
    exit /b 0
)

if "%USE_STAGING%"=="1" (
    "%ISCC%" /DAppSourceDir="%STAGING_DIR%" /Q "%~dp0installer.iss"
) else (
    "%ISCC%" /Q "%~dp0installer.iss"
)

if %ERRORLEVEL% EQU 0 (
    REM Clean up staging directory
    if exist "%STAGING_DIR%" rd /s /q "%STAGING_DIR%" >nul 2>&1
    
    REM Provide both setup.exe and MyMouseMyChoice_Setup.exe in root and dist
    if exist "dist\setup.exe" (
        copy /y "dist\setup.exe" "%~dp0setup.exe" >nul 2>&1
        copy /y "dist\setup.exe" "%~dp0MyMouseMyChoice_Setup.exe" >nul 2>&1
        copy /y "dist\setup.exe" "dist\MyMouseMyChoice_Setup.exe" >nul 2>&1
    )
    
    echo.
    echo ========================================================
    echo  SUCCESS! Build Complete:
    echo   1. Standalone Binary: MyMouseMyChoice.exe
    echo   2. Setup Installer:   setup.exe
    echo      [Also saved as:    MyMouseMyChoice_Setup.exe]
    echo      [Output path:      dist\setup.exe]
    echo ========================================================
) else (
    echo.
    echo Inno Setup compilation failed with code %ERRORLEVEL%.
)

echo.
if "%~1" NEQ "/nopause" pause
