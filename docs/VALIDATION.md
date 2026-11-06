# Validation — 2026-11-07

Local Windows 10 build 19045, Windows PowerShell 5.1.19041.7802 and PowerShell 7.6.9.

Both editions passed the dependency-free test suite: bilingual HTML, HTML/error escaping, empty sections, exact numeric JSON, Unicode roundtrip, UTF-8 BOM, unique output directories, deterministic collector fixtures, partial source failure/continuation, empty event logs, invalid range/language and actual Windows collection.

In the restricted test account, CIM access was denied and sources were correctly reported unavailable. In the normal Windows session, PowerShell 7 collected all six sections. Windows PowerShell 5.1 collected five sections; its event-log source returned a Windows provider-description error (parameter reference %1). The event section is marked unavailable, not counted as zero. This remains a known compatibility limitation of the local preview. No privileged repair was attempted.

The tests permit unavailable real sources; they do not claim that every collector succeeds in every environment. Deterministic fixtures verify collection continuation and data shape independently of local privileges. Windows 11, GitHub-hosted CI, browser visual inspection and a stable release have not yet been validated for this new tool.
