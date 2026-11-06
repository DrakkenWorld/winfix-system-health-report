# WinFix System Health Report

Version 0.1.0 — local preview, not a published stable release.

A read-only Windows inventory with local HTML and JSON exports. Runs on Windows PowerShell 5.1 and PowerShell 7, without modules to install or administrator rights required. Some sources may be unavailable under restricted accounts.

```powershell
powershell.exe -NoProfile -File ./script/WinFix-SystemHealthReport.ps1 -OutputDirectory ./WinFix-Reports -Language en -EventDays 7
```

Use `pwsh.exe` for PowerShell 7. Review the downloaded code and follow your execution policy; this tool does not change that policy. Open report.html in the printed output directory. Every run creates a new directory. JSON schema version 1 preserves numeric byte values; dates include an offset or UTC marker. HTML field names remain the stable Windows inventory names in both languages.

Sources: Windows version/boot time, computer manufacturer/model/RAM, CPU, local fixed volumes, signed-driver inventory, and counts of critical/error/warning events in System and Application. EventDays accepts 1–30 (default 7). Events are capped at the latest 1,000 matching records per log; LimitReached signals possible truncation. An event section error discards that section's partial data and records the failure.

No repairs, service changes, deletion, remote requests, telemetry, health score, or automatic report opening. This is not a complete security audit or a Windows support-status checker. Counts and unsigned drivers do not prove a fault. No deliberate collection of serial numbers, computer/user names, IP addresses or event message text. Hardware names and operating-system error messages can still be private: inspect reports before sharing. Drivers can produce a large report; collection is synchronous. Individual CIM operations request a 15-second timeout; there is no global deadline or interactive cancellation interface in this preview.

Exit codes: 0 all sources collected; 2 at least one source unavailable and reports written; 1 fatal collection/export error (a partial output directory may remain). PowerShell parameter binding errors are nonzero. Outputs are the only intended filesystem changes. Reports contain no external assets or executable scripts; strings are HTML escaped.

Run `powershell.exe -NoProfile -File tests/Run-Tests.ps1`, then repeat with `pwsh.exe`. Tests cover deterministic collection failures, rendering, input validation and a real Windows collection. Clean Windows 11 manual testing is still required. See [French guide](README.fr.md), [validation](docs/VALIDATION.md) and [MIT license](LICENSE).
