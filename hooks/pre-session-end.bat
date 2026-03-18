@echo off
REM Pre-Session-End Hook for Windows
REM Prompts user to save session progress before exiting Claude Code

setlocal enabledelayedexpansion

echo ========================================
echo   Session End Detected
echo ========================================
echo.

REM Check if we're in a git repository
git rev-parse --git-dir >nul 2>&1
if errorlevel 1 (
    echo Not in a git repository. Skipping session save.
    exit /b 0
)

REM Check if memory/ directory exists
if not exist "memory" (
    echo No memory/ directory found. Creating...
    mkdir memory
)

REM Check if there are uncommitted changes
git diff --quiet >nul 2>&1
set "DIFF_EXIT=%errorlevel%"
git diff --cached --quiet >nul 2>&1
set "CACHED_EXIT=%errorlevel%"

if not "%DIFF_EXIT%"=="0" (
    echo Warning: You have uncommitted changes.
    echo.
) else if not "%CACHED_EXIT%"=="0" (
    echo Warning: You have uncommitted changes.
    echo.
)

REM Prompt user
echo Would you like to save your session progress?
echo.
echo This will:
echo   - Update memory/session.md with current progress
echo   - Record any lessons learned in memory/project-knowledge.md
echo   - Update PROJECT_CONTEXT.md (if exists)
echo.
echo Options:
echo   [y] Yes, save session progress (recommended)
echo   [n] No, exit without saving
echo   [c] Cancel exit, continue working
echo.

set /p "CHOICE=Your choice [y/n/c]: "

if /i "%CHOICE%"=="y" (
    echo.
    echo Triggering session-end...
    echo.
    REM Return special exit code to trigger session-end
    exit /b 42
) else if /i "%CHOICE%"=="n" (
    echo.
    echo Warning: Exiting without saving. Progress may be lost.
    echo.
    exit /b 0
) else if /i "%CHOICE%"=="c" (
    echo.
    echo Cancelled exit. Continue working.
    echo.
    exit /b 1
) else (
    echo.
    echo Invalid choice. Cancelling exit.
    echo.
    exit /b 1
)

endlocal
