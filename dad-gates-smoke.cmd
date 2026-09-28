@echo off
REM dad-gates-smoke.cmd - prove the kit's gates actually fire (not just that the hook files exist).
REM   dad-gates-smoke.cmd [-ProjectDir .]
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0dad-gates-smoke.ps1" %*
