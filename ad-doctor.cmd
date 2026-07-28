@echo off
REM ad-doctor.cmd - readiness check: prerequisites, Ollama + models, the kit, the global install.
REM Read-only - it diagnoses and prints the fix commands; it changes nothing.
REM   ad-doctor.cmd                            check the stack
REM   ad-doctor.cmd -ProjectDir C:\src\MyApp   also check that project's wiring
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ad-doctor.ps1" %*
