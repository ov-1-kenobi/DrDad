@echo off
REM Double-click to switch to the FAST model (qwen3-14b-cc). Restart Claude Code after.
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0use-model.ps1" fast
echo.
pause
endlocal
