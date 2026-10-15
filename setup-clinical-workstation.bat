@echo off
setlocal
REM ==========================================================================
REM  Clinical Workstation Provisioner -- Citrix + Epic EHR
REM --------------------------------------------------------------------------
REM  RECONSTRUCTION (2026) of a script originally written ~2016-2018 at
REM  MemorialCare. The original was a one-click .bat that installed and
REM  configured Citrix on ambulatory-site workstations so clinicians could
REM  reach the Epic EHR server back at the hospital -- plus automatic Windows
REM  network tuning for clinical use. No other clinical training specialist
REM  had automated it. It got the author promoted.
REM
REM  The original file is lost. This is rebuilt from  memory.
REM  Blocks tagged [ORIGINAL] are as remembered. Blocks tagged [RECONSTRUCTED]
REM  fill gaps with standard Citrix/Epic deployment practice of the era.
REM  Validate every default before pointing this at real infrastructure.
REM ==========================================================================

REM ============================ CONFIG ======================================
REM  Everything site-specific lives here. Change these, nothing else.

set "INSTALLER_URL=https://downloadplugins.citrix.com/[your-org]/CitrixWorkspaceApp.exe"
set "INSTALLER_EXE=%TEMP%\CitrixWorkspaceApp.exe"

set "STORE_NAME=ClinicalApps"
set "STORE_URL=https://storefront.hospital.example.com/Citrix/ClinicalApps/discovery"
set "STORE_DESC=Hospital Clinical Apps"

set "EPIC_HOST=epic.hospital.example.com"

set "LOG=%TEMP%\clinical-workstation-setup.log"
REM ========================== END CONFIG ====================================


call :log "=== Clinical Workstation Provisioner starting ==="

REM ---- 1. Must run as administrator [ORIGINAL] ------------------------------
net session >nul 2>&1
if %errorlevel% neq 0 (
    call :log "ERROR: not running as administrator."
    echo This script must be run as Administrator. Right-click the file and choose "Run as administrator".
    pause
    exit /b 1
)
call :log "Administrator rights confirmed."

REM ---- 2. Fetch the Citrix installer -----------------------------------------
REM  [ORIGINAL] the script downloaded the Citrix client onto the machine.
REM  [RECONSTRUCTED] the original likely copied it from a hospital network
REM  share; HTTPS download is used here so the script is self-contained.
call :log "Downloading Citrix installer..."
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri '%INSTALLER_URL%' -OutFile '%INSTALLER_EXE%' -UseBasicParsing" >> "%LOG%" 2>&1
if %errorlevel% neq 0 (
    call :log "ERROR: download failed. Check INSTALLER_URL in the CONFIG block."
    echo Download failed - see %LOG%.
    pause
    exit /b 1
)
call :log "Download complete."

REM ---- 3. Silent install with the store preconfigured [ORIGINAL] -------------
REM  The STORE0 parameter bakes the StoreFront account into the install so
REM  clinicians never have to type a server address themselves.
call :log "Installing Citrix silently..."
"%INSTALLER_EXE%" /silent STORE0="%STORE_NAME%;%STORE_URL%;On;%STORE_DESC%" >> "%LOG%" 2>&1
if %errorlevel% neq 0 (
    call :log "WARNING: installer exited with code %errorlevel%. Continuing - install will be verified next."
)
REM Give the installer a moment to settle before verification.
timeout /t 15 /nobreak >nul

REM ---- 4. Verify the install [RECONSTRUCTED] ---------------------------------
if exist "%ProgramFiles(x86)%\Citrix\ICA Client\SelfServicePlugin\SelfService.exe" (
    call :log "Verified: Citrix SelfService present (x86)."
) else if exist "%ProgramFiles%\Citrix\ICA Client\SelfServicePlugin\SelfService.exe" (
    call :log "Verified: Citrix SelfService present (x64)."
) else (
    call :log "ERROR: Citrix install not found after setup. Aborting."
    echo Install verification failed - see %LOG%.
    pause
    exit /b 1
)

