@echo off
REM dad-run-summary.cmd - console run summary: wall-clock, files touched, findings, gate interventions, tokens (C4).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0dad-run-summary.ps1" %*
