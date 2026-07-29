$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$VenvPython = Join-Path $Root ".venv\Scripts\python.exe"

if (-not (Test-Path $VenvPython)) {
    throw "No existe .venv. Ejecute primero el instalador."
}

$env:PYTHONPATH = Join-Path $Root "src"
& $VenvPython -m pytest tests/test_spb_005_1_foundation_runtime.py -v
if ($LASTEXITCODE -ne 0) {
    throw "Las pruebas de SPB-005.1-F001 fallaron."
}
