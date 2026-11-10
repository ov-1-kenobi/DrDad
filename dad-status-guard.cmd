@echo off
REM dad-status-guard.cmd - refuse a story marked DONE by anything other than close-unit (pre-commit + close-unit check).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0dad-status-guard.ps1" %*
