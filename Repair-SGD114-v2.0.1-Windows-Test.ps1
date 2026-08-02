<#
.SYNOPSIS
    Corrige la prueba Windows de SGD-114 v2.0 y completa su validación.

.DESCRIPTION
    Soluciona WinError 145 en:
      test_SGD_114_v2_detecta_directorio_faltante

    La prueba utilizaba Path.rmdir() sobre dashboard/, pero el fixture
    había creado dashboard/status.json. El correctivo usa shutil.rmtree()
    y luego ejecuta:
      - 6 pruebas específicas;
      - suite completa;
      - auditoría institucional real;
      - manifiesto SHA-256;
      - evento PMO;
      - publicación del release;
      - quality gate y cierre institucional.

.PARAMETER ProjectRoot
    Ruta raíz del repositorio SGODA-PUINAVE.

.PARAMETER RequireCleanGit
    Exige un worktree limpio durante la auditoría. No se recomienda antes
    de hacer commit de este correctivo.

.EXAMPLE
    .\Repair-SGD114-v2.0.1-Windows-Test.ps1
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$RequireCleanGit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Assert-Path {
    param([string]$Path, [string]$Description)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se encontró $Description en: $Path"
    }
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)

    $Parent = Split-Path -Parent $Path

    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se pudo crear: $Path"
    }

    $Info = Get-Item -LiteralPath $Path

    if ($Info.Length -le 0) {
        throw "El archivo quedó vacío: $Path"
    }

    Write-Host "Corregido: $Path ($($Info.Length) bytes)" -ForegroundColor Green
}

