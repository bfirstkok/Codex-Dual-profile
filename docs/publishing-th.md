# สำหรับผู้ดูแล: เผยแพร่ขึ้น GitHub

โฟลเดอร์นี้เตรียมไว้สำหรับ GitHub Repository ชื่อ `codex-dual-profile-windows` ของบัญชี `bfirstkok` แต่ **การดาวน์โหลด ZIP ไม่ได้สร้าง Repository บน GitHub โดยอัตโนมัติ**

## 1. ติดตั้งเครื่องมือ

ติดตั้ง [Git for Windows](https://git-scm.com/download/win) และ [GitHub CLI](https://cli.github.com/) ก่อน แล้วเปิด PowerShell:

```powershell
gh auth login
```

ตรวจว่าล็อกอินเป็นบัญชี GitHub ที่ต้องการเผยแพร่

## 2. สร้าง Public Repository และ Push

แตกไฟล์ ZIP แล้วเปิด PowerShell ที่โฟลเดอร์โปรเจกต์ (ไม่ใช่ใน `scripts`):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Publish-To-GitHub.ps1 -Owner bfirstkok -Repository codex-dual-profile-windows
```

สคริปต์ตรวจเครื่องมือ ตรวจชื่อ Repo ว่ายังไม่ถูกใช้ และขอให้พิมพ์ `PUBLISH` เพื่อยืนยัน **การเผยแพร่สู่สาธารณะ** โดย Stage เฉพาะรายการไฟล์ที่อนุญาตไว้ ไม่รวมไฟล์ Secret

> หาก Repository มีอยู่แล้ว สคริปต์จะหยุดเพื่อป้องกันการ Push ทับโดยไม่ได้ตั้งใจ

## 3. สร้าง GitHub Release หลังทดสอบจริง

เมื่อทดสอบบน Windows ผ่านแล้ว ให้สร้าง Tag จากโฟลเดอร์ Repository:

```powershell
git tag v0.1.0-beta
git push origin v0.1.0-beta
```

GitHub Actions จะตรวจไวยากรณ์ PowerShell และสร้าง `Codex-Dual-Profile-Windows.zip` ในหน้า Releases เมื่อ CI ผ่าน

## 4. Checklist ก่อนปล่อยสู่สาธารณะ

- [ ] ไม่มี API Key หรือไฟล์ `*.dpapi` / `auth.json` / `.env` / Config ส่วนตัว
- [ ] วิธี A สร้าง Backup และ Restore ได้
- [ ] วิธี B ไม่แก้ `%USERPROFILE%\.codex`
- [ ] เปิดสองหน้าต่างได้จริงในเวอร์ชัน Codex ที่ทดสอบ
- [ ] ทดสอบ Basic Responses API, Streaming และ Tool Calling
- [ ] README ระบุว่าเป็น Community/Unofficial และมีข้อจำกัดของ MSIX
