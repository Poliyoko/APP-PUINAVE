[CmdletBinding()]
param(
    [switch]$Publish,
    [string]$CommitMessage = "chore(repository): canonical institutional publish",
    [string]$EvidenceCommitMessage = "chore(repository): publish canonical release evidence"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

$Validation = Join-Path `
    $Root `
    "artifacts\pmo\SGD-114G-v1.0.0\prepublish-validation.json"

python -m sgoda.governance.release_management.cli `
    --root "$Root" `
    --operation "normalize-all" `
    --output-json "$Validation"

if ($LASTEXITCODE -ne 0) {
    throw "SGD-114G no pudo normalizar los releases."
}

python -m sgoda.governance.release_management.cli `
    --root "$Root" `
    --operation "validate" `
    --output-json "$Validation"

if ($LASTEXITCODE -ne 0) {
    throw "SGD-114G bloqueó la publicación por inconsistencias de release."
}

$Publisher = Join-Path `
    $PSScriptRoot `
    "Invoke-SPB007-InstitutionalPublish.ps1"

if ($Publish) {
    & $Publisher `
        -Publish `
        -CommitMessage $CommitMessage `
        -EvidenceCommitMessage $EvidenceCommitMessage
}
else {
    & $Publisher
}

exit $LASTEXITCODE