<#
.SYNOPSIS
    High-Performance Bulk Windows Font Installer (Direct Win32/Registry).
#>

# Self-elevation check
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    $scriptPath = $MyInvocation.MyCommand.Path
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
    exit
}

Clear-Host
$Host.UI.RawUI.WindowTitle = "Windows Font Bulk Installer"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($ScriptDir)) {
    $ScriptDir = (Get-Location).Path
}

# Auto-detect Fonts folder (if run from Windows_Scripts or from Fonts itself)
$fontsSourceDir = $ScriptDir
$parentDir = Split-Path -Parent $ScriptDir
if (Test-Path "$ScriptDir\..\Fonts") {
    $fontsSourceDir = (Resolve-Path "$ScriptDir\..\Fonts").Path
} elseif (Test-Path "$ScriptDir\Fonts") {
    $fontsSourceDir = (Resolve-Path "$ScriptDir\Fonts").Path
}

Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "          High-Speed Windows Font Bulk Installer         " -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Description:" -ForegroundColor Yellow
Write-Host "  Scans the Fonts folder and all subfolders recursively," -ForegroundColor Gray
Write-Host "  and bulk installs all font files (.ttf, .otf, .ttc, .fon)" -ForegroundColor Gray
Write-Host "  directly into Windows and broadcasts changes system-wide." -ForegroundColor Gray
Write-Host ""
Write-Host "Fonts Source: $fontsSourceDir" -ForegroundColor DarkGray
Write-Host ""
Write-Host "Press [Enter] to continue or [Ctrl+C] to cancel..." -ForegroundColor Green
[void][System.Console]::ReadLine()

# Win32 API to broadcast font change
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class FontManager {
    [DllImport("gdi32.dll", EntryPoint = "AddFontResourceW", SetLastError = true)]
    public static extern int AddFontResource([In, MarshalAs(UnmanagedType.LPWStr)] string lpFileName);

    [DllImport("user32.dll", EntryPoint = "PostMessageW", SetLastError = true)]
    public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);

    public const int HWND_BROADCAST = 0xffff;
    public const int WM_FONTCHANGE = 0x001D;
}
"@

$fontsDir = "$env:SystemRoot\Fonts"
$regKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
$extensions = @("*.ttf", "*.otf", "*.ttc", "*.fon")

Write-Host "`n[*] Scanning for font files in $fontsSourceDir..." -ForegroundColor Cyan
$fontFiles = Get-ChildItem -Path $fontsSourceDir -Include $extensions -Recurse -File

if (-not $fontFiles -or $fontFiles.Count -eq 0) {
    Write-Warning "No font files found in $fontsSourceDir"
    Write-Host "`nPress [Enter] to exit..." -ForegroundColor Gray
    [void][System.Console]::ReadLine()
    exit
}

Write-Host "[*] Found $($fontFiles.Count) font file(s). Installing in fast batch mode..." -ForegroundColor Green

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$installed = 0
$skipped = 0

Add-Type -AssemblyName System.Drawing

foreach ($font in $fontFiles) {
    $destPath = Join-Path $fontsDir $font.Name
    $isNew = -not (Test-Path -LiteralPath $destPath)

    if ($isNew) {
        try {
            Copy-Item -LiteralPath $font.FullName -Destination $destPath -Force
        }
        catch {
            Write-Warning "Could not copy $($font.Name): $_"
            continue
        }
    }

    $fontTitle = [System.IO.Path]::GetFileNameWithoutExtension($font.Name)
    try {
        $pfc = New-Object System.Drawing.Text.PrivateFontCollection
        $pfc.AddFontFile($destPath)
        if ($pfc.Families.Length -gt 0) {
            $fontTitle = $pfc.Families[0].Name
        }
        $pfc.Dispose()
    }
    catch {}

    if ($font.Extension -ieq ".otf") {
        $regValueName = "$fontTitle (OpenType)"
    } else {
        $regValueName = "$fontTitle (TrueType)"
    }

    try {
        Set-ItemProperty -Path $regKey -Name $regValueName -Value $font.Name -Type String -Force -ErrorAction SilentlyContinue
        [FontManager]::AddFontResource($destPath) | Out-Null

        if ($isNew) {
            $installed++
            Write-Host "  [+] $fontTitle ($($font.Name))" -ForegroundColor Green
        } else {
            $skipped++
        }
    }
    catch {
        Write-Warning "Registry registration failed for $($font.Name)"
    }
}

# Broadcast font table update
[FontManager]::PostMessage([IntPtr][FontManager]::HWND_BROADCAST, [FontManager]::WM_FONTCHANGE, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null

$sw.Stop()

Write-Host "`n=========================================================" -ForegroundColor Green
Write-Host " [SUCCESS] Finished in $($sw.Elapsed.TotalSeconds.ToString("0.0")) seconds!" -ForegroundColor Green
Write-Host "   Installed : $installed" -ForegroundColor Green
Write-Host "   Existed   : $skipped" -ForegroundColor Yellow
Write-Host "=========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Press [Enter] to exit..." -ForegroundColor Gray
[void][System.Console]::ReadLine()
