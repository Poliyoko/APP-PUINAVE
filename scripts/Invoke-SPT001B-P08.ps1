[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

python -m sgoda.rlb.canonical_consolidator `
    --canonical "artifacts/rlb/SPT-001B-P07/reprocessed/palabras-canonicas.json" `
    --profile "artifacts/rlb/SPT-001B-P07/reprocessed/perfil-rlb.json" `
    --errors "artifacts/rlb/SPT-001B-P07/reprocessed/errores-importacion.json" `
    --schema "artifacts/rlb/SPT-001B-P07/schema-p07-normalized.json" `
    --output "artifacts/rlb/SPT-001B-P08"

if ($LASTEXITCODE -ne 0) {
    throw "SPT-001B-P08 terminó con errores."
}