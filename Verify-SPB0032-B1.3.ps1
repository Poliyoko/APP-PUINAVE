[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path $RepositoryRoot).Path
$env:PYTHONPATH = Join-Path $root "src"

$required = @(
    "src\sgoda\pmo\audit\checks\quality.py",
    "tests\pmo\audit\test_b1_3_quality.py",
    ".github\workflows\spb-003-2-closure-audit.yml",
    "artifacts\development\spb-003.2-b1.3\manifest.json"
)

$missing = @($required | Where-Object { -not (Test-Path (Join-Path $root $_)) })
if ($missing.Count -gt 0) {
    throw "Faltan archivos B1.3: $($missing -join ', ')"
}

Push-Location $root
try {
    Write-Host "1/4 Pruebas PMO" -ForegroundColor Yellow
    python -m pytest -q tests/pmo/audit
    if ($LASTEXITCODE -ne 0) { throw "Pruebas PMO fallidas." }

    Write-Host "2/4 Pruebas Builder" -ForegroundColor Yellow
    if (Test-Path ".\builder\tests") {
        Push-Location ".\builder"
        try {
            python -m pytest -q
            if ($LASTEXITCODE -ne 0) { throw "Pruebas Builder fallidas." }
        }
        finally { Pop-Location }
    }
    else {
        Write-Warning "No existe builder\tests."
    }

    Write-Host "3/4 Auditor modular" -ForegroundColor Yellow
    python -m sgoda.pmo.audit.cli --repository . --output artifacts/audit/spb-003.2
    $auditExit = $LASTEXITCODE
    if ($auditExit -notin @(0,2)) { throw "Código inesperado del Auditor: $auditExit" }

    Write-Host "4/4 Validación de evidencias" -ForegroundColor Yellow
    $json = ".\artifacts\audit\spb-003.2\SGD-401-auditoria-integral.json"
    $md = ".\artifacts\audit\spb-003.2\SGD-401-informe-auditoria-integral.md"
    $act = ".\artifacts\audit\spb-003.2\ACT-003.2-acta-tecnica-cierre.md"
    foreach ($path in @($json,$md,$act)) {
        if (-not (Test-Path $path)) { throw "No se generó: $path" }
    }

    $data = Get-Content $json -Raw -Encoding utf8 | ConvertFrom-Json
    Write-Host ""
    Write-Host "Dictamen: $($data.verdict)" -ForegroundColor Cyan
    Write-Host "Cumplimiento: $($data.compliance_percentage)%"
    Write-Host "Bloqueantes: $($data.blocking_findings)"
    Write-Host "Verificación B1.3 completada." -ForegroundColor Green
}
finally {
    Pop-Location
}
