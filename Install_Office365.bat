@echo off
setlocal
cd /d "%~dp0"
title Office 365 Offline Installer

powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"\"%~dp0Install_Office365.ps1\"\"' -Verb RunAs"
