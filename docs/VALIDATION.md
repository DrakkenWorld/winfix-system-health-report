# Validation

## Version 1.1.0

The x64 EXE compiled with warnings treated as errors. On Windows 10 build 19045, the application opened successfully and its embedded collector created complete French and English HTML/JSON reports in folders with spaces, accented characters and an ampersand. The test also verified that a file at the requested output path is preserved. GitHub Actions runs the desktop, PowerShell and archive tests before publishing the EXE and ZIP.

## Version 1.0.0 — 2026-11-11

All six sources were collected successfully in the normal Windows session on Windows 10 build 19045 with Windows PowerShell 5.1 and PowerShell 7. The event collector reads raw levels through the Windows event log API. This avoids the provider-description failure seen in the preview.

Both editions passed report localization, HTML escaping, numeric JSON, Unicode, unique output directories, invalid input rejection and real collection. Event fixtures verify empty logs, the difference between an exact limit and truncation, counts by level, resource cleanup and preserving one log when the other is inaccessible.

The Windows workflow runs the two PowerShell editions and verifies the ZIP by extracting it and running its PowerShell entry point before publishing. The [Actions history](https://github.com/DrakkenWorld/winfix-system-health-report/actions) records hosted results. The local test used Windows 10. The hosted workflow records its own Windows runner environment.

## Preview — 2026-11-07

Local Windows 10 build 19045, Windows PowerShell 5.1.19041.7802 and PowerShell 7.6.9.

Both editions passed the dependency-free test suite: bilingual HTML, HTML/error escaping, empty sections, exact numeric JSON, Unicode roundtrip, UTF-8 BOM, unique output directories, deterministic collector fixtures, partial source failure/continuation, empty event logs, invalid range/language and actual Windows collection.

In the restricted test account, CIM access was denied and sources were correctly reported unavailable. In the normal Windows session, PowerShell 7 collected all six sections. Windows PowerShell 5.1 collected five sections; its event-log source returned a Windows provider-description error (parameter reference %1). The event section is marked unavailable, not counted as zero. This remains a known compatibility limitation of the local preview. No privileged repair was attempted.

The tests permit unavailable real sources; they do not claim that every collector succeeds in every environment. Deterministic fixtures verify collection continuation and data shape independently of local privileges. Windows 11, GitHub-hosted CI, browser visual inspection and a stable release have not yet been validated for this new tool.
