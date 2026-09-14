@echo off
REM env.cmd - manage DrDad knowledge environments (isolated trees that hold corpora).
REM   env.cmd                 list environments (root: %USERPROFILE%\.drdad\environments, or DRDAD_ENV_ROOT)
REM   env.cmd new web         create an environment
REM   env.cmd remove web      archive to a dated zip, then remove the live tree (safe)
REM   env.cmd where           print the environments root
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0env.ps1" %*
