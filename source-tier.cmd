@echo off
REM source-tier.cmd - the HUMAN sets a source tier (primary/secondary); the ledger records the stamp. Asks at the console.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0source-tier.ps1" %*
