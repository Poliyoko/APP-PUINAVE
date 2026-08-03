[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Component,

    [Parameter(Mandatory = $true)]
    [string]$TestPath,

    [Parameter(Mandatory = $true)]
    [string]$ReportPath,

    [Parameter(Mandatory = $true)]
    [string]$SummaryJson,

    [Parameter(Mandatory = $true)]
    [string]$SummaryMarkdown,

    [string]$Scope = "specific",

    [string]$EvidencePath,

    [string]$EvidenceKey = "specific_tests"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

$ReportParent = Split-Path -Parent $ReportPath
if ($ReportParent) {
    New-Item -ItemType Directory -Path $ReportParent -Force | Out-Null
}

& python -m pytest `
    "$TestPath" `
    --junitxml="$ReportPath" `
    -q

if ($LASTEXITCODE -ne 0) {
    throw "pytest terminó con errores. Código: $LASTEXITCODE"
}

$Arguments = @(
    "-m",
    "sgoda.governance.test_evidence.cli",
    "--junit",
    $ReportPath,
    "--component",
    $Component,
    "--scope",
    $Scope,
    "--output-json",
    $SummaryJson,
    "--output-md",
    $SummaryMarkdown,
    "--evidence-key",
    $EvidenceKey
)

if ($EvidencePath) {
    $Arguments += @(
        "--evidence",
        $EvidencePath
    )
}

& python @Arguments

exit $LASTEXITCODE