REM ---- 5. Windows network tuning for Epic over Citrix -------------------------
REM  [ORIGINAL] in purpose: the script automatically improved network settings
REM  on Windows for clinical Epic use. The author recalls borrowing these
REM  tweaks from Chris Titus Tech's Ultimate Windows Utility (winutil).
REM  [RECONSTRUCTED] in exact settings. The tweaks below are standard
REM  equivalents - re-validate against current Epic and Citrix documentation
REM  before use.
call :log "Applying network tuning..."
REM Constrain TCP auto-tuning: unrestricted auto-tuning could starve thin ICA sessions.
netsh interface tcp set global autotuninglevel=restricted >> "%LOG%" 2>&1
REM Era-accurate: disable chimney offload, a known source of flaky ICA sessions.
netsh interface tcp set global chimney=disabled >> "%LOG%" 2>&1
call :log "Network tuning applied."

REM ---- 6. Telemetry removal ----------------------------------------------------
REM  [ORIGINAL] in purpose: the script stripped Windows telemetry, with the
REM  approach borrowed from Chris Titus Tech's Ultimate Windows Utility.
REM  [RECONSTRUCTED] in exact commands - standard equivalents below.
REM  Credit: https://github.com/ChrisTitusTech/winutil (MIT licensed).
call :log "Removing Windows telemetry..."
REM Disable telemetry via group policy registry key.
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f >> "%LOG%" 2>&1
REM Disable the Connected User Experiences and Telemetry service.
sc stop DiagTrack >nul 2>&1
sc config DiagTrack start= disabled >> "%LOG%" 2>&1
REM Disable the dmwappushservice (telemetry push).
sc stop dmwappushsvc >nul 2>&1
sc config dmwappushsvc start= disabled >> "%LOG%" 2>&1
REM Disable telemetry scheduled tasks.
schtasks /Change /TN "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator" /Disable >nul 2>&1
schtasks /Change /TN "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip" /Disable >nul 2>&1
schtasks /Change /TN "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" /Disable >nul 2>&1
schtasks /Change /TN "\Microsoft\Windows\Application Experience\ProgramDataUpdater" /Disable >nul 2>&1
call :log "Telemetry removal applied."

REM ---- 7. Connectivity test ---------------------------------------------------
REM  [ORIGINAL] the script configured AND tested the connection.
REM  [RECONSTRUCTED] exact test method: reach the Epic host and confirm the
REM  StoreFront discovery endpoint answers over HTTPS.
call :log "Testing connectivity to %EPIC_HOST%..."
ping -n 2 "%EPIC_HOST%" >nul 2>&1
if %errorlevel% neq 0 (
    call :log "WARNING: cannot ping %EPIC_HOST%. Possible network or DNS issue."
) else (
    call :log "Ping to %EPIC_HOST% OK."
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { 'StoreFront HTTPS status: ' + (Invoke-WebRequest -Uri '%STORE_URL%' -UseBasicParsing -TimeoutSec 15).StatusCode } catch { 'StoreFront HTTPS FAILED: ' + $_.Exception.Message }" >> "%LOG%" 2>&1
call :log "StoreFront reachability check done - see log for result."

REM ---- 8. Cleanup --------------------------------------------------------------
del /f /q "%INSTALLER_EXE%" 2>nul
call :log "Installer cleaned up."
call :log "=== Done. Workstation provisioned. ==="
echo.
echo Workstation provisioned. Full log: %LOG%
echo A restart is recommended to finalize the Citrix install.
set /p "REBOOT=Restart now? (Y/N): "
if /i "%REBOOT%"=="Y" (
    call :log "Restarting at user request."
    shutdown /r /t 10 /c "Restarting to finalize Citrix clinical workstation setup."
)
pause
exit /b 0

:log
echo [%DATE% %TIME%] %~1>> "%LOG%"
echo %~1
goto :eof
