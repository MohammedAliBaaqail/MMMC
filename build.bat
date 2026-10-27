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
taskkill /f /im G502X_Studio.exe >nul 2>&1
taskkill /f /im Ahk2Exe.exe >nul 2>&1
ping 127.0.0.1 -n 2 >nul

REM --- Step 1: Compile Standalone Executable ---
echo [1/2] Compiling MyMouseMyChoice.exe with Ahk2Exe...

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
    pause
    exit /b %ERRORLEVEL%
)
copy /y "%~dp0MyMouseMyChoice.exe" "%~dp0G502X_Studio.exe" >nul
echo       Standalone binary created: MyMouseMyChoice.exe (also synced G502X_Studio.exe)
echo.

REM --- Step 2: Build Windows Setup Installer ---
echo [2/2] Building Windows Setup Installer with Inno Setup...

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
    echo but installer setup could not be compiled.
    echo.
    pause
    exit /b 0
)

"%ISCC%" /Q "%~dp0installer.iss"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ========================================================
    echo  SUCCESS! Build Complete:
    echo   1. Standalone EXE: MyMouseMyChoice.exe
    echo   2. Setup Installer: dist\MyMouseMyChoice_Setup_v2.0.exe
    echo ========================================================
) else (
    echo.
    echo Inno Setup compilation failed with code %ERRORLEVEL%.
)

echo.
pause
