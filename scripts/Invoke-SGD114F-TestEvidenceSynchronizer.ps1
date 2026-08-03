[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Junit,

    [Parameter(Mandatory = $true)]
    [string]$Component,

    [Parameter(Mandatory = $true)]
    [string]$Scope,

    [Parameter(Mandatory = $true)]
    [string]$OutputJson,

    [Parameter(Mandatory = $true)]
    [string]$OutputMarkdown,

    [string]$Evidence,

    [string]$EvidenceKey = "specific_tests"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

$Arguments = @(
    "-m",
    "sgoda.governance.test_evidence.cli",
    "--junit",
    $Junit,
    "--component",
    $Component,
    "--scope",
    $Scope,
    "--output-json",
    $OutputJson,
    "--output-md",
    $OutputMarkdown,
    "--evidence-key",
    $EvidenceKey
)

if ($Evidence) {
    $Arguments += @(
        "--evidence",
        $Evidence
    )
}

& python @Arguments

exit $LASTEXITCODE