@echo off
REM Install pre-session-end hook for Windows
REM Supports both cmd.exe and PowerShell environments

setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "HOOK_SOURCE_BAT=%SCRIPT_DIR%pre-session-end.bat"
set "HOOK_DEST_DIR=%USERPROFILE%\.claude\hooks"
set "HOOK_DEST_BAT=%HOOK_DEST_DIR%\pre-session-end.bat"
set "SETTINGS_FILE=%USERPROFILE%\.claude\settings.json"

echo Installing pre-session-end hook for Windows...
echo.

REM Create hooks directory if it doesn't exist
if not exist "%HOOK_DEST_DIR%" (
    mkdir "%HOOK_DEST_DIR%"
    echo Created hooks directory: %HOOK_DEST_DIR%
)

REM Copy hook script
echo Copying hook to %HOOK_DEST_BAT%
copy /Y "%HOOK_SOURCE_BAT%" "%HOOK_DEST_BAT%" >nul
if errorlevel 1 (
    echo Error: Failed to copy hook script
    exit /b 1
)

REM Check if settings.json exists
if not exist "%SETTINGS_FILE%" (
    echo Creating %SETTINGS_FILE%
    echo {} > "%SETTINGS_FILE%"
)

REM Check if hook is already configured
findstr /C:"PreSessionEnd" "%SETTINGS_FILE%" >nul 2>&1
if not errorlevel 1 (
    echo.
    echo Warning: PreSessionEnd hook already configured in settings.json
    echo Please manually verify the configuration.
) else (
    echo Configuring hook in settings.json
    echo.
    echo Please manually add the following to %SETTINGS_FILE%:
    echo.
    echo   "hooks": {
    echo     "PreSessionEnd": [
    echo       {
    echo         "type": "command",
    echo         "command": "%HOOK_DEST_BAT:\=\\%"
    echo       }
    echo     ]
    echo   }
    echo.
)

echo.
echo ========================================
echo Installation complete!
echo ========================================
echo.
echo The hook will prompt you to save progress before exiting Claude Code.
echo.

endlocal
