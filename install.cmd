@echo off
REM install.cmd - double-click (or run) launcher for install.ps1.
REM Runs the PowerShell installer from THIS folder with execution policy bypassed,
REM so you don't have to type the powershell incantation. Passes through any args.
setlocal
echo ============================================================
echo  Local Claude Code kit - installer
echo ============================================================
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" (
  echo Installer finished. See the steps printed above.
) else (
  echo Installer exited with code %RC%. Scroll up for the error.
)
echo.
pause
endlocal
