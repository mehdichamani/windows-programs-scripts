@echo off
setlocal
cd /d "%~dp0"
title Windows Font Bulk Installer

powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"\"%~dp0install_fonts.ps1\"\"' -Verb RunAs"
