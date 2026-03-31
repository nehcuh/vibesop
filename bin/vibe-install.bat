@echo off
REM Vibe installation script for Windows with environment detection

setlocal enabledelayedexpansion

REM Configuration
set "SCRIPT_DIR=%~dp0"
set "REPO_ROOT=%SCRIPT_DIR%.."
set "CONFIG_DIR=%USERPROFILE%\.vibe"
set "CONFIG_FILE=%CONFIG_DIR%\config.json"
set "INSTALL_DIR=%USERPROFILE%\.local\bin"
set "MISSING_DEPS="
set "HAS_RUBY=0"
set "HAS_GIT=0"

echo ===============================================================================
echo.
echo                    VIBE - Windows Installation Wizard
echo.
echo ===============================================================================
echo.

REM Debug: Show paths
echo [DEBUG] SCRIPT_DIR = %SCRIPT_DIR%
echo [DEBUG] REPO_ROOT  = %REPO_ROOT%
echo.

REM Validate repository
echo Checking repository structure...
if not exist "%REPO_ROOT%\core" (
    echo [ERROR] Invalid vibe repository. Missing 'core' directory
    echo [DEBUG] Looking for: %REPO_ROOT%\core
    pause
    exit /b 1
)
echo [OK] Found: core

if not exist "%REPO_ROOT%\lib" (
    echo [ERROR] Invalid vibe repository. Missing 'lib' directory
    echo [DEBUG] Looking for: %REPO_ROOT%\lib
    pause
    exit /b 1
)
echo [OK] Found: lib

if not exist "%REPO_ROOT%\bin\vibe" (
    echo [ERROR] bin/vibe not found in repository
    echo [DEBUG] Looking for: %REPO_ROOT%\bin\vibe
    pause
    exit /b 1
)
echo [OK] Found: bin/vibe
echo.

REM Detect Ruby
echo Detecting dependencies...
where ruby >nul 2>&1
if %errorlevel% equ 0 (
    set "HAS_RUBY=1"
    echo [OK] Ruby is installed
) else (
    echo [WARNING] Ruby not found
    set "MISSING_DEPS=%MISSING_DEPS% Ruby"
)

REM Detect Git
where git >nul 2>&1
if %errorlevel% equ 0 (
    set "HAS_GIT=1"
    echo [OK] Git is installed
) else (
    echo [WARNING] Git not found
    set "MISSING_DEPS=%MISSING_DEPS% Git"
)
echo.

REM Handle missing dependencies
if not "%MISSING_DEPS%"=="" (
    echo ===============================================================================
    echo Missing required dependencies: %MISSING_DEPS%
    echo.
    echo Please install:
    echo   Ruby: https://rubyinstaller.org/downloads/
    echo   Git:  https://git-scm.com/download/win
    echo.
    echo After installing, run this script again.
    echo ===============================================================================
    pause
    exit /b 0
)

REM Full installation
echo.
echo ===============================================================================
echo Starting installation...
echo ===============================================================================
echo.

REM Create config directory
if not exist "%CONFIG_DIR%" (
    mkdir "%CONFIG_DIR%"
    echo [OK] Created: %CONFIG_DIR%
)

REM Create install directory
if not exist "%INSTALL_DIR%" (
    mkdir "%INSTALL_DIR%"
    echo [OK] Created: %INSTALL_DIR%
)

REM Save configuration
echo { > "%CONFIG_FILE%"
echo   "repo_root": "%REPO_ROOT:\=\\%", >> "%CONFIG_FILE%"
echo   "installed_at": "%date% %time%", >> "%CONFIG_FILE%"
echo   "platform": "windows", >> "%CONFIG_FILE%"
echo   "install_mode": "full" >> "%CONFIG_FILE%"
echo } >> "%CONFIG_FILE%"
echo [OK] Saved configuration to %CONFIG_FILE%

REM Create wrapper batch script
set "WRAPPER_PATH=%INSTALL_DIR%\vibe.bat"
echo @echo off > "%WRAPPER_PATH%"
echo setlocal >> "%WRAPPER_PATH%"
echo set "REPO_ROOT=%REPO_ROOT%" >> "%WRAPPER_PATH%"
echo ruby "%%REPO_ROOT%%\bin\vibe" %%* >> "%WRAPPER_PATH%"
echo [OK] Created: %WRAPPER_PATH%

echo.
echo ===============================================================================
echo Installation Complete!
echo ===============================================================================
echo.
echo Quick Start:
echo   vibe --version
echo   vibe doctor
echo   vibe init --platform claude-code
echo.
echo NOTE: Make sure %INSTALL_DIR% is in your PATH
echo.

pause
exit /b 0
