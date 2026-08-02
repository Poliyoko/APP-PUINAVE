<#
.SYNOPSIS
    Ejecuta SPT-011A v1.0.1 — Institutional Evidence Closure.

.DESCRIPTION
    Correctivo institucional único para resolver SGD114C-R007 en SPT-011.

    El script:
      - valida la línea base de SPT-011;
      - crea respaldo institucional;
      - ejecuta sintaxis y pruebas específicas;
      - ejecuta la suite completa;
      - ejecuta nuevamente la demostración operativa;
      - genera evidencia legítima antes de SGD-114C;
      - valida que el directorio de evidencias no esté vacío;
      - regenera SGD-116;
      - reevalúa SPT-011 mediante SGD-114C;
      - regenera SGD-115;
      - crea evidencia definitiva y release;
      - deja preparado el incremento para SPB-007.

.PARAMETER ProjectRoot
    Raíz del repositorio.

.PARAMETER SkipFullSuite
    Omite la suite completa. No recomendado.

.PARAMETER SkipInstitutionalClosure
    Omite SGD-116, SGD-114C, SGD-115 y release.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipFullSuite,
    [switch]$SkipInstitutionalClosure
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([Parameter(Mandatory = $true)][string]$Message)

    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Require-File {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "No se encontró el archivo requerido: $Path"
    }
}

function Write-Utf8 {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $Parent = Split-Path -Parent $Path

    if ($Parent) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        (New-Object System.Text.UTF8Encoding($false))
    )

    $Info = Get-Item -LiteralPath $Path

    if ($Info.Length -le 0) {
        throw "El archivo quedó vacío: $Path"
    }

    Write-Host "Creado/actualizado: $Path ($($Info.Length) bytes)" `
        -ForegroundColor Green
}

function Write-Json {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][object]$Value
    )

    $Parent = Split-Path -Parent $Path

    if ($Parent) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    $Json = $Value | ConvertTo-Json -Depth 100

    [System.IO.File]::WriteAllText(
        $Path,
        $Json + [Environment]::NewLine,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$Description,
        [Parameter(Mandatory = $true)][scriptblock]$Action
    )

    Write-Step $Description
    $global:LASTEXITCODE = 0
    & $Action

    if ($LASTEXITCODE -ne 0) {
        throw "$Description terminó con errores. Código: $LASTEXITCODE"
    }
}

function Backup-File {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$BackupDirectory,
        [Parameter(Mandatory = $true)][string]$Root
    )

    if (Test-Path -LiteralPath $Source -PathType Leaf) {
        $RelativeName = $Source.Replace($Root, "")
        $RelativeName = $RelativeName.TrimStart(
            [char[]]@([char]92, [char]47)
        )
        $RelativeName = $RelativeName.Replace(
            [string][char]92,
            "__"
        )
        $RelativeName = $RelativeName.Replace("/", "__")

        Copy-Item `
            -LiteralPath $Source `
            -Destination (Join-Path $BackupDirectory $RelativeName) `
            -Force
    }
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-011"
$EvidenceDir = Join-Path $PmoDir "evidence"
$ReleaseDir = Join-Path $ProjectRoot "releases\SPT-011A-v1.0.1"

$BackupDir = Join-Path `
    $PmoDir `
    ("backups\pre-SPT011A-" + (Get-Date -Format "yyyyMMdd-HHmmss"))

$ComponentPath = Join-Path `
    $ProjectRoot `
    "config\operational_platform\SPT-011-component.json"

$PolicyPath = Join-Path `
    $ProjectRoot `
    "config\operational_platform\SPT-011-operational-policy.json"

$RuntimeConfigPath = Join-Path `
    $ProjectRoot `
    "config\operational_platform\SPT-011-runtime.json"

$TestPath = Join-Path `
    $ProjectRoot `
    "tests\operational_platform\test_SPT_011_operational_sgoda_platform.py"

$CliPath = Join-Path `
    $ProjectRoot `
    "src\sgoda\operational_platform\cli.py"

$DemoRlbPath = Join-Path `
    $ProjectRoot `
    "artifacts\operational_platform\SPT-011\demo-rlb.json"

$DemoMediaPath = Join-Path `
    $ProjectRoot `
    "artifacts\operational_platform\SPT-011\demo-media.json"

