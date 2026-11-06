<#
.SYNOPSIS
    Automated OpenSSH Server Installer and Configurator for Windows VM
#>

# 1. Self-elevation to Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    $scriptPath = $MyInvocation.MyCommand.Path
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
    exit
}

Clear-Host
$Host.UI.RawUI.WindowTitle = "Windows VM OpenSSH Setup"

Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "       Windows VM OpenSSH Server Automated Setup         " -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Description:" -ForegroundColor Yellow
Write-Host "  Installs latest Microsoft.OpenSSH via winget, enables and" -ForegroundColor Gray
Write-Host "  starts sshd service automatically, opens Firewall Port 22," -ForegroundColor Gray
Write-Host "  sets PowerShell as default shell, and detects Host SSH Key" -ForegroundColor Gray
Write-Host "  for instant passwordless authentication." -ForegroundColor Gray
Write-Host ""
Write-Host "Press [Enter] to continue or [Ctrl+C] to cancel..." -ForegroundColor Green
[void][System.Console]::ReadLine()

# 2. Check if OpenSSH Server is already installed
$sshdPath = "$env:ProgramFiles\OpenSSH\sshd.exe"
$service = Get-Service -Name "sshd" -ErrorAction SilentlyContinue

if (-not $service -and -not (Test-Path $sshdPath)) {
    Write-Host "[1/5] Installing OpenSSH Preview via winget..." -ForegroundColor Yellow
    winget install --id Microsoft.OpenSSH.Preview --source winget --accept-package-agreements --accept-source-agreements --silent
} else {
    Write-Host "[1/5] OpenSSH Server is already installed." -ForegroundColor Green
}

# 3. Register service if binary exists but service is not registered
$service = Get-Service -Name "sshd" -ErrorAction SilentlyContinue
if (-not $service -and (Test-Path "$env:ProgramFiles\OpenSSH\install-sshd.ps1")) {
    Write-Host "[*] Registering sshd service..." -ForegroundColor Yellow
    Push-Location "$env:ProgramFiles\OpenSSH"
    & powershell.exe -ExecutionPolicy Bypass -File install-sshd.ps1
    Pop-Location
}

# 4. Configure & Start sshd service
Write-Host "[2/5] Configuring & starting sshd service..." -ForegroundColor Yellow
Set-Service -Name "sshd" -StartupType Automatic
Restart-Service -Name "sshd" -Force

# 5. Configure Windows Firewall
Write-Host "[3/5] Configuring Windows Firewall for Port 22..." -ForegroundColor Yellow
$fwRule = Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue
if (-not $fwRule) {
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
} else {
    Set-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -Enabled True | Out-Null
}

# 6. Set PowerShell as Default SSH Shell
Write-Host "[4/5] Setting PowerShell as default login shell..." -ForegroundColor Yellow
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null

# 7. Setup Passwordless SSH Key Authentication dynamically
Write-Host "[5/5] Checking for Host SSH Public Key..." -ForegroundColor Yellow

$adminKeyPath = "$env:ProgramData\ssh\administrators_authorized_keys"
if (-not (Test-Path "$env:ProgramData\ssh")) {
    New-Item -Path "$env:ProgramData\ssh" -ItemType Directory -Force | Out-Null
}

$possibleKeyPaths = @(
    "\\host.lan\Data\Home\.ssh\id_ed25519.pub",
    "\\host.lan\Data\Home\.ssh\id_rsa.pub",
    "$env:USERPROFILE\Desktop\Shared\Home\.ssh\id_ed25519.pub",
    "$env:USERPROFILE\Desktop\Shared\Home\.ssh\id_rsa.pub"
)

Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    $possibleKeyPaths += "$($_.Root)Home\.ssh\id_ed25519.pub"
    $possibleKeyPaths += "$($_.Root).ssh\id_ed25519.pub"
}

$foundKey = $null
foreach ($path in $possibleKeyPaths) {
    if (Test-Path -LiteralPath $path) {
        $content = (Get-Content -LiteralPath $path -Raw).Trim()
        if (-not [string]::IsNullOrWhiteSpace($content) -and $content.StartsWith("ssh-")) {
            $foundKey = $content
            Write-Host "    Found Host Key from: $path" -ForegroundColor Green
            break
        }
    }
}

if ($foundKey) {
    $existingKeys = if (Test-Path $adminKeyPath) { Get-Content $adminKeyPath } else { @() }
    if ($existingKeys -notcontains $foundKey) {
        Add-Content -Path $adminKeyPath -Value $foundKey -Encoding utf8
        Write-Host "    Successfully added Host Key to administrators_authorized_keys." -ForegroundColor Green
    } else {
        Write-Host "    Host Key is already present in administrators_authorized_keys." -ForegroundColor Green
    }

    icacls.exe $adminKeyPath /inheritance:r /grant "Administrators:F" /grant "SYSTEM:F" | Out-Null
} else {
    Write-Host "    No host public key found automatically. You can log in using Windows password." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=========================================================" -ForegroundColor Green
Write-Host " [SUCCESS] OpenSSH Server setup is completely finished!  " -ForegroundColor Green
Write-Host "   Status : $( (Get-Service sshd).Status )" -ForegroundColor Cyan
Write-Host "   Port   : 22 (Allowed in Firewall)" -ForegroundColor Cyan
Write-Host "   Shell  : PowerShell" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Press [Enter] to exit..." -ForegroundColor Gray
[void][System.Console]::ReadLine()
