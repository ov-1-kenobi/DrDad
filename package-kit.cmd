@echo off
REM package-kit.cmd - build a clean, movable copy of the kit for the folder-copy install path.
REM   package-kit.cmd                      -> ..\AD-kit-v<version>.zip
REM   package-kit.cmd -OutDir D:\transfer  -> into that folder
REM   package-kit.cmd -Folder              -> unzipped folder instead of a zip
REM Excludes bin/obj, _tempReference, docs\.index, .claude, .git; verifies the dev-path placeholder
REM survived and that scan-secrets is clean. On the target: extract, then run install.cmd.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0package-kit.ps1" %*
