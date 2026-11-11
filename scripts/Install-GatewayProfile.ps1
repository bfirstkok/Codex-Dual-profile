#Requires -Version 5.1
<#
.SYNOPSIS
  Install an isolated, unofficial Codex Desktop profile for a Responses API gateway.
.DESCRIPTION
  Only writes beneath %LOCALAPPDATA%\Codex-Gateway-Profiles\<ProfileName>
  and creates an optional desktop shortcut. Never edits %USERPROFILE%\.codex.
.EXAMPLE
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-GatewayProfile.ps1 -ProfileName AskMe -Model gpt-6.1-sol -BaseUrl https://myai.askme.co.th/api/v1/proxy/openai/v1
#>
[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9_-]{1,32}$')]
    [string]$ProfileName = 'AskMe',
    [ValidatePattern('^[A-Za-z0-9_.:/-]+$')]
    [string]$Model = 'gpt-6.1-sol',
    [string]$BaseUrl = 'https://myai.askme.co.th/api/v1/proxy/openai/v1',
    [switch]$UpdateKey,
    [switch]$ReplaceConfig,
    [switch]$SkipApiTest,
    [switch]$NoShortcut,
    [switch]$ReplaceShortcut
)
$ErrorActionPreference = 'Stop'

function Assert-BaseUrl([string]$Value) {
    $uri = $null
    if (-not [Uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$uri) -or
        $uri.Scheme -ne 'https' -or $uri.UserInfo -or $uri.Query -or $uri.Fragment) {
        throw 'BaseUrl must be an HTTPS API base URL, without credentials, query string, or fragment.'
    }
    if ($Value -match "['`"`r`n]") { throw 'BaseUrl contains unsupported characters.' }
}
function Assert-WindowsPath([string]$PathValue) {
    if ($PathValue -match '[&%!^'']' -or @($PathValue.ToCharArray() | Where-Object { [int]$_ -gt 127 }).Count -gt 0) {
        throw 'This version requires ASCII Windows paths without CMD metacharacters (& % ! ^ or apostrophe). No original app was changed.'
    }
}

Assert-BaseUrl $BaseUrl
$source = Split-Path -Parent $MyInvocation.MyCommand.Path
$profilesRoot = Join-Path $env:LOCALAPPDATA 'Codex-Gateway-Profiles'
$root = Join-Path $profilesRoot $ProfileName
$codexHome = Join-Path $root 'codex-home'
$webData = Join-Path $root 'web-data'
$keyPath = Join-Path $root 'api-key.dpapi'
$configPath = Join-Path $codexHome 'config.toml'
$launcherPath = Join-Path $root 'Start-GatewayProfile.ps1'
$helperPath = Join-Path $root 'Get-ProfileToken.ps1'
$testPath = Join-Path $root 'Test-GatewayAPI.ps1'
$psExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
Assert-WindowsPath $root
Assert-WindowsPath $psExe

$pkg = Get-AppxPackage -Name 'OpenAI.Codex' | Select-Object -First 1
if (-not $pkg) { throw 'OpenAI.Codex Store package not found. Install Codex Desktop first.' }
$exe = Join-Path $pkg.InstallLocation 'app\ChatGPT.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw "Cannot find Codex executable: $exe" }
Assert-WindowsPath $exe
Import-Module Appx -ErrorAction SilentlyContinue
if (-not (Get-Command Invoke-CommandInDesktopPackage -ErrorAction SilentlyContinue)) {
    throw 'Invoke-CommandInDesktopPackage is unavailable; this unofficial dual-window method is not compatible here.'
}

New-Item -ItemType Directory -Force -Path $root,$codexHome,$webData | Out-Null
foreach ($fileName in 'Start-GatewayProfile.ps1','Get-ProfileToken.ps1','Test-GatewayAPI.ps1') {
    $from = Join-Path $source $fileName
    if (-not (Test-Path -LiteralPath $from)) { throw "Required helper script missing: $from" }
    Copy-Item -LiteralPath $from -Destination (Join-Path $root $fileName) -Force
}

