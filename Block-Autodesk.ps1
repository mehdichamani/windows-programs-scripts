<#
.SYNOPSIS
    Autodesk Firewall Rule Automation (Inbound & Outbound Blocker)
#>

# Self-elevation check to Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    $scriptPath = $MyInvocation.MyCommand.Path
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
    exit
}

Clear-Host
$Host.UI.RawUI.WindowTitle = "Autodesk Firewall Blocker"

Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "       Autodesk Firewall Blocker (Inbound & Outbound)    " -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Description:" -ForegroundColor Yellow
Write-Host "  Scans standard Autodesk directories recursively and" -ForegroundColor Gray
Write-Host "  creates inbound and outbound Windows Firewall block" -ForegroundColor Gray
Write-Host "  rules for all detected executables to stop background calls." -ForegroundColor Gray
Write-Host ""
Write-Host "Press [Enter] to continue or [Ctrl+C] to cancel..." -ForegroundColor Green
[void][System.Console]::ReadLine()

$targets = @(
    'C:\Program Files\Autodesk',
    'C:\Program Files (x86)\Autodesk',
    'C:\Program Files\Common Files\Autodesk Shared',
    'C:\Program Files (x86)\Common Files\Autodesk Shared'
)

Write-Host "[*] Scanning for Autodesk executables..." -ForegroundColor Cyan

$existingTargets = $targets | Where-Object { Test-Path -LiteralPath $_ }

if (-not $existingTargets -or $existingTargets.Count -eq 0) {
    Write-Warning "None of the standard Autodesk directories were found on this system:"
    $targets | ForEach-Object { Write-Host "    - $_" -ForegroundColor DarkGray }
    Write-Host "`nPress [Enter] to exit..." -ForegroundColor Gray
    [void][System.Console]::ReadLine()
    exit
}

$exeFiles = Get-ChildItem -Path $existingTargets -Filter *.exe -Recurse -File -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty FullName -Unique

if (-not $exeFiles -or $exeFiles.Count -eq 0) {
    Write-Warning "No Autodesk executables found in target directories."
    Write-Host "`nPress [Enter] to exit..." -ForegroundColor Gray
    [void][System.Console]::ReadLine()
    exit
}

Write-Host "[*] Found $($exeFiles.Count) executable(s). Configuring firewall block rules..." -ForegroundColor Green

$count = 0
$skipped = 0

foreach ($exe in $exeFiles) {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($exe)
    $dir = [System.IO.Path]::GetFileName([System.IO.Path]::GetDirectoryName($exe))
    $ruleNameIn  = "Block Autodesk In: $dir - $name"
    $ruleNameOut = "Block Autodesk Out: $dir - $name"

    try {
        $existingIn = Get-NetFirewallRule -DisplayName $ruleNameIn -ErrorAction SilentlyContinue
        if (-not $existingIn) {
            New-NetFirewallRule -DisplayName $ruleNameIn -Direction Inbound -Program $exe -Action Block -Profile Any -ErrorAction Stop | Out-Null
        }

        $existingOut = Get-NetFirewallRule -DisplayName $ruleNameOut -ErrorAction SilentlyContinue
        if (-not $existingOut) {
            New-NetFirewallRule -DisplayName $ruleNameOut -Direction Outbound -Program $exe -Action Block -Profile Any -ErrorAction Stop | Out-Null
        }

        $count++
    }
    catch {
        Write-Warning "Could not create firewall rules for $exe: $_"
        $skipped++
    }
}

Write-Host ""
Write-Host "=========================================================" -ForegroundColor Green
Write-Host "                   Process Complete                      " -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Green
Write-Host "  Executables Processed : $count" -ForegroundColor Cyan
Write-Host "  Total Rules Created   : $($count * 2) (Inbound & Outbound)" -ForegroundColor Cyan
if ($skipped -gt 0) {
    Write-Host "  Failed / Errors       : $skipped" -ForegroundColor Red
}
Write-Host ""
Write-Host "Press [Enter] to exit..." -ForegroundColor Gray
[void][System.Console]::ReadLine()
