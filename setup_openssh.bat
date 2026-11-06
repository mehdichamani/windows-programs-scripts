@echo off
setlocal
cd /d "%~dp0"
title Windows VM OpenSSH Setup

powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"\"%~dp0setup_openssh.ps1\"\"' -Verb RunAs"
