# ollama-tuning.ps1
# Performance options for the OLLAMA SERVER (not Claude Code). These are Windows
# environment variables read by Ollama itself. Run ONCE; they persist. Ollama must
# restart to pick them up.
#
# Usage:  powershell -ExecutionPolicy Bypass -File .\ollama-tuning.ps1

$ErrorActionPreference = "Stop"

Write-Host "Setting Ollama performance env vars (persisted at User scope)..." -ForegroundColor Cyan

# Flash attention: faster attention + lower memory. REQUIRED before KV-cache quantization works.
[Environment]::SetEnvironmentVariable("OLLAMA_FLASH_ATTENTION", "1", "User")

# Quantize the KV cache to 8-bit: the biggest VRAM win on a 16 GB card. Lets more of the
# model + context live on the GPU. Use "q4_0" for even less memory (small quality cost).
[Environment]::SetEnvironmentVariable("OLLAMA_KV_CACHE_TYPE", "q8_0", "User")

# Keep the model resident in VRAM between turns so it doesn't reload every request.
[Environment]::SetEnvironmentVariable("OLLAMA_KEEP_ALIVE", "30m", "User")

Write-Host "Set: OLLAMA_FLASH_ATTENTION=1, OLLAMA_KV_CACHE_TYPE=q8_0, OLLAMA_KEEP_ALIVE=30m" -ForegroundColor Green

Write-Host "`nRestarting Ollama (best effort)..." -ForegroundColor Cyan
Get-Process -Name "ollama app", "ollama" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Start-Process "ollama" -ArgumentList "serve" -WindowStyle Hidden -ErrorAction SilentlyContinue

Write-Host "`nMOST RELIABLE restart: quit Ollama from the system tray and reopen it." -ForegroundColor Yellow
Write-Host "Verify it loaded the model on GPU with:  ollama ps" -ForegroundColor Green
