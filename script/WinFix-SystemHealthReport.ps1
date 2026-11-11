#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path (Get-Location) 'WinFix-Reports'),
    [ValidateSet('en','fr')][string]$Language = 'en',
    [ValidateRange(1,30)][int]$EventDays = 7,
    [switch]$OpenReport
)
$ErrorActionPreference = 'Stop'
try {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'Windows is required.' }
    Import-Module (Join-Path $PSScriptRoot 'WinFix.Health.psm1') -Force
    Write-Host $(if ($Language -eq 'fr') { 'Collecte en lecture seule en cours…' } else { 'Collecting a read-only inventory…' })
    $data = Get-WinFixHealthData -EventDays $EventDays
    $path = Write-WinFixHealthReport -Data $data -OutputDirectory $OutputDirectory -Language $Language
    Write-Host $path
    $missing = @($data.Sections | Where-Object Status -ne 'ok').Count
    Write-Host $(if ($Language -eq 'fr') { "Rapports HTML et JSON créés. Sections incomplètes : $missing." } else { "HTML and JSON reports created. Incomplete sections: $missing." })
    if ($OpenReport) {
        try { Start-Process -FilePath (Join-Path $path 'report.html') -ErrorAction Stop }
        catch { Write-Warning $(if ($Language -eq 'fr') { 'Ouverture automatique impossible. Ouvrez report.html dans le dossier indiqué.' } else { 'Could not open the browser. Open report.html in the directory shown.' }) }
    }
    if ($missing) { exit 2 }
    exit 0
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
