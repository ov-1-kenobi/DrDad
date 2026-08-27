@echo off
REM free-locks.cmd - clear a build lock held by a left-over app process (MSB3026 / 'being used by another
REM process'). Only kills processes running from THIS project's own folder - safe on any machine.
REM   dad free-locks
REM   dad free-locks -WhatIf        list what would be killed, kill nothing
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0free-locks.ps1" %*