function Write-JsonUtf8 {
    param([string]$Path, [object]$Data)

    $Parent = Split-Path -Parent $Path

    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    $Json = $Data | ConvertTo-Json -Depth 50

    [System.IO.File]::WriteAllText(
        $Path,
        $Json + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot

$SrcRoot = Join-Path $ProjectRoot "src"
$env:PYTHONPATH = $SrcRoot

$TestPath = Join-Path $ProjectRoot "tests\governance\test_SGD_114_v2_repository_governance.py"
$ModulePath = Join-Path $ProjectRoot "src\sgoda\governance\repository_governance.py"
$PolicyPath = Join-Path $ProjectRoot "config\governance\sgd-114-v2-repository-policy.json"
$LegacyGatePolicy = Join-Path $ProjectRoot "config\governance\sgd-114-policy.json"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\pmo\SGD-114-v2"
$AuditPath = Join-Path $ArtifactsDir "repository-audit.json"
$ManifestPath = Join-Path $ArtifactsDir "repository-manifest.json"
$EventPath = Join-Path $ArtifactsDir "repository-governance-event.json"
$RepairEvidencePath = Join-Path $ArtifactsDir "SGD-114-v2.0.1-windows-test-evidence.json"
$GatePath = Join-Path $ArtifactsDir "SGD-114-v2-quality-gate.json"
$DashboardPath = Join-Path $ProjectRoot "dashboard\SGD-114-v2-dashboard.json"
$ReleaseDir = Join-Path $ProjectRoot "releases\SGD-114-v2.0.1"

Write-Step "Validando instalación parcial SGD-114 v2.0"

foreach ($Required in @(
    $TestPath,
    $ModulePath,
    $PolicyPath,
    $LegacyGatePolicy,
    (Join-Path $ProjectRoot "pytest.ini"),
    (Join-Path $ProjectRoot ".git")
)) {
    Assert-Path -Path $Required -Description $Required
}

$TestContent = Get-Content -LiteralPath $TestPath -Raw

Write-Step "Aplicando correctivo compatible con Windows"

if ($TestContent -notmatch "import shutil") {
    $TestContent = $TestContent -replace (
        "import json\r?\nimport subprocess",
        "import json`nimport shutil`nimport subprocess"
    )
}

$OldExpression = '(root / "dashboard").rmdir()'
$NewExpression = 'shutil.rmtree(root / "dashboard")'

if ($TestContent.Contains($OldExpression)) {
    $TestContent = $TestContent.Replace(
        $OldExpression,
        $NewExpression
    )
}
elseif (-not $TestContent.Contains($NewExpression)) {
    throw "No se encontró la instrucción rmdir esperada para corregir."
}

Write-Utf8NoBom -Path $TestPath -Content $TestContent

Write-Step "Verificando el cambio aplicado"

& python -c "from pathlib import Path; p=Path(r'tests/governance/test_SGD_114_v2_repository_governance.py'); t=p.read_text(encoding='utf-8'); assert 'import shutil' in t; assert 'shutil.rmtree(root / \"dashboard\")' in t; assert '(root / \"dashboard\").rmdir()' not in t; print('Correctivo Windows verificado')"

if ($LASTEXITCODE -ne 0) {
    throw "La verificación del correctivo falló."
}

Write-Step "Ejecutando la prueba que falló"

& python -m pytest `
    "tests/governance/test_SGD_114_v2_repository_governance.py::test_SGD_114_v2_detecta_directorio_faltante" `
    -q

if ($LASTEXITCODE -ne 0) {
    throw "La prueba corregida continúa fallando."
}

Write-Step "Ejecutando las 6 pruebas específicas"

& python -m pytest `
    "tests/governance/test_SGD_114_v2_repository_governance.py" `
    -q

if ($LASTEXITCODE -ne 0) {
    throw "Las pruebas específicas SGD-114 v2.0.1 fallaron."
}

Write-Step "Ejecutando suite completa"

& python -m pytest

if ($LASTEXITCODE -ne 0) {
    throw "La suite completa terminó con errores."
}

Write-Step "Ejecutando auditoría institucional real"

$AuditArguments = @(
    "-m",
    "sgoda.governance.repository_governance",
    "--root",
    $ProjectRoot,
    "--policy",
    "config/governance/sgd-114-v2-repository-policy.json",
    "--audit-output",
    "artifacts/pmo/SGD-114-v2/repository-audit.json",
    "--manifest-output",
    "artifacts/pmo/SGD-114-v2/repository-manifest.json",
    "--event-output",
    "artifacts/pmo/SGD-114-v2/repository-governance-event.json"
)

if ($RequireCleanGit) {
    $AuditArguments += "--require-clean-git"
}

& python @AuditArguments

if ($LASTEXITCODE -ne 0) {
    throw "La auditoría institucional real no fue aprobada."
}

foreach ($Artifact in @(
    $AuditPath,
    $ManifestPath,
    $EventPath
)) {
    Assert-Path -Path $Artifact -Description $Artifact
}

$Audit = Get-Content -LiteralPath $AuditPath -Raw |
    ConvertFrom-Json
$Manifest = Get-Content -LiteralPath $ManifestPath -Raw |
    ConvertFrom-Json

if (-not $Audit.passed) {
    throw "La auditoría no contiene passed=true."
}

if ([int]$Manifest.total_files -le 0) {
    throw "El manifiesto no contiene archivos."
}

Write-Step "Generando evidencia del correctivo"

$RepairEvidence = [ordered]@{
    increment_code = "SGD-114-v2"
    correction_version = "2.0.1"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    platform = "Windows"
    corrected_test = "test_SGD_114_v2_detecta_directorio_faltante"
    root_cause = "Path.rmdir requires an empty directory"
    correction = "shutil.rmtree removes the fixture directory recursively"
    failed_test_reexecuted = "approved"
    specific_tests = "6 approved"
    full_suite = "approved"
    audit = "approved"
    git_clean = $Audit.git.clean
    manifest_total_files = $Manifest.total_files
}
Write-JsonUtf8 -Path $RepairEvidencePath -Data $RepairEvidence

Write-Step "Publicando release correctivo"

if (-not (Test-Path -LiteralPath $ReleaseDir)) {
    New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null
}

foreach ($Artifact in @(
    $AuditPath,
    $ManifestPath,
    $EventPath,
    $RepairEvidencePath,
    $PolicyPath,
    $TestPath
)) {
    Copy-Item `
        -LiteralPath $Artifact `
        -Destination (Join-Path $ReleaseDir (Split-Path $Artifact -Leaf)) `
        -Force
}

Write-Step "Ejecutando quality gate y cierre institucional"

& python -m sgoda.governance.evidence_policy `
    --root "$ProjectRoot" `
    --policy "config/governance/sgd-114-policy.json" `
    --increment "SGD-114-v2" `
    --status "institutionally_closed" `
    --output "$GatePath"

if ($LASTEXITCODE -ne 0) {
    $Failure = Get-Content -LiteralPath $GatePath -Raw |
        ConvertFrom-Json
    $Missing = $Failure.missing_categories -join ", "
    throw "Quality gate SGD-114 v2.0.1 no aprobado. Faltan: $Missing"
}

$Gate = Get-Content -LiteralPath $GatePath -Raw |
    ConvertFrom-Json

if (-not $Gate.passed) {
    throw "El quality gate no contiene passed=true."
}

if (-not $Gate.closure_authorized) {
    throw "SGD-114 no autorizó el cierre institucional."
}

$Dashboard = [ordered]@{
    policy = "SGD-114"
    version = "2.0.1"
    status = "institutionally_closed"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    windows_test_fix = "approved"
    specific_tests = 6
    full_suite = "approved"
    audit_passed = $Audit.passed
    git_clean = $Audit.git.clean
    git_branch = $Audit.git.branch
    git_head = $Audit.git.head
    tracked_files = $Audit.git.tracked_files
    manifest_files = $Manifest.total_files
    quality_gate = "authorized"
    release = "SGD-114-v2.0.1"
}
Write-JsonUtf8 -Path $DashboardPath -Data $Dashboard

Write-Step "Resultado final"

Write-Host "SGD-114 v2.0.1 corregido y validado." -ForegroundColor Green
Write-Host "Prueba Windows: APROBADA." -ForegroundColor Green
Write-Host "Pruebas específicas: 6 APROBADAS." -ForegroundColor Green
Write-Host "Suite completa: APROBADA." -ForegroundColor Green
Write-Host "Auditoría institucional: APROBADA." -ForegroundColor Green
Write-Host "Manifiesto SHA-256: GENERADO." -ForegroundColor Green
Write-Host "Cierre institucional: AUTORIZADO." -ForegroundColor Green
Write-Host "Git limpio: $($Audit.git.clean)" -ForegroundColor Cyan
Write-Host "Archivos manifestados: $($Manifest.total_files)" -ForegroundColor Cyan
Write-Host "Suite total esperada: 97 pruebas." -ForegroundColor Cyan
Write-Host "Release: releases\SGD-114-v2.0.1" -ForegroundColor Cyan

if (-not $Audit.git.clean) {
    Write-Host ""
    Write-Host "El estado Git no está limpio porque existen cambios pendientes." -ForegroundColor Yellow
    Write-Host "Revise, confirme y publique los archivos antes de la auditoría estricta." -ForegroundColor Yellow
}
