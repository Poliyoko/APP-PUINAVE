[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Component,

    [Parameter(Mandatory = $true)]
    [string[]]$TestPath,

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

if (@($TestPath).Count -eq 0) {
    throw "Debe proporcionar al menos una ruta de prueba."
}

foreach ($Path in $TestPath) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "No existe la ruta de prueba: $Path"
    }
}

$ReportParent = Split-Path -Parent $ReportPath
if ($ReportParent) {
    New-Item -ItemType Directory -Path $ReportParent -Force | Out-Null
}

$PytestArguments = @(
    "-m",
    "pytest"
)

$PytestArguments += @($TestPath)
$PytestArguments += @(
    "--junitxml=$ReportPath",
    "-q"
)

& python @PytestArguments

if ($LASTEXITCODE -ne 0) {
    throw "pytest terminó con errores. Código: $LASTEXITCODE"
}

$SummaryArguments = @(
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
    $SummaryArguments += @(
        "--evidence",
        $EvidencePath
    )
}

& python @SummaryArguments

exit $LASTEXITCODE