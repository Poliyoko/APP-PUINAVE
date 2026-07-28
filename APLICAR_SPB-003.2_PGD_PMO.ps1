param(
    [Parameter(Mandatory=$true)]
    [string]$RepoPath
)

$ErrorActionPreference = "Stop"
$Source = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Test-Path (Join-Path $RepoPath ".git"))) {
    throw "La ruta indicada no es un repositorio Git: $RepoPath"
}

$items = @("src", "tests", "scripts", "docs", "knowledge")
foreach ($item in $items) {
    $from = Join-Path $Source $item
    if (Test-Path $from) {
        Copy-Item $from $RepoPath -Recurse -Force
    }
}

Push-Location $RepoPath
try {
    $env:PYTHONPATH = (Resolve-Path ".\src").Path
    python -m compileall src
    pytest tests/test_pmo_governance_platform.py -q
    python scripts/pmo/generate_governance_platform.py --model knowledge/project_model.json --output .
    git diff --check
    git status --short
}
finally {
    Pop-Location
}
