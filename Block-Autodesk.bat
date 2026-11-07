@echo off
setlocal
cd /d "%~dp0"
title Autodesk Firewall Blocker

powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"\"%~dp0Block-Autodesk.ps1\"\"' -Verb RunAs"
