#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$root = Join-Path $temp ('WinFixHealthDesktop-' + [guid]::NewGuid().ToString('N'))
$null = [IO.Directory]::CreateDirectory($root)
try {
    & "$PSScriptRoot/../desktop/Build-Portable.ps1" -OutputDirectory $root
    $exe = Join-Path $root 'WinFix-SystemHealthReport-Windows-x64.exe'
    $process = Start-Process -FilePath $exe -ArgumentList '--test-window' -PassThru
    if (-not $process.WaitForExit(15000)) { $process.Kill(); throw 'Window startup timed out' }
    if ($process.ExitCode -ne 0) { throw 'Window startup failed' }
    foreach ($language in 'fr','en') {
        $output = Join-Path $root "Rapports é & $language"
        $process = Start-Process -FilePath $exe -ArgumentList @('--test-collect', ('"' + $output + '"'), $language) -PassThru
        if (-not $process.WaitForExit(90000)) { $process.Kill(); throw 'Desktop collection timed out' }
        $reports = @(Get-ChildItem -LiteralPath $output -Directory)
        if ($reports.Count -ne 1) { throw 'Expected one report directory' }
        $html = [IO.File]::ReadAllText((Join-Path $reports[0].FullName 'report.html'))
        $data = Get-Content -LiteralPath (Join-Path $reports[0].FullName 'report.json') -Raw | ConvertFrom-Json
        $code = if (@($data.Sections | Where-Object Status -ne 'ok').Count) { 2 } else { 0 }
        if ($process.ExitCode -ne $code -or $data.Sections.Count -ne 6 -or $data.ToolVersion -ne '1.1.0' -or -not $html.Contains('lang="' + $language + '"')) {
            throw "Desktop report or exit code mismatch for $language"
        }
        Write-Host "PASS: desktop $language, exit $code, HTML and JSON with Unicode output path"
    }
    $blocked = Join-Path $root 'Existing file'
    [IO.File]::WriteAllText($blocked, 'preserve me')
    $process = Start-Process -FilePath $exe -ArgumentList @('--test-collect', ('"' + $blocked + '"'), 'fr') -PassThru
    if (-not $process.WaitForExit(90000)) { $process.Kill(); throw 'Desktop error test timed out' }
    if ($process.ExitCode -ne 1 -or [IO.File]::ReadAllText($blocked) -ne 'preserve me') { throw 'Output-file protection failed' }
    Write-Host 'PASS: visible window startup and preservation of existing output file'
} finally {
    if ([IO.Path]::GetDirectoryName($root) -eq $temp.TrimEnd([IO.Path]::DirectorySeparatorChar)) {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}
