<#
.SYNOPSIS
    Corrige la resolución de la ruta del Excel oficial en SPT-001B-P06.

.DESCRIPTION
    Este correctivo parte de P06 v1.1 ya validado con 68 pruebas.
    Resuelve rutas relativas contra la raíz del repositorio, localiza
    automáticamente archivos .xlsx y completa:
      - procesamiento del Excel oficial;
      - artefactos RLB;
      - evento RepositoryImported;
      - evidencia del correctivo;
      - dashboard;
      - quality gate SGD-114.

.PARAMETER ProjectRoot
    Ruta raíz del repositorio.

.PARAMETER OfficialExcelPath
    Ruta absoluta o relativa al Excel oficial.

.EXAMPLE
    .\Repair-SPT001B-P06-v1.2-ExcelPath.ps1

.EXAMPLE
    .\Repair-SPT001B-P06-v1.2-ExcelPath.ps1 `
        -OfficialExcelPath ".\Repositorio LExico Base (Excel)-1.xlsx"
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [string]$OfficialExcelPath = ""
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

function Resolve-ProjectPath {
    param(
        [string]$Root,
        [string]$PathValue
    )

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return ""
    }

    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }

    return [System.IO.Path]::GetFullPath(
        (Join-Path $Root $PathValue)
    )
}

function Write-JsonUtf8 {
    param([string]$Path, [object]$Data)

    $Parent = Split-Path -Parent $Path

    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    $Json = $Data | ConvertTo-Json -Depth 20

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

$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-001B-P06"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\rlb\SPT-001B-P06"
$DashboardPath = Join-Path $ProjectRoot "dashboard\SPT-001B-P06-dashboard.json"
$GatePath = Join-Path $PmoDir "SPT-001B-P06-quality-gate.json"
$EvidencePath = Join-Path $PmoDir "SPT-001B-P06-v1.2-excel-path-evidence.json"

Write-Step "Validando línea base P06"

foreach ($Required in @(
    "src\sgoda\rlb\pipeline.py",
    "src\sgoda\rlb\cli.py",
    "src\sgoda\rlb\__init__.py",
    "tests\rlb\test_pipeline_p06.py",
    "config\rlb\schema-v1.json",
    "config\governance\sgd-114-policy.json"
)) {
    Assert-Path `
        -Path (Join-Path $ProjectRoot $Required) `
        -Description $Required
}

Write-Step "Resolviendo Excel oficial"

if (-not [string]::IsNullOrWhiteSpace($OfficialExcelPath)) {
    $OfficialExcelPath = Resolve-ProjectPath `
        -Root $ProjectRoot `
        -PathValue $OfficialExcelPath
}
else {
    $Candidates = @(
        Get-ChildItem `
            -LiteralPath $ProjectRoot `
            -File `
            -Filter "*.xlsx" |
        Where-Object { $_.Name -notlike "~`$*" } |
        Sort-Object Name
    )

    if ($Candidates.Count -eq 0) {
        throw (
            "No se encontró ningún archivo .xlsx en la raíz del repositorio. " +
            "Copie el Excel allí o use -OfficialExcelPath con su ruta absoluta."
        )
    }

    if ($Candidates.Count -gt 1) {
        Write-Host "Archivos Excel encontrados:" -ForegroundColor Yellow

        foreach ($Candidate in $Candidates) {
            Write-Host "  $($Candidate.FullName)" -ForegroundColor Yellow
        }

        Write-Host "Se utilizará el primero por orden alfabético." -ForegroundColor Yellow
    }

    $OfficialExcelPath = $Candidates[0].FullName
}

Assert-Path -Path $OfficialExcelPath -Description "el Excel oficial"

Write-Host "Excel seleccionado: $OfficialExcelPath" -ForegroundColor Green

Write-Step "Validando nuevamente la suite completa"

& python -m pytest
if ($LASTEXITCODE -ne 0) {
    throw "La suite completa terminó con errores."
}

Write-Step "Procesando Excel oficial"

& python -m sgoda.rlb.cli `
    --excel "$OfficialExcelPath" `
    --schema "config/rlb/schema-v1.json" `
    --output "artifacts/rlb/SPT-001B-P06" `
    --events "artifacts/pmo/SPT-001B-P06/repository-events.jsonl"

if ($LASTEXITCODE -ne 0) {
    throw "Falló el procesamiento del Excel oficial."
}

foreach ($Artifact in @(
    "palabras-canonicas.json",
    "perfil-rlb.json",
    "errores-importacion.json",
    "resumen-ejecucion.json"
)) {
    Assert-Path `
        -Path (Join-Path $ArtifactsDir $Artifact) `
        -Description $Artifact
}

Assert-Path `
    -Path (Join-Path $PmoDir "repository-events.jsonl") `
    -Description "repository-events.jsonl"

Write-Step "Generando evidencia del correctivo"

$Evidence = [ordered]@{
    increment_code = "SPT-001B-P06"
    correction_version = "1.2"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    correction = "relative_excel_path_resolved_against_project_root"
    project_root = $ProjectRoot
    official_excel = $OfficialExcelPath
    full_suite = "approved"
    pipeline_execution = "approved"
    generated_artifacts = @(
        "artifacts/rlb/SPT-001B-P06/palabras-canonicas.json",
        "artifacts/rlb/SPT-001B-P06/perfil-rlb.json",
        "artifacts/rlb/SPT-001B-P06/errores-importacion.json",
        "artifacts/rlb/SPT-001B-P06/resumen-ejecucion.json",
        "artifacts/pmo/SPT-001B-P06/repository-events.jsonl"
    )
}
Write-JsonUtf8 -Path $EvidencePath -Data $Evidence

Write-Step "Ejecutando quality gate SGD-114"

& python -m sgoda.governance.evidence_policy `
    --root "$ProjectRoot" `
    --policy "config/governance/sgd-114-policy.json" `
    --increment "SPT-001B-P06" `
    --status "technically_completed" `
    --output "$GatePath"

if ($LASTEXITCODE -ne 0) {
    throw "El quality gate SGD-114 no fue aprobado."
}

$Gate = Get-Content -LiteralPath $GatePath -Raw |
    ConvertFrom-Json

if (-not $Gate.passed) {
    throw "El quality gate no contiene passed=true."
}

$Profile = Get-Content `
    -LiteralPath (Join-Path $ArtifactsDir "perfil-rlb.json") `
    -Raw |
    ConvertFrom-Json

$Dashboard = [ordered]@{
    increment_code = "SPT-001B-P06"
    correction_version = "1.2"
    status = "technically_completed"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    official_repository_processed = $true
    official_excel = $OfficialExcelPath
    total_hojas = $Profile.total_hojas
    total_registros = $Profile.total_registros
    registros_validos = $Profile.total_registros_validos
    registros_con_errores = $Profile.total_registros_con_errores
    full_suite = "approved"
    quality_gate = "approved"
}
Write-JsonUtf8 -Path $DashboardPath -Data $Dashboard

Write-Step "Resultado final"

Write-Host "SPT-001B-P06 v1.2 completado correctamente." -ForegroundColor Green
Write-Host "Excel oficial: PROCESADO." -ForegroundColor Green
Write-Host "Suite completa: APROBADA." -ForegroundColor Green
Write-Host "Artefactos RLB: GENERADOS." -ForegroundColor Green
Write-Host "Quality gate SGD-114: APROBADO." -ForegroundColor Green
Write-Host "Perfil: $ArtifactsDir\perfil-rlb.json" -ForegroundColor Cyan
Write-Host "Evidencia: $EvidencePath" -ForegroundColor Cyan