$DemoResultPath = Join-Path `
    $ProjectRoot `
    "artifacts\operational_platform\SPT-011\demo-operational-result-v1.0.1.json"

$PreGateJson = Join-Path `
    $EvidenceDir `
    "SPT-011A-pre-gate-evidence.json"

$PreGateMd = Join-Path `
    $EvidenceDir `
    "SPT-011A-pre-gate-evidence.md"

$TestEvidenceJson = Join-Path `
    $EvidenceDir `
    "SPT-011A-test-evidence.json"

$DemoEvidenceJson = Join-Path `
    $EvidenceDir `
    "SPT-011A-demo-evidence.json"

$GateJson = Join-Path `
    $PmoDir `
    "SPT-011A-policy-result.json"

$GateMd = Join-Path `
    $PmoDir `
    "SPT-011A-policy-result.md"

$FinalEvidenceJson = Join-Path `
    $PmoDir `
    "SPT-011A-implementation-evidence.json"

$FinalEvidenceMd = Join-Path `
    $PmoDir `
    "SPT-011A-implementation-evidence.md"

$CorrectiveComponentPath = Join-Path `
    $ProjectRoot `
    "config\operational_platform\SPT-011A-component.json"

$CorrectiveDocPath = Join-Path `
    $ProjectRoot `
    "docs\07_Fase_Tecnologica_III\SPT-011\SPT-011A-Institutional-Evidence-Closure.md"

Write-Step "Validando línea base SPT-011"

