@echo off
REM ollama-tuning.cmd - set Ollama's GPU tuning env vars (flash attention, KV-cache quant,
REM keep-alive). RESTART Ollama afterward for them to take effect.
REM   ollama-tuning.cmd
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ollama-tuning.ps1" %*
