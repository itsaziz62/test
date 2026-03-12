@echo off
:: ==========================================================================
:: Seismic Pipeline - Windows Setup (One-Click)
:: Double-click this file to install everything automatically
:: Requirements: Windows 10 (Build 19041+) or Windows 11
:: ==========================================================================

title Seismic Pipeline - Windows Setup
color 0A

echo.
echo ============================================================
echo   Seismic Pipeline - Windows Setup
echo ============================================================
echo.

:: --------------------------------------------------------------------------
:: STEP 1 - Check Windows version
:: --------------------------------------------------------------------------
echo [1/5] Checking Windows version...
for /f "tokens=4-5 delims=. " %%i in ('ver') do set VERSION=%%i.%%j
echo       Windows version: %VERSION%

:: Check if Build >= 19041 (needed for WSL2)
for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber 2^>nul') do set BUILD=%%a
if %BUILD% LSS 19041 (
    echo.
    echo [ERROR] Windows Build %BUILD% detected.
    echo         WSL 2 requires Build 19041 or higher.
    echo         Please update Windows first: Settings > Windows Update
    echo.
    pause
    exit /b 1
)
echo       Build %BUILD% - OK
echo.

:: --------------------------------------------------------------------------
:: STEP 2 - Enable WSL & Virtual Machine Platform
:: --------------------------------------------------------------------------
echo [2/5] Enabling WSL 2 features (requires Admin)...
echo       This may take a moment...
echo.

:: Check if running as admin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Please run this script as Administrator!
    echo         Right-click setup.bat → "Run as administrator"
    echo.
    pause
    exit /b 1
)

:: Enable features
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart >nul 2>&1
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart >nul 2>&1
wsl --set-default-version 2 >nul 2>&1
echo       WSL 2 features enabled - OK
echo.

:: --------------------------------------------------------------------------
:: STEP 3 - Install Ubuntu 20.04
:: --------------------------------------------------------------------------
echo [3/5] Checking Ubuntu 20.04...

:: Check if Ubuntu already installed
wsl -l -q 2>nul | findstr /i "Ubuntu-20.04" >nul
if %errorlevel% equ 0 (
    echo       Ubuntu-20.04 already installed - OK
) else (
    echo       Installing Ubuntu-20.04 from Microsoft Store...
    echo       A browser window will open. Click "Get" then "Install".
    echo.
    start ms-windows-store://pdp/?ProductId=8PNK1KHX424W
    echo.
    echo       After installing Ubuntu, open it once to set username/password,
    echo       then close it and re-run this script.
    echo.
    pause
    exit /b 0
)
echo.

:: --------------------------------------------------------------------------
:: STEP 4 - Check Docker Desktop
:: --------------------------------------------------------------------------
echo [4/5] Checking Docker Desktop...

where docker >nul 2>&1
if %errorlevel% neq 0 (
    echo       Docker not found. Opening download page...
    echo       Install Docker Desktop and enable "Use WSL 2 backend" during setup.
    echo.
    start https://www.docker.com/products/docker-desktop/
    echo       After installing Docker Desktop:
    echo         1. Open Docker Desktop
    echo         2. Settings > Resources > WSL Integration
    echo         3. Enable for Ubuntu-20.04
    echo         4. Re-run this script
    echo.
    pause
    exit /b 0
) else (
    echo       Docker found - OK
)
echo.

:: --------------------------------------------------------------------------
:: STEP 5 - Clone repos & run pipeline inside WSL
:: --------------------------------------------------------------------------
echo [5/5] Setting up pipeline inside WSL...
echo.

:: Run the rest inside WSL Ubuntu
wsl -d Ubuntu-20.04 bash -c ^
"set -e; ^
echo '--- Creating folders ---'; ^
mkdir -p ~/Documents; ^
cd ~/Documents; ^
if [ ! -d 'Automation' ]; then ^
  echo '--- Cloning pipeline repo ---'; ^
  git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git Automation; ^
fi; ^
if [ ! -d 'EQTransformer-master' ]; then ^
  echo '--- Cloning EQTransformer ---'; ^
  git clone https://github.com/smousavi05/EQTransformer.git EQTransformer-master; ^
fi; ^
echo '--- Copying EQTransformer into project ---'; ^
cp -r EQTransformer-master Automation/EQTransformer-master; ^
echo '--- Creating required folders ---'; ^
mkdir -p Automation/data Automation/Output Automation/config Automation/Model; ^
echo '--- Starting Docker pipeline ---'; ^
cd Automation; ^
docker compose up"

echo.
echo ============================================================
echo   Setup Complete! Pipeline is now running.
echo ============================================================
echo.
echo   To run again later, open Ubuntu-20.04 terminal and type:
echo     cd ~/Documents/Automation
echo     docker compose up
echo.
echo   For GPU support:
echo     docker compose --profile gpu up
echo.
pause
