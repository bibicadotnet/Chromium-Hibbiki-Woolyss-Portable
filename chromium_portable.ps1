# ===========================
# Chromium Hibbiki Woolyss + Chrome++ Auto Installer
# ===========================

function Ensure-Admin {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -Command `"irm https://go.bibica.net/chromium_portable | iex`"" -Verb RunAs
        exit
    }
}

function Download-File($url, $dest) {
    if (-not (Test-Path $dest)) {
        (New-Object Net.WebClient).DownloadFile($url, $dest)
    }
}

function New-CleanDir($path) {
    if (Test-Path $path) { Remove-Item $path -Recurse -Force }
    New-Item -ItemType Directory -Path $path -Force | Out-Null
}

function Extract-7z($archive, $dest) {
    & $Global:SevenZip x $archive -o"$dest" -y | Out-Null
}

Ensure-Admin
Clear-Host
Write-Host "Chromium Hibbiki Woolyss Portable with Chrome++ Auto Installer" -BackgroundColor DarkGreen

# Stop Chromium if running
Stop-Process -Name "chrome" -Force -ErrorAction SilentlyContinue

Write-Host "You are about to install the Chromium browser (Portable edition, no system installation needed) with Chrome++ enhancements." -ForegroundColor Yellow
Write-Host "Please enter the folder path where Chromium Portable should be stored." -ForegroundColor Yellow
Write-Host "If you leave it blank and press Enter, the default will be: C:\Chromium_Portable" -ForegroundColor Gray

$installPath = Read-Host "Enter installation folder path"
if ([string]::IsNullOrWhiteSpace($installPath)) { 
    $installPath = "C:\Chromium_Portable"
    Write-Host "=> Using default path: $installPath" -ForegroundColor Green
}

if (-not (Test-Path $installPath)) { 
    New-Item -ItemType Directory -Path $installPath -Force | Out-Null
}


# 7zr.exe path
$Global:SevenZip = "$env:TEMP\7zr.exe"
Download-File "https://www.7-zip.org/a/7zr.exe" $SevenZip

# --- Install Chromium ---
$release = Invoke-RestMethod "https://api.github.com/repos/Hibbiki/chromium-win64/releases/latest"
$chromeAsset = $release.assets | Where-Object name -eq "chrome.7z" 
if (-not $chromeAsset) { Write-Host "chrome.7z not found!" -ForegroundColor Red; exit }

$chromeZip = "$env:TEMP\chrome.7z"
Write-Host "`nInstalling Chromium $($release.tag_name)..."
Download-File $chromeAsset.browser_download_url $chromeZip

$extractPath = "$env:TEMP\chrome_extract"
New-CleanDir $extractPath
Extract-7z $chromeZip $extractPath

$chromeBin = Get-ChildItem -Path $extractPath -Recurse -Directory -Name "Chrome-bin" | Select-Object -First 1
if (-not $chromeBin) { Write-Host "Chrome-bin not found!" -ForegroundColor Red; exit }

$targetPath = Join-Path $installPath "Chrome"
if (Test-Path $targetPath) { Remove-Item $targetPath -Recurse -Force }
Copy-Item (Join-Path $extractPath $chromeBin) $targetPath -Recurse -Force

# Apply registry policy
$regPath = "$env:TEMP\optimize.reg"
Download-File "https://raw.githubusercontent.com/bibicadotnet/chromium-debloat/main/disable_chromium_features.reg" $regPath
Start-Process "regedit.exe" -ArgumentList "/s `"$regPath`"" -Wait -NoNewWindow

# --- Install Chrome++ ---
$chromePlusRelease = Invoke-RestMethod "https://api.github.com/repos/Bush2021/chrome_plus/releases/latest"
$chromePlusAsset = $chromePlusRelease.assets | Where-Object { $_.name -like "*Chrome*x86_x64_arm64.7z" }
if (-not $chromePlusAsset) { Write-Host "Chrome++ not found!" -ForegroundColor Red; exit }

$chromePlusZip = "$env:TEMP\chrome_plus.7z"
Write-Host "Installing Chrome++ $($chromePlusRelease.tag_name)..."
Download-File $chromePlusAsset.browser_download_url $chromePlusZip

$chromePlusExtract = "$env:TEMP\chrome_plus_extract"
New-CleanDir $chromePlusExtract
Extract-7z $chromePlusZip $chromePlusExtract

$appPath = Get-ChildItem -Path $chromePlusExtract -Recurse -Directory | Where-Object { $_.FullName -like "*\x64\App" } | Select-Object -First 1
if (-not $appPath) { Write-Host "x64/App not found!" -ForegroundColor Red; exit }

Copy-Item (Join-Path $appPath.FullName "version.dll") $targetPath -Force
Download-File "https://github.com/bibicadotnet/Chromium-Hibbiki-Woolyss-Portable/raw/main/chrome%2B%2B.ini" (Join-Path $targetPath "chrome++.ini")

# --- Install Widevine ---
Write-Host "Installing WidevineCdm..."
$widevineZip = "$env:TEMP\WidevineCdm.7z"
Download-File "https://github.com/bibicadotnet/Chromium-Hibbiki-Woolyss-Portable/raw/main/WidevineCdm.7z" $widevineZip

$widevineExtract = "$env:TEMP\widevine_extract"
New-CleanDir $widevineExtract
Extract-7z $widevineZip $widevineExtract

$version = $release.tag_name -replace '^v(\d+\.\d+\.\d+\.\d+).*', '$1'
$versionPath = Join-Path $targetPath $version
if (-not (Test-Path $versionPath)) { New-Item -ItemType Directory -Path $versionPath -Force | Out-Null }
Copy-Item (Join-Path $widevineExtract "WidevineCdm") (Join-Path $versionPath "WidevineCdm") -Recurse -Force

# --- Cleanup ---
Remove-Item $chromeZip, $chromePlusZip, $regPath, $widevineZip -Force -ErrorAction SilentlyContinue
Remove-Item $extractPath, $chromePlusExtract, $widevineExtract -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`nChromium Hibbiki Woolyss Portable with Chrome++ installation completed!" -ForegroundColor Green
Write-Host "Installation location: $targetPath" -ForegroundColor Cyan