if (-not (Test-Path -LiteralPath $keyPath) -or $UpdateKey) {
    Write-Host 'Enter gateway API key (input is hidden). It will NOT be stored in the config file.' -ForegroundColor Yellow
    $secure = Read-Host 'Gateway API key' -AsSecureString
    if ($secure.Length -eq 0) { throw 'The gateway API key cannot be empty.' }
    try {
        $cipherText = ConvertFrom-SecureString -SecureString $secure
        Set-Content -LiteralPath $keyPath -Value $cipherText -Encoding ASCII -NoNewline
    } finally { $secure.Dispose() }
} else { Write-Host 'Reusing existing DPAPI-encrypted key. Use -UpdateKey to replace it.' }

if ((Test-Path -LiteralPath $configPath) -and -not $ReplaceConfig) {
    Write-Warning "Existing config preserved at $configPath. Use -ReplaceConfig (creates a backup) if necessary."
} else {
    if (Test-Path -LiteralPath $configPath) {
        $backup = "$configPath.backup-$(Get-Date -Format yyyyMMdd-HHmmss)"
        Copy-Item -LiteralPath $configPath -Destination $backup -ErrorAction Stop
        Write-Host "Backup created: $backup"
    }
    # TOML literal strings are safe here because we validate ASCII paths and strip apostrophes above.
    # Do NOT combine model_providers.gateway.auth with env_key/requires_openai_auth.
    $config = @"
model = '$Model'
model_provider = 'gateway'
model_reasoning_effort = 'medium'
cli_auth_credentials_store = 'file'

[model_providers.gateway]
name = 'Custom Responses Gateway'
base_url = '$($BaseUrl.TrimEnd('/'))'
wire_api = 'responses'

[model_providers.gateway.auth]
command = '$psExe'
args = ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', '$helperPath']
timeout_ms = 15000
refresh_interval_ms = 0
"@
    [System.IO.File]::WriteAllText($configPath, $config, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Created isolated config: $configPath" -ForegroundColor Green
}

if (-not $NoShortcut) {
    $desktop = [Environment]::GetFolderPath('Desktop')
    $shortcutPath = Join-Path $desktop "Codex - $ProfileName Gateway.lnk"
    if ((Test-Path -LiteralPath $shortcutPath) -and -not $ReplaceShortcut) {
        Write-Warning "Existing shortcut preserved: $shortcutPath. Use -ReplaceShortcut only if you intentionally want to replace it."
    } else {
        if (Test-Path -LiteralPath $shortcutPath) {
            $shortcutBackup = "$shortcutPath.backup-$(Get-Date -Format yyyyMMdd-HHmmss)"
            Copy-Item -LiteralPath $shortcutPath -Destination $shortcutBackup -ErrorAction Stop
            Write-Host "Old shortcut backed up: $shortcutBackup"
        }
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $psExe
    $shortcut.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $launcherPath + '"'
    $shortcut.WorkingDirectory = $root
    $shortcut.Description = "Isolated Codex Desktop profile: $ProfileName. Unofficial launcher."
    $shortcut.IconLocation = "$exe,0"
        $shortcut.Save()
        Write-Host "Shortcut: $shortcutPath" -ForegroundColor Green
    }
}
Write-Host 'Your original Codex home directory was not modified.' -ForegroundColor Green
if (-not $SkipApiTest) {
    & $psExe -NoProfile -ExecutionPolicy Bypass -File $testPath -ProfileRoot $root
    if ($LASTEXITCODE -ne 0) { Write-Warning "Profile created, but API smoke test did not pass. Check model entitlement and key." }
} else { Write-Warning 'API test skipped. Verify Responses API streaming and tools manually.' }
Write-Host "Launch the second instance with the Start-GatewayProfile.ps1 launcher or its new shortcut."
Write-Warning 'Desktop multi-profile activation is unofficial and version-sensitive; verify isolation after updates.'
