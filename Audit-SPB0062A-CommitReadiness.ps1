param(
    [Parameter(Mandatory=$false)]
    [string]$RepositoryRoot = (Get-Location).Path,

    [Parameter(Mandatory=$false)]
    [switch]$RunTests
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$OutputEncoding = [System.Text.UTF8Encoding]::new()

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Invoke-Capture {
    param(
        [Parameter(Mandatory=$true)][scriptblock]$Command,
        [Parameter(Mandatory=$true)][string]$Label
    )
    try {
        $output = & $Command 2>&1 | Out-String
        return [ordered]@{
            label = $Label
            ok = ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE)
            exit_code = $(if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE })
            output = $output.TrimEnd()
        }
    }
    catch {
        return [ordered]@{
            label = $Label
            ok = $false
            exit_code = 1
            output = $_.Exception.Message
        }
    }
}

$root = (Resolve-Path $RepositoryRoot).Path
Set-Location $root

if (-not (Test-Path ".git")) {
    throw "La ruta no corresponde a un repositorio Git: $root"
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$auditDir = Join-Path $root "artifacts/pmo/SPB-006-SEMS/commit-readiness/$timestamp"
New-Item -ItemType Directory -Path $auditDir -Force | Out-Null

Write-Host ""
Write-Host "============================================================"
Write-Host " SPB-006.2-A - Auditoria Integral de Preparacion para Commit v1.2"
Write-Host "============================================================"
Write-Host ""
Write-Host "Repositorio: $root"
Write-Host "Salida:      $auditDir"
Write-Host ""

$targetPaths = @(
    "Apply-SPB0061-SEMS-Core.ps1",
    "Apply-SPB0062A-Retention-Governance.ps1",
    "src/sgoda/pmo/evidence",
    "tests/pmo/evidence",
    "config/evidence-retention-policies.json",
    "docs/01_Gobierno/SGD-110-Politica-Gestion-Evidencias.md",
    "docs/01_Gobierno/SGD-111-Ciclo-de-Vida-de-Evidencias.md",
    "docs/01_Gobierno/SGD-113-Politica-Retencion-Evidencias.md",
    "docs/03_ADR/ADR-010-Evidence-Management-System.md",
    "docs/03_ADR/ADR-011-Retention-Policy-Engine.md",
    "docs/standards/Evidence-Management-Standard.md",
    "artifacts/pmo/SPB-006-SEMS"
)

$requiredPaths = @(
    "Apply-SPB0062A-Retention-Governance.ps1",
    "src/sgoda/pmo/evidence/models.py",
    "src/sgoda/pmo/evidence/retention_policy.py",
    "src/sgoda/pmo/evidence/retention.py",
    "src/sgoda/pmo/evidence/retention_audit.py",
    "src/sgoda/pmo/evidence/manager.py",
    "src/sgoda/pmo/evidence/cli.py",
    "config/evidence-retention-policies.json",
    "tests/pmo/evidence/test_retention_manager.py",
    "docs/01_Gobierno/SGD-113-Politica-Retencion-Evidencias.md",
    "docs/03_ADR/ADR-011-Retention-Policy-Engine.md",
    "artifacts/pmo/SPB-006-SEMS/SPB-006.2-A-implementation-manifest.json"
)

$porcelain = git status --porcelain=v1 --untracked-files=all
if ($LASTEXITCODE -ne 0) { throw "No fue posible consultar git status." }

$entries = @()
foreach ($line in $porcelain) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -lt 4) { continue }

    $xy = $line.Substring(0,2)
    $rawPath = $line.Substring(3).Trim()
    if ($rawPath -match " -> ") {
        $rawPath = ($rawPath -split " -> ")[-1]
    }
    $normalized = $rawPath.Replace("\", "/")

    $belongs = $false
    foreach ($target in $targetPaths) {
        $t = $target.Replace("\", "/").TrimEnd("/")
        if ($normalized -eq $t -or $normalized.StartsWith("$t/")) {
            $belongs = $true
            break
        }
    }

    $entries += [pscustomobject]@{
        xy = $xy
        index_status = $xy.Substring(0,1)
        worktree_status = $xy.Substring(1,1)
        path = $normalized
        scope = $(if ($belongs) { "SPB-006" } else { "OTHER" })
    }
}

$scopeEntries = @($entries | Where-Object scope -eq "SPB-006")
$otherEntries = @($entries | Where-Object scope -eq "OTHER")
$stagedScope = @($scopeEntries | Where-Object { $_.index_status -ne " " -and $_.index_status -ne "?" })
$unstagedScope = @($scopeEntries | Where-Object { $_.worktree_status -ne " " -or $_.xy -eq "??" })

$missing = @()
foreach ($path in $requiredPaths) {
    if (-not (Test-Path $path)) { $missing += $path }
}

$policyDefect = $false
$policyMessage = ""
$policyPath = "config/evidence-retention-policies.json"
if (Test-Path $policyPath) {
    try {
        $policyDoc = Get-Content $policyPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $bad = @($policyDoc.policies | Where-Object { $_.policy_id -eq "RET-LEGAL-HOLD" })
        if ($bad.Count -gt 0) {
            $policyDefect = $true
            $policyMessage = "RET-LEGAL-HOLD permanece en el conjunto automatico."
        } else {
            $policyMessage = "RET-LEGAL-HOLD no esta en el conjunto automatico."
        }
    }
    catch {
        $policyDefect = $true
        $policyMessage = "No se pudo analizar el archivo de politicas: $($_.Exception.Message)"
    }
} else {
    $policyDefect = $true
    $policyMessage = "No existe el archivo de politicas."
}

$installerDefect = $false
$installerMessage = ""
$installerPath = "Apply-SPB0062A-Retention-Governance.ps1"
if (Test-Path $installerPath) {
    $installerText = Get-Content $installerPath -Raw -Encoding UTF8
    if ($installerText -match '"policy_id"\s*:\s*"RET-LEGAL-HOLD"' -or
        $installerText -match "'policy_id'\s*:\s*'RET-LEGAL-HOLD'") {
        $installerDefect = $true
        $installerMessage = "El instalador todavia contiene RET-LEGAL-HOLD y puede reintroducir el defecto."
    } else {
        $installerMessage = "El instalador no contiene una definicion automatica de RET-LEGAL-HOLD."
    }
} else {
    $installerDefect = $true
    $installerMessage = "No existe el instalador SPB-006.2-A."
}

$backupLike = @(
    $scopeEntries | Where-Object {
        $_.path -notmatch '(^|/)artifacts/pmo/SPB-006-SEMS/(installer-fix-backups|auditor-patch-backups)(/|$)' -and
        (
            $_.path -match '(^|/)(patch-backups|backups|obsolete-installers)(/|$)' -or
            $_.path -match '\.before-' -or
            $_.path -match '\.bak$'
        )
    }
)

$checks = @()
$env:PYTHONPATH = "src"

if ($RunTests) {
    $checks += Invoke-Capture -Label "pytest evidence" -Command {
        python -m pytest tests/pmo/evidence -q
    }
    $checks += Invoke-Capture -Label "retention dry-run" -Command {
        python -m sgoda.pmo.evidence --root . retention --dry-run
    }
    $checks += Invoke-Capture -Label "retention audit" -Command {
        python -m sgoda.pmo.evidence --root . retention-audit
    }
}

$blockers = @()
if ($missing.Count -gt 0) {
    $blockers += "Faltan archivos requeridos."
}
if ($policyDefect) {
    $blockers += $policyMessage
}
if ($installerDefect) {
    $blockers += $installerMessage
}
if ($backupLike.Count -gt 0) {
    $blockers += "Hay respaldos o instaladores obsoletos dentro del alcance propuesto."
}
foreach ($check in $checks) {
    if (-not $check.ok) {
        $blockers += "Fallo la validacion: $($check.label)"
    }
}

$ready = ($blockers.Count -eq 0)

$stagePaths = @(
    $scopeEntries |
    Where-Object {
        $_.path -notmatch '(^|/)(commit-readiness|patch-backups|backups|obsolete-installers)(/|$)' -and
        $_.path -notmatch '\.before-' -and
        $_.path -notmatch '\.bak$'
    } |
    Select-Object -ExpandProperty path -Unique |
    Sort-Object
)

$stageScript = @()
$stageScript += '$ErrorActionPreference = "Stop"'
$stageScript += '# Propuesta generada. Revise antes de ejecutar.'
$stageScript += 'git reset'
foreach ($p in $stagePaths) {
    $escaped = $p.Replace("'", "''")
    $stageScript += "git add -- '$escaped'"
}
$stageScript += 'git diff --cached --stat'
$stageScript += 'git diff --cached --check'
$stageScript += 'git status --short'
$stageScript += '# No ejecuta commit automaticamente.'

Write-Utf8NoBom -Path (Join-Path $auditDir "Proposed-Stage-SPB0062A.ps1") `
    -Content ($stageScript -join [Environment]::NewLine)

$entries | ConvertTo-Csv -NoTypeInformation |
    Set-Content -Path (Join-Path $auditDir "git-change-classification.csv") -Encoding UTF8

$porcelain | Set-Content -Path (Join-Path $auditDir "git-status-porcelain.txt") -Encoding UTF8

$report = [ordered]@{
    schema = "sgoda.commit-readiness-audit/v1"
    auditor_version = "1.2"
    deliverable = "SPB-006.2-A"
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repository_root = $root
    ready_for_selective_staging = $ready
    totals = [ordered]@{
        all_changes = $entries.Count
        spb006_changes = $scopeEntries.Count
        other_changes = $otherEntries.Count
        staged_spb006 = $stagedScope.Count
        unstaged_or_untracked_spb006 = $unstagedScope.Count
        required_missing = $missing.Count
        backup_like_in_scope = $backupLike.Count
    }
    policy_validation = [ordered]@{
        ok = (-not $policyDefect)
        message = $policyMessage
    }
    installer_validation = [ordered]@{
        ok = (-not $installerDefect)
        message = $installerMessage
    }
    required_missing = $missing
    blockers = $blockers
    proposed_stage_paths = $stagePaths
    checks = $checks
}

$reportJson = $report | ConvertTo-Json -Depth 20
Write-Utf8NoBom -Path (Join-Path $auditDir "commit-readiness-report.json") -Content $reportJson

$summary = @"
# SPB-006.2-A - Auditoria Integral de Preparacion para Commit

- Fecha UTC: $($report.generated_at)
- Repositorio: $root
- Preparado para staging selectivo: $ready
- Cambios totales: $($entries.Count)
- Cambios del alcance SPB-006: $($scopeEntries.Count)
- Cambios ajenos al alcance: $($otherEntries.Count)
- Archivos requeridos faltantes: $($missing.Count)
- Respaldos/obsoletos dentro del alcance: $($backupLike.Count)

## Politica

$policyMessage

## Instalador

$installerMessage

## Bloqueadores

$(
    if ($blockers.Count -eq 0) {
        "- Ninguno."
    } else {
        ($blockers | ForEach-Object { "- $_" }) -join [Environment]::NewLine
    }
)

## Resultado

$(
    if ($ready) {
        "La auditoria permite revisar y ejecutar el script Proposed-Stage-SPB0062A.ps1."
    } else {
        "No ejecute staging ni commit hasta resolver los bloqueadores."
    }
)
"@

Write-Utf8NoBom -Path (Join-Path $auditDir "AUDIT-SUMMARY.md") -Content $summary

Write-Host ""
Write-Host "Cambios totales:                  $($entries.Count)"
Write-Host "Cambios del alcance SPB-006:      $($scopeEntries.Count)"
Write-Host "Cambios de otros entregables:     $($otherEntries.Count)"
Write-Host "Archivos requeridos faltantes:    $($missing.Count)"
Write-Host "Respaldos/obsoletos en alcance:   $($backupLike.Count)"
Write-Host ""
Write-Host "Politica:   $policyMessage"
Write-Host "Instalador: $installerMessage"
Write-Host ""

if ($ready) {
    Write-Host "RESULTADO: PREPARADO PARA REVISION DE STAGING SELECTIVO" -ForegroundColor Green
    Write-Host "Revise:"
    Write-Host "  $auditDir\AUDIT-SUMMARY.md"
    Write-Host "  $auditDir\commit-readiness-report.json"
    Write-Host "  $auditDir\Proposed-Stage-SPB0062A.ps1"
} else {
    Write-Host "RESULTADO: BLOQUEADO" -ForegroundColor Yellow
    foreach ($b in $blockers) {
        Write-Host " - $b"
    }
}

Write-Host ""
Write-Host "La auditoria no ejecuto git add, commit, tag ni eliminaciones."
