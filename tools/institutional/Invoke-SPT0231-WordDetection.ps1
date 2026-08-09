[CmdletBinding()]param([Parameter(Mandatory=$true)][string]$SourcePath)
Set-StrictMode -Version Latest;$ErrorActionPreference="Stop"
$r=@(& git rev-parse --show-toplevel 2>$null);if($LASTEXITCODE -ne 0 -or $r.Count -eq 0){throw "No repository root."}
$root=([string]$r[0]).Trim();$source=$SourcePath;if(-not[IO.Path]::IsPathRooted($source)){$source=Join-Path $root $source};if(-not(Test-Path -LiteralPath $source -PathType Leaf)){throw "Source not found: $source"}
$env:PYTHONPATH=Join-Path $root "src";& python -m sgoda.integration.spt0231.cli --project-root $root --source $source;if($LASTEXITCODE -ne 0){throw "SPT-023.1 detection failed."}