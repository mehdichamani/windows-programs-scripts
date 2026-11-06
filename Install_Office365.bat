@echo off
setlocal
pushd "%~dp0"
title Office 365 Offline Installer

:: Check for Administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd.exe -ArgumentList '/c \"\"%~dpnx0\"\"' -Verb RunAs"
    popd
    exit /b
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install_Office365.ps1"
popd
