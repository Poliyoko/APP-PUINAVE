param()

$ErrorActionPreference = 'Stop'

$Repo = (git rev-parse --show-toplevel).Trim()
Set-Location -LiteralPath $Repo

$Python =
    Join-Path $Repo ".venv\Scripts\python.exe"

$Generator =
    Join-Path $Repo `
        "scripts\demo25\build_demo25_ui_config_driven.py"

if (-not (Test-Path -LiteralPath $Python -PathType Leaf)) {
    throw "PROJECT_VENV_PYTHON_MISSING"
}

if (-not (Test-Path -LiteralPath $Generator -PathType Leaf)) {
    throw "CONFIG_DRIVEN_GENERATOR_MISSING"
}

& $Python $Generator $Repo

if ($LASTEXITCODE -ne 0) {
    throw "CONFIG_DRIVEN_GENERATION_FAILED"
}

Write-Host "DEMO25_CONFIG_DRIVEN_GENERATION=PASS"