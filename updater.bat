@echo OFF
:: MPV Unified Updater - Quick launcher
:: Double-click to check and update mpv + ffmpeg + yt-dlp + portable_config
pushd %~dp0

where pwsh >nul 2>nul
if %errorlevel% equ 0 (
    pwsh -NoProfile -NoLogo -ExecutionPolicy Bypass -File "%~dp0mpv-update.ps1" %*
) else (
    powershell -NoProfile -NoLogo -ExecutionPolicy Bypass -File "%~dp0mpv-update.ps1" %*
)

exit /b %errorlevel%
