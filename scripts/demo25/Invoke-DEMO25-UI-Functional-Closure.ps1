param()

$ErrorActionPreference = 'Stop'

$Repo = (git rev-parse --show-toplevel).Trim()
Set-Location -LiteralPath $Repo

$Python =
    Join-Path $Repo `
        ".venv\Scripts\python.exe"

$Transformer =
    Join-Path $Repo `
        "scripts\demo25\apply_demo25_ui_functional_closure.py"

if (-not (Test-Path -LiteralPath $Python -PathType Leaf)) {
    throw "PROJECT_VENV_PYTHON_MISSING"
}

if (-not (Test-Path -LiteralPath $Transformer -PathType Leaf)) {
    throw "PERSISTENT_UI_TRANSFORMER_MISSING"
}

& $Python $Transformer $Repo

if ($LASTEXITCODE -ne 0) {
    throw "PERSISTENT_UI_TRANSFORM_FAILED"
}

Write-Host "DEMO25_UI_PERSISTENT_TRANSFORM=PASS"