@echo off
REM Vibe installation script for Windows
REM Installs vibe command to user PATH and records project location

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "REPO_ROOT=%SCRIPT_DIR%.."
set "CONFIG_DIR=%USERPROFILE%\.vibe"
set "CONFIG_FILE=%CONFIG_DIR%\config.json"
set "INSTALL_DIR=%USERPROFILE%\.local\bin"

echo Vibe Installation for Windows
echo ==================================================
echo.
echo Project location: %REPO_ROOT%
echo Install target: %INSTALL_DIR%\vibe.bat
echo.

REM Validate repository structure
if not exist "%REPO_ROOT%\core" (
    echo Error: Invalid vibe repository. Missing 'core' directory
    exit /b 1
)
if not exist "%REPO_ROOT%\lib" (
    echo Error: Invalid vibe repository. Missing 'lib' directory
    exit /b 1
)
if not exist "%REPO_ROOT%\bin\vibe" (
    echo Error: bin/vibe not found in repository
    exit /b 1
)

set /p "CONFIRM=Continue? [y/N] "
if /i not "%CONFIRM%"=="y" if /i not "%CONFIRM%"=="yes" (
    echo Installation cancelled.
    exit /b 0
)

echo.
echo Installing...
echo.

REM Create config directory
if not exist "%CONFIG_DIR%" (
    mkdir "%CONFIG_DIR%"
    echo Created config directory: %CONFIG_DIR%
)

REM Save configuration
echo { > "%CONFIG_FILE%"
echo   "repo_root": "%REPO_ROOT:\=\\%", >> "%CONFIG_FILE%"
echo   "installed_at": "%date% %time%", >> "%CONFIG_FILE%"
echo   "platform": "windows" >> "%CONFIG_FILE%"
echo } >> "%CONFIG_FILE%"
echo Saved configuration to %CONFIG_FILE%

REM Create install directory
if not exist "%INSTALL_DIR%" (
    mkdir "%INSTALL_DIR%"
    echo Created install directory: %INSTALL_DIR%
)

REM Create wrapper batch script for cmd.exe/PowerShell
set "WRAPPER_PATH=%INSTALL_DIR%\vibe.bat"
echo @echo off > "%WRAPPER_PATH%"
echo REM Vibe wrapper for Windows (cmd.exe/PowerShell) >> "%WRAPPER_PATH%"
echo setlocal >> "%WRAPPER_PATH%"
echo. >> "%WRAPPER_PATH%"
echo set "CONFIG_FILE=%%USERPROFILE%%\.vibe\config.json" >> "%WRAPPER_PATH%"
echo. >> "%WRAPPER_PATH%"
echo if not exist "%%CONFIG_FILE%%" ( >> "%WRAPPER_PATH%"
echo     echo Error: Vibe not properly installed. Run vibe-install.bat from the repository. >> "%WRAPPER_PATH%"
echo     exit /b 1 >> "%WRAPPER_PATH%"
echo ) >> "%WRAPPER_PATH%"
echo. >> "%WRAPPER_PATH%"
echo REM Parse JSON to get repo_root (simple extraction) >> "%WRAPPER_PATH%"
echo for /f "tokens=2 delims=:," %%%%a in ('findstr "repo_root" "%%CONFIG_FILE%%"') do ( >> "%WRAPPER_PATH%"
echo     set "REPO_ROOT=%%%%a" >> "%WRAPPER_PATH%"
echo     set "REPO_ROOT=!REPO_ROOT:"=!" >> "%WRAPPER_PATH%"
echo     set "REPO_ROOT=!REPO_ROOT: =!" >> "%WRAPPER_PATH%"
echo ) >> "%WRAPPER_PATH%"
echo. >> "%WRAPPER_PATH%"
echo if not exist "%%REPO_ROOT%%\bin\vibe" ( >> "%WRAPPER_PATH%"
echo     echo Error: Vibe repository not found at %%REPO_ROOT%% >> "%WRAPPER_PATH%"
echo     exit /b 1 >> "%WRAPPER_PATH%"
echo ) >> "%WRAPPER_PATH%"
echo. >> "%WRAPPER_PATH%"
echo ruby "%%REPO_ROOT%%\bin\vibe" %%* >> "%WRAPPER_PATH%"
echo Installed cmd.exe wrapper to %WRAPPER_PATH%

REM Create wrapper script for Git Bash/MSYS2 (for Claude Code internal use)
set "BASH_WRAPPER=%INSTALL_DIR%\vibe"
echo #!/bin/bash> "%BASH_WRAPPER%"
echo # Vibe wrapper for Git Bash on Windows>> "%BASH_WRAPPER%"
echo.>> "%BASH_WRAPPER%"
echo # Get config file path (Git Bash uses HOME, not USERPROFILE)>> "%BASH_WRAPPER%"
echo if [ -n "$HOME" ]; then>> "%BASH_WRAPPER%"
echo     CONFIG_FILE="$HOME/.vibe/config.json">> "%BASH_WRAPPER%"
echo else>> "%BASH_WRAPPER%"
echo     CONFIG_FILE="$USERPROFILE/.vibe/config.json">> "%BASH_WRAPPER%"
echo fi>> "%BASH_WRAPPER%"
echo.>> "%BASH_WRAPPER%"
echo if [ ! -f "$CONFIG_FILE" ]; then>> "%BASH_WRAPPER%"
echo     echo "Error: Vibe not properly installed. Run vibe-install.bat from the repository.">> "%BASH_WRAPPER%"
echo     exit 1>> "%BASH_WRAPPER%"
echo fi>> "%BASH_WRAPPER%"
echo.>> "%BASH_WRAPPER%"
echo # Extract repo_root from JSON>> "%BASH_WRAPPER%"
echo REPO_ROOT=$(grep -o '"repo_root"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" ^| sed 's/.*"repo_root"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')>> "%BASH_WRAPPER%"
echo.>> "%BASH_WRAPPER%"
echo # Convert Windows path to Git Bash format>> "%BASH_WRAPPER%"
echo # C:\path\to\repo -^> /c/path/to/repo>> "%BASH_WRAPPER%"
echo REPO_ROOT=$(echo "$REPO_ROOT" ^| sed 's/\\/\//g' ^| sed 's/^C:/\/c/' ^| sed 's/^D:/\/d/' ^| sed 's/^E:/\/e/')>> "%BASH_WRAPPER%"
echo.>> "%BASH_WRAPPER%"
echo if [ ! -f "$REPO_ROOT/bin/vibe" ]; then>> "%BASH_WRAPPER%"
echo     echo "Error: Vibe repository not found at $REPO_ROOT">> "%BASH_WRAPPER%"
echo     exit 1>> "%BASH_WRAPPER%"
echo fi>> "%BASH_WRAPPER%"
echo.>> "%BASH_WRAPPER%"
echo # Run the Ruby script with all arguments>> "%BASH_WRAPPER%"
echo ruby "$REPO_ROOT/bin/vibe" "$@">> "%BASH_WRAPPER%"
echo Created Git Bash wrapper at %BASH_WRAPPER%

echo.
echo ========================================
echo Installation complete!
echo ========================================
echo.
echo Next steps:
echo 1. Add %INSTALL_DIR% to your PATH if not already added
echo    - Open System Properties ^> Environment Variables
echo    - Add %INSTALL_DIR% to your user PATH
echo.
echo 2. Verify installation: vibe --version
echo.
echo 3. Run 'vibe init --platform claude-code' to set up global configuration
echo.

endlocal
