@echo off
REM use-model.cmd - switch the Claude Code session model (wrapper for use-model.ps1).
REM Usage:  use-model.cmd fast   |   use-model.cmd quality   |   use-model.cmd ^<model-name^>
setlocal
if "%~1"=="" (
  echo Usage: use-model.cmd fast ^| quality ^| ^<ollama-model-name^>
  echo.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0use-model.ps1" %*
echo.
pause
endlocal
