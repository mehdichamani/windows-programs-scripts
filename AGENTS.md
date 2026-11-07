# Project Rules & Scripting Standards: Windows_Scripts

This repository contains automated maintenance, installation, and configuration scripts for Windows and Windows VMs. All scripts must follow uniform architecture, UI/UX conventions, and cross-platform compatibility rules.

---

## 1. Script Architecture & Pairing

Every operational tool in this repo should provide two files:
1. **Double-Click Batch Launcher (`<ToolName>.bat`)**:
   - Acts as the primary entry point for Windows Explorer / Desktop users.
   - Sets working directory to the script's folder (`cd /d "%~dp0"`).
   - Sets the console window title.
   - Automatically handles UAC elevation and launches the paired PowerShell script with bypass flags:
     ```bat
     @echo off
     setlocal
     cd /d "%~dp0"
     title <Tool Name Window Title>

     powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"\"%~dp0<ToolName>.ps1\"\"' -Verb RunAs"
     ```

2. **PowerShell Engine (`<ToolName>.ps1`)**:
   - Contains the core execution logic, UI styling, and error handling.

---

## 2. PowerShell Script Structure & UI/UX Style

Every PowerShell script must adhere to the following structure:

### A. Synopsis & Self-Elevation
Always check for administrative privileges at the start and elevate if missing:
```powershell
<#
.SYNOPSIS
    <Brief 1-line description of the script>
#>

# Self-elevation check to Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    $scriptPath = $MyInvocation.MyCommand.Path
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
    exit
}
```

### B. Console Initialization & Header Banner
Clear the console, assign the window title, and print a formatted header banner with a description and confirmation pause:
```powershell
Clear-Host
$Host.UI.RawUI.WindowTitle = "<Tool Window Title>"

Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "                    <Tool Title Banner>                  " -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Description:" -ForegroundColor Yellow
Write-Host "  <Clear 2-3 line summary of what this tool performs>    " -ForegroundColor Gray
Write-Host ""
Write-Host "Press [Enter] to continue or [Ctrl+C] to cancel..." -ForegroundColor Green
[void][System.Console]::ReadLine()
```

### C. Standardized Logging & Progress Indicators
Use consistent formatting for logging and progress:
- Step indicators: `Write-Host "[*] <Step description>..." -ForegroundColor Cyan`
- Sub-steps: `Write-Host "[1/5] <Sub-step>..." -ForegroundColor Yellow`
- Warnings: `Write-Warning "<Warning message>"`
- Success messages: `Write-Host "    Found / Completed: <detail>" -ForegroundColor Green`
- Errors: `Write-Host "[!] ERROR: <message>" -ForegroundColor Red`

### D. Safe Execution & Error Handling
- Validate paths with `Test-Path` before reading or executing.
- Use `try / catch` around critical calls and report skipped items gracefully instead of crashing.
- Check for existing configurations (e.g. firewall rules, registry keys) before applying changes to prevent duplicates.

### E. Completion Summary & Exit Pause
Summarize the outcome and wait for the user to press Enter so the elevated PowerShell window does not close abruptly:
```powershell
Write-Host ""
Write-Host "=========================================================" -ForegroundColor Green
Write-Host "                   Process Complete                      " -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Green
Write-Host "  Items Processed : $count" -ForegroundColor Cyan
if ($failed -gt 0) {
    Write-Host "  Failed / Errors : $failed" -ForegroundColor Red
}
Write-Host ""
Write-Host "Press [Enter] to exit..." -ForegroundColor Gray
[void][System.Console]::ReadLine()
```

---

## 3. Cross-Platform & Repository Conventions

1. **Line Endings (`CRLF`)**:
   - All `.bat`, `.cmd`, and `.ps1` files must use CRLF (`\r\n`) line endings as enforced by `.gitattributes`.
2. **Path Handling**:
   - Always resolve script directories dynamically (`$PSScriptRoot` or `Split-Path -Parent $MyInvocation.MyCommand.Path` or `%~dp0` in batch). Never hardcode relative drive letters or parent assumption without fallbacks.
3. **Documentation**:
   - Whenever a new script or tool is added, update [README.md](README.md) with a clear description in Persian in the contents table.
