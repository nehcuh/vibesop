@echo off
REM Vibe installation script for Windows with environment detection
REM Features:
REM   - Detects required dependencies (Ruby, Git)
REM   - Provides installation guidance for missing dependencies
REM   - Offers automated installer downloads where possible
REM   - Fallback to bash-only mode if Ruby is unavailable

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
set "HAS_BUN=0"
set "HAS_NPM=0"

REM Color codes for Windows 10+ (will work in Windows Terminal and modern CMD)
for /F %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "RED=%ESC%[31m"
set "GREEN=%ESC%[32m"
set "YELLOW=%ESC%[33m"
set "BLUE=%ESC%[34m"
set "CYAN=%ESC%[36m"
set "BOLD=%ESC%[1m"
set "NC=%ESC%[0m"

REM ========================================
REM Print Functions
REM ========================================

:print_header
echo.
echo %BOLD%%CYAN%██╗   ██╗███████╗██████╗       ██╗   ██╗██╗██████╗ ███████╗%NC%
echo %BOLD%%CYAN%██║   ██║██╔════╝██╔══██╗      ██║   ██║██║██╔══██╗██╔════╝%NC%
echo %BOLD%%CYAN%██║   ██║█████╗  ██████╔╝█████╗██║   ██║██║██║  ██║█████╗  %NC%
echo %BOLD%%CYAN%╚██╗ ██╔╝██╔══╝  ██╔══██╗╚════╝██║   ██║██║██║  ██║██╔══╝  %NC%
echo %BOLD%%CYAN% ╚████╔╝ ███████╗██████╔╝      ╚██████╔╝██║██████╔╝███████╗%NC%
echo %BOLD%%CYAN%  ╚═══╝  ╚══════╝╚═════╝        ╚═════╝ ╚═╝╚═════╝ ╚══════╝%NC%
echo.
echo %BOLD%Windows Installation Wizard%NC%
echo ================================================================================
echo.
goto :eof

:print_success
echo %GREEN%✓%NC% %~1
goto :eof

:print_error
echo %RED%✗%NC% %~1
goto :eof

:print_warning
echo %YELLOW⚠%NC% %~1
goto :eof

:print_info
echo %BLUEℹ%NC% %~1
goto :eof

:print_section
echo.
echo %BOLD%%CYAN%▶ %~1%NC%
echo -------------------------------------------------------------------------------
goto :eof

:print_sub
echo   %~1
goto :eof

:print_divider
echo ================================================================================
echo.
goto :eof

REM ========================================
REM Environment Detection
REM ========================================

:detect_ruby
set "HAS_RUBY=0"
where ruby >nul 2>&1
if %errorlevel% equ 0 (
    set "HAS_RUBY=1"
    for /f "tokens=2" %%i in ('ruby -v 2^>^&1 ^| findstr /r "^ruby"') do set "RUBY_VERSION=%%i"
    call :print_success "Ruby found: !RUBY_VERSION!"
) else (
    call :print_error "Ruby not found"
    set "MISSING_DEPS=%MISSING_DEPS% Ruby"
)
goto :eof

:detect_git
set "HAS_GIT=0"
where git >nul 2>&1
if %errorlevel% equ 0 (
    set "HAS_GIT=1"
    for /f "tokens=3" %%i in ('git --version 2^>^&1') do set "GIT_VERSION=%%i"
    call :print_success "Git found: !GIT_VERSION!"
) else (
    call :print_error "Git not found"
    set "MISSING_DEPS=%MISSING_DEPS% Git"
)
goto :eof

:detect_node_tools
where bun >nul 2>&1
if %errorlevel% equ 0 (
    set "HAS_BUN=1"
    call :print_success "Bun found (optional)"
) else (
    call :print_sub "Bun not found (optional, for some features)"
)

