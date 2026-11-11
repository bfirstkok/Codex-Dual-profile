#Requires -Version 5.1
<#
.SYNOPSIS
  Opt-in: switch the NORMAL Codex config to a Responses API gateway; or restore a chosen backup.
.DESCRIPTION
  This script DOES edit %USERPROFILE%\.codex\config.toml when -Action Enable is selected.
  It writes a timestamped backup before editing. No global environment variables are set.
  It does not start or log out of Codex Desktop; close it manually first.
#>
[CmdletBinding()]
param(
    [ValidateSet('Enable','Restore')]
    [string]$Action = 'Enable',
    [ValidatePattern('^[A-Za-z0-9_.:/-]+$')]
    [string]$Model = 'gpt-6.1-sol',
    [string]$BaseUrl = 'https://myai.askme.co.th/api/v1/proxy/openai/v1',
    [string]$BackupPath = ''
)
$ErrorActionPreference = 'Stop'
$mainHome = Join-Path $env:USERPROFILE '.codex'
$configPath = Join-Path $mainHome 'config.toml'

if ($Action -eq 'Restore') {
    if ([string]::IsNullOrWhiteSpace($BackupPath)) { throw 'To restore, pass -BackupPath with the exact backup filename.' }
    $resolved = (Resolve-Path -LiteralPath $BackupPath -ErrorAction Stop).Path
    if ((Split-Path -Leaf $resolved) -notlike 'config.toml.backup-*') { throw 'Expected a config.toml.backup-* file.' }
    if (-not (Test-Path -LiteralPath $configPath)) { throw 'Current config.toml not found.' }
    $safety = "$configPath.before-restore-$(Get-Date -Format yyyyMMdd-HHmmss)"
    Copy-Item -LiteralPath $configPath -Destination $safety -ErrorAction Stop
    Copy-Item -LiteralPath $resolved -Destination $configPath -ErrorAction Stop
    Write-Host "Restored config from $resolved; prior version saved to $safety" -ForegroundColor Green
    return
}

$uri = $null
if (-not [Uri]::TryCreate($BaseUrl,[UriKind]::Absolute,[ref]$uri) -or
    $uri.Scheme -ne 'https' -or $uri.UserInfo -or $uri.Query -or $uri.Fragment -or
    $BaseUrl -match "['`"`r`n]") { throw 'BaseUrl must be a simple HTTPS API base URL.' }

$source = Split-Path -Parent $MyInvocation.MyCommand.Path
$authRoot = Join-Path $env:LOCALAPPDATA 'Codex-Gateway-Profiles\main-provider-auth'
$keyFile = Join-Path $authRoot 'api-key.dpapi'
$helper = Join-Path $authRoot 'Get-ProfileToken.ps1'
$psExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
if (@($authRoot.ToCharArray() | Where-Object { [int]$_ -gt 127 }).Count -gt 0 -or
    $authRoot -match "['`"`r`n]") {
    throw 'Current Windows profile path is incompatible with this simple TOML helper; do not edit the main config.'
}
# This first-time guard prevents silently overwriting or duplicating an existing provider table.
New-Item -ItemType Directory -Path $mainHome -Force | Out-Null
$current = ''
if (Test-Path -LiteralPath $configPath) { $current = Get-Content -LiteralPath $configPath -Raw }
if ($current -match '(?m)^\s*\[model_providers\.gateway_main(?:\]|\.)') {
    throw 'gateway_main provider already exists. Restore first or edit manually; no main config changed.'
}

New-Item -ItemType Directory -Path $authRoot -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $source 'Get-ProfileToken.ps1') -Destination $helper -Force
if (-not (Test-Path -LiteralPath $keyFile)) {
    Write-Host 'Enter gateway API key for the main Codex provider (hidden input).' -ForegroundColor Yellow
    $secure = Read-Host 'Gateway API key' -AsSecureString
    if ($secure.Length -eq 0) { throw 'API key cannot be empty.' }
    try {
        Set-Content -LiteralPath $keyFile -Value (ConvertFrom-SecureString -SecureString $secure) -Encoding ASCII -NoNewline
    } finally { $secure.Dispose() }
}

$backup = "$configPath.backup-$(Get-Date -Format yyyyMMdd-HHmmss)"
if (Test-Path -LiteralPath $configPath) {
    Copy-Item -LiteralPath $configPath -Destination $backup -ErrorAction Stop
} else { [System.IO.File]::WriteAllText($backup, '', [System.Text.UTF8Encoding]::new($false)) }

# Restrict edits of model/model_provider to the TOML root before the first table.
$firstTable = [regex]::Match($current, '(?m)^\s*\[')
if ($firstTable.Success) {
    $rootPart = $current.Substring(0,$firstTable.Index)
    $tables = $current.Substring($firstTable.Index)
} else { $rootPart = $current; $tables = '' }
$rootPart = [regex]::Replace($rootPart,'(?m)^[ \t]*(model|model_provider)[ \t]*=.*(?:\r?\n|$)','')
$rootPart = "model = '$Model'`r`nmodel_provider = 'gateway_main'`r`n" + $rootPart.TrimStart([char[]]@([char]13,[char]10))
$rootPart = $rootPart.TrimEnd([char[]]@([char]13,[char]10)) + "`r`n`r`n"

$provider = @"
[model_providers.gateway_main]
name = 'Custom Responses Gateway'
base_url = '$($BaseUrl.TrimEnd('/'))'
wire_api = 'responses'

[model_providers.gateway_main.auth]
command = '$psExe'
args = ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', '$helper']
timeout_ms = 15000
refresh_interval_ms = 0
"@
$newText = $rootPart + $tables.TrimEnd([char[]]@([char]13,[char]10)) + "`r`n`r`n" + $provider + "`r`n"
[System.IO.File]::WriteAllText($configPath, $newText, [System.Text.UTF8Encoding]::new($false))
Write-Host "Main config updated: $configPath" -ForegroundColor Green
Write-Host "Backup: $backup" -ForegroundColor Green
Write-Host "To undo: powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Set-MainProvider.ps1 -Action Restore -BackupPath `"$backup`""
Write-Warning 'Main Codex is now configured for gateway use, not ChatGPT plan billing. Reopen the app and verify.'
