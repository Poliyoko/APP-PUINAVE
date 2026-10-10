param(
    [Parameter(Mandatory=$true)][string]$SourceView,
    [Parameter(Mandatory=$true)][string]$Taxonomy,
    [Parameter(Mandatory=$true)][string]$Output,
    [string]$Python = 'python'
)
$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$PreviousPythonPath = $env:PYTHONPATH
try {
    $env:PYTHONPATH = Join-Path $RepoRoot 'src'
    & $Python -m sgoda.integration.spt0233.real508_preparation --source-view $SourceView --taxonomy $Taxonomy --output $Output
    if ($LASTEXITCODE -ne 0) { throw 'REAL508 category preparation failed.' }
} finally {
    $env:PYTHONPATH = $PreviousPythonPath
}
