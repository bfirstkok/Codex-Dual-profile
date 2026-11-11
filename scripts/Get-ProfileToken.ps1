#Requires -Version 5.1
# Called from Codex custom-provider .auth. Its stdout contains a SECRET.
# Do not copy/paste its output, log it, or publish profile directories.
$ErrorActionPreference = 'Stop'
$path = Join-Path $PSScriptRoot 'api-key.dpapi'
if (-not (Test-Path -LiteralPath $path)) { throw 'Encrypted gateway API key not found in profile directory.' }
$secure = ConvertTo-SecureString (Get-Content -LiteralPath $path -Raw)
$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try { [Console]::Out.WriteLine([Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)) }
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    $secure.Dispose()
}