foreach ($Required in @(
    (Join-Path $ProjectRoot "pytest.ini"),
    $ComponentPath,
    $PolicyPath,
    $RuntimeConfigPath,
    $TestPath,
    $CliPath,
    $DemoRlbPath,
    $DemoMediaPath,
    (Join-Path $ProjectRoot "src\sgoda\governance\policy_cli.py"),
    (Join-Path $ProjectRoot "config\governance\SGD-114C-policy.json"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py"),
    (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1")
)) {
    Require-File -Path $Required
}

Write-Step "Creando respaldo institucional"

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

foreach ($Affected in @(
    $PreGateJson,
    $PreGateMd,
    $TestEvidenceJson,
    $DemoEvidenceJson,
    $GateJson,
    $GateMd,
    $FinalEvidenceJson,
    $FinalEvidenceMd,
    $CorrectiveComponentPath,
    $CorrectiveDocPath
)) {
    Backup-File `
        -Source $Affected `
        -BackupDirectory $BackupDir `
        -Root $ProjectRoot
}

Write-Step "Registrando correctivo SPT-011A"

$CorrectiveComponent = @'
{
  "increment_code": "SPT-011A",
  "name": "Institutional Evidence Closure",
  "component_type": "institutional_evidence_closure",
  "version": "1.0.1",
  "status": "implemented",
  "phase": "Fase Tecnológica III",
  "dependencies": [
    "SPT-011",
    "SGD-114C",
    "SGD-115",
    "SGD-116"
  ],
  "source": [
    "Repair-SPT011A-v1.0.1-Institutional-Evidence-Closure.ps1"
  ],
  "tests": [
    "tests/operational_platform/test_SPT_011_operational_sgoda_platform.py"
  ],
  "documentation": [
    "docs/07_Fase_Tecnologica_III/SPT-011/SPT-011A-Institutional-Evidence-Closure.md"
  ]
}
'@

$CorrectiveDoc = @'
# SPT-011A v1.0.1 — Institutional Evidence Closure

SPT-011A corrige el orden institucional de SPT-011.

La evidencia legítima se genera antes de ejecutar SGD-114C, resolviendo la
regla bloqueante SGD114C-R007.

El cierre ejecuta pruebas, demostración, evidencia previa, SGD-116,
SGD-114C, SGD-115, evidencia definitiva y release.

No se crean evidencias ficticias. Cada artefacto registra resultados reales
de pruebas, demostración, políticas y trazabilidad.
'@

Write-Utf8 `
    -Path $CorrectiveComponentPath `
    -Content $CorrectiveComponent

Write-Utf8 `
    -Path $CorrectiveDocPath `
    -Content $CorrectiveDoc

Invoke-Checked "Validando sintaxis Python de SPT-011" {
    python -m py_compile `
        "src/sgoda/operational_platform/models.py" `
        "src/sgoda/operational_platform/settings.py" `
        "src/sgoda/operational_platform/database.py" `
        "src/sgoda/operational_platform/rlb_adapter.py" `
        "src/sgoda/operational_platform/media_adapter.py" `
        "src/sgoda/operational_platform/n8n_contracts.py" `
        "src/sgoda/operational_platform/flutter_contracts.py" `
        "src/sgoda/operational_platform/service.py" `
        "src/sgoda/operational_platform/api.py" `
        "src/sgoda/operational_platform/cli.py" `
        "src/sgoda/operational_platform/__init__.py" `
        "tests/operational_platform/test_SPT_011_operational_sgoda_platform.py"
}

$SpecificTestStarted = [DateTime]::UtcNow

Invoke-Checked "Ejecutando 14 pruebas específicas SPT-011" {
    python -m pytest `
        "tests/operational_platform/test_SPT_011_operational_sgoda_platform.py" `
        -q
}

$SpecificTestFinished = [DateTime]::UtcNow

$FullSuiteStarted = $null
$FullSuiteFinished = $null

if (-not $SkipFullSuite) {
    $FullSuiteStarted = [DateTime]::UtcNow

    Invoke-Checked "Ejecutando suite completa del repositorio" {
        python -m pytest
    }

    $FullSuiteFinished = [DateTime]::UtcNow
}

Write-Step "Ejecutando demostración operativa corregida"

Invoke-Checked "Consultando ficha operativa AMDA" {
    python -m sgoda.operational_platform.cli `
        --settings "$RuntimeConfigPath" `
        --rlb "$DemoRlbPath" `
        --media "$DemoMediaPath" `
        --operation "get_lexical_card" `
        --entry "LEX-001" `
        --payload "{}" `
        --output "$DemoResultPath"
}

$Demo = Get-Content `
    -LiteralPath $DemoResultPath `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if ($Demo.status -ne "ok") {
    throw "La demostración operativa no fue aprobada."
}

if ($Demo.data.entryId -ne "LEX-001") {
    throw "La demostración no devolvió LEX-001."
}

if ($Demo.data.languages.pu -ne "AMDA") {
    throw "La demostración no recuperó AMDA."
}

if (-not [bool]$Demo.data.noInvention) {
    throw "La demostración no respetó noInvention=true."
}

if (@($Demo.data.media).Count -lt 2) {
    throw "La demostración no recuperó multimedia suficiente."
}

Write-Step "Generando evidencia legítima previa al gate"

New-Item -ItemType Directory -Path $EvidenceDir -Force | Out-Null

Write-Json `
    -Path $TestEvidenceJson `
    -Value ([ordered]@{
        increment_code = "SPT-011A"
        parent_increment = "SPT-011"
        evidence_type = "test_execution"
        generated_at_utc = [DateTime]::UtcNow.ToString("o")
        syntax_validation = "passed"
        specific_tests = [ordered]@{
            file = (
                "tests/operational_platform/" +
                "test_SPT_011_operational_sgoda_platform.py"
            )
            expected_count = 14
            status = "passed"
            started_at_utc = $SpecificTestStarted.ToString("o")
            finished_at_utc = $SpecificTestFinished.ToString("o")
        }
        full_suite = [ordered]@{
            executed = (-not $SkipFullSuite)
            status = (
                if ($SkipFullSuite) {
                    "skipped_by_operator"
                }
                else {
                    "passed"
                }
            )
            started_at_utc = (
                if ($FullSuiteStarted) {
                    $FullSuiteStarted.ToString("o")
                }
                else {
                    $null
                }
            )
            finished_at_utc = (
                if ($FullSuiteFinished) {
                    $FullSuiteFinished.ToString("o")
                }
                else {
                    $null
                }
            )
        }
    })

Write-Json `
    -Path $DemoEvidenceJson `
    -Value ([ordered]@{
        increment_code = "SPT-011A"
        parent_increment = "SPT-011"
        evidence_type = "operational_demo"
        generated_at_utc = [DateTime]::UtcNow.ToString("o")
        status = $Demo.status
        operation = $Demo.operation
        entry_id = $Demo.data.entryId
        puinave = $Demo.data.languages.pu
        spanish = $Demo.data.languages.es
        english_us = $Demo.data.languages.'en-US'
        italian = $Demo.data.languages.it
        media_count = @($Demo.data.media).Count
        no_invention = [bool]$Demo.data.noInvention
        result_path = (
            "artifacts/operational_platform/SPT-011/" +
            "demo-operational-result-v1.0.1.json"
        )
    })

Write-Json `
    -Path $PreGateJson `
    -Value ([ordered]@{
        increment_code = "SPT-011A"
        parent_increment = "SPT-011"
        version = "1.0.1"
        evidence_type = "institutional_pre_gate"
        status = "ready_for_policy_evaluation"
        generated_at_utc = [DateTime]::UtcNow.ToString("o")
        blocking_rule_addressed = "SGD114C-R007"
        evidence_directory = "artifacts/pmo/SPT-011/evidence"
        evidence_files = @(
            "SPT-011A-test-evidence.json",
            "SPT-011A-demo-evidence.json",
            "SPT-011A-pre-gate-evidence.json",
            "SPT-011A-pre-gate-evidence.md"
        )
        specific_tests = 14
        full_suite_executed = (-not $SkipFullSuite)
        demo_approved = ($Demo.status -eq "ok")
        no_invention = [bool]$Demo.data.noInvention
        backup = $BackupDir
    })

$PreGateMarkdown = @"
# SPT-011A — Evidencia previa al gate

- Incremento padre: SPT-011
- Correctivo: SPT-011A v1.0.1
- Regla atendida: SGD114C-R007
- Pruebas específicas: 14 aprobadas
- Suite completa ejecutada: $(-not $SkipFullSuite)
- Demostración operativa: APROBADA
- Entrada demostrada: LEX-001 / AMDA
- Multimedia recuperada: $(@($Demo.data.media).Count)
- No invención: $([bool]$Demo.data.noInvention)
- Estado: LISTO PARA EVALUACIÓN
"@

Write-Utf8 `
    -Path $PreGateMd `
    -Content $PreGateMarkdown

$EvidenceFiles = @(
    Get-ChildItem `
        -LiteralPath $EvidenceDir `
        -File `
        -ErrorAction Stop
)

if ($EvidenceFiles.Count -lt 4) {
    throw (
        "La evidencia previa es insuficiente. " +
        "Archivos encontrados: $($EvidenceFiles.Count)"
    )
}

foreach ($EvidenceFile in $EvidenceFiles) {
    if ($EvidenceFile.Length -le 0) {
        throw "Se detectó evidencia vacía: $($EvidenceFile.FullName)"
    }
}

Write-Host (
    "Evidencia previa generada: " +
    "$($EvidenceFiles.Count) archivos válidos."
) -ForegroundColor Green

if (-not $SkipInstitutionalClosure) {
    Write-Step "Regenerando Roadmap Maestro SGD-116"

    Invoke-Checked "Actualizando SGD-116" {
        python -m sgoda.roadmap.cli `
            --root "$ProjectRoot" `
            --output "artifacts/roadmap/SGD-116"
    }

    $RoadmapValidationPath = Join-Path `
        $ProjectRoot `
        "artifacts\roadmap\SGD-116\validation.json"

    Require-File -Path $RoadmapValidationPath

    $RoadmapValidation = Get-Content `
        -LiteralPath $RoadmapValidationPath `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

    if (-not [bool]$RoadmapValidation.passed) {
        throw "SGD-116 no aprobó SPT-011A."
    }

    Write-Step "Evaluando SPT-011A mediante SGD-114C"

    & python -m sgoda.governance.policy_cli `
        --root "$ProjectRoot" `
        --policy "config/governance/SGD-114C-policy.json" `
        --increment "SPT-011A" `
        --output-json "$GateJson" `
        --output-md "$GateMd"

    $GateExitCode = $LASTEXITCODE

    Require-File -Path $GateJson
    Require-File -Path $GateMd

    $Gate = Get-Content `
        -LiteralPath $GateJson `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

    if ($GateExitCode -ne 0 -or -not [bool]$Gate.approved) {
        @($Gate.results) |
            Where-Object { $_.blocking } |
            Format-Table rule, name, message, remediation -AutoSize

        throw "SGD-114C no aprobó SPT-011A."
    }

    Write-Step "Regenerando Documentación Maestra SGD-115"

    Invoke-Checked "Actualizando SGD-115" {
        python -m sgoda.documentation.master_docs `
            --root "$ProjectRoot" `
            --output "artifacts/documentation/SGD-115"
    }

    Write-Step "Generando evidencia definitiva"

    Write-Json `
        -Path $FinalEvidenceJson `
        -Value ([ordered]@{
            increment_code = "SPT-011A"
            parent_increment = "SPT-011"
            version = "1.0.1"
            name = "Institutional Evidence Closure"
            phase = "Fase Tecnológica III"
            status = "implemented_and_approved"
            generated_at_utc = [DateTime]::UtcNow.ToString("o")
            corrected_rule = "SGD114C-R007"
            correction = (
                "Institutional evidence is generated before " +
                "policy evaluation."
            )
            evidence_directory = "artifacts/pmo/SPT-011/evidence"
            evidence_file_count = $EvidenceFiles.Count
            specific_tests = 14
            specific_tests_status = "passed"
            full_suite_executed = (-not $SkipFullSuite)
            full_suite_status = (
                if ($SkipFullSuite) {
                    "skipped_by_operator"
                }
                else {
                    "passed"
                }
            )
            demo_status = $Demo.status
            demo_entry_id = $Demo.data.entryId
            demo_puinave = $Demo.data.languages.pu
            demo_media_count = @($Demo.data.media).Count
            no_invention = [bool]$Demo.data.noInvention
            roadmap_approved = [bool]$RoadmapValidation.passed
            policy_approved = [bool]$Gate.approved
            policy_exit_code = $Gate.exit_code
            documentation_updated = $true
            backup = $BackupDir
        })

    $FinalMarkdown = @"
# SPT-011A v1.0.1 — Cierre institucional

## Resultado

- Regla corregida: SGD114C-R007
- Evidencia previa al gate: GENERADA
- Archivos de evidencia: $($EvidenceFiles.Count)
- Pruebas específicas: 14 APROBADAS
- Suite completa: $(if ($SkipFullSuite) { "OMITIDA" } else { "APROBADA" })
- Demostración AMDA: APROBADA
- SGD-116: APROBADO
- SGD-114C: APROBADO
- SGD-115: ACTUALIZADO
- No invención Puinave: APROBADA
- Estado: CERRADO TÉCNICAMENTE
"@

    Write-Utf8 `
        -Path $FinalEvidenceMd `
        -Content $FinalMarkdown

    Write-Step "Creando release técnico"

    New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

    foreach ($ReleaseFile in @(
        $CorrectiveComponentPath,
        $CorrectiveDocPath,
        $PreGateJson,
        $PreGateMd,
        $TestEvidenceJson,
        $DemoEvidenceJson,
        $GateJson,
        $GateMd,
        $FinalEvidenceJson,
        $FinalEvidenceMd,
        $DemoResultPath
    )) {
        Require-File -Path $ReleaseFile

        Copy-Item `
            -LiteralPath $ReleaseFile `
            -Destination (
                Join-Path $ReleaseDir (Split-Path $ReleaseFile -Leaf)
            ) `
            -Force
    }
}

Write-Step "Resultado final"

Write-Host "SPT-011A v1.0.1 implementado." -ForegroundColor Green
Write-Host "Institutional Evidence Closure: OPERATIVO." -ForegroundColor Green
Write-Host "SGD114C-R007: CORREGIDO." -ForegroundColor Green
Write-Host "Evidencia previa al gate: GENERADA." -ForegroundColor Green
Write-Host "Pruebas específicas: 14 APROBADAS." -ForegroundColor Green

if (-not $SkipFullSuite) {
    Write-Host "Suite completa: APROBADA." -ForegroundColor Green
}

Write-Host "Demostración operativa AMDA: APROBADA." -ForegroundColor Green
Write-Host "No invención Puinave: APROBADA." -ForegroundColor Green

if (-not $SkipInstitutionalClosure) {
    Write-Host "SGD-116: APROBADO." -ForegroundColor Green
    Write-Host "SGD-114C: APROBADO." -ForegroundColor Green
    Write-Host "SGD-115: ACTUALIZADO." -ForegroundColor Green
    Write-Host "Release: releases\SPT-011A-v1.0.1" -ForegroundColor Cyan
    Write-Host "Evidencia: $FinalEvidenceJson" -ForegroundColor Cyan
}

Write-Host "Respaldo: $BackupDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "Revise git status y publique mediante SPB-007." `
    -ForegroundColor Yellow
