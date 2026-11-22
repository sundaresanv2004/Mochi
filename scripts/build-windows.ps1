# Builds Mochi for Windows into dist\Mochi (Mochi.exe plus the Swift runtime it needs, so it runs on PCs
# without Swift) and zips it as dist\Mochi-<version>-windows.zip.
#
#   .\scripts\build-windows.ps1                  version from Support\Info.plist
#   .\scripts\build-windows.ps1 -Version 1.2.3
#
# Google Calendar sign-in: set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET (an OAuth client of type
# "Desktop app") to put them into the build (Mochi.config.json next to Mochi.exe), never into git.
# Without them, people paste their own client in Settings > Reminders.
param([string]$Version = "")
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

if (-not (Get-Command swift -ErrorAction SilentlyContinue)) {
    throw "Swift isn't installed. Install it with: winget install --id Swift.Toolchain -e"
}
if (-not $Version) {
    $plist = Get-Content Support\Info.plist -Raw
    $Version = [regex]::Match($plist, '<key>CFBundleShortVersionString</key>\s*<string>([^<]+)</string>').Groups[1].Value
}

# Where the Swift runtime DLLs live (the per-user or the machine-wide install).
$swiftCore = Get-ChildItem -Path "$env:LOCALAPPDATA\Programs\Swift\Runtimes", "$env:ProgramFiles\Swift\Runtimes" `
    -Filter swiftCore.dll -Recurse -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
if (-not $swiftCore) { throw "Couldn't find the Swift runtime (swiftCore.dll)." }
$runtime = $swiftCore.DirectoryName
# Find Swift's own DLLs first: Windows won't search for DLLs through junctions on PATH (scoop's "current"
# folders, Oracle's javapath), which otherwise breaks reading Package.swift.
$env:Path = "$runtime;" + $env:Path

# A windowed app (no console window), starting at the usual C entry point.
swift build -c release -Xlinker /SUBSYSTEM:WINDOWS -Xlinker /ENTRY:mainCRTStartup
if ($LASTEXITCODE -ne 0) { throw "swift build failed" }
$bin = (swift build -c release --show-bin-path).Trim()

$out = "dist\Mochi"
if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Force $out | Out-Null
Copy-Item "$bin\Mochi.exe" $out
Copy-Item "$runtime\*.dll" $out
Copy-Item LICENSE $out

if ($env:GOOGLE_CLIENT_ID) {
    $config = @{ GoogleClientID = $env:GOOGLE_CLIENT_ID }
    if ($env:GOOGLE_CLIENT_SECRET) { $config.GoogleClientSecret = $env:GOOGLE_CLIENT_SECRET }
    else { Write-Warning "GOOGLE_CLIENT_SECRET is not set; Google usually needs it for Desktop app clients" }
    $config | ConvertTo-Json | Set-Content "$out\Mochi.config.json" -Encoding UTF8
    Write-Host "Google Calendar: using the OAuth client from GOOGLE_CLIENT_ID"
} else {
    if ($env:GOOGLE_CLIENT_SECRET) { Write-Warning "GOOGLE_CLIENT_SECRET is set but GOOGLE_CLIENT_ID isn't; ignoring it" }
    Write-Host "Google Calendar: GOOGLE_CLIENT_ID not set, so people will paste their own OAuth client in Settings"
}

$zip = "dist\Mochi-$Version-windows.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path "$out\*" -DestinationPath $zip
Write-Host "Built $out\Mochi.exe and $zip"
