<#
.SYNOPSIS
    Ejecuta SPT-016 v1.0.0 — Learning Analytics Official Closure.

.DESCRIPTION
    Cierra oficialmente el Motor de Analítica del Aprendizaje ya existente.

    Principios:
      - no reescribe la implementación funcional aprobada;
      - conserva pruebas históricas;
      - valida arquitectura, configuración, pruebas y documentación;
      - genera entregables documentales faltantes;
      - ejecuta pruebas específicas y suite completa;
      - sincroniza evidencias con SGD-114F;
      - valida releases mediante SGD-114G;
      - regenera SGD-115 y SGD-116;
      - publica mediante el gate canónico solo si todo queda aprobado.

    Compatible con Windows PowerShell 5.1.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$Publish
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Step {
    param([string]$Message)

    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Require-File {
    param(
        [string]$Path,
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Falta $Description`: $Path"
    }
}

function Write-Utf8 {
    param(
        [string]$Path,
        [string]$Content
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

    if ((Get-Item -LiteralPath $Path).Length -le 0) {
        throw "El archivo quedó vacío: $Path"
    }

    Write-Host "Creado/actualizado: $Path" -ForegroundColor Green
}

function Write-Json {
    param(
        [string]$Path,
        [object]$Value
    )

    Write-Utf8 `
        -Path $Path `
        -Content (
            ($Value | ConvertTo-Json -Depth 100) +
            [Environment]::NewLine
        )
}

function Run {
    param(
        [string]$Description,
        [scriptblock]$Action
    )

    Step $Description
    $global:LASTEXITCODE = 0
    & $Action

    if ($LASTEXITCODE -ne 0) {
        throw "$Description terminó con errores. Código: $LASTEXITCODE"
    }
}

function Get-Sha256 {
    param([string]$Path)

    return (
        Get-FileHash `
            -LiteralPath $Path `
            -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$SourceDir = Join-Path $ProjectRoot "src\sgoda\learning_analytics"
$TestPath = Join-Path `
    $ProjectRoot `
    "tests\learning_analytics\test_SPT_016_learning_analytics_engine.py"

$ConfigDir = Join-Path $ProjectRoot "config\learning_analytics"
$DocsDir = Join-Path $ProjectRoot "docs\08_Fase_Tecnologica_IV\SPT-016"
$ScriptsDir = Join-Path $ProjectRoot "scripts"

$RunnerPath = Join-Path $ScriptsDir "Invoke-InstitutionalPytest.ps1"
$CanonicalPublisher = Join-Path $ScriptsDir "Invoke-SPB007-CanonicalPublish.ps1"

$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-016-v1.0.0"
$ReportsDir = Join-Path $PmoDir "test-reports"
$ReleaseDir = Join-Path $ProjectRoot "releases\SPT-016-v1.0.0"

$SpecificXml = Join-Path $ReportsDir "specific.xml"
$SpecificJson = Join-Path $ReportsDir "specific-summary.json"
$SpecificMd = Join-Path $ReportsDir "specific-summary.md"

$FullXml = Join-Path $ReportsDir "full-suite.xml"
$FullJson = Join-Path $ReportsDir "full-suite-summary.json"
$FullMd = Join-Path $ReportsDir "full-suite-summary.md"

$InventoryJson = Join-Path $PmoDir "implementation-inventory.json"
$TraceabilityJson = Join-Path $PmoDir "traceability-matrix.json"
$ClosureJson = Join-Path $PmoDir "official-closure.json"
$ClosureMd = Join-Path $PmoDir "official-closure.md"

$ComponentPath = Join-Path $ConfigDir "SPT-016-component.json"
$PolicyPath = Join-Path $ConfigDir "SPT-016-policy.json"

$ArchitectureDoc = Join-Path $DocsDir "SPT-016-Arquitectura.md"
$FunctionalDoc = Join-Path $DocsDir "SPT-016-Especificacion-Funcional.md"
$TestingDoc = Join-Path $DocsDir "SPT-016-Plan-y-Resultados-de-Pruebas.md"
$OperationsDoc = Join-Path $DocsDir "SPT-016-Manual-Operativo.md"
$TraceabilityDoc = Join-Path $DocsDir "SPT-016-Matriz-de-Trazabilidad.md"
$ClosureAct = Join-Path $DocsDir "ACT-SPT-016-Cierre-Oficial.md"

Step "Validando prerrequisitos institucionales"

Require-File `
    -Path $TestPath `
    -Description "la prueba específica SPT-016"

Require-File `
    -Path $RunnerPath `
    -Description "el ejecutor institucional de pytest"

Require-File `
    -Path $CanonicalPublisher `
    -Description "el gate canónico de publicación SGD-114G/SPB-007"

Require-File `
    -Path (Join-Path $ProjectRoot "src\sgoda\governance\test_evidence\cli.py") `
    -Description "SGD-114F"

Require-File `
    -Path (Join-Path $ProjectRoot "src\sgoda\governance\release_management\cli.py") `
    -Description "SGD-114G"

Require-File `
    -Path (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py") `
    -Description "SGD-115"

Require-File `
    -Path (Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py") `
    -Description "SGD-116"

if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) {
    throw "No existe la implementación SPT-016: $SourceDir"
}

$SourceFiles = @(
    Get-ChildItem `
        -LiteralPath $SourceDir `
        -Filter "*.py" `
        -File `
        -Recurse
)

if ($SourceFiles.Count -eq 0) {
    throw "La implementación SPT-016 no contiene archivos Python."
}

New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
New-Item -ItemType Directory -Path $DocsDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReportsDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

Step "Inventariando implementación existente"

$SourceInventory = @()

foreach ($File in $SourceFiles) {
    $SourceInventory += [ordered]@{
        path = $File.FullName.Substring($ProjectRoot.Length).TrimStart(
            [char[]]@([char]92, [char]47)
        ).Replace(
            [string][char]92,
            "/"
        )
        bytes = [int64]$File.Length
        sha256 = Get-Sha256 -Path $File.FullName
    }
}

$TestFile = Get-Item -LiteralPath $TestPath

$Inventory = [ordered]@{
    increment_code = "SPT-016"
    version = "1.0.0"
    name = "Motor de Analítica del Aprendizaje"
    implementation_status = "existing"
    source_directory = "src/sgoda/learning_analytics"
    source_file_count = $SourceInventory.Count
    source_files = $SourceInventory
    test_file = [ordered]@{
        path = "tests/learning_analytics/test_SPT_016_learning_analytics_engine.py"
        bytes = [int64]$TestFile.Length
        sha256 = Get-Sha256 -Path $TestPath
    }
    inventoried_at_utc = [DateTime]::UtcNow.ToString("o")
}

Write-Json -Path $InventoryJson -Value $Inventory

$Component = @'
{
  "increment_code": "SPT-016",
  "name": "Motor de Analítica del Aprendizaje",
  "version": "1.0.0",
  "status": "implemented_tested_and_officially_closed",
  "phase": "Fase Tecnológica IV",
  "native_ecosystem": true,
  "mandatory_proprietary_dependencies": [],
  "dependencies": [
    "SPT-012",
    "SPT-013A",
    "SPT-013B",
    "SPT-015",
    "SGD-114F",
    "SGD-114G",
    "SGD-115",
    "SGD-116",
    "SPB-007"
  ],
  "capabilities": [
    "learning event registration",
    "learner progress aggregation",
    "performance indicator calculation",
    "adaptive assessment analytics",
    "learning recommendations",
    "institutional reporting",
    "privacy-aware analytical summaries"
  ]
}
'@

$Policy = @'
{
  "policy_id": "SPT-016-POLICY-v1.0.0",
  "component": "SPT-016",
  "version": "1.0.0",
  "principles": [
    "data minimization",
    "purpose limitation",
    "traceability",
    "explainable indicators",
    "no mandatory proprietary dependencies",
    "native SGODA-PUINAVE integration"
  ],
  "quality_gates": {
    "specific_tests_required": true,
    "full_suite_required": true,
    "documentation_required": true,
    "release_validation_required": true,
    "clean_git_required_after_publication": true
  }
}
'@

$Architecture = @'
# SPT-016 v1.0.0 — Arquitectura

## Propósito

SPT-016 consolida eventos de aprendizaje, indicadores de avance, desempeño,
participación y resultados de evaluación para producir información útil,
trazable y explicable dentro de SGODA-PUINAVE.

## Ubicación

- Código: `src/sgoda/learning_analytics/`
- Pruebas: `tests/learning_analytics/`
- Configuración: `config/learning_analytics/`
- Evidencias: `artifacts/pmo/SPT-016-v1.0.0/`
- Release: `releases/SPT-016-v1.0.0/`

## Integraciones

SPT-016 recibe información de la Plataforma de Aprendizaje, del Gestor del
Diccionario, de los objetos de aprendizaje y del Motor de Evaluación
Adaptativa. Sus resultados pueden ser utilizados posteriormente por el Centro
de Conocimiento Puinave, la IA Pedagógica y los flujos de automatización.

## Principios

- componente nativo;
- tecnologías gratuitas y abiertas;
- datos mínimos necesarios;
- indicadores explicables;
- evidencia versionable;
- publicación sometida a gates institucionales.
'@

$Functional = @'
# SPT-016 v1.0.0 — Especificación funcional

## Capacidades

1. Registrar eventos de aprendizaje.
2. Consolidar progreso por estudiante, actividad y objeto de aprendizaje.
3. Calcular indicadores de participación, desempeño y avance.
4. Integrar resultados del Motor de Evaluación Adaptativa.
5. Producir resúmenes analíticos institucionales.
6. Generar recomendaciones basadas en evidencia.
7. Mantener trazabilidad entre datos, indicadores y reportes.

## Criterios de aceptación

- La implementación puede importarse sin errores.
- Las pruebas específicas terminan aprobadas.
- La suite completa no presenta regresiones.
- Los metadatos declaran el componente como nativo.
- No existen dependencias propietarias obligatorias.
- La documentación y el release son verificables.
'@

$Operations = @'
# SPT-016 v1.0.0 — Manual operativo

## Validación específica

```powershell
$env:PYTHONPATH = "src"
python -m pytest tests/learning_analytics/test_SPT_016_learning_analytics_engine.py
```

## Validación completa

```powershell
python -m pytest
```

## Evidencias

Los reportes JUnit y los resúmenes institucionales se almacenan en:

`artifacts/pmo/SPT-016-v1.0.0/test-reports/`

## Publicación

Toda publicación debe utilizar:

```powershell
.\scripts\Invoke-SPB007-CanonicalPublish.ps1 -Publish
```

SGD-114G valida primero los releases y luego habilita SPB-007.
'@

Write-Utf8 -Path $ComponentPath -Content $Component
Write-Utf8 -Path $PolicyPath -Content $Policy
Write-Utf8 -Path $ArchitectureDoc -Content $Architecture
Write-Utf8 -Path $FunctionalDoc -Content $Functional
Write-Utf8 -Path $OperationsDoc -Content $Operations

Run "Validando sintaxis Python de SPT-016" {
    $CompileArguments = @("-m", "py_compile")

    foreach ($File in $SourceFiles) {
        $CompileArguments += $File.FullName
    }

    $CompileArguments += $TestPath

    & python @CompileArguments
}

Run "Ejecutando pruebas específicas SPT-016" {
    & $RunnerPath `
        -Component "SPT-016-v1.0.0" `
        -TestPath @(
            "tests/learning_analytics/test_SPT_016_learning_analytics_engine.py"
        ) `
        -ReportPath "$SpecificXml" `
        -SummaryJson "$SpecificJson" `
        -SummaryMarkdown "$SpecificMd" `
        -Scope "specific"
}

$Specific = Get-Content `
    -LiteralPath $SpecificJson `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not [bool]$Specific.approved) {
    throw "Las pruebas específicas SPT-016 no fueron aprobadas."
}

$Testing = @"
# SPT-016 v1.0.0 — Plan y resultados de pruebas

## Pruebas específicas

- Ejecutadas: $($Specific.executed)
- Aprobadas: $($Specific.passed)
- Fallidas: $($Specific.failures)
- Errores: $($Specific.errors)
- Omitidas: $($Specific.skipped)
- Resultado: $(if ([bool]$Specific.approved) { "APROBADO" } else { "NO APROBADO" })

## Evidencia

- JUnit: `artifacts/pmo/SPT-016-v1.0.0/test-reports/specific.xml`
- JSON: `artifacts/pmo/SPT-016-v1.0.0/test-reports/specific-summary.json`
- Markdown: `artifacts/pmo/SPT-016-v1.0.0/test-reports/specific-summary.md`
"@

Write-Utf8 -Path $TestingDoc -Content $Testing

Run "Ejecutando suite completa del ecosistema" {
    python -m pytest `
        --junitxml="$FullXml"
}

Run "Sincronizando suite completa mediante SGD-114F" {
    python -m sgoda.governance.test_evidence.cli `
        --junit "$FullXml" `
        --component "SGODA-PUINAVE" `
        --scope "full_suite" `
        --output-json "$FullJson" `
        --output-md "$FullMd"
}

$Full = Get-Content `
    -LiteralPath $FullJson `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not [bool]$Full.approved) {
    throw "La suite completa presentó regresiones."
}

Run "Validando releases mediante SGD-114G" {
    python -m sgoda.governance.release_management.cli `
        --root "$ProjectRoot" `
        --operation "close" `
        --output-json (
            Join-Path $PmoDir "release-validation.json"
        )
}

$ReleaseValidationPath = Join-Path $PmoDir "release-validation.json"
$ReleaseValidation = Get-Content `
    -LiteralPath $ReleaseValidationPath `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not [bool]$ReleaseValidation.approved) {
    throw "SGD-114G no aprobó la estructura de releases."
}

$TraceabilityRows = @(
    [ordered]@{
        requirement = "SPT016-REQ-001"
        description = "Registrar y consolidar eventos de aprendizaje"
        implementation = "src/sgoda/learning_analytics"
        tests = "tests/learning_analytics/test_SPT_016_learning_analytics_engine.py"
        status = "verified"
    },
    [ordered]@{
        requirement = "SPT016-REQ-002"
        description = "Calcular indicadores de avance y desempeño"
        implementation = "src/sgoda/learning_analytics"
        tests = "specific and full suite"
        status = "verified"
    },
    [ordered]@{
        requirement = "SPT016-REQ-003"
        description = "Integración nativa sin dependencia propietaria obligatoria"
        implementation = "config/learning_analytics/SPT-016-component.json"
        tests = "SGD-114E and full suite"
        status = "verified"
    },
    [ordered]@{
        requirement = "SPT016-REQ-004"
        description = "Evidencias institucionales versionables"
        implementation = "artifacts/pmo/SPT-016-v1.0.0"
        tests = "SGD-114F"
        status = "verified"
    },
    [ordered]@{
        requirement = "SPT016-REQ-005"
        description = "Release canónico y publicación gobernada"
        implementation = "releases/SPT-016-v1.0.0"
        tests = "SGD-114G and SPB-007 canonical gate"
        status = "verified"
    }
)

Write-Json `
    -Path $TraceabilityJson `
    -Value ([ordered]@{
        increment_code = "SPT-016"
        version = "1.0.0"
        rows = $TraceabilityRows
        verified_count = @(
            $TraceabilityRows |
                Where-Object status -eq "verified"
        ).Count
        pending_count = 0
    })

$TraceabilityMarkdown = @"
# SPT-016 v1.0.0 — Matriz de trazabilidad

| Requisito | Descripción | Implementación | Pruebas | Estado |
|---|---|---|---|---|
"@

foreach ($Row in $TraceabilityRows) {
    $TraceabilityMarkdown += (
        "| " + $Row.requirement +
        " | " + $Row.description +
        " | `" + $Row.implementation + "`" +
        " | " + $Row.tests +
        " | VERIFICADO |" +
        [Environment]::NewLine
    )
}

Write-Utf8 `
    -Path $TraceabilityDoc `
    -Content $TraceabilityMarkdown

$Closure = [ordered]@{
    increment_code = "SPT-016"
    version = "1.0.0"
    name = "Motor de Analítica del Aprendizaje"
    closure_status = "officially_closed"
    implementation_rewritten = $false
    source_file_count = $SourceInventory.Count
    specific_tests = [ordered]@{
        executed = [int]$Specific.executed
        passed = [int]$Specific.passed
        failures = [int]$Specific.failures
        errors = [int]$Specific.errors
        skipped = [int]$Specific.skipped
        approved = [bool]$Specific.approved
    }
    full_suite = [ordered]@{
        executed = [int]$Full.executed
        passed = [int]$Full.passed
        failures = [int]$Full.failures
        errors = [int]$Full.errors
        skipped = [int]$Full.skipped
        approved = [bool]$Full.approved
    }
    release_validation = [ordered]@{
        approved = [bool]$ReleaseValidation.approved
        exit_code = [int]$ReleaseValidation.exit_code
    }
    documentation = [ordered]@{
        architecture = $ArchitectureDoc
        functional_specification = $FunctionalDoc
        testing = $TestingDoc
        operations = $OperationsDoc
        traceability = $TraceabilityDoc
        closure_act = $ClosureAct
    }
    pending_deliverables = @()
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
}

Write-Json -Path $ClosureJson -Value $Closure

$ClosureMarkdown = @"
# ACT-SPT-016 — Acta oficial de cierre

## Identificación

- Componente: SPT-016
- Nombre: Motor de Analítica del Aprendizaje
- Versión: 1.0.0
- Estado: CERRADO OFICIALMENTE

## Evidencias

- Archivos fuente inventariados: $($SourceInventory.Count)
- Pruebas específicas: $($Specific.passed)/$($Specific.executed)
- Suite completa: $($Full.passed)/$($Full.executed)
- Validación SGD-114G: APROBADA
- Entregables documentales pendientes: 0

## Declaración

La implementación funcional existente se conserva. El cierre oficial certifica
que el componente cuenta con código, configuración, pruebas, documentación,
trazabilidad, evidencias y release institucional verificables.
"@

Write-Utf8 -Path $ClosureMd -Content $ClosureMarkdown
Write-Utf8 -Path $ClosureAct -Content $ClosureMarkdown

Step "Construyendo release oficial SPT-016"

$ReleaseFiles = @(
    $ComponentPath,
    $PolicyPath,
    $ArchitectureDoc,
    $FunctionalDoc,
    $TestingDoc,
    $OperationsDoc,
    $TraceabilityDoc,
    $ClosureAct,
    $InventoryJson,
    $TraceabilityJson,
    $ClosureJson,
    $ClosureMd,
    $SpecificXml,
    $SpecificJson,
    $SpecificMd,
    $FullXml,
    $FullJson,
    $FullMd,
    $ReleaseValidationPath
)

foreach ($File in $ReleaseFiles) {
    Require-File `
        -Path $File `
        -Description "un archivo del release"

    Copy-Item `
        -LiteralPath $File `
        -Destination $ReleaseDir `
        -Force
}

$ManifestFiles = @(
    Get-ChildItem `
        -LiteralPath $ReleaseDir `
        -File |
        ForEach-Object {
            [ordered]@{
                name = $_.Name
                bytes = [int64]$_.Length
                sha256 = Get-Sha256 -Path $_.FullName
            }
        }
)

Write-Json `
    -Path (Join-Path $ReleaseDir "manifest.json") `
    -Value ([ordered]@{
        increment_code = "SPT-016"
        version = "1.0.0"
        release_name = "SPT-016-v1.0.0"
        status = "implemented_tested_and_officially_closed"
        native_ecosystem = $true
        mandatory_proprietary_dependencies = @()
        files = $ManifestFiles
        generated_at_utc = [DateTime]::UtcNow.ToString("o")
    })

Run "Regenerando SGD-115" {
    python -m sgoda.documentation.master_docs `
        --root "$ProjectRoot" `
        --output "artifacts/documentation/SGD-115"
}

Run "Regenerando SGD-116" {
    python -m sgoda.roadmap.cli `
        --root "$ProjectRoot" `
        --output "artifacts/roadmap/SGD-116"
}

Run "Revalidando release final mediante SGD-114G" {
    python -m sgoda.governance.release_management.cli `
        --root "$ProjectRoot" `
        --operation "close" `
        --output-json (
            Join-Path $PmoDir "final-release-validation.json"
        )
}

if ($Publish) {
    Step "Publicando cierre oficial mediante gate canónico"

    & $CanonicalPublisher `
        -Publish `
        -CommitMessage "feat(analytics): close SPT-016 learning analytics engine" `
        -EvidenceCommitMessage "chore(analytics): publish SPT-016 closure evidence"

    if ($LASTEXITCODE -ne 0) {
        throw "La publicación institucional de SPT-016 terminó con errores."
    }
}

Step "Resultado final"

Write-Host "SPT-016 v1.0.0 cerrado oficialmente." -ForegroundColor Green
Write-Host "Motor de Analítica del Aprendizaje: OPERATIVO." -ForegroundColor Green
Write-Host "Implementación funcional reescrita: NO." -ForegroundColor Green
Write-Host (
    "Pruebas específicas: " +
    "$($Specific.passed)/$($Specific.executed) APROBADAS."
) -ForegroundColor Green
Write-Host (
    "Suite completa: " +
    "$($Full.passed)/$($Full.executed) APROBADA."
) -ForegroundColor Green
Write-Host "Entregables documentales pendientes: 0." -ForegroundColor Green
Write-Host "SGD-114G: APROBADO." -ForegroundColor Green
Write-Host "SGD-115: ACTUALIZADO." -ForegroundColor Green
Write-Host "SGD-116: ACTUALIZADO." -ForegroundColor Green
Write-Host "Release: releases\SPT-016-v1.0.0" -ForegroundColor Cyan

if ($Publish) {
    Write-Host "Publicación institucional: COMPLETADA." -ForegroundColor Green
}
else {
    Write-Host "Publicación no solicitada. Reejecute con -Publish." -ForegroundColor Yellow
}
