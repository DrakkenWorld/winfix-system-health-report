#requires -Version 5.1
param(
    [Parameter(Mandatory)][string]$OutputDirectory,
    [Parameter(Mandatory)][string]$ResultFile,
    [ValidateSet('en','fr')][string]$Language
)
$ErrorActionPreference = 'Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'WinFix.Health.psm1') -Force
    $data = Get-WinFixHealthData
    $path = Write-WinFixHealthReport -Data $data -OutputDirectory $OutputDirectory -Language $Language
    [IO.File]::WriteAllText($ResultFile, $path, [Text.Encoding]::UTF8)
    if (@($data.Sections | Where-Object Status -ne 'ok').Count) { exit 2 }
    exit 0
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
