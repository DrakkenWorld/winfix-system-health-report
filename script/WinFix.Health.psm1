#requires -Version 5.1
Set-StrictMode -Version 2.0
function New-WinFixEventReader {
    param([string]$LogName, [datetime]$StartUtc, [datetime]$EndUtc)
    # Read only raw event levels; never render provider descriptions/messages.
    $start = $StartUtc.ToUniversalTime().ToString('o')
    $end = $EndUtc.ToUniversalTime().ToString('o')
    $xpath = "*[System[(Level=1 or Level=2 or Level=3) and TimeCreated[@SystemTime >= '$start' and @SystemTime <= '$end']]]"
    $query = New-Object System.Diagnostics.Eventing.Reader.EventLogQuery($LogName, [System.Diagnostics.Eventing.Reader.PathType]::LogName, $xpath)
    $query.ReverseDirection = $true
    return (New-Object System.Diagnostics.Eventing.Reader.EventLogReader($query))
}
function Get-WinFixEventSummary {
    param([string]$LogName, [datetime]$StartUtc, [datetime]$EndUtc, [int]$Limit=1000)
    $reader = $null
    $count = 0; $critical = 0; $errors = 0; $warnings = 0; $truncated = $false
    try {
        $reader = New-WinFixEventReader $LogName $StartUtc $EndUtc
        while ($true) {
            $record = $reader.ReadEvent()
            if ($null -eq $record) { break }
            try {
                # One extra record distinguishes an exact limit from truncation.
                if ($count -eq $Limit) { $truncated = $true; break }
                switch ([int]$record.Level) { 1 { $critical++ } 2 { $errors++ } 3 { $warnings++ } }
                $count++
            } finally { $record.Dispose() }
        }
        [pscustomobject]@{ Log=$LogName; Status='ok'; StartUtc=$StartUtc.ToUniversalTime().ToString('o'); EndUtc=$EndUtc.ToUniversalTime().ToString('o'); ReturnedCount=$count; Limit=$Limit; Truncated=$truncated; Critical=$critical; Errors=$errors; Warnings=$warnings; Error=$null }
    } catch {
        # Failed reads are unknown, never a misleading zero. Other logs still run.
        [pscustomobject]@{ Log=$LogName; Status='unavailable'; StartUtc=$StartUtc.ToUniversalTime().ToString('o'); EndUtc=$EndUtc.ToUniversalTime().ToString('o'); ReturnedCount=$null; Limit=$Limit; Truncated=$null; Critical=$null; Errors=$null; Warnings=$null; Error=$_.Exception.Message }
    } finally { if ($null -ne $reader) { $reader.Dispose() } }
}
function Get-WinFixHealthData {
    [CmdletBinding()]
    param([ValidateRange(1,30)][int]$EventDays = 7)
    $sections = New-Object 'System.Collections.Generic.List[object]'
    $endUtc = [datetime]::UtcNow
    $startUtc = $endUtc.AddDays(-$EventDays)
    $probes = [ordered]@{
        Windows = { Get-CimInstance Win32_OperatingSystem -OperationTimeoutSec 15 -ErrorAction Stop | Select-Object Caption, Version, BuildNumber, OSArchitecture, @{n='LastBootUpTime';e={if ($_.LastBootUpTime) {$_.LastBootUpTime.ToUniversalTime().ToString('o')}}} }
        Computer = { Get-CimInstance Win32_ComputerSystem -OperationTimeoutSec 15 -ErrorAction Stop | Select-Object Manufacturer, Model, TotalPhysicalMemory, NumberOfLogicalProcessors }
        Processor = { Get-CimInstance Win32_Processor -OperationTimeoutSec 15 -ErrorAction Stop | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors }
        Volumes = { Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -OperationTimeoutSec 15 -ErrorAction Stop | Select-Object DeviceID, FileSystem, Size, FreeSpace }
        Drivers = { Get-CimInstance Win32_PnPSignedDriver -OperationTimeoutSec 15 -ErrorAction Stop | Sort-Object DeviceName | Select-Object DeviceName, DriverProviderName, DriverVersion, @{n='DriverDate';e={if ($_.DriverDate) {$_.DriverDate.ToUniversalTime().ToString('o')}}}, IsSigned }
        Events = {
            foreach ($log in @('System','Application')) {
                Get-WinFixEventSummary $log $startUtc $endUtc
            }
        }
    }
    foreach ($name in $probes.Keys) {
        try {
            $rows = @(& $probes[$name])
            $partial = $name -eq 'Events' -and @($rows | Where-Object Status -ne 'ok').Count -gt 0
            $status = if ($partial) { 'partial' } else { 'ok' }
            $sections.Add([pscustomobject]@{ Name=$name; Status=$status; Data=$rows; Error=$null })
        } catch {
            $sections.Add([pscustomobject]@{ Name=$name; Status='unavailable'; Data=@(); Error=$_.Exception.Message })
        }
    }
    [pscustomobject]@{ SchemaVersion=1; ToolVersion='1.1.0'; GeneratedUtc=$endUtc.ToString('o'); Sections=@($sections.ToArray()) }
}
function Write-WinFixHealthReport {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Data, [Parameter(Mandatory)][string]$OutputDirectory, [ValidateSet('en','fr')][string]$Language='en')
    $fr = $Language -eq 'fr'
    $title = if ($fr) { 'Rapport de santé du système' } else { 'System health report' }
    $notice = if ($fr) { 'Inventaire en lecture seule, sans score de santé. Une section indisponible ne prouve pas une panne. Les événements sont limités aux 1 000 plus récents par journal ; leurs nombres ne constituent pas un diagnostic. Les rapports peuvent contenir des informations privées : vérifiez-les avant partage.' } else { 'Read-only inventory, without a health score. An unavailable section does not prove a fault. Events are limited to the latest 1,000 per log; counts are not a diagnosis. Reports may contain private information: review before sharing.' }
    $labels = if ($fr) { @{Windows='Windows';Computer='Ordinateur';Processor='Processeur';Volumes='Volumes';Drivers='Pilotes';Events='Événements'} } else { @{} }
    $fields = if ($fr) { @{
        Caption='Édition';Version='Version';BuildNumber='Build';OSArchitecture='Architecture';LastBootUpTime='Dernier démarrage (UTC)';Manufacturer='Fabricant';Model='Modèle';TotalPhysicalMemory='Mémoire physique (octets)';NumberOfLogicalProcessors='Processeurs logiques';Name='Nom';NumberOfCores='Cœurs';DeviceID='Lecteur';FileSystem='Système de fichiers';Size='Capacité (octets)';FreeSpace='Espace libre (octets)';DeviceName='Périphérique';DriverProviderName='Éditeur du pilote';DriverVersion='Version du pilote';DriverDate='Date du pilote (UTC)';IsSigned='Signé';Log='Journal';Status='Statut';StartUtc='Début (UTC)';EndUtc='Fin (UTC)';ReturnedCount='Événements comptés';Limit='Limite';Truncated='Résultats tronqués';Critical='Critiques';Errors='Erreurs';Warnings='Avertissements';Error='Erreur de collecte'
    } } else { @{
        Caption='Edition';BuildNumber='Build';OSArchitecture='Architecture';LastBootUpTime='Last boot (UTC)';TotalPhysicalMemory='Physical memory (bytes)';NumberOfLogicalProcessors='Logical processors';NumberOfCores='Cores';DeviceID='Drive';FileSystem='File system';Size='Capacity (bytes)';FreeSpace='Free space (bytes)';DeviceName='Device';DriverProviderName='Driver provider';DriverVersion='Driver version';DriverDate='Driver date (UTC)';IsSigned='Signed';StartUtc='Start (UTC)';EndUtc='End (UTC)';ReturnedCount='Events counted';Truncated='Truncated';Error='Collection error'
    } }
    $encode = { param($value) [Net.WebUtility]::HtmlEncode([string]$value) }
    $display = {
        param($value)
        if ($null -eq $value) { return '—' }
        if ($value -is [bool]) { if ($value) { if ($fr) { return 'Oui' }; return 'Yes' }; if ($fr) { return 'Non' }; return 'No' }
        if ($value -is [datetime]) { return $value.ToUniversalTime().ToString('o') }
        if ($value -eq 'unavailable') { if ($fr) { return 'Indisponible' }; return 'Unavailable' }
        if ($value -eq 'ok') { if ($fr) { return 'Collecté' }; return 'Collected' }
        return [string]$value
    }
    $body = New-Object Text.StringBuilder
    foreach ($section in $Data.Sections) {
        $heading = $section.Name
        if ($labels.ContainsKey($heading)) { $heading = $labels[$heading] }
        [void]$body.Append('<section id="' + (& $encode $section.Name) + '"><h2>' + (& $encode $heading) + '</h2>')
        if ($section.Name -eq 'Drivers') {
            $summary = if ($fr) { 'Afficher les pilotes' } else { 'Show drivers' }
            [void]$body.Append('<details><summary>' + $summary + ' (' + @($section.Data).Count + ')</summary>')
        }
        if ($section.Status -eq 'unavailable') {
            $unavailable = if ($fr) { 'Indisponible' } else { 'Unavailable' }
            [void]$body.Append('<p>' + $unavailable + ': ' + (& $encode $section.Error) + '</p>')
        } elseif (@($section.Data).Count -eq 0) {
            [void]$body.Append($(if ($fr) { '<p>Aucune donnée.</p>' } else { '<p>No data.</p>' }))
        } else {
            if ($section.Status -eq 'partial') {
                [void]$body.Append($(if ($fr) { '<p class="warning">Collecte partielle : consultez le statut de chaque journal.</p>' } else { '<p class="warning">Partial collection: check each log status.</p>' }))
            }
            foreach ($row in $section.Data) {
                [void]$body.Append('<dl>')
                foreach ($property in $row.PSObject.Properties) {
                    $value = $property.Value
                    if ($value -is [datetime]) { $value = $value.ToUniversalTime().ToString('o') }
                    $field = $property.Name
                    if ($fields.ContainsKey($field)) { $field = $fields[$field] }
                    [void]$body.Append('<dt>' + (& $encode $field) + '</dt><dd>' + (& $encode (& $display $value)) + '</dd>')
                }
                [void]$body.Append('</dl>')
            }
        }
        if ($section.Name -eq 'Drivers') { [void]$body.Append('</details>') }
        [void]$body.Append('</section>')
    }
    $complete = @($Data.Sections | Where-Object Status -eq 'ok').Count
    $coverage = if ($fr) { "$complete / $(@($Data.Sections).Count) sections collectées intégralement" } else { "$complete / $(@($Data.Sections).Count) sections fully collected" }
    $nav = foreach ($section in $Data.Sections) {
        $name = $section.Name; if ($labels.ContainsKey($name)) { $name = $labels[$name] }
        '<a href="#' + (& $encode $section.Name) + '">' + (& $encode $name) + '</a>'
    }
    $html = '<!doctype html><html lang="' + $Language + '"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta name="color-scheme" content="light"><title>' + $title + '</title><style>
