# Troubleshooting — ปัญหาที่พบบ่อย

| อาการ | สาเหตุที่เป็นไปได้ | วิธีแก้/ตรวจ |
|---|---|---|
| `HTTP 403` | โมเดลไม่มีสิทธิ์, Key/บัญชี/นโยบาย Gateway | ตรวจชื่อโมเดลจาก Provider; ทดลองโมเดลที่ใช้งานได้จริง เช่น `gpt-6.1-sol` ในบัญชีที่รองรับ; ไม่ใช่หลักฐานว่า Key ผิดเสมอ |
| `HTTP 401` | Key หมดอายุ/ไม่ถูกต้อง | รัน Installer พร้อม `-UpdateKey` และกรอกใหม่ |
| `HTTP 404` | Base URL ไม่รองรับ `/responses` | ตรวจ Base URL ว่าลงท้ายด้วย API root (`.../v1`) ไม่ใช่ `.../chat/completions` |
| `HTTP 429` | Rate limit/Quota | ตรวจหน้า Gateway และรอให้โควตากลับมา |
| `The file is not digitally signed` | Execution Policy บล็อกไฟล์ `.ps1` | ตรวจสคริปต์ก่อน แล้วรัน `powershell.exe -NoProfile -ExecutionPolicy Bypass -File ...` (เฉพาะโปรเซสนี้) |
| `Cannot overwrite variable HOME` | สคริปต์รุ่นเก่าใช้ `$home` ชนกับ `$HOME` | ใช้สคริปต์รุ่นนี้ที่ใช้ `$codexHome`; อย่าเขียนทับ `$HOME` |
| `elseif` / `else` not recognized | วางแต่ละส่วนแยกจาก `if` | วาง `if`/`elseif`/`else` ทั้งชุดในครั้งเดียว |
| ไม่พบ `OpenAI.Codex` | ไม่ได้ติดตั้ง Codex จาก Store หรือ Package Name ต่าง | ติดตั้ง/ตรวจ `Get-AppxPackage -Name OpenAI.Codex` |
| ไม่มี `Invoke-CommandInDesktopPackage` | Windows/MSIX ไม่รองรับวิธีนี้ | ใช้ Codex CLI แยก `CODEX_HOME` แทน; GUI dual-instance อาจทำไม่ได้บนเครื่องนี้ |
| เปิด Shortcut แล้วกลับไปหน้าต่างเดิม | การแยก `--user-data-dir` ไม่ทำงานในเวอร์ชันนี้ | อัปเดตแอป/ตรวจ Launcher; อย่าถือว่ามีสองโปรไฟล์เพียงเพราะเปิดสองหน้าต่าง |
| เปิดสองหน้าต่างได้แต่ใช้ Provider เดียวกัน | Config/Environment ไม่แยกจริง | ตรวจ Config ของแต่ละโปรไฟล์ และดู Request Logs ของ Gateway |
| เปิด Codex หลักแล้วไม่ใช้ ChatGPT | Config หลักยังมี `model_provider` ของ Gateway | Restore Config สำรองจากวิธี A และล็อกอิน ChatGPT อีกครั้ง |

## คำสั่งตรวจแบบไม่แสดง API Key

```powershell
Get-AppxPackage -Name OpenAI.Codex | Select-Object Name, Version
Get-Content "$env:USERPROFILE\.codex\config.toml" | Select-String '^(model|model_provider)\s*='
Get-Content "$env:LOCALAPPDATA\Codex-Gateway-Profiles\AskMe\codex-home\config.toml" | Select-String '^(model|model_provider|base_url)\s*='
```

ก่อนแชร์ผลลัพธ์ ให้ตรวจว่าไม่มี Secret หรือข้อมูลส่วนตัวติดไปด้วย
