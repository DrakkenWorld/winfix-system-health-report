#requires -Version 5.1
[CmdletBinding()]
param([string]$OutputDirectory = (Join-Path $PSScriptRoot '../artifacts'))
$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) { throw 'The Windows x64 .NET Framework compiler is required.' }
$repository = Split-Path $PSScriptRoot -Parent
$output = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDirectory)
$null = [IO.Directory]::CreateDirectory($output)
$exe = Join-Path $output 'WinFix-SystemHealthReport-Windows-x64.exe'
$manifest = Join-Path $PSScriptRoot 'app.manifest'
$worker = Join-Path $PSScriptRoot 'Collect.ps1'
$module = Join-Path $repository 'script\WinFix.Health.psm1'
$license = Join-Path $repository 'LICENSE'
$source = Join-Path $PSScriptRoot 'Program.cs'
$arguments = @(
    '/nologo', '/target:winexe', '/platform:x64', '/optimize+', '/codepage:65001',
    '/warnaserror+', "/out:$exe", "/win32manifest:$manifest",
    '/reference:System.Windows.Forms.dll', '/reference:System.Drawing.dll',
    "/resource:$worker,Collect.ps1",
    "/resource:$module,WinFix.Health.psm1",
    "/resource:$license,LICENSE", $source
)
& $compiler @arguments
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw 'Portable application build failed.' }
Write-Host $exe