where npm >nul 2>&1
if %errorlevel% equ 0 (
    set "HAS_NPM=1"
    for /f "tokens=1" %%i in ('npm -v 2^>^&1') do set "NPM_VERSION=%%i"
    call :print_success "NPM found: !NPM_VERSION! (optional)"
) else (
    call :print_sub "NPM not found (optional, for some features)"
)
goto :eof

:detect_all
call :print_section "Environment Detection"
call :detect_ruby
call :detect_git
call :detect_node_tools

if "%MISSING_DEPS%"=="" (
    call :print_success "All required dependencies found!"
) else (
    call :print_warning "Missing required dependencies:%MISSING_DEPS%"
)
goto :eof

REM ========================================
REM Installation Guidance
REM ========================================

:show_ruby_install_guide
call :print_section "Ruby Installation Guide"

echo Ruby is required for vibe to function properly.
echo.
echo %BOLD%Recommended Installation Methods:%NC%
echo.
echo   1. %BOLD%RubyInstaller (Recommended)%NC%
echo      Download: https://rubyinstaller.org/downloads/
echo      - Choose version 3.0 or higher
echo      - During install, check "Add Ruby to PATH"
echo      - Also install "MSYS2 development tools" when prompted
echo.
echo   2. %BOLD%Chocolatey (if already installed)%NC%
echo      choco install ruby
echo.
echo   3. %BOLD%Scoop (if already installed)%NC%
echo      scoop install ruby
echo.
echo   4. %BOLD%Winget (Windows 10+)%NC%
echo      winget install RubyInstaller.Ruby
echo.
goto :eof

:show_git_install_guide
call :print_section "Git Installation Guide"

echo Git is required for version control and vibe operations.
echo.
echo %BOLD%Recommended Installation Methods:%NC%
echo.
echo   1. %BOLD%Git for Windows (Recommended)%NC%
echo      Download: https://git-scm.com/download/win
echo      - During install, choose "Git from the command line"
echo      - Recommended: "Checkout Windows-style, commit Unix-style line endings"
echo.
echo   2. %BOLD%Chocolatey (if already installed)%NC%
echo      choco install git
echo.
echo   3. %BOLD%Scoop (if already installed)%NC%
echo      scoop install git
echo.
echo   4. %BOLD%Winget (Windows 10+)%NC%
echo      winget install Git.Git
echo.
goto :eof

:show_bun_install_guide
call :print_section "Bun Installation Guide (Optional)"

echo Bun is optional but recommended for faster package operations.
echo.
echo %BOLD%Installation Methods:%NC%
echo.
echo   1. %BOLD%Official Script (PowerShell)%NC%
echo      irm bun.sh/install.ps1 ^| iex
echo.
echo   2. %BOLD%Chocolatey (if already installed)%NC%
echo      choco install bun
echo.
echo   3. %BOLD%Scoop (if already installed)%NC%
echo      scoop install bun
echo.
echo   4. %BOLD%Winget (Windows 10+)%NC%
echo      winget install Oven-Sh.Bun
echo.
goto :eof

:open_download_page
set "URL=%~1"
call :print_info "Opening download page in your default browser..."
echo.
echo %CYAN%If the browser doesn't open automatically, visit:%NC%
echo   %URL%
echo.

REM Try to open URL with default methods
start "" "%URL%" 2>nul
timeout /t 2 >nul

REM If start failed, try PowerShell
if errorlevel 1 (
    powershell -Command "Start-Process '%URL%'" 2>nul
)
goto :eof

REM ========================================
REM Installation Options
REM ========================================

