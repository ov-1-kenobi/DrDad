@echo off
REM dad-gates-log.cmd - append to / query grades\gates-log.jsonl (the gate-decision log, C3).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0dad-gates-log.ps1" %*
