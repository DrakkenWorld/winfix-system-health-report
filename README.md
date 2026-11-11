# WinFix System Health Report

A read-only Windows inventory with HTML and JSON reports that stay on your computer.

1. Download and fully extract **WinFix-SystemHealthReport-v1.0.0.zip** from [GitHub Releases](https://github.com/DrakkenWorld/winfix-system-health-report/releases/latest).
2. Double-click **Start-EN.cmd** in the extracted folder.
3. Read the HTML report in your browser. Find both files in **WinFix-Reports** next to the launcher.

The launcher uses Windows PowerShell 5.1, included with Windows 10/11. It applies its execution policy only to that PowerShell process. Review downloaded code before running it. A [French guide](README.fr.md) is available.

## PowerShell

```powershell
.\script\WinFix-SystemHealthReport.ps1 -Language en -OutputDirectory .\WinFix-Reports -EventDays 7
```

Run from an extracted folder in Windows PowerShell 5.1 or PowerShell 7. Use `-OpenReport` to open HTML after export. Choose 1–30 days for events. Each run creates a distinct folder. Exit codes are 0 for complete collection, 2 for a partial report and 1 for a fatal error.

## What the report contains

Windows edition, build and boot time, computer model and RAM, CPU, fixed-drive capacity and free space, driver names, versions and signing status. System and Application logs are summarized separately. Each count covers up to 1,000 of the newest matching critical, error and warning events in the requested period. A truncated log is labeled. An inaccessible log has unknown counts while the other log remains available. Counts are inventory data and require context to diagnose a problem.

The tool reads local sources without requiring administrator rights. Access depends on Windows permissions. Reports omit event message text, machine and user names, serial numbers and IP addresses by design. Review hardware and error details before sharing. JSON uses schema version 1 and UTC timestamps. HTML and JSON are written to the chosen output folder.

## Validation

Run `tests/Run-Tests.ps1` under both PowerShell editions and `tests/Test-Package.ps1` to test the extracted ZIP. Use `Build-Release.ps1` to generate a ZIP and SHA-256 checksum. See [validation evidence](docs/VALIDATION.md) and the [MIT license](LICENSE).
