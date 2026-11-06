#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path (Get-Location) 'WinFix-Reports'),
    [ValidateSet('en','fr')][string]$Language = 'en',
    [ValidateRange(1,30)][int]$EventDays = 7
)
$ErrorActionPreference = 'Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'WinFix.Health.psm1') -Force
    $data = Get-WinFixHealthData -EventDays $EventDays
    $path = Write-WinFixHealthReport -Data $data -OutputDirectory $OutputDirectory -Language $Language
    Write-Host $path
    if (@($data.Sections | Where-Object Status -ne 'ok').Count) { exit 2 }
    exit 0
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
