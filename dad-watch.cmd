@echo off
REM dad-watch.cmd - the watchdog. Run in a SECOND terminal while a session works.
REM It cannot interrupt a spiralling subagent (nothing can) - it makes the silence LOUD in minutes
REM instead of hours. A spiral writes nothing, so no-writes is the signal.
REM   dad watch                     3 idle minutes
REM   dad watch -IdleMinutes 2
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0dad-watch.ps1" %*