:install_ruby
call :show_ruby_install_guide
call :print_divider
echo.
echo %BOLD%Options:%NC%
echo   1. Open RubyInstaller download page
echo   2. Install via winget (Windows 10+)
echo   3. Install via choco (if Chocolatey is installed)
echo   4. Skip for now (limited functionality)
echo.
choice /c 1234 /n /m "Select option (1-4): "
if errorlevel 4 goto :eof
if errorlevel 3 (
    where choco >nul 2>&1
    if errorlevel 1 (
        call :print_error "Chocolatey not found. Please install Ruby manually."
        pause
        goto :install_ruby
    )
    call :print_info "Installing Ruby via Chocolatey..."
    choco install ruby -y
    if errorlevel 0 (
        call :print_success "Ruby installed! Please restart your command prompt."
        pause
        exit /b 0
    )
)
if errorlevel 2 (
    call :print_info "Installing Ruby via winget..."
    winget install RubyInstaller.Ruby
    if errorlevel 0 (
        call :print_success "Ruby installed! Please restart your command prompt."
        pause
        exit /b 0
    )
)
if errorlevel 1 (
    call :open_download_page "https://rubyinstaller.org/downloads/"
    call :print_info "After installing Ruby, close and reopen this window, then run the installer again."
    pause
    exit /b 0
)
goto :eof

:install_git
call :show_git_install_guide
call :print_divider
echo.
echo %BOLD%Options:%NC%
echo   1. Open Git for Windows download page
echo   2. Install via winget (Windows 10+)
echo   3. Install via choco (if Chocolatey is installed)
echo   4. Install via scoop (if Scoop is installed)
echo   5. Skip for now
echo.
choice /c 12345 /n /m "Select option (1-5): "
if errorlevel 5 goto :eof
if errorlevel 4 (
    where scoop >nul 2>&1
    if errorlevel 1 (
        call :print_error "Scoop not found. Please install Git manually."
        pause
        goto :install_git
    )
    call :print_info "Installing Git via Scoop..."
    scoop install git
    if errorlevel 0 (
        call :print_success "Git installed! Please restart your command prompt."
        pause
        exit /b 0
    )
)
if errorlevel 3 (
    where choco >nul 2>&1
    if errorlevel 1 (
        call :print_error "Chocolatey not found. Please install Git manually."
        pause
        goto :install_git
    )
    call :print_info "Installing Git via Chocolatey..."
    choco install git -y
    if errorlevel 0 (
        call :print_success "Git installed! Please restart your command prompt."
        pause
        exit /b 0
    )
)
if errorlevel 2 (
    call :print_info "Installing Git via winget..."
    winget install Git.Git
    if errorlevel 0 (
        call :print_success "Git installed! Please restart your command prompt."
        pause
        exit /b 0
    )
)
if errorlevel 1 (
    call :open_download_page "https://git-scm.com/download/win"
    call :print_info "After installing Git, close and reopen this window, then run the installer again."
    pause
    exit /b 0
)
goto :eof

REM ========================================
REM Fallback Mode
REM ========================================

:install_fallback_mode
call :print_section "Limited Installation (Bash Fallback Mode)"
echo.
echo %YELLOW%Since Ruby is not available, vibe will be installed in limited mode.%NC%
echo.
echo %BOLD%What works in limited mode:%NC%
echo   - build: Build pre-generated configurations
echo   - switch: Apply configurations to your project
echo   - targets: List available configurations
echo   - doctor: Check environment status
echo.
echo %BOLD%What won't work:%NC%
echo   - init: Initialize new configurations
echo   - route: AI-powered skill routing
echo   - skills: Manage skills
echo   - inspect: Configuration inspection
echo.
echo For full functionality, please install Ruby and run this installer again.
echo.
choice /c YN /n /m "Install in limited mode? [Y/N]: "
if errorlevel 2 goto :eof

call :do_install fallback
goto :eof

REM ========================================
REM Main Installation
REM ========================================

:validate_repo
if not exist "%REPO_ROOT%\core" (
    call :print_error "Invalid vibe repository. Missing 'core' directory"
    exit /b 1
)
if not exist "%REPO_ROOT%\lib" (
    call :print_error "Invalid vibe repository. Missing 'lib' directory"
    exit /b 1
)
if not exist "%REPO_ROOT%\bin\vibe" (
    call :print_error "bin/vibe not found in repository"
    exit /b 1
)
call :print_success "Repository structure validated"
goto :eof