*{box-sizing:border-box}body{font:16px/1.6 system-ui,sans-serif;background:#eef3f8;color:#172b40;margin:0}header,main,footer{max-width:1080px;margin:auto;padding:32px 24px}header{padding-top:56px}h1{font-size:clamp(2rem,5vw,3.4rem);line-height:1.12;letter-spacing:-.04em;margin:12px 0 24px}h2{font-size:1.4rem;margin:0 0 20px}.eyebrow{font-size:.8rem;font-weight:750;letter-spacing:.16em;color:#186a79}.coverage{display:inline-block;background:#d7eef0;padding:8px 16px;border-radius:24px;font-weight:650}.notice{max-width:850px}nav{display:flex;flex-wrap:wrap;gap:10px;margin-top:24px}a{color:#13596c;text-underline-offset:4px}nav a{border:1px solid #b6cbd8;padding:6px 14px;border-radius:8px;text-decoration:none}a:focus-visible,summary:focus-visible{outline:3px solid #186a79;outline-offset:4px}main{padding-top:0}section{background:white;border:1px solid #dae3ec;border-radius:16px;margin-bottom:20px;padding:28px;scroll-margin-top:16px}dl{display:grid;grid-template-columns:minmax(140px,1fr) minmax(0,2fr);gap:8px 24px;border-top:1px solid #e4eaf0;padding-top:20px;margin:20px 0;overflow-wrap:anywhere}dt{font-weight:650;color:#456078}dd{margin:0}.warning{background:#fff1d6;color:#704a00;padding:12px 16px;border-radius:8px}summary{cursor:pointer;font-weight:650;color:#13596c}footer{font-size:.85rem;color:#456078;padding-top:0}@media(max-width:560px){section{padding:20px}dl{grid-template-columns:1fr;gap:2px}dd{margin-bottom:12px}header,main,footer{padding-left:16px;padding-right:16px}}@media print{body{background:white}header{padding-top:0}nav{display:none}section{border-radius:0;break-inside:avoid}details:not([open]){display:none}}
</style></head><body><header><div class="eyebrow">WINFIX KIT · SYSTEM HEALTH REPORT 1.1.0</div><h1>' + $title + '</h1><p class="coverage">' + $coverage + '</p><p class="notice">' + $notice + '</p><p>UTC: ' + (& $encode $Data.GeneratedUtc) + '</p><nav aria-label="Sections">' + ($nav -join '') + '</nav></header><main>' + $body.ToString() + '</main><footer>WinFix Kit · MIT · HTML / JSON · ' + $(if ($fr) {'Les détails des pilotes sont repliés par défaut. Dépliez-les avant impression.'} else {'Driver details are collapsed by default. Expand them before printing.'}) + '</footer></body></html>'
    $json = $Data | ConvertTo-Json -Depth 12
    $output = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
    $null = New-Item -ItemType Directory -Path $output -Force -ErrorAction Stop
    # A separate directory for each run prevents overwriting an earlier report.
    $run = Join-Path $output ('WinFix-Health-' + [guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $run -ErrorAction Stop
    $utf8 = New-Object Text.UTF8Encoding($true)
    [IO.File]::WriteAllText((Join-Path $run 'report.html'), $html, $utf8)
    [IO.File]::WriteAllText((Join-Path $run 'report.json'), $json, $utf8)
    return $run
}
Export-ModuleMember -Function Get-WinFixHealthData, Write-WinFixHealthReport
