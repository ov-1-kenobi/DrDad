@echo off
REM Double-click to switch to the QUALITY model (qwen3-coder-next-cc). Restart Claude Code after.
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0use-model.ps1" quality
echo.
pause
endlocal
