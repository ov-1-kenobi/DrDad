@echo off
REM uninstall.cmd - launcher for uninstall.ps1. Pass -Full for the deep clean.
REM   uninstall.cmd          (remove commands/agents + restore settings.json)
REM   uninstall.cmd -Full    (also: ollama -cc model variants + OLLAMA_* env vars)
setlocal
echo ============================================================
echo  AD-kit - uninstall
echo ============================================================
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1" %*
echo.
pause
endlocal
