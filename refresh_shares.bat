@echo off
setlocal
cd /d "%~dp0"
title Shared Drives Cache Refresher

echo =========================================================
echo             Shared Drives Cache Refresher
echo =========================================================
echo.
echo Description:
echo   Clears Windows SMB and network share caches, then restarts
echo   Windows Explorer so newly added files from the host
echo   appear immediately without restarting the VM.
echo.
echo Press [Enter] to continue or [Ctrl+C] to cancel...
pause >nul

echo.
echo [*] Flushing network connections and share cache...
net use * /delete /y

echo.
echo [*] Restarting Windows Explorer...
taskkill /f /im explorer.exe >nul 2>&1
timeout /t 1 /nobreak >nul
start explorer.exe

echo.
echo =========================================================
echo  [SUCCESS] Network shares and cache refreshed cleanly!
echo =========================================================
echo.
echo Press [Enter] to exit...
pause >nul