:do_install
set "MODE=%~1"

REM Create config directory
if not exist "%CONFIG_DIR%" (
    mkdir "%CONFIG_DIR%"
    call :print_success "Created config directory: %CONFIG_DIR%"
)

REM Save configuration
echo { > "%CONFIG_FILE%"
echo   "repo_root": "%REPO_ROOT:\=\\%", >> "%CONFIG_FILE%"
echo   "installed_at": "%date% %time%", >> "%CONFIG_FILE%"
echo   "platform": "windows", >> "%CONFIG_FILE%"
echo   "install_mode": "%MODE%" >> "%CONFIG_FILE%"
echo } >> "%CONFIG_FILE%"
call :print_success "Saved configuration to %CONFIG_FILE%"

REM Create install directory
if not exist "%INSTALL_DIR%" (
    mkdir "%INSTALL_DIR%"
    call :print_success "Created install directory: %INSTALL_DIR%"
)

REM Create wrapper batch script
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
echo REM Parse JSON to get repo_root and install_mode >> "%WRAPPER_PATH%"
echo for /f "tokens=2 delims=:," %%%%a in ('findstr "repo_root" "%%CONFIG_FILE%%"') do ( >> "%WRAPPER_PATH%"
echo     set "REPO_ROOT=%%%%a" >> "%WRAPPER_PATH%"
echo     set "REPO_ROOT=!REPO_ROOT:"=!" >> "%WRAPPER_PATH%"
echo     set "REPO_ROOT=!REPO_ROOT: =!" >> "%WRAPPER_PATH%"
echo ) >> "%WRAPPER_PATH%"
echo. >> "%WRAPPER_PATH%"
echo REM Check install mode for fallback >> "%WRAPPER_PATH%"
echo findstr /c:"fallback" "%%CONFIG_FILE%%" ^>nul 2^>^&1 >> "%WRAPPER_PATH%"
echo if %%errorlevel%% equ 0 ( >> "%WRAPPER_PATH%"
echo     REM Fallback mode: use vibe-bash.sh >> "%WRAPPER_PATH%"
echo     bash "%%REPO_ROOT%%\bin\vibe-bash.sh" %%* >> "%WRAPPER_PATH%"
echo ) else ( >> "%WRAPPER_PATH%"
echo     REM Full mode: use Ruby >> "%WRAPPER_PATH%"
echo     ruby "%%REPO_ROOT%%\bin\vibe" %%* >> "%WRAPPER_PATH%"
echo ) >> "%WRAPPER_PATH%"

call :print_success "Installed cmd.exe wrapper to %WRAPPER_PATH%"

