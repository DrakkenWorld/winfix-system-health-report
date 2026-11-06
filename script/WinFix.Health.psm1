#requires -Version 5.1
Set-StrictMode -Version 2.0
function Get-WinFixHealthData {
    [CmdletBinding()]
    param([ValidateRange(1,30)][int]$EventDays = 7)
    $sections = New-Object 'System.Collections.Generic.List[object]'
    $probes = [ordered]@{
        Windows = { Get-CimInstance Win32_OperatingSystem -OperationTimeoutSec 15 -ErrorAction Stop | Select-Object Caption, Version, BuildNumber, OSArchitecture, LastBootUpTime }
        Computer = { Get-CimInstance Win32_ComputerSystem -OperationTimeoutSec 15 -ErrorAction Stop | Select-Object Manufacturer, Model, TotalPhysicalMemory, NumberOfLogicalProcessors }
        Processor = { Get-CimInstance Win32_Processor -OperationTimeoutSec 15 -ErrorAction Stop | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors }
        Volumes = { Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -OperationTimeoutSec 15 -ErrorAction Stop | Select-Object DeviceID, FileSystem, Size, FreeSpace }
        Drivers = { Get-CimInstance Win32_PnPSignedDriver -OperationTimeoutSec 15 -ErrorAction Stop | Select-Object DeviceName, DriverProviderName, DriverVersion, DriverDate, IsSigned }
        Events = {
            foreach ($log in @('System','Application')) {
                $errors = @()
                $items = @(Get-WinEvent -FilterHashtable @{ LogName=$log; StartTime=(Get-Date).AddDays(-$EventDays); Level=1,2,3 } -MaxEvents 1000 -ErrorAction SilentlyContinue -ErrorVariable errors)
                $unexpected = @($errors | Where-Object { $_.FullyQualifiedErrorId -notlike 'NoMatchingEventsFound*' })
                if ($unexpected.Count) { throw $unexpected[0] }
                [pscustomobject]@{ Log=$log; Days=$EventDays; ReturnedCount=$items.Count; Limit=1000; LimitReached=($items.Count -eq 1000); Critical=@($items | Where-Object Level -eq 1).Count; Errors=@($items | Where-Object Level -eq 2).Count; Warnings=@($items | Where-Object Level -eq 3).Count }
            }
        }
    }
    foreach ($name in $probes.Keys) {
        try {
            $rows = @(& $probes[$name])
            $sections.Add([pscustomobject]@{ Name=$name; Status='ok'; Data=$rows; Error=$null })
        } catch {
            $sections.Add([pscustomobject]@{ Name=$name; Status='unavailable'; Data=@(); Error=$_.Exception.Message })
        }
    }
    [pscustomobject]@{ SchemaVersion=1; ToolVersion='0.1.0'; GeneratedUtc=[DateTime]::UtcNow.ToString('o'); Sections=@($sections.ToArray()) }
}
function Write-WinFixHealthReport {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Data, [Parameter(Mandatory)][string]$OutputDirectory, [ValidateSet('en','fr')][string]$Language='en')
    $fr = $Language -eq 'fr'
    $title = if ($fr) { 'Rapport de santé du système' } else { 'System health report' }
    $notice = if ($fr) { 'Inventaire en lecture seule, sans score de santé. Une section indisponible ne prouve pas une panne. Les événements sont limités aux 1 000 plus récents par journal ; leurs nombres ne constituent pas un diagnostic. Les rapports peuvent contenir des informations privées : vérifiez-les avant partage.' } else { 'Read-only inventory, without a health score. An unavailable section does not prove a fault. Events are limited to the latest 1,000 per log; counts are not a diagnosis. Reports may contain private information: review before sharing.' }
    $labels = if ($fr) { @{Windows='Windows';Computer='Ordinateur';Processor='Processeur';Volumes='Volumes';Drivers='Pilotes';Events='Événements'} } else { @{} }
    $encode = { param($value) [Net.WebUtility]::HtmlEncode([string]$value) }
    $body = New-Object Text.StringBuilder
    foreach ($section in $Data.Sections) {
        $heading = $section.Name
        if ($labels.ContainsKey($heading)) { $heading = $labels[$heading] }
        [void]$body.Append('<section><h2>' + (& $encode $heading) + '</h2>')
        if ($section.Status -ne 'ok') {
            $unavailable = if ($fr) { 'Indisponible' } else { 'Unavailable' }
            [void]$body.Append('<p>' + $unavailable + ': ' + (& $encode $section.Error) + '</p>')
        } elseif (@($section.Data).Count -eq 0) {
            [void]$body.Append($(if ($fr) { '<p>Aucune donnée.</p>' } else { '<p>No data.</p>' }))
        } else {
            foreach ($row in $section.Data) {
                [void]$body.Append('<dl>')
                foreach ($property in $row.PSObject.Properties) {
                    $value = $property.Value
                    if ($value -is [datetime]) { $value = $value.ToUniversalTime().ToString('o') }
                    [void]$body.Append('<dt>' + (& $encode $property.Name) + '</dt><dd>' + (& $encode $value) + '</dd>')
                }
                [void]$body.Append('</dl>')
            }
        }
        [void]$body.Append('</section>')
    }
    $html = '<!doctype html><html lang="' + $Language + '"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>' + $title + '</title><style>body{font:16px system-ui;max-width:1000px;margin:2rem auto;padding:0 1rem;color:#17212b}section{border-top:1px solid #ccc}dl{padding:1rem;background:#f2f5f8;overflow-wrap:anywhere}dt{font-weight:bold}dd{margin:0 0 .5rem}</style><h1>' + $title + '</h1><p>' + $notice + '</p><p>UTC: ' + (& $encode $Data.GeneratedUtc) + '</p>' + $body.ToString() + '</html>'
    $json = $Data | ConvertTo-Json -Depth 12
    $null = New-Item -ItemType Directory -Path $OutputDirectory -Force -ErrorAction Stop
    # A separate directory for each run prevents overwriting an earlier report.
    $run = Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) ('WinFix-Health-' + [guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $run -ErrorAction Stop
    $utf8 = New-Object Text.UTF8Encoding($true)
    [IO.File]::WriteAllText((Join-Path $run 'report.html'), $html, $utf8)
    [IO.File]::WriteAllText((Join-Path $run 'report.json'), $json, $utf8)
    return $run
}
Export-ModuleMember -Function Get-WinFixHealthData, Write-WinFixHealthReport
