#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$repository = Split-Path $PSScriptRoot -Parent
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$root = Join-Path $tempRoot ('WinFixHealthZip-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $root
try {
    & (Join-Path $repository 'Build-Release.ps1') -OutputDirectory $root
    $version = (Get-Content (Join-Path $repository 'VERSION') -Raw).Trim()
    $zip = Join-Path $root "WinFix-SystemHealthReport-v$version.zip"
    $expected = ((Get-Content (Join-Path $root 'SHA256SUMS.txt') -Raw).Trim() -split '\s+')[0]
    if ((Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash -ne $expected) { throw 'Package hash mismatch' }
    $extracted = Join-Path $root 'Extracted tool'
    Expand-Archive -LiteralPath $zip -DestinationPath $extracted
    foreach ($file in @('Start-FR.cmd','Start-EN.cmd','LICENSE','README.md','README.fr.md','script/WinFix.Health.psm1','script/WinFix-SystemHealthReport.ps1')) {
        if (-not (Test-Path -LiteralPath (Join-Path $extracted $file) -PathType Leaf)) { throw "Missing $file" }
    }
    $output = Join-Path $root 'Local reports'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $extracted 'script/WinFix-SystemHealthReport.ps1') -OutputDirectory $output -Language fr -EventDays 1
    $code = $LASTEXITCODE
    if ($code -notin @(0,2)) { throw "Packaged CLI exit: $code" }
    $reports = @(Get-ChildItem -LiteralPath $output -Directory)
    if ($reports.Count -ne 1) { throw 'Expected one report directory' }
    $report = Get-Content (Join-Path $reports[0].FullName 'report.json') -Raw | ConvertFrom-Json
    $html = [IO.File]::ReadAllText((Join-Path $reports[0].FullName 'report.html'))
    $incomplete = @($report.Sections | Where-Object Status -ne 'ok').Count
    $expectedCode = if ($incomplete) {2} else {0}
    if ($report.ToolVersion -ne $version -or $report.Sections.Count -ne 6 -or $code -ne $expectedCode -or -not $html.Contains('lang="fr"')) {
        throw 'Packaged CLI report or status mismatch'
    }
    Write-Host 'PASS: archive checksum, expected files, packaged Windows PowerShell CLI and both exports'
    exit 0
} finally {
    if ([IO.Path]::GetDirectoryName($root) -eq $tempRoot.TrimEnd([IO.Path]::DirectorySeparatorChar)) {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}
