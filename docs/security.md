# Security & compatibility notes

This is an unofficial Windows Codex Desktop profile launcher, **not** an OpenAI product. Read the scripts before running them. Microsoft Store packaging, `Invoke-CommandInDesktopPackage`, and Chromium/Electron `--user-data-dir` behavior can change without notice.

## Credentials

- API keys are entered via `Read-Host -AsSecureString` and saved as Windows DPAPI-encrypted strings for the **current Windows user**.
- The token helper prints the decrypted token to stdout **only when invoked by Codex** as a command-backed provider authentication hook. Do not run it to inspect output, pipe it to a log, or paste it into a chat.
- The token is decrypted in process memory during use. DPAPI is not a defense against malware running as your logged-in Windows user.
- Do not commit `%LOCALAPPDATA%\Codex-Gateway-Profiles`, `*.dpapi`, `auth.json`, `.env`, or personal `config.toml`.
- Avoid exposing key material through command-line arguments, shell history, screenshots, or issue reports.
- Key rotation: re-run the installer with `-UpdateKey`; revoke leaked keys in the provider's dashboard.

## Main vs isolated profile

- `Install-GatewayProfile.ps1` writes only to a new directory under `%LOCALAPPDATA%\Codex-Gateway-Profiles\<ProfileName>` and an optional desktop shortcut. It does not modify the normal `%USERPROFILE%\.codex`.
- `Set-MainProvider.ps1` **intentionally edits** the main config after creating a timestamped backup. Only run this when you want to replace the main provider.
- Do not mix `[model_providers.<id>.auth]` with `env_key` or `requires_openai_auth` for the same provider.
- API tests can consume provider quota or incur charges. They do not prove streaming/tool-call compatibility or the billing path.

## Compatibility limits

- Tested pattern: Windows 11 Microsoft Store `OpenAI.Codex` MSIX with `app\ChatGPT.exe` and `Invoke-CommandInDesktopPackage` available.
- Windows paths with certain CMD metacharacters or non-ASCII characters are deliberately rejected by the dual-window launcher rather than risking incorrect command execution.
- No guarantee of two independently functioning Desktop windows on all versions. Test after updates.
- No automated network downloads, permanent execution-policy changes, or registry edits.

## Reporting issues

Include Windows version, Codex package version, the exact command (without secrets), HTTP status, and sanitized logs. Never include a token, cookie, credential file, or personal project contents.
