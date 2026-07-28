@echo off
REM voice.cmd - push-to-talk voice loop for Claude Code (STT + TTS, local).
REM Run this FROM YOUR PROJECT FOLDER (the current directory is the project Claude works in):
REM   cd C:\src\MyProject
REM   C:\path\to\AD-kit\voice.cmd
REM Needs uv (winget install astral-sh.uv). First run downloads deps + the whisper model (internet once).
where uv >nul 2>nul
if errorlevel 1 (
  echo uv not found. Install it first:  winget install astral-sh.uv
  exit /b 1
)
uv run "%~dp0voice.py" %*
