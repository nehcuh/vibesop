@echo off
setlocal enabledelayedexpansion

REM Configuration
set "SCRIPT_DIR=%~dp0"
set "REPO_ROOT=%SCRIPT_DIR%.."
set "CONFIG_DIR=%USERPROFILE%\.vibe"
set "INSTALL_DIR=%USERPROFILE%\.local\bin"

echo ===============================================================================
echo.
echo                    VIBE - Windows Installation Wizard
echo.
echo ===============================================================================
echo.
echo [DEBUG] Script location: %SCRIPT_DIR%
echo [DEBUG] Repo root: %REPO_ROOT%
echo.

REM Step 1: Validate repository
echo [1/4] Validating repository structure...
if not exist "%REPO_ROOT%\core" (
    echo [ERROR] Missing: core\ directory
    goto :error
)
if not exist "%REPO_ROOT%\lib" (
    echo [ERROR] Missing: lib\ directory
    goto :error
)
if not exist "%REPO_ROOT%\bin\vibe" (
    echo [ERROR] Missing: bin\vibe
    goto :error
)
echo [OK] Repository structure validated
echo.

REM Step 2: Detect dependencies
echo [2/4] Checking dependencies...

set "HAS_RUBY=0"
where ruby >nul 2>&1
if %errorlevel% equ 0 (
    set "HAS_RUBY=1"
    echo [OK] Ruby is installed
) else (
    echo [WARN] Ruby is NOT installed (required for full functionality)
)

set "HAS_GIT=0"
where git >nul 2>&1
if %errorlevel% equ 0 (
    set "HAS_GIT=1"
    echo [OK] Git is installed
) else (
    echo [WARN] Git is NOT installed (required)
)
echo.

REM Step 3: Show installation guide if missing deps
if "%HAS_RUBY%"=="0" (
    echo ===============================================================================
    echo ACTION REQUIRED: Install Ruby
    echo ===============================================================================
    echo.
    echo Download Ruby from: https://rubyinstaller.org/downloads/
    echo.
    echo 1. Download Ruby+Devkit 3.0 or higher
    echo 2. Run installer - check "Add Ruby to PATH"
    echo 3. Also install MSYS2 when prompted
    echo 4. Close and reopen CMD after installation
    echo.
    echo Then run this installer again.
    echo ===============================================================================
    echo.
    pause
    exit /b 0
)

if "%HAS_GIT%"=="0" (
    echo ===============================================================================
    echo ACTION REQUIRED: Install Git
    echo ===============================================================================
    echo.
    echo Download Git from: https://git-scm.com/download/win
    echo.
    echo 1. Download Git for Windows
    echo 2. Run installer with default options
    echo 3. Close and reopen CMD after installation
    echo.
    echo Then run this installer again.
    echo ===============================================================================
    echo.
    pause
    exit /b 0
)

REM Step 4: Install Vibe
echo [3/4] Creating configuration...
if not exist "%CONFIG_DIR%" mkdir "%CONFIG_DIR%"
echo [OK] Created: %CONFIG_DIR%

echo [4/4] Creating wrapper scripts...
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

REM Create batch wrapper for CMD
echo @echo off > "%INSTALL_DIR%\vibe.bat"
echo set "REPO_ROOT=%REPO_ROOT%" >> "%INSTALL_DIR%\vibe.bat"
echo ruby "%%REPO_ROOT%%\bin\vibe" %%* >> "%INSTALL_DIR%\vibe.bat"
echo [OK] Created: %INSTALL_DIR%\vibe.bat

REM Create bash wrapper for Git Bash
echo #!/bin/bash > "%INSTALL_DIR%\vibe"
echo REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." ^&^& pwd)" >> "%INSTALL_DIR%\vibe"
echo exec ruby "$REPO_ROOT/bin/vibe" "$@" >> "%INSTALL_DIR%\vibe"
echo [OK] Created: %INSTALL_DIR%\vibe

echo.
echo ===============================================================================
echo                    INSTALLATION COMPLETE!
echo ===============================================================================
echo.
echo Quick Start:
echo   vibe --version
echo   vibe doctor
echo   vibe init --platform claude-code
echo.
echo IMPORTANT: Add %INSTALL_DIR% to your PATH
echo.
echo   1. Press Win+R, type: sysdm.cpl
echo   2. Advanced ^> Environment Variables
echo   3. Edit "Path" under User variables
echo   4. Add: %INSTALL_DIR%
echo.
pause
exit /b 0

:error
echo.
echo ===============================================================================
echo Installation FAILED
echo ===============================================================================
echo.
echo Please run this script from the vibesop repository root.
echo Current directory should contain: core\, lib\, bin\vibe
echo.
pause
exit /b 1
