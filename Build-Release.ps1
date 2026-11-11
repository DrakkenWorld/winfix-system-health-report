#requires -Version 5.1
[CmdletBinding()]
param([string]$OutputDirectory = (Join-Path $PSScriptRoot 'artifacts'), [switch]$IncludeDesktop)
$ErrorActionPreference='Stop'
$version=(Get-Content (Join-Path $PSScriptRoot 'VERSION') -Raw).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw 'Invalid version' }
$output=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
$null=New-Item -ItemType Directory -Path $output -Force
$tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$stage=Join-Path $tempRoot ('WinFixHealthPackage-' + [guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $stage
try {
    foreach ($item in @('script','docs','Start-FR.cmd','Start-EN.cmd','README.md','README.fr.md','LICENSE','VERSION')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $item) -Destination $stage -Recurse
    }
    $zip=Join-Path $output "WinFix-SystemHealthReport-v$version.zip"
    if (Test-Path -LiteralPath $zip) { throw "Output already exists: $zip. Use a new output directory." }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::CreateFromDirectory($stage,$zip)
    $assets = @($zip)
    if ($IncludeDesktop) {
        & "$PSScriptRoot/desktop/Build-Portable.ps1" -OutputDirectory $output
        $assets += Join-Path $output 'WinFix-SystemHealthReport-Windows-x64.exe'
    }
    $hashes = foreach ($asset in $assets) {
        '{0}  {1}' -f (Get-FileHash -LiteralPath $asset -Algorithm SHA256).Hash.ToLowerInvariant(), [IO.Path]::GetFileName($asset)
    }
    [IO.File]::WriteAllLines((Join-Path $output 'SHA256SUMS.txt'), [string[]]$hashes, [Text.Encoding]::ASCII)
    Write-Host $zip
} finally {
    if ([IO.Path]::GetDirectoryName($stage) -eq $tempRoot.TrimEnd([IO.Path]::DirectorySeparatorChar)) {
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
}
