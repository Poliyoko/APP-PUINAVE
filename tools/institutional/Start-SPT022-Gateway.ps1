[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = (& git rev-parse --show-toplevel).Trim()
Set-Location -LiteralPath $Root

$env:PYTHONPATH = Join-Path $Root "src"
$env:SGODA_PROJECT_ROOT = $Root

python -m uvicorn sgoda.main:app --host 127.0.0.1 --port 8000
exit $LASTEXITCODE