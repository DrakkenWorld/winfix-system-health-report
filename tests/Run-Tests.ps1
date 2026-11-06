#requires -Version 5.1
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '../script/WinFix.Health.psm1') -Force
$root = Join-Path ([IO.Path]::GetTempPath()) ('WinFixHealthTests-' + [guid]::NewGuid().ToString('N'))
function Assert($value, $message) { if (-not $value) { throw $message } }
try {
    $fixture = [pscustomobject]@{SchemaVersion=1; ToolVersion='0.1.0'; GeneratedUtc='2026-11-07T00:00:00Z'; Sections=@(
        [pscustomobject]@{Name='Windows';Status='ok';Data=@([pscustomobject]@{Caption='<script>alert("é")</script>';Bytes=1234567890123});Error=$null},
        [pscustomobject]@{Name='Drivers';Status='ok';Data=@();Error=$null},
        [pscustomobject]@{Name='Events';Status='unavailable';Data=@();Error='<denied>&'}
    )}
    foreach ($language in @('en','fr')) {
        $path = Write-WinFixHealthReport $fixture $root $language
        $htmlPath = Join-Path $path 'report.html'
        $html = [IO.File]::ReadAllText($htmlPath)
        Assert ($html.Contains('lang="' + $language + '"')) 'Language'
        Assert ($html.Contains('&lt;script&gt;') -and -not $html.Contains('<script>')) 'HTML escaping'
        Assert ($html.Contains('&lt;denied&gt;&amp;')) 'Error escaping'
        Assert ($html.Contains($(if ($language -eq 'fr') {'Aucune donnée.'} else {'No data.'}))) 'Empty section'
        $json = Get-Content (Join-Path $path 'report.json') -Raw | ConvertFrom-Json
        Assert ($json.Sections[0].Data[0].Bytes -eq 1234567890123) 'Exact JSON number'
        Assert ($json.Sections[0].Data[0].Caption -eq $fixture.Sections[0].Data[0].Caption) 'Unicode JSON roundtrip'
        $bytes = [IO.File]::ReadAllBytes($htmlPath)
        Assert ($bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) 'UTF8 BOM'
    }
    Assert (@(Get-ChildItem $root -Directory).Count -eq 2) 'Runs never overwrite'
    Write-Host 'PASS: bilingual HTML, escaping, empty/error sections, JSON, Unicode, BOM and distinct runs'
    $module = Get-Module WinFix.Health
    & $module {
        function Get-CimInstance {
            param($ClassName, $Filter, $OperationTimeoutSec, $ErrorAction)
            if ($ClassName -eq 'Win32_Processor') { throw 'fixture access denied' }
            [pscustomobject]@{Caption='Fixture Windows';Name='Fixture CPU';DeviceName='Fixture driver'}
        }
        function Get-WinEvent { param($FilterHashtable, $MaxEvents, $ErrorAction, $ErrorVariable) @() }
        $result = Get-WinFixHealthData
        if ($result.Sections.Count -ne 6) { throw 'All six sections collected' }
        if ($result.Sections[2].Status -ne 'unavailable') { throw 'Partial failure captured' }
        if ($result.Sections[5].Data.Count -ne 2 -or $result.Sections[5].Data[0].ReturnedCount -ne 0) { throw 'Empty event logs' }
        if ($result.Sections[4].Status -ne 'ok') { throw 'Collection continues after failure' }
    }
    Write-Host 'PASS: deterministic collector fixture, partial access failure and continuation'
    $rejected = $false
    try { Get-WinFixHealthData -EventDays 0 } catch { $rejected = $true }
    Assert $rejected 'Reject invalid event range'
    $rejected = $false
    try { Write-WinFixHealthReport $fixture $root 'de' } catch { $rejected = $true }
    Assert $rejected 'Reject unsupported language'
    Write-Host 'PASS: parameter validation'
    # A real, read-only collection checks Windows integration without assuming admin rights.
    Remove-Module WinFix.Health
    Import-Module (Join-Path $PSScriptRoot '../script/WinFix.Health.psm1') -Force
    $actual = Get-WinFixHealthData -EventDays 1
    Assert ($actual.Sections.Count -eq 6) 'Real collection shape'
    Assert (@($actual.Sections | Where-Object { $_.Status -notin @('ok','unavailable') }).Count -eq 0) 'Real section statuses'
    Write-Host ('PASS: real Windows collection; unavailable sections: ' + @($actual.Sections | Where-Object Status -ne 'ok').Count)
    exit 0
} finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
