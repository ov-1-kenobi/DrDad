@echo off
REM archive-tasks.cmd - move the bodies of a closed story's ticked tasks from docs\TASKS.md to docs\archive (headings stay).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0archive-tasks.ps1" %*
