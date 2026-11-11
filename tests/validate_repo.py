"""Portable, offline repository sanity checks (stdlib only)."""
from pathlib import Path
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = [
    "README.md", "README.en.md", "LICENSE", ".gitignore", "CHANGELOG.md",
    "scripts/Install-GatewayProfile.ps1", "scripts/Start-GatewayProfile.ps1",
    "scripts/Get-ProfileToken.ps1", "scripts/Test-GatewayAPI.ps1",
    "scripts/Set-MainProvider.ps1", "scripts/Publish-To-GitHub.ps1",
    "docs/01-replace-main-th.md", "docs/02-dual-profile-th.md",
    "docs/security.md", "docs/troubleshooting-th.md",
    "docs/images/dual-profiles.svg", "docs/images/replace-main.svg",
    ".github/workflows/ci-release.yml",
]
for item in REQUIRED:
    assert (ROOT / item).is_file(), f"Missing {item}"

for svg in (ROOT / "docs/images").glob("*.svg"):
    ET.parse(svg)

secret_pattern = re.compile(r"(?:ghp_|github_pat_|sk-proj-)[A-Za-z0-9_-]{16,}")
for path in ROOT.rglob("*"):
    if not path.is_file():
        continue
    assert not path.name.endswith(".dpapi"), f"Credential file included: {path}"
    assert path.name != "auth.json", f"Authentication file included: {path}"
    if path.suffix.lower() in {".ps1", ".md", ".yml", ".yaml", ".txt", ".toml"}:
        data = path.read_text(encoding="utf-8")
        assert not secret_pattern.search(data), f"Potential embedded secret in {path}"

main_script = (ROOT / "scripts/Set-MainProvider.ps1").read_text(encoding="utf-8")
dual_script = (ROOT / "scripts/Install-GatewayProfile.ps1").read_text(encoding="utf-8")
assert "config.toml.backup-" in main_script, "Main provider switch needs backup support"
assert "-ReplaceConfig" in dual_script, "Installer needs safe config replacement option"
assert "ConvertFrom-SecureString" in dual_script, "Installer should encrypt credential"
assert not re.search(r"(?im)^\s*\$home\s*=", dual_script), "Do not overwrite PowerShell HOME"
print("PASS: required files, diagrams, backup/DPAPI markers, and secret-pattern checks")
print("NOTE: no live Windows/MSIX/Responses API integration test was run")
