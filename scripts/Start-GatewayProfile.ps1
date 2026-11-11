#Requires -Version 5.1
# Unofficial Windows Store/MSIX dual-instance workaround. Run from installed profile folder.
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$codexHome = Join-Path $root 'codex-home'
$webData = Join-Path $root 'web-data'
$wrapper = Join-Path $root 'launch-gateway.cmd'
if (-not (Test-Path -LiteralPath (Join-Path $codexHome 'config.toml'))) {
    throw 'Config not found. Run Install-GatewayProfile.ps1 first.'
}
$pkg = Get-AppxPackage -Name 'OpenAI.Codex' | Select-Object -First 1
if (-not $pkg) { throw 'OpenAI.Codex Store package not found.' }
$exe = Join-Path $pkg.InstallLocation 'app\ChatGPT.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw "Executable not found: $exe" }
New-Item -ItemType Directory -Force -Path $webData | Out-Null
foreach ($p in @($codexHome, $webData, $exe)) {
    if ($p -match '[&%!^'']' -or @($p.ToCharArray() | Where-Object { [int]$_ -gt 127 }).Count -gt 0) {
        throw 'Unsupported path characters for the Windows CMD wrapper (ASCII only; avoid & % ! ^ apostrophe).'
    }
}
# Environment assignment must happen in the package-context child process, not only the parent PowerShell.
@"
@echo off
set "CODEX_HOME=$codexHome"
start "" /b "$exe" --user-data-dir="$webData"
"@ | Set-Content -LiteralPath $wrapper -Encoding ASCII
Import-Module Appx -ErrorAction SilentlyContinue
if (-not (Get-Command Invoke-CommandInDesktopPackage -ErrorAction SilentlyContinue)) {
    throw 'Invoke-CommandInDesktopPackage unavailable; unsupported package/Windows version.'
}
Invoke-CommandInDesktopPackage -PackageFamilyName $pkg.PackageFamilyName -AppId 'App' -Command "$env:SystemRoot\System32\cmd.exe" -Args "/d /c `"$wrapper`"" -PreventBreakaway
