# Contributing

Issues and pull requests are welcome. Please test on a disposable Windows user profile before changing an active Codex installation.

## Before opening a PR

1. Explain the Windows version, Codex package version, and whether the Store/MSIX workaround works.
2. Run `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Static-Checks.ps1` on Windows.
3. Do not add real credentials, `auth.json`, encrypted DPAPI blobs, `.env`, personal configs, or screenshots with sensitive content.
4. Preserve main Codex config in dual-profile mode. Main-provider changes must be explicit and reversible.
5. Mark unverified compatibility claims clearly.

This is a community project, not an official OpenAI, Microsoft, or AskMe integration.
