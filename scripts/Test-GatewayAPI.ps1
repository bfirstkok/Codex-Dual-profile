#Requires -Version 5.1
# One small, potentially billable request to the gateway Responses API. Never prints API key.
[CmdletBinding()]
param(
    [string]$ProfileRoot = $PSScriptRoot,
    [string]$Model = '',
    [string]$BaseUrl = ''
)
$ErrorActionPreference = 'Stop'
$configPath = Join-Path $ProfileRoot 'codex-home\config.toml'
$helper = Join-Path $ProfileRoot 'Get-ProfileToken.ps1'
if (-not (Test-Path -LiteralPath $configPath)) { throw "Cannot find profile config: $configPath" }
if (-not (Test-Path -LiteralPath $helper)) { throw "Cannot find token helper: $helper" }
$config = Get-Content -LiteralPath $configPath -Raw
if (-not $Model) {
    $match = [regex]::Match($config, '(?m)^model\s*=\s*[''\"]([^''\"]+)[''\"]')
    if (-not $match.Success) { throw 'Cannot determine model in config.' }
    $Model = $match.Groups[1].Value
}
if (-not $BaseUrl) {
    $match = [regex]::Match($config, '(?m)^base_url\s*=\s*[''\"]([^''\"]+)[''\"]')
    if (-not $match.Success) { throw 'Cannot determine gateway base_url in config.' }
    $BaseUrl = $match.Groups[1].Value
}
$key = & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $helper
if ([string]::IsNullOrWhiteSpace($key)) { throw 'Cannot retrieve decrypted API key.' }
$uri = $BaseUrl.TrimEnd('/') + '/responses'
$body = @{ model = $Model; input = 'Reply exactly gateway-ok'; stream = $false } | ConvertTo-Json -Compress
try {
    Write-Host "Checking Responses API for model $Model..." -ForegroundColor Cyan
    $null = Invoke-RestMethod -Uri $uri -Method Post -ContentType 'application/json' -Headers @{ Authorization = "Bearer $key" } -Body $body -TimeoutSec 45
    Write-Host 'PASS: Basic Responses API request accepted.' -ForegroundColor Green
    Write-Warning 'Basic success does not prove streaming, tool calls, GUI isolation, or billing routing. Verify in Codex and gateway logs.'
} catch {
    if ($_.Exception.Response) {
        Write-Warning "Responses API returned HTTP $([int]$_.Exception.Response.StatusCode)."
    } else {
        Write-Warning 'The gateway request failed (network, TLS, or response format).'
    }
    Write-Warning 'Check model entitlement, API key, and endpoint. Do not post secrets or raw HTTP headers.'
    exit 1
} finally {
    Remove-Variable -Name key -ErrorAction SilentlyContinue
}
