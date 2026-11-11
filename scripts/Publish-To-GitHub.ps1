#Requires -Version 5.1
<#
.SYNOPSIS
  Publish this source tree as a NEW public GitHub repository, after explicit confirmation.
.DESCRIPTION
  Requires Git and GitHub CLI (`gh`) already installed and authenticated.
  Stages an explicit allowlist of project files; never stages local profile or secret files.
  Aborts if the repository already exists or the local folder is already a Git repository.
.EXAMPLE
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Publish-To-GitHub.ps1 -Owner bfirstkok -Repository codex-dual-profile-windows
#>
[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9-]{1,39}$')]
    [string]$Owner = 'bfirstkok',
    [ValidatePattern('^[A-Za-z0-9_.-]{1,100}$')]
    [string]$Repository = 'codex-dual-profile-windows'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git not found. Install Git for Windows first.' }
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw 'GitHub CLI (gh) not found. Install GitHub CLI first.' }
if (Test-Path -LiteralPath (Join-Path $root '.git')) { throw 'This folder is already a Git repository. Publish manually after reviewing its remotes.' }

& gh auth status 1>$null 2>$null
if ($LASTEXITCODE -ne 0) { throw 'GitHub CLI not authenticated. Run gh auth login, then retry.' }
& gh repo view "$Owner/$Repository" --json name 1>$null 2>$null
if ($LASTEXITCODE -eq 0) { throw "Repository $Owner/$Repository already exists. This script creates NEW repositories only." }

$files = @('README.md','README.en.md','LICENSE','CHANGELOG.md','CONTRIBUTING.md','.gitignore','scripts','docs','tests','.github')
foreach ($path in $files) { if (-not (Test-Path -LiteralPath (Join-Path $root $path))) { throw "Required source item missing: $path" } }
$secretFiles = @(Get-ChildItem -LiteralPath $root -Recurse -File | Where-Object { $_.Name -match '(?i)\.dpapi$|^auth\.json$|^\.env(?:\.|$)|^config\.toml$' })
if ($secretFiles.Count -gt 0) {
    throw 'Local secrets or config files detected in source tree. Remove them from the publish directory and retry.'
}
Write-Host ''
Write-Host "PUBLIC REPOSITORY: https://github.com/$Owner/$Repository" -ForegroundColor Yellow
Write-Host 'Only documented project source files (README, docs, scripts, tests, workflows, license) will be staged.'
Write-Host 'This action publishes source code publicly. Do not proceed if you have inserted private data.' -ForegroundColor Yellow
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'tests\Static-Checks.ps1')
if ($LASTEXITCODE -ne 0) { throw 'Static checks failed; publication aborted.' }
$confirmation = Read-Host 'Type PUBLISH to confirm public upload'
if ($confirmation -cne 'PUBLISH') { throw 'Cancelled; nothing published.' }

Push-Location $root
try {
    & git init -b main
    if ($LASTEXITCODE -ne 0) { throw 'git init failed.' }
    & git add -- $files
    if ($LASTEXITCODE -ne 0) { throw 'git add failed.' }
    $staged = & git diff --cached --name-only
    if (-not $staged) { throw 'No files staged.' }
    Write-Host 'Staged files:' -ForegroundColor Cyan
    $staged | ForEach-Object { Write-Host "  $_" }
    & git commit -m 'Initial public beta: Codex dual profile manager'
    if ($LASTEXITCODE -ne 0) { throw 'git commit failed. Configure git user.name and user.email if needed.' }
    & gh repo create "$Owner/$Repository" --public --source . --remote origin --push --description 'Unofficial Codex Desktop dual-profile and AI Gateway setup for Windows'
    if ($LASTEXITCODE -ne 0) { throw 'GitHub repository creation or push failed. Check gh auth and git remotes; do not blindly rerun.' }
    Write-Host "Published: https://github.com/$Owner/$Repository" -ForegroundColor Green
    Write-Host 'No Release was created. Validate on Windows before tagging a release.'
} finally { Pop-Location }
