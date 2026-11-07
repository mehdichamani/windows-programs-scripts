<#
.SYNOPSIS
    Office 365 Offline Installer (Word, Excel, PowerPoint)
#>

$ErrorActionPreference = "Stop"

# Self-elevation check to Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    $scriptPath = $MyInvocation.MyCommand.Path
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
    exit
}

# Determine script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($scriptDir)) {
    $scriptDir = $PSScriptRoot
}
if ([string]::IsNullOrWhiteSpace($scriptDir)) {
    $scriptDir = (Get-Location).Path
}

Clear-Host
$Host.UI.RawUI.WindowTitle = "Office 365 Offline Installer"

Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "     Office 365 Offline Installer (Word, Excel, PPT)     " -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Description:" -ForegroundColor Yellow
Write-Host "  Installs Microsoft Office 365 offline directly from the" -ForegroundColor Gray
Write-Host "  mounted ISO media using Office Deployment Tool (ODT)," -ForegroundColor Gray
Write-Host "  excluding bloatware and unnecessary packages." -ForegroundColor Gray
Write-Host ""
Write-Host "Press [Enter] to continue or [Ctrl+C] to cancel..." -ForegroundColor Green
[void][System.Console]::ReadLine()

$workDir = $null

# 2. Check if files are directly in the script directory
if ((Test-Path "$scriptDir\ODT.exe") -and (Test-Path "$scriptDir\Office\Data")) {
    $workDir = "$scriptDir\"
    Write-Host "[*] Found Office media in current directory: $workDir" -ForegroundColor Cyan
}

# 3. Search mounted drives D: through Z:
if (-not $workDir) {
    Write-Host "[*] Scanning drives for mounted Office ISO..." -ForegroundColor Yellow
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Name -match '^[D-Z]$' }
    foreach ($drive in $drives) {
        $root = "$($drive.Name):\"
        if ((Test-Path "$root\ODT.exe") -and (Test-Path "$root\Office\Data")) {
            $workDir = $root
            Write-Host "[*] Detected mounted Office media at drive: $workDir" -ForegroundColor Green
            break
        }
    }
}

if (-not $workDir) {
    Write-Host "[!] ERROR: Could not find mounted Office drive with ODT.exe and Office\Data!" -ForegroundColor Red
    Write-Host "[!] Please make sure the ISO is mounted to a drive letter." -ForegroundColor Red
    Write-Host "`nPress [Enter] to exit..." -ForegroundColor Gray
    [void][System.Console]::ReadLine()
    exit 1
}

# 4. Create offline configuration XML
$xmlPath = "$env:TEMP\office365_offline.xml"
$xmlContent = @"
<Configuration>
  <Add SourcePath="$workDir" OfficeClientEdition="64" Channel="Current">
    <Product ID="O365ProPlusRetail">
      <Language ID="en-us" />

      <!-- Apps to INSTALL (Commented out = Installed) -->
      <!-- <ExcludeApp ID="Word" /> -->
      <!-- <ExcludeApp ID="Excel" /> -->
      <!-- <ExcludeApp ID="PowerPoint" /> -->

      <!-- Apps to EXCLUDE (Uncommented = Excluded / Not Installed) -->
      <ExcludeApp ID="Outlook" />
      <ExcludeApp ID="OneNote" />
      <ExcludeApp ID="Access" />
      <ExcludeApp ID="Publisher" />
      <ExcludeApp ID="OneDrive" />
      <ExcludeApp ID="Teams" />
      <ExcludeApp ID="Lync" />
      <ExcludeApp ID="Groove" />
      <ExcludeApp ID="Bing" />
    </Product>
  </Add>
  <Property Name="SharedComputerLicensing" Value="0" />
  <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
  <Property Name="DeviceBasedLicensing" Value="0" />
  <Property Name="SCLCacheOverride" Value="0" />
  <Property Name="AUTOACTIVATE" Value="0" />
  <Display Level="Full" AcceptEULA="TRUE" />
  <Updates Enabled="FALSE" />
  <RemoveMSI />
</Configuration>
"@

Set-Content -Path $xmlPath -Value $xmlContent -Encoding UTF8
Write-Host "[*] Generated config at: $xmlPath" -ForegroundColor Cyan
Write-Host "[*] Launching ODT Installer from $workDir\ODT.exe ..." -ForegroundColor Cyan
Write-Host ""

$odtExe = "$workDir\ODT.exe"
$process = Start-Process -FilePath $odtExe -ArgumentList "/configure `"$xmlPath`"" -Wait -PassThru

if ($process.ExitCode -eq 0) {
    Write-Host ""
    Write-Host "=========================================================" -ForegroundColor Green
    Write-Host "   [SUCCESS] Office 365 installed successfully!          " -ForegroundColor Green
    Write-Host "=========================================================" -ForegroundColor Green
    Write-Host ""
    
    $activator = "$workDir\Activator.cmd"
    if (Test-Path $activator) {
        Write-Host "Activation:" -ForegroundColor Yellow
        Write-Host "  Permanent offline activation using Ohook." -ForegroundColor Gray
        Write-Host ""
        Write-Host "Press [Enter] to activate now or [Ctrl+C] to skip..." -ForegroundColor Green
        [void][System.Console]::ReadLine()

        Write-Host "[*] Running Ohook activation..." -ForegroundColor Cyan
        Start-Process -FilePath $activator -ArgumentList "/Ohook" -Wait
    }
} else {
    Write-Host ""
    Write-Host "[!] Installation finished with exit code: $($process.ExitCode)" -ForegroundColor Red
}

Remove-Item $xmlPath -ErrorAction SilentlyContinue

Write-Host "`nPress [Enter] to exit..." -ForegroundColor Gray
[void][System.Console]::ReadLine()
