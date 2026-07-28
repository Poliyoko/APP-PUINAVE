[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepositoryRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

[Console]::InputEncoding  = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$root = (Resolve-Path $RepositoryRoot).Path
Push-Location $root

try {
    $env:PYTHONPATH = Join-Path $root "src"

    Write-Host "1/4 Compilación del Auditor" -ForegroundColor Yellow
    python -m compileall -q .\src\sgoda\pmo
    if ($LASTEXITCODE -ne 0) {
        throw "Falló la compilación del PMO."
    }

    Write-Host "2/4 Pruebas PMO" -ForegroundColor Yellow
    python -m pytest -q tests/pmo/audit
    if ($LASTEXITCODE -ne 0) {
        throw "Fallaron las pruebas PMO."
    }

    Write-Host "3/4 Pruebas Builder" -ForegroundColor Yellow
    Push-Location .\builder
    try {
        python -m pytest -q
        if ($LASTEXITCODE -ne 0) {
            throw "Fallaron las pruebas Builder."
        }
    }
    finally {
        Pop-Location
    }

    Write-Host "4/4 Auditor modular" -ForegroundColor Yellow
    python -m sgoda.pmo.audit.cli `
        --repository . `
        --output artifacts/audit/spb-003.2

    $auditExit = $LASTEXITCODE
    if ($auditExit -notin @(0, 2)) {
        throw "Código inesperado del Auditor: $auditExit"
    }

    $jsonPath = ".\artifacts\audit\spb-003.2\SGD-401-informe-auditoria-integral.json"
    if (-not (Test-Path $jsonPath)) {
        throw "No se generó $jsonPath"
    }

    $data = Get-Content $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $blocking = @($data.findings | Where-Object { $_.blocking -eq $true })
    $mojibake = @(
        $data.findings |
        Where-Object { $_.code -eq "AIR-QLT-002" }
    )
    $git = @(
        $data.findings |
        Where-Object { $_.code -eq "AIR-GIT-002" }
    )

    Write-Host ""
    Write-Host "RESULTADO B1.4" -ForegroundColor Cyan
    Write-Host "Dictamen:        $($data.verdict)"
    Write-Host "Cumplimiento:    $($data.compliance_percentage)%"
    Write-Host "Bloqueantes:     $($data.blocking_findings)"
    Write-Host "Mojibake:        $($mojibake[0].status)"
    Write-Host "Estado Git:      $($git[0].status)"
    Write-Host ""

    $blocking |
        Select-Object code, category, status, title, recommendation |
        Format-Table -Wrap -AutoSize

    if ($mojibake[0].status -ne "PASS") {
        throw "Continúa pendiente AIR-QLT-002."
    }

    Write-Host "B1.4 validado: el bloqueante de mojibake fue resuelto." -ForegroundColor Green

    if ($git[0].status -ne "PASS") {
        Write-Warning "Solo queda normalizar el árbol Git mediante el script de preparación."
    }
}
finally {
    Pop-Location
}
