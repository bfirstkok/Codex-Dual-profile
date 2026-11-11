#Requires -Version 5.1
# Safe static checks: no network, no API keys, no Codex installation required.
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$scripts = @(Get-ChildItem -LiteralPath (Join-Path $repo 'scripts') -Filter '*.ps1' -File)
if ($scripts.Count -lt 5) { throw 'Expected at least five PowerShell scripts.' }
$failures = New-Object 'System.Collections.Generic.List[string]'
foreach ($file in $scripts) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
    foreach ($parseError in $parseErrors) {
        $failures.Add("$($file.Name): $($parseError.Message)")
    }
    $content = Get-Content -LiteralPath $file.FullName -Raw
    if ($content -match '(?im)^\s*\$home\s*=') { $failures.Add("$($file.Name): Do not overwrite PowerShell HOME variable.") }
    if ($content -match '(?i)Invoke-Expression|\biex\s*\(') { $failures.Add("$($file.Name): Dynamic code evaluation is not allowed.") }
}
$expected = @('README.md','README.en.md','LICENSE','.gitignore','docs/01-replace-main-th.md','docs/02-dual-profile-th.md')
foreach ($path in $expected) {
    if (-not (Test-Path -LiteralPath (Join-Path $repo $path))) { $failures.Add("Missing required file: $path") }
}
# Basic secret hygiene: catch common hardcoded token prefixes. Not a substitute for full secret scanning.
$trackedText = Get-ChildItem -LiteralPath $repo -Recurse -File | Where-Object {
    $_.Extension -in '.ps1','.md','.yml','.yaml','.toml','.txt' -or $_.Name -eq '.gitignore'
}
foreach ($file in $trackedText) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    if ($content -match '(?i)(?:ghp_|github_pat_|sk-proj-)[A-Za-z0-9_\-]{16,}') {
        $failures.Add("Potential credential in: $($file.FullName)")
    }
}
if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    throw "Static checks failed ($($failures.Count) issues)."
}
Write-Host "PASS: $($scripts.Count) PowerShell scripts parsed and required files present." -ForegroundColor Green
Write-Warning 'These are static checks only; no live Windows/MSIX/API integration test was run.'
