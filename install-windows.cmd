@echo off
setlocal
cd /d "%~dp0"
title SkyOrcaMax Simulator - Windows Setup

echo SkyOrcaMax Simulator Windows Setup
echo ==================================
echo.
echo Dependency dan Python akan dipasang otomatis jika diperlukan.
echo Proses build pertama dapat berlangsung cukup lama.
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-windows.ps1"
if errorlevel 1 (
    echo.
    echo Setup gagal. Periksa pesan error di atas.
    pause
    exit /b 1
)

echo.
echo Setup selesai. Shortcut aplikasi sudah dibuat di Desktop.
pause