REM Create wrapper script for Git Bash
set "BASH_WRAPPER=%INSTALL_DIR%\vibe"
echo #!/bin/bash> "%BASH_WRAPPER%"
echo # Vibe wrapper for Git Bash on Windows>> "%BASH_WRAPPER%"
echo.>> "%BASH_WRAPPER%"
echo # Get config file path>> "%BASH_WRAPPER%"
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
echo REPO_ROOT=$(grep -o '"repo_root"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" 2^>/dev/null ^| sed 's/.*"repo_root"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')>> "%BASH_WRAPPER%"
echo.>> "%BASH_WRAPPER%"
echo # Extract install_mode>> "%BASH_WRAPPER%"
echo INSTALL_MODE=$(grep -o '"install_mode"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" 2^>/dev/null ^| sed 's/.*"install_mode"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')>> "%BASH_WRAPPER%"
echo.>> "%BASH_WRAPPER%"
echo # Convert Windows path to Git Bash format>> "%BASH_WRAPPER%"
echo REPO_ROOT=$(echo "$REPO_ROOT" ^| sed 's/\\/\//g' ^| sed 's/^\([A-Za-z]\)::/\L\1/')>> "%BASH_WRAPPER%"
echo.>> "%BASH_WRAPPER%"
echo # Check install mode>> "%BASH_WRAPPER%"
echo if [ "$INSTALL_MODE" = "fallback" ]; then>> "%BASH_WRAPPER%"
echo     # Fallback mode: use vibe-bash.sh>> "%BASH_WRAPPER%"
echo     exec "$REPO_ROOT/bin/vibe-bash.sh" "$@">> "%BASH_WRAPPER%"
echo else>> "%BASH_WRAPPER%"
echo     # Full mode: use Ruby>> "%BASH_WRAPPER%"
echo     if [ ! -f "$REPO_ROOT/bin/vibe" ]; then>> "%BASH_WRAPPER%"
echo         echo "Error: Vibe repository not found at $REPO_ROOT">> "%BASH_WRAPPER%"
echo         exit 1>> "%BASH_WRAPPER%"
echo     fi>> "%BASH_WRAPPER%"
echo     exec ruby "$REPO_ROOT/bin/vibe" "$@">> "%BASH_WRAPPER%"
echo fi>> "%BASH_WRAPPER%"

call :print_success "Created Git Bash wrapper at %BASH_WRAPPER%"

REM Check PATH
echo %INSTALL_DIR% | findstr /C:"%PATH%" >nul
if errorlevel 1 (
    call :print_warning "%INSTALL_DIR% is not in your PATH"
    echo.
    echo %BOLD%To add vibe to your PATH:%NC%
    echo   1. Press Win+R, type: sysdm.cpl
    echo   2. Go to Advanced ^> Environment Variables
    echo   3. Edit "Path" under User variables
    echo   4. Add: %INSTALL_DIR%
    echo.
    echo   Or run this command as Administrator:
    echo   setx PATH "%PATH%;%INSTALL_DIR%"
    echo.
) else (
    call :print_success "%INSTALL_DIR% is already in your PATH"
)
goto :eof

:show_completion
call :print_divider
echo %BOLD%%GREEN%Installation Complete!%NC%
echo ================================================================================
echo.
if "%~1"=="fallback" (
    echo %YELLOW%Limited mode installed (Ruby not found)%NC%
    echo.
    echo To enable full functionality:
    echo   1. Install Ruby from https://rubyinstaller.org/downloads/
    echo   2. Restart this window
    echo   3. Run: vibe-install.bat
    echo.
) else (
    echo %GREEN%Full mode installed!%NC%
    echo.
)
echo %BOLD%Quick Start:%NC%
echo   vibe --version
echo   vibe doctor
echo   vibe init --platform claude-code
echo.
echo %BOLD%Documentation:%NC%
echo   https://github.com/your-org/vibesop
echo.
goto :eof

REM ========================================
REM Main Entry Point
REM ========================================

:main
cls
call :print_header

REM Validate repository
call :validate_repo
if errorlevel 1 exit /b 1

REM Detect environment
call :detect_all

REM Handle missing dependencies
if not "%MISSING_DEPS%"=="" (
    call :print_divider
    call :print_warning "Installation cannot proceed without required dependencies"
    echo.

    REM Check each missing dependency
    if "%HAS_RUBY%"=="0" (
        call :install_ruby
        REM Re-detect after potential installation
        call :detect_ruby
    )

    if "%HAS_GIT%"=="0" (
        call :install_git
        REM Re-detect after potential installation
        call :detect_git
    )

    REM Re-check
    if "%HAS_RUBY%"=="0" (
        echo.
        call :print_error "Ruby is still not found"
        choice /c YN /n /m "Install in limited mode without Ruby? [Y/N]: "
        if errorlevel 2 (
            echo Installation cancelled.
            exit /b 0
        )
        call :install_fallback_mode
        call :show_completion fallback
        exit /b 0
    )
)

REM Full installation
call :print_divider
call :print_section "Installing Vibe"
call :do_install full
call :show_completion full

pause
exit /b 0

REM Run main
:main
