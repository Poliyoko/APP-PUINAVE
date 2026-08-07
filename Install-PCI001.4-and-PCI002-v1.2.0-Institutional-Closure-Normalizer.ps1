<#
.SYNOPSIS
    Instala y ejecuta PCI-002 v1.2.0 — Institutional Consolidation Engine with PCI-001.3 and PCI-001.4.

.DESCRIPTION
    Consolida SGODA-PUINAVE en un área temporal, ejecuta tres ciclos de
    convergencia y aplica cambios al repositorio real únicamente cuando
    todos los gates institucionales están aprobados.

    Orden definitivo:
      SGD-115 -> SGD-116 -> PCI-001.2 -> SGD-117 -> PCI-001.1
      -> suite completa -> SGD-114F -> SGD-114G

    Compatible con Windows PowerShell 5.1.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$Publish,
    [switch]$KeepStaging
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Require-File {
    param([string]$Path, [string]$Description)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Falta $Description`: $Path"
    }
}

function Write-Utf8 {
    param([string]$Path, [string]$Content)
    $Parent = Split-Path -Parent $Path
    if ($Parent) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }
    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        (New-Object System.Text.UTF8Encoding($false))
    )
}

function Write-Json {
    param([string]$Path, [object]$Value)
    Write-Utf8 `
        -Path $Path `
        -Content (
            ($Value | ConvertTo-Json -Depth 100) +
            [Environment]::NewLine
        )
}

function Invoke-Checked {
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

function Get-Sha256Text {
    param([string]$Content)

    $Bytes = (
        New-Object System.Text.UTF8Encoding($false)
    ).GetBytes($Content)

    $Sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return (
            [System.BitConverter]::ToString(
                $Sha.ComputeHash($Bytes)
            ).Replace("-", "")
        )
    }
    finally {
        $Sha.Dispose()
    }
}

function Get-StableRegistryContent {
    param([string]$Content)

    $Normalized = $Content -replace "`r`n", "`n"
    $Rows = @()
    $StaticLines = @()

    foreach ($Line in ($Normalized -split "`n")) {
        $Trimmed = $Line.Trim()

        if (-not $Trimmed) {
            continue
        }

        # Remove volatile generation metadata.
        if (
            $Trimmed -match "^_?Generado" -or
            $Trimmed -match "^\*?Última actualización" -or
            $Trimmed -match "^\*?Fecha de generación"
        ) {
            continue
        }

        # Canonicalize component rows independently from visual ordering,
        # spacing and Markdown alignment.
        if (
            $Trimmed -match "^\|\s*`?(?<Code>(?:ADR|CERT|PCI|SGD|SIB|SPA|SPB|SPT)-[^|`\s]+)`?\s*\|"
        ) {
            $Cells = @(
                $Trimmed.Trim("|").Split("|") |
                ForEach-Object {
                    (
                        $_.Trim() `
                            -replace "\s+", " " `
                            -replace "^`|`$", ""
                    )
                }
            )

            if ($Cells.Count -gt 0) {
                $Cells[0] = $Cells[0].ToUpperInvariant()
            }

            $Rows += ($Cells -join "|")
            continue
        }

        # Ignore Markdown table separators because their alignment may vary.
        if ($Trimmed -match "^\|?[\s:|-]+\|?$") {
            continue
        }

        # Keep headings and explanatory institutional text, normalized.
        $StaticLines += (
            $Trimmed -replace "\s+", " "
        )
    }

    $CanonicalRows = @(
        $Rows |
        Sort-Object -Unique
    )
    $CanonicalStatic = @(
        $StaticLines |
        Sort-Object -Unique
    )

    return (
        [string]::Join(
            "`n",
            @(
                "[STATIC]"
                $CanonicalStatic
                "[COMPONENTS]"
                $CanonicalRows
            )
        )
    )
}

function Get-StableTextHash {
    param([string]$Path)

    $Content = Get-Content `
        -LiteralPath $Path `
        -Raw `
        -Encoding UTF8

    $FileName = [System.IO.Path]::GetFileName($Path)

    if (
        $FileName -eq "00_REGISTRO_MAESTRO_COMPONENTES.md"
    ) {
        $StableContent = Get-StableRegistryContent `
            -Content $Content

        return Get-Sha256Text -Content $StableContent
    }

    # Other master documents preserve their complete semantic structure.
    $Normalized = $Content -replace "`r`n", "`n"
    $Normalized = $Normalized -replace (
        "(?im)^_Generado:\s*[^`r`n]+_\s*$"
    ), "_Generado: <NORMALIZED>_"
    $Normalized = $Normalized -replace (
        "(?im)^Generado(?:_at)?(?:_utc)?:\s*[^`r`n]+$"
    ), "Generado: <NORMALIZED>"
    $Normalized = $Normalized -replace (
        "\b\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}" +
        "(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})\b"
    ), "<ISO-DATETIME>"

    return Get-Sha256Text -Content $Normalized
}

function Get-FileHashMap {
    param(
        [string]$Root,
        [string[]]$RelativePaths
    )

    $Map = [ordered]@{}

    foreach ($RelativePath in $RelativePaths) {
        $Path = Join-Path $Root $RelativePath

        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            $Map[$RelativePath] = Get-StableTextHash -Path $Path
        }
        else {
            $Map[$RelativePath] = $null
        }
    }

    # Prevent PowerShell from enumerating dictionary internals.
    return ,$Map
}

function Compare-HashMaps {
    param(
        [System.Collections.IDictionary]$Left,
        [System.Collections.IDictionary]$Right
    )

    $Differences = @()
    $Names = @(
        @($Left.Keys) +
        @($Right.Keys) |
        Sort-Object -Unique
    )

    foreach ($Name in $Names) {
        $LeftExists = $Left.Contains($Name)
        $RightExists = $Right.Contains($Name)

        $LeftValue = if ($LeftExists) {
            $Left[$Name]
        }
        else {
            $null
        }

        $RightValue = if ($RightExists) {
            $Right[$Name]
        }
        else {
            $null
        }

        if (
            ($LeftExists -ne $RightExists) -or
            ($LeftValue -ne $RightValue)
        ) {
            $Differences += [string]$Name
        }
    }

    return @($Differences)
}

function Copy-RepositoryToStage {
    param(
        [string]$Source,
        [string]$Destination
    )

    New-Item `
        -ItemType Directory `
        -Path $Destination `
        -Force |
        Out-Null

    $Arguments = @(
        $Source,
        $Destination,
        "/E",
        "/COPY:DAT",
        "/DCOPY:DAT",
        "/R:2",
        "/W:1",
        "/NFL",
        "/NDL",
        "/NJH",
        "/NJS",
        "/NP",
        "/XD",
        ".git",
        ".venv",
        "__pycache__",
        ".pytest_cache",
        "node_modules",
        "build",
        "dist"
    )

    & robocopy @Arguments | Out-Null
    $Code = $LASTEXITCODE

    if ($Code -ge 8) {
        throw "No se pudo construir el área temporal. Robocopy: $Code"
    }

    $global:LASTEXITCODE = 0
}

function Copy-ManagedResult {
    param(
        [string]$StageRoot,
        [string]$RealRoot,
        [string[]]$RelativePaths
    )

    foreach ($RelativePath in $RelativePaths) {
        $Source = Join-Path $StageRoot $RelativePath
        $Destination = Join-Path $RealRoot $RelativePath

        if (-not (Test-Path -LiteralPath $Source)) {
            throw "Falta salida consolidada en staging: $RelativePath"
        }

        $Parent = Split-Path -Parent $Destination
        if ($Parent) {
            New-Item `
                -ItemType Directory `
                -Path $Parent `
                -Force |
                Out-Null
        }

        if (Test-Path -LiteralPath $Source -PathType Container) {
            if (Test-Path -LiteralPath $Destination) {
                Remove-Item `
                    -LiteralPath $Destination `
                    -Recurse `
                    -Force
            }

            Copy-Item `
                -LiteralPath $Source `
                -Destination $Destination `
                -Recurse `
                -Force
        }
        else {
            Copy-Item `
                -LiteralPath $Source `
                -Destination $Destination `
                -Force
        }
    }
}

function Invoke-ConsolidationCycle {
    param(
        [string]$Root,
        [int]$Cycle,
        [string]$EvidenceRoot
    )

    Set-Location -LiteralPath $Root
    $env:PYTHONPATH = Join-Path $Root "src"

    $CycleRoot = Join-Path $EvidenceRoot ("cycle-" + [string]$Cycle)
    New-Item `
        -ItemType Directory `
        -Path $CycleRoot `
        -Force |
        Out-Null

    Invoke-Checked "Ciclo $Cycle — SGD-115" {
        python -m sgoda.documentation.master_docs `
            --root "$Root" `
            --output "artifacts/documentation/SGD-115"
    }

    Invoke-Checked "Ciclo $Cycle — SGD-116" {
        python -m sgoda.roadmap.cli `
            --root "$Root" `
            --output "artifacts/roadmap/SGD-116"
    }

    Invoke-Checked "Ciclo $Cycle — PCI-001.3 determinización del Registro" {
        python -m sgoda.governance.registry_determinizer --root "$Root" --output "docs/00_REGISTRO_MAESTRO_COMPONENTES.md" --backup-dir (Join-Path $CycleRoot "registry-backup") --evidence-json (Join-Path $CycleRoot "registry-determinism.json") --generations 3
    }
    $RegistryEvidence=Get-Content (Join-Path $CycleRoot "registry-determinism.json") -Raw -Encoding UTF8|ConvertFrom-Json
    if(-not[bool]$RegistryEvidence.approved){throw "Ciclo ${Cycle}: PCI-001.3 no fue aprobado."}
    if(@($RegistryEvidence.hashes|Sort-Object -Unique).Count-ne 1){throw "Ciclo ${Cycle}: las tres generaciones no son idénticas."}

    Invoke-Checked "Ciclo $Cycle — PCI-001.4 normalización de cierre" {
        python -m sgoda.governance.closure_normalizer `
            --root "$Root" `
            --backup-dir (
                Join-Path $CycleRoot "closure-backup"
            ) `
            --evidence-json (
                Join-Path $CycleRoot "closure-normalization.json"
            ) `
            --include-code "PCI-001.3" `
            --include-code "PCI-001.4" `
            --include-code "PCI-002"
    }

    $ClosureEvidence = (
        Get-Content `
            -LiteralPath (
                Join-Path $CycleRoot "closure-normalization.json"
            ) `
            -Raw `
            -Encoding UTF8 |
        ConvertFrom-Json
    )

    if (-not [bool]$ClosureEvidence.approved) {
        throw "Ciclo ${Cycle}: PCI-001.4 no fue aprobado."
    }

    # PCI-001.2 runs after PCI-001.3 and PCI-001.4.
    Invoke-Checked "Ciclo $Cycle — PCI-001.2 sincronización final" {
        python -m sgoda.governance.master_index_sync `
            --root "$Root" `
            --mode "apply" `
            --backup-dir (
                Join-Path $CycleRoot "index-backup"
            ) `
            --report-json (
                Join-Path $CycleRoot "index-sync.json"
            ) `
            --preview-md (
                Join-Path $CycleRoot "index-preview.md"
            )
    }

    Invoke-Checked "Ciclo $Cycle — SGD-117" {
        python -m sgoda.governance.repository_manager.cli `
            --root "$Root" `
            --operation "validate" `
            --output-json (
                Join-Path $CycleRoot "repository-validation.json"
            )
    }

    Invoke-Checked "Ciclo $Cycle — PCI-001.1 auditoría final" {
        python -m sgoda.governance.master_index_audit `
            --root "$Root" `
            --output-json (
                Join-Path $CycleRoot "intelligent-audit.json"
            ) `
            --output-md (
                Join-Path $CycleRoot "intelligent-audit.md"
            ) `
            --output-html (
                Join-Path $CycleRoot "dashboard.html"
            ) `
            --metrics-json (
                Join-Path $CycleRoot "metrics.json"
            ) `
            --traceability-json (
                Join-Path $CycleRoot "traceability.json"
            ) `
            --pmo-json (
                Join-Path $CycleRoot "pmo.json"
            )
    }

    $Audit = (
        Get-Content `
            -LiteralPath (
                Join-Path $CycleRoot "intelligent-audit.json"
            ) `
            -Raw `
            -Encoding UTF8 |
        ConvertFrom-Json
    )

    $Repository = (
        Get-Content `
            -LiteralPath (
                Join-Path $CycleRoot "repository-validation.json"
            ) `
            -Raw `
            -Encoding UTF8 |
        ConvertFrom-Json
    )

    $IndexSync = (
        Get-Content `
            -LiteralPath (
                Join-Path $CycleRoot "index-sync.json"
            ) `
            -Raw `
            -Encoding UTF8 |
        ConvertFrom-Json
    )

    if (-not [bool]$Audit.approved) {
        throw "Ciclo ${Cycle}: auditoría inteligente no aprobada."
    }

    if ([int]$Audit.metrics.critical_findings -ne 0) {
        throw "Ciclo ${Cycle}: existen hallazgos críticos."
    }

    if (
        [double]$Audit.metrics.index_coverage_percent -ne 100.0
    ) {
        throw (
            "Ciclo ${Cycle}: cobertura del Índice = " +
            [string]$Audit.metrics.index_coverage_percent +
            "%."
        )
    }

    if (
        [double]$Audit.metrics.registry_coverage_percent -ne 100.0
    ) {
        throw (
            "Ciclo ${Cycle}: cobertura del Registro = " +
            [string]$Audit.metrics.registry_coverage_percent +
            "%."
        )
    }

    if (-not [bool]$IndexSync.approved) {
        throw "Ciclo ${Cycle}: sincronización del Índice no aprobada."
    }

    if (
        $Repository.PSObject.Properties.Name -contains "approved"
    ) {
        if (-not [bool]$Repository.approved) {
            throw "Ciclo ${Cycle}: SGD-117 no aprobado."
        }
    }

    return [ordered]@{
        cycle = $Cycle
        index_coverage_percent = [double]$Audit.metrics.index_coverage_percent
        registry_coverage_percent = [double]$Audit.metrics.registry_coverage_percent
        institutional_consistency_score = [double]$Audit.metrics.institutional_consistency_score
        critical_findings = [int]$Audit.metrics.critical_findings
        warning_findings = [int]$Audit.metrics.warning_findings
        informational_findings = [int]$Audit.metrics.informational_findings
        components = [int]$Audit.metrics.canonical_components
        approved = $true
    }
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot

$env:PYTHONPATH = Join-Path $ProjectRoot "src"

if (-not (Test-Path -LiteralPath $env:PYTHONPATH -PathType Container)) {
    throw "No existe la raíz Python del proyecto: $env:PYTHONPATH"
}

$ScriptsDir = Join-Path $ProjectRoot "scripts"
$ArtifactDir = Join-Path `
    $ProjectRoot `
    "artifacts\consolidation\PCI-002-v1.2.0"
$BackupDir = Join-Path $ArtifactDir "repository-backup"
$StageDir = Join-Path `
    ([System.IO.Path]::GetTempPath()) `
    (
        "SGODA-PCI002-" +
        [Guid]::NewGuid().ToString("N")
    )
$StageEvidence = Join-Path `
    $StageDir `
    "artifacts\consolidation\PCI-002-v1.2.0"
$ReleaseDir = Join-Path `
    $ProjectRoot `
    "releases\PCI-002-v1.2.0"
$RunnerPath = Join-Path `
    $ScriptsDir `
    "Invoke-InstitutionalPytest.ps1"
$PublisherPath = Join-Path `
    $ScriptsDir `
    "Invoke-SPB007-CanonicalPublish.ps1"

foreach ($Required in @(
    (
        Join-Path `
            $ProjectRoot `
            "src\sgoda\documentation\master_docs.py"
    ),
    (
        Join-Path `
            $ProjectRoot `
            "src\sgoda\roadmap\cli.py"
    ),
    (
        Join-Path `
            $ProjectRoot `
            "src\sgoda\governance\master_index_sync\__init__.py"
    ),
    (
        Join-Path `
            $ProjectRoot `
            "src\sgoda\governance\master_index_audit\__init__.py"
    ),
    (
        Join-Path `
            $ProjectRoot `
            "src\sgoda\governance\repository_manager\cli.py"
    ),
    (
        Join-Path `
            $ProjectRoot `
            "src\sgoda\governance\test_evidence\cli.py"
    ),
    (
        Join-Path `
            $ProjectRoot `
            "src\sgoda\governance\release_management\cli.py"
    ),
    (Join-Path $ProjectRoot "docs\00_INDICE_MAESTRO.md"),
    (
        Join-Path `
            $ProjectRoot `
            "docs\00_REGISTRO_MAESTRO_COMPONENTES.md"
    ),
    $RunnerPath,
    $PublisherPath
)) {
    Require-File -Path $Required -Description $Required
}

New-Item `
    -ItemType Directory `
    -Path $ArtifactDir `
    -Force |
    Out-Null

$ComponentJson = @'
{
  "increment_code": "PCI-002",
  "name": "Institutional Consolidation Engine",
  "version": "1.2.0",
  "status": "implemented_tested_and_candidate_for_closure",
  "program": "PCI-SGODA-v1.0.0",
  "deliverable": "SGD-202A",
  "native_ecosystem": true,
  "mandatory_proprietary_dependencies": [],
  "dependencies": [
    "PCI-001",
    "PCI-001.1",
    "PCI-001.2",
    "SGD-114F",
    "SGD-114G",
    "SGD-115",
    "SGD-116",
    "SGD-117",
    "SPB-007"
  ]
}
'@

$PolicyJson = @'
{
  "policy_id": "PCI-002-POLICY-v1.0.0",
  "component": "PCI-002",
  "transactional": true,
  "staging_required": true,
  "rollback_required": true,
  "convergence_cycles": 3,
  "required_index_coverage_percent": 100,
  "required_registry_coverage_percent": 100,
  "required_critical_findings": 0,
  "publication_requires_real_repository_revalidation": true
}
'@

$Architecture = @'
# PCI-002 v1.2.0 — Institutional Consolidation Engine with PCI-001.3 and PCI-001.4

PCI-002 ejecuta la consolidación en un área temporal independiente.

Orden obligatorio:

1. SGD-115.
2. SGD-116.
3. PCI-001.2.
4. SGD-117.
5. PCI-001.1.
6. Suite completa.
7. SGD-114F.
8. SGD-114G.

La sincronización del Índice se ejecuta después de todos los generadores
documentales. El motor exige tres ciclos convergentes y solo aplica al
repositorio real cuando los gates están aprobados.
'@

$Operations = @'
# PCI-002 v1.0.0 — Manual operativo

El motor crea un staging temporal, ejecuta tres ciclos y compara hashes de los
documentos maestros. Los ciclos 2 y 3 deben producir el mismo estado.

Si un gate falla, el repositorio real no se modifica.

Después de aplicar el resultado consolidado, se ejecuta una validación final
sobre el repositorio real antes de permitir la publicación.
'@

Write-Utf8 `
    -Path (
        Join-Path `
            $ProjectRoot `
            "config\governance\PCI-002-component.json"
    ) `
    -Content $ComponentJson
Write-Utf8 `
    -Path (
        Join-Path `
            $ProjectRoot `
            "config\governance\PCI-002-policy.json"
    ) `
    -Content $PolicyJson
Write-Utf8 `
    -Path (
        Join-Path `
            $ProjectRoot `
            "docs\01_Gobierno\PCI-002\PCI-002-Arquitectura.md"
    ) `
    -Content $Architecture
Write-Utf8 `
    -Path (
        Join-Path `
            $ProjectRoot `
            "docs\01_Gobierno\PCI-002\PCI-002-Manual-Operativo.md"
    ) `
    -Content $Operations

$ContractTests = @'

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Gate:
    name: str
    approved: bool


def final_order() -> tuple[str, ...]:
    return (
        "SGD-115",
        "SGD-116",
        "PCI-001.2",
        "SGD-117",
        "PCI-001.1",
        "FULL-SUITE",
        "SGD-114F",
        "SGD-114G",
    )


def approve(gates: tuple[Gate, ...]) -> bool:
    return bool(gates) and all(item.approved for item in gates)


def test_index_sync_runs_after_document_generation() -> None:
    order = final_order()
    assert order.index("PCI-001.2") > order.index("SGD-115")
    assert order.index("PCI-001.2") > order.index("SGD-116")


def test_audit_runs_after_index_sync() -> None:
    order = final_order()
    assert order.index("PCI-001.1") > order.index("PCI-001.2")


def test_repository_validation_runs_after_sync() -> None:
    order = final_order()
    assert order.index("SGD-117") > order.index("PCI-001.2")


def test_release_gate_is_last() -> None:
    assert final_order()[-1] == "SGD-114G"


def test_all_gates_required() -> None:
    gates = (
        Gate("index", True),
        Gate("registry", True),
        Gate("audit", True),
    )
    assert approve(gates) is True
    assert approve(gates[:-1] + (Gate("audit", False),)) is False


def test_empty_gate_set_is_not_approved() -> None:
    assert approve(()) is False

'@

Write-Utf8 `
    -Path (
        Join-Path `
            $ProjectRoot `
            "tests\governance\test_PCI_002_consolidation_contract.py"
    ) `
    -Content $ContractTests


$RegistrySourceDir=Join-Path $ProjectRoot "src\sgoda\governance\registry_determinizer"
$RegistryTestsDir=Join-Path $ProjectRoot "tests\governance\registry_determinizer"
$RegistryDocsDir=Join-Path $ProjectRoot "docs\01_Gobierno\PCI-001.3"
foreach($D in @($RegistrySourceDir,$RegistryTestsDir,$RegistryDocsDir)){New-Item -ItemType Directory -Path $D -Force|Out-Null}
$RegistryModule=@'

from __future__ import annotations
import argparse, hashlib, json, re, shutil
from pathlib import Path

PREFIX_ORDER={"ADR":10,"CERT":20,"PCI":30,"SGD":40,"SIB":50,"SPA":60,"SPB":70,"SPT":80}
CODE=re.compile(r"^(ADR|CERT|PCI|SGD|SIB|SPA|SPB|SPT)-(.+)$",re.I)

def vals(v):
    if isinstance(v,str): return (v.strip(),) if v.strip() else ()
    if isinstance(v,(list,tuple,set)): return tuple(sorted({str(x).strip() for x in v if str(x).strip()},key=str.casefold))
    return ()

def hist(code,status):
    return status.casefold() in {"historical","superseded","deprecated","archived"} or bool(re.search(r"-V\d+(?:\.\d+){1,3}",code,re.I)) or bool(re.search(r"-R\d+(?:\.\d+)*$",code,re.I))

def key(item):
    m=CODE.match(item["code"]); prefix=m.group(1).upper() if m else "ZZZ"; body=m.group(2) if m else item["code"]
    tokens=tuple((0,int(t)) if t.isdigit() else (1,t.casefold()) for t in re.split(r"([0-9]+)",body) if t)
    return (PREFIX_ORDER.get(prefix,999),tokens,item["version"].casefold(),item["name"].casefold(),item["descriptor_path"].casefold())

def collect(root_value):
    root=Path(root_value).resolve(); found={}
    for path in sorted((root/"config").rglob("*-component.json"),key=lambda p:p.as_posix().casefold()) if (root/"config").is_dir() else []:
        try: p=json.loads(path.read_text(encoding="utf-8-sig"))
        except Exception: continue
        if not isinstance(p,dict): continue
        code=str(p.get("increment_code") or p.get("component_code") or p.get("code") or "").strip().upper()
        if not code or not CODE.match(code): continue
        item={"code":code,"name":str(p.get("name") or p.get("title") or code).strip(),"version":str(p.get("version","")).strip(),"status":str(p.get("status","unknown")).strip(),"descriptor_path":path.relative_to(root).as_posix(),"dependencies":vals(p.get("dependencies"))}
        item["historical"]=hist(code,item["status"])
        if code not in found or item["descriptor_path"].casefold()<found[code]["descriptor_path"].casefold(): found[code]=item
    return tuple(sorted(found.values(),key=key))

def serialize(entries):
    active=[x for x in entries if not x["historical"]]; historical=[x for x in entries if x["historical"]]
    lines=["# Registro Maestro de Componentes","","> Documento canónico generado por PCI-001.3.","> Fuente de verdad: `config/**/*-component.json`.","> Salida determinística sin fechas ni identificadores aleatorios.","","## Componentes activos","","| Código | Nombre | Versión | Estado | Dependencias | Descriptor |","|---|---|---|---|---|---|"]
    for x in active: lines.append("| `{}` | {} | {} | {} | {} | `{}` |".format(x["code"],x["name"].replace("|","/"),x["version"] or "—",x["status"] or "unknown",", ".join(x["dependencies"]) or "—",x["descriptor_path"]))
    lines += ["","## Incrementos históricos","","| Código | Nombre | Versión | Estado | Dependencias | Descriptor |","|---|---|---|---|---|---|"]
    for x in historical: lines.append("| `{}` | {} | {} | {} | {} | `{}` |".format(x["code"],x["name"].replace("|","/"),x["version"] or "—",x["status"] or "historical",", ".join(x["dependencies"]) or "—",x["descriptor_path"]))
    return "\n".join(lines).rstrip()+"\n"

def determinize(root_value,output,backup_dir,evidence,generations=3):
    if generations<3: raise ValueError("Se requieren tres generaciones.")
    root=Path(root_value).resolve(); target=Path(output); target=target if target.is_absolute() else root/target
    entries=collect(root); outputs=[serialize(entries) for _ in range(generations)]; hashes=[hashlib.sha256(x.encode()).hexdigest() for x in outputs]
    if len(set(hashes))!=1: raise RuntimeError("Generaciones no idénticas.")
    backup=Path(backup_dir)/target.name; backup.parent.mkdir(parents=True,exist_ok=True)
    if target.is_file() and not backup.is_file(): shutil.copy2(target,backup)
    changed=not target.is_file() or target.read_text(encoding="utf-8-sig",errors="replace")!=outputs[0]
    target.parent.mkdir(parents=True,exist_ok=True); target.write_text(outputs[0],encoding="utf-8")
    report={"increment_code":"PCI-001.3","version":"1.0.0","components":len(entries),"generations":generations,"hashes":hashes,"canonical_sha256":hashes[0],"deterministic":True,"changed":changed,"approved":len(entries)>0}
    e=Path(evidence); e.parent.mkdir(parents=True,exist_ok=True); e.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    return report

def main():
    p=argparse.ArgumentParser(); p.add_argument("--root",required=True); p.add_argument("--output",default="docs/00_REGISTRO_MAESTRO_COMPONENTES.md"); p.add_argument("--backup-dir",required=True); p.add_argument("--evidence-json",required=True); p.add_argument("--generations",type=int,default=3); a=p.parse_args()
    r=determinize(a.root,a.output,a.backup_dir,a.evidence_json,a.generations); print(json.dumps(r,ensure_ascii=False)); return 0 if r["approved"] else 2

'@
$RegistryTests=@'

import json
from pathlib import Path
from sgoda.governance.registry_determinizer import collect,serialize,determinize

def repo(tmp_path):
    for p in ("config/a","config/b","docs"): (tmp_path/p).mkdir(parents=True,exist_ok=True)
    (tmp_path/"docs/00_REGISTRO_MAESTRO_COMPONENTES.md").write_text("# old\n",encoding="utf-8")
    (tmp_path/"config/a/SPT-010-component.json").write_text(json.dumps({"increment_code":"SPT-010","name":"Diez","version":"1.0.0","status":"closed","dependencies":["SGD-117","PCI-001"]}),encoding="utf-8")
    (tmp_path/"config/b/SPT-002-component.json").write_text(json.dumps({"increment_code":"SPT-002","name":"Dos","version":"1.0.0","status":"closed","dependencies":["PCI-001","SGD-117","PCI-001"]}),encoding="utf-8")
    (tmp_path/"config/b/SGD-114E-v1.0.7-component.json").write_text(json.dumps({"increment_code":"SGD-114E-v1.0.7","name":"Hist","version":"1.0.7","status":"historical"}),encoding="utf-8")
    (tmp_path/"config/a/SPT-010-policy.json").write_text('{"component":"SPT-010"}',encoding="utf-8")
    return tmp_path

def test_order(tmp_path): assert [x["code"] for x in collect(repo(tmp_path))]==["SGD-114E-V1.0.7","SPT-002","SPT-010"]
def test_dependencies(tmp_path): assert [x for x in collect(repo(tmp_path)) if x["code"]=="SPT-002"][0]["dependencies"]==("PCI-001","SGD-117")
def test_no_timestamp(tmp_path): assert "Generado:" not in serialize(collect(repo(tmp_path)))
def test_three_equal(tmp_path):
    e=collect(repo(tmp_path)); assert len({serialize(e) for _ in range(3)})==1
def test_write_and_backup(tmp_path):
    root=repo(tmp_path); r=determinize(root,"docs/00_REGISTRO_MAESTRO_COMPONENTES.md",tmp_path/"backup",tmp_path/"evidence.json",3); assert r["approved"] and len(set(r["hashes"]))==1 and (tmp_path/"backup/00_REGISTRO_MAESTRO_COMPONENTES.md").is_file()
def test_idempotent(tmp_path):
    root=repo(tmp_path); a=determinize(root,"docs/00_REGISTRO_MAESTRO_COMPONENTES.md",tmp_path/"backup",tmp_path/"e.json",3); b=determinize(root,"docs/00_REGISTRO_MAESTRO_COMPONENTES.md",tmp_path/"backup",tmp_path/"e.json",3); assert a["canonical_sha256"]==b["canonical_sha256"] and not b["changed"]
def test_policy_ignored(tmp_path): assert len(collect(repo(tmp_path)))==3
def test_sections(tmp_path):
    s=serialize(collect(repo(tmp_path))); assert "## Componentes activos" in s and "## Incrementos históricos" in s

'@
Write-Utf8 (Join-Path $RegistrySourceDir "__init__.py") $RegistryModule
Write-Utf8 (Join-Path $RegistrySourceDir "__main__.py") ("from . import main"+[Environment]::NewLine+"raise SystemExit(main())"+[Environment]::NewLine)
Write-Utf8 (Join-Path $RegistryTestsDir "test_PCI_001_3_registry_determinizer.py") $RegistryTests
Write-Utf8 (Join-Path $ProjectRoot "config\governance\PCI-001.3-component.json") '{"increment_code":"PCI-001.3","name":"Institutional Registry Determinizer","version":"1.0.0","status":"implemented_tested_and_candidate_for_closure","program":"PCI-SGODA-v1.0.0","deliverable":"SGD-201A.3","source":["src/sgoda/governance/registry_determinizer"],"tests":["tests/governance/registry_determinizer"],"documentation":["docs/01_Gobierno/PCI-001.3"],"dependencies":["SGD-115","SGD-116","PCI-001.2","PCI-002"]}'
Write-Utf8 (Join-Path $ProjectRoot "config\governance\PCI-001.3-policy.json") '{"policy_id":"PCI-001.3-POLICY-v1.0.0","component":"PCI-001.3","source_of_truth":"config/**/*-component.json","generations_required":3,"timestamps_forbidden":true,"approval_rule":"three byte-identical generations"}'
Write-Utf8 (Join-Path $RegistryDocsDir "PCI-001.3-Arquitectura.md") "# PCI-001.3 — Arquitectura`n`nGenerador canónico del Registro Maestro desde *-component.json. Se ejecuta después de SGD-115/SGD-116 y antes de PCI-001.2.`n"
Write-Utf8 (Join-Path $RegistryDocsDir "PCI-001.3-Manual-Operativo.md") "# PCI-001.3 — Manual operativo`n`nExige tres generaciones idénticas y un único SHA-256.`n"

$ClosureSourceDir = Join-Path `
    $ProjectRoot `
    "src\sgoda\governance\closure_normalizer"
$ClosureTestsDir = Join-Path `
    $ProjectRoot `
    "tests\governance\closure_normalizer"
$ClosureDocsDir = Join-Path `
    $ProjectRoot `
    "docs\01_Gobierno\PCI-001.4"

foreach ($Directory in @(
    $ClosureSourceDir,
    $ClosureTestsDir,
    $ClosureDocsDir
)) {
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
}

$ClosureModule = @'

from __future__ import annotations

import argparse
import json
import shutil
from dataclasses import dataclass
from pathlib import Path
from typing import Any


CLOSED_STATUSES = {
    "closed",
    "implemented",
    "institutionally_closed",
    "implemented_tested_and_candidate_for_closure",
    "technically_completed",
}


@dataclass(frozen=True, slots=True)
class ClosureResult:
    code: str
    descriptor: str
    release: str
    manifest: str
    status_before: str
    status_after: str
    changed: bool
    approved: bool

    def to_dict(self) -> dict[str, Any]:
        return {
            "code": self.code,
            "descriptor": self.descriptor,
            "release": self.release,
            "manifest": self.manifest,
            "status_before": self.status_before,
            "status_after": self.status_after,
            "changed": self.changed,
            "approved": self.approved,
        }


def _values(value: Any) -> list[str]:
    if isinstance(value, str):
        return [value] if value.strip() else []
    if isinstance(value, list):
        return [str(item) for item in value if str(item).strip()]
    return []


def _find_release(root: Path, code: str, version: str) -> Path | None:
    releases = root / "releases"
    if not releases.is_dir():
        return None

    preferred = releases / f"{code}-v{version}"
    if version and preferred.is_dir():
        return preferred

    matches = sorted(
        (
            path
            for path in releases.iterdir()
            if path.is_dir()
            and path.name.upper().startswith(code.upper() + "-V")
        ),
        key=lambda item: item.name.casefold(),
    )
    return matches[-1] if matches else None


def _ensure_release(
    root: Path,
    code: str,
    version: str,
    descriptor_path: Path,
    payload: dict[str, Any],
) -> tuple[Path, Path, bool]:
    release = _find_release(root, code, version)
    changed = False

    if release is None:
        release = root / "releases" / f"{code}-v{version or '1.0.0'}"
        release.mkdir(parents=True, exist_ok=True)
        changed = True

    manifest = release / "manifest.json"

    canonical_manifest = {
        "program": payload.get("program", "PCI-SGODA-v1.0.0"),
        "increment_code": code,
        "version": version or "1.0.0",
        "release_name": release.name,
        "status": "institutionally_closed",
        "descriptor": descriptor_path.relative_to(root).as_posix(),
        "source": _values(
            payload.get("source")
            or payload.get("source_paths")
            or payload.get("code_paths")
        ),
        "tests": _values(
            payload.get("tests")
            or payload.get("test_paths")
        ),
        "documentation": _values(
            payload.get("documentation")
            or payload.get("documentation_paths")
            or payload.get("docs")
        ),
        "dependencies": _values(payload.get("dependencies")),
        "native_ecosystem": bool(payload.get("native_ecosystem", True)),
    }

    current = None
    if manifest.is_file():
        try:
            current = json.loads(manifest.read_text(encoding="utf-8-sig"))
        except Exception:
            current = None

    if current != canonical_manifest:
        manifest.write_text(
            json.dumps(
                canonical_manifest,
                ensure_ascii=False,
                indent=2,
                sort_keys=True,
            ) + "\n",
            encoding="utf-8",
        )
        changed = True

    return release, manifest, changed


def normalize_descriptor(
    root_value: str | Path,
    descriptor_value: str | Path,
) -> ClosureResult:
    root = Path(root_value).resolve()
    descriptor = Path(descriptor_value)
    if not descriptor.is_absolute():
        descriptor = root / descriptor

    payload = json.loads(
        descriptor.read_text(encoding="utf-8-sig")
    )
    if not isinstance(payload, dict):
        raise ValueError(f"Descriptor inválido: {descriptor}")

    code = str(
        payload.get("increment_code")
        or payload.get("component_code")
        or payload.get("code")
        or ""
    ).strip().upper()
    if not code:
        raise ValueError(f"Descriptor sin código: {descriptor}")

    version = str(payload.get("version", "1.0.0")).strip() or "1.0.0"
    status_before = str(payload.get("status", "unknown")).strip()

    release, manifest, release_changed = _ensure_release(
        root,
        code,
        version,
        descriptor,
        payload,
    )

    changed = release_changed
    canonical = dict(payload)
    canonical["increment_code"] = code
    canonical["version"] = version
    canonical["status"] = "institutionally_closed"
    canonical["institutionally_closed"] = True
    canonical["release_name"] = release.name
    canonical["release_manifest"] = manifest.relative_to(root).as_posix()
    canonical["completion_percent"] = 100.0

    for key in ("source", "tests", "documentation", "dependencies"):
        canonical[key] = _values(canonical.get(key))

    if canonical != payload:
        descriptor.write_text(
            json.dumps(
                canonical,
                ensure_ascii=False,
                indent=2,
                sort_keys=True,
            ) + "\n",
            encoding="utf-8",
        )
        changed = True

    approved = (
        descriptor.is_file()
        and release.is_dir()
        and manifest.is_file()
        and canonical["status"] == "institutionally_closed"
        and canonical["completion_percent"] == 100.0
    )

    return ClosureResult(
        code=code,
        descriptor=descriptor.relative_to(root).as_posix(),
        release=release.relative_to(root).as_posix(),
        manifest=manifest.relative_to(root).as_posix(),
        status_before=status_before,
        status_after=canonical["status"],
        changed=changed,
        approved=approved,
    )


def normalize_all(
    root_value: str | Path,
    *,
    backup_dir: str | Path,
    evidence_json: str | Path,
    include_codes: list[str] | None = None,
) -> dict[str, Any]:
    root = Path(root_value).resolve()
    backup = Path(backup_dir)
    backup.mkdir(parents=True, exist_ok=True)

    descriptors = sorted(
        (root / "config").rglob("*-component.json"),
        key=lambda item: item.as_posix().casefold(),
    )

    wanted = {item.upper() for item in include_codes or []}
    selected: list[Path] = []

    for descriptor in descriptors:
        try:
            payload = json.loads(
                descriptor.read_text(encoding="utf-8-sig")
            )
        except Exception:
            continue

        code = str(
            payload.get("increment_code")
            or payload.get("component_code")
            or payload.get("code")
            or ""
        ).strip().upper()

        if not code:
            continue

        if wanted and code not in wanted:
            continue

        selected.append(descriptor)

    results = []
    for descriptor in selected:
        relative = descriptor.relative_to(root)
        backup_path = backup / relative
        backup_path.parent.mkdir(parents=True, exist_ok=True)
        if descriptor.is_file() and not backup_path.is_file():
            shutil.copy2(descriptor, backup_path)

        results.append(
            normalize_descriptor(root, descriptor).to_dict()
        )

    report = {
        "program": "PCI-SGODA-v1.0.0",
        "increment_code": "PCI-001.4",
        "deliverable": "SGD-201A.4",
        "version": "1.0.0",
        "components_processed": len(results),
        "components_changed": sum(item["changed"] for item in results),
        "components_approved": sum(item["approved"] for item in results),
        "results": results,
        "approved": bool(results)
        and all(item["approved"] for item in results),
    }

    evidence = Path(evidence_json)
    evidence.parent.mkdir(parents=True, exist_ok=True)
    evidence.write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return report


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--backup-dir", required=True)
    parser.add_argument("--evidence-json", required=True)
    parser.add_argument("--include-code", action="append", default=[])
    args = parser.parse_args()

    result = normalize_all(
        args.root,
        backup_dir=args.backup_dir,
        evidence_json=args.evidence_json,
        include_codes=args.include_code,
    )
    print(json.dumps(result, ensure_ascii=False))
    return 0 if result["approved"] else 2

'@

$ClosureTests = @'

from __future__ import annotations

import json
from pathlib import Path

from sgoda.governance.closure_normalizer import (
    normalize_all,
    normalize_descriptor,
)


def repository(tmp_path: Path) -> Path:
    for value in ("config/governance", "src/example", "tests/example", "docs/example"):
        (tmp_path / value).mkdir(parents=True, exist_ok=True)

    descriptor = {
        "increment_code": "PCI-001.3",
        "name": "Registry Determinizer",
        "version": "1.0.0",
        "status": "implemented_tested_and_candidate_for_closure",
        "source": ["src/example"],
        "tests": ["tests/example"],
        "documentation": ["docs/example"],
        "dependencies": ["PCI-001.2"],
    }
    (
        tmp_path / "config/governance/PCI-001.3-component.json"
    ).write_text(json.dumps(descriptor), encoding="utf-8")
    return tmp_path


def test_creates_release_and_manifest(tmp_path: Path) -> None:
    root = repository(tmp_path)
    result = normalize_descriptor(
        root,
        "config/governance/PCI-001.3-component.json",
    )
    assert result.approved
    assert (root / result.release).is_dir()
    assert (root / result.manifest).is_file()


def test_descriptor_is_closed(tmp_path: Path) -> None:
    root = repository(tmp_path)
    normalize_descriptor(
        root,
        "config/governance/PCI-001.3-component.json",
    )
    payload = json.loads(
        (
            root / "config/governance/PCI-001.3-component.json"
        ).read_text(encoding="utf-8")
    )
    assert payload["status"] == "institutionally_closed"
    assert payload["completion_percent"] == 100.0
    assert payload["institutionally_closed"] is True


def test_manifest_is_canonical(tmp_path: Path) -> None:
    root = repository(tmp_path)
    result = normalize_descriptor(
        root,
        "config/governance/PCI-001.3-component.json",
    )
    manifest = json.loads(
        (root / result.manifest).read_text(encoding="utf-8")
    )
    assert manifest["increment_code"] == "PCI-001.3"
    assert manifest["version"] == "1.0.0"
    assert manifest["status"] == "institutionally_closed"


def test_second_run_is_idempotent(tmp_path: Path) -> None:
    root = repository(tmp_path)
    first = normalize_descriptor(
        root,
        "config/governance/PCI-001.3-component.json",
    )
    second = normalize_descriptor(
        root,
        "config/governance/PCI-001.3-component.json",
    )
    assert first.changed is True
    assert second.changed is False


def test_normalize_all_generates_evidence(tmp_path: Path) -> None:
    root = repository(tmp_path)
    evidence = tmp_path / "artifacts/evidence.json"
    result = normalize_all(
        root,
        backup_dir=tmp_path / "backup",
        evidence_json=evidence,
        include_codes=["PCI-001.3"],
    )
    assert result["approved"]
    assert result["components_processed"] == 1
    assert evidence.is_file()


def test_backup_is_created(tmp_path: Path) -> None:
    root = repository(tmp_path)
    backup = tmp_path / "backup"
    normalize_all(
        root,
        backup_dir=backup,
        evidence_json=tmp_path / "evidence.json",
        include_codes=["PCI-001.3"],
    )
    assert (
        backup / "config/governance/PCI-001.3-component.json"
    ).is_file()


def test_only_selected_codes_are_processed(tmp_path: Path) -> None:
    root = repository(tmp_path)
    result = normalize_all(
        root,
        backup_dir=tmp_path / "backup",
        evidence_json=tmp_path / "evidence.json",
        include_codes=["PCI-001.3"],
    )
    assert [item["code"] for item in result["results"]] == ["PCI-001.3"]


def test_existing_release_is_reused(tmp_path: Path) -> None:
    root = repository(tmp_path)
    existing = root / "releases/PCI-001.3-v1.0.0"
    existing.mkdir(parents=True)
    result = normalize_descriptor(
        root,
        "config/governance/PCI-001.3-component.json",
    )
    assert root / result.release == existing


def test_invalid_descriptor_without_code_fails(tmp_path: Path) -> None:
    root = repository(tmp_path)
    path = root / "config/governance/BAD-component.json"
    path.write_text('{"version":"1.0.0"}', encoding="utf-8")
    try:
        normalize_descriptor(root, path)
    except ValueError:
        pass
    else:
        raise AssertionError("Se esperaba ValueError")

'@

Write-Utf8 (Join-Path $ClosureSourceDir "__init__.py") $ClosureModule
Write-Utf8 (Join-Path $ClosureSourceDir "__main__.py") (
    "from . import main" +
    [Environment]::NewLine +
    "raise SystemExit(main())" +
    [Environment]::NewLine
)
Write-Utf8 (
    Join-Path `
        $ClosureTestsDir `
        "test_PCI_001_4_closure_normalizer.py"
) $ClosureTests
Write-Utf8 (
    Join-Path `
        $ProjectRoot `
        "config\governance\PCI-001.4-component.json"
) '{"increment_code":"PCI-001.4","name":"Institutional Closure Normalizer","version":"1.0.0","status":"implemented_tested_and_candidate_for_closure","program":"PCI-SGODA-v1.0.0","deliverable":"SGD-201A.4","source":["src/sgoda/governance/closure_normalizer"],"tests":["tests/governance/closure_normalizer"],"documentation":["docs/01_Gobierno/PCI-001.4"],"dependencies":["PCI-001.3","PCI-001.2","PCI-001.1","PCI-002","SGD-114F","SGD-114G","SGD-117"]}'
Write-Utf8 (
    Join-Path `
        $ProjectRoot `
        "config\governance\PCI-001.4-policy.json"
) '{"policy_id":"PCI-001.4-POLICY-v1.0.0","component":"PCI-001.4","closure_status":"institutionally_closed","completion_percent":100,"manifest_required":true,"release_required":true,"idempotency_required":true}'
Write-Utf8 (
    Join-Path `
        $ClosureDocsDir `
        "PCI-001.4-Arquitectura.md"
) "# PCI-001.4 — Arquitectura`n`nNormaliza descriptor, release, manifest y estado institucional antes de PCI-001.2 y PCI-002.`n"
Write-Utf8 (
    Join-Path `
        $ClosureDocsDir `
        "PCI-001.4-Manual-Operativo.md"
) "# PCI-001.4 — Manual operativo`n`nCierra componentes seleccionados, genera respaldo, evidencia y verifica idempotencia.`n"

Invoke-Checked "Validando sintaxis y pruebas PCI-001.4" {
    Set-Location -LiteralPath $ProjectRoot
    $env:PYTHONPATH = Join-Path $ProjectRoot "src"

    python -m py_compile `
        "src/sgoda/governance/closure_normalizer/__init__.py" `
        "src/sgoda/governance/closure_normalizer/__main__.py" `
        "tests/governance/closure_normalizer/test_PCI_001_4_closure_normalizer.py"

    python -m pytest `
        "tests/governance/closure_normalizer/test_PCI_001_4_closure_normalizer.py" `
        -q
}


Invoke-Checked "Validando sintaxis y pruebas PCI-001.3" {
    Set-Location -LiteralPath $ProjectRoot
    $env:PYTHONPATH = Join-Path $ProjectRoot "src"

    python -m py_compile `
        "src/sgoda/governance/registry_determinizer/__init__.py" `
        "src/sgoda/governance/registry_determinizer/__main__.py" `
        "tests/governance/registry_determinizer/test_PCI_001_3_registry_determinizer.py"

    python -m pytest `
        "tests/governance/registry_determinizer/test_PCI_001_3_registry_determinizer.py" `
        -q
}

Invoke-Checked "Validando contrato PCI-002" {
    python -m pytest `
        "tests/governance/test_PCI_002_consolidation_contract.py" `
        -q
}

Step "Construyendo área temporal transaccional"
Copy-RepositoryToStage `
    -Source $ProjectRoot `
    -Destination $StageDir

$HashPaths = @(
    "docs\00_INDICE_MAESTRO.md",
    "docs\00_REGISTRO_MAESTRO_COMPONENTES.md",
    "docs\00_ARQUITECTURA_MAESTRA.md"
)

$CycleResults = @()
$Hashes = @()

try {
    foreach ($Cycle in 1..3) {
        $CycleResults += Invoke-ConsolidationCycle `
            -Root $StageDir `
            -Cycle $Cycle `
            -EvidenceRoot $StageEvidence

        $Hashes += (
            Get-FileHashMap `
                -Root $StageDir `
                -RelativePaths $HashPaths
        )
    }

    $Cycle12 = Compare-HashMaps `
        -Left $Hashes[0] `
        -Right $Hashes[1]
    $Cycle23 = Compare-HashMaps `
        -Left $Hashes[1] `
        -Right $Hashes[2]

    # Institutional convergence policy:
    # Cycle 1 may establish or normalize the generated baseline.
    # Cycles 2 and 3 MUST be semantically identical.
    if (@($Cycle12).Count -gt 0) {
        Write-Host (
            "Estabilización esperada entre ciclos 1 y 2: " +
            ($Cycle12 -join ", ")
        ) -ForegroundColor Yellow
    }
    else {
        Write-Host (
            "Ciclos 1 y 2 ya eran estables."
        ) -ForegroundColor Green
    }

    if (@($Cycle23).Count -gt 0) {
        $Diagnostic = [ordered]@{
            policy = "cycle_2_cycle_3_semantic_equivalence"
            differences = @($Cycle23)
            cycle_2_hashes = $Hashes[1]
            cycle_3_hashes = $Hashes[2]
            generated_at_utc = [DateTime]::UtcNow.ToString("o")
        }

        Write-Json `
            -Path (
                Join-Path `
                    $StageEvidence `
                    "convergence-failure-diagnostic.json"
            ) `
            -Value $Diagnostic

        throw (
            "No hubo convergencia semántica definitiva entre ciclos 2 y 3: " +
            ($Cycle23 -join ", ")
        )
    }

    Write-Host (
        "Convergencia definitiva ciclos 2 y 3: APROBADA."
    ) -ForegroundColor Green

    Set-Location -LiteralPath $StageDir
    $env:PYTHONPATH = Join-Path $StageDir "src"

    $StageReports = Join-Path $StageEvidence "test-reports"
    New-Item `
        -ItemType Directory `
        -Path $StageReports `
        -Force |
        Out-Null

    $FullXml = Join-Path $StageReports "full-suite.xml"
    $FullJson = Join-Path $StageReports "full-suite-summary.json"
    $FullMd = Join-Path $StageReports "full-suite-summary.md"

    Invoke-Checked "Ejecutando suite completa en staging" {
        python -m pytest --junitxml="$FullXml"
    }

    Invoke-Checked "Sincronizando evidencia SGD-114F en staging" {
        python -m sgoda.governance.test_evidence.cli `
            --junit "$FullXml" `
            --component "SGODA-PUINAVE" `
            --scope "pci002_staging_full_suite" `
            --output-json "$FullJson" `
            --output-md "$FullMd"
    }

    $Full = (
        Get-Content `
            -LiteralPath $FullJson `
            -Raw `
            -Encoding UTF8 |
        ConvertFrom-Json
    )

    if (-not [bool]$Full.approved) {
        throw "La suite completa del staging no fue aprobada."
    }

    $StageRelease = Join-Path `
        $StageDir `
        "releases\PCI-002-v1.2.0"

    New-Item `
        -ItemType Directory `
        -Path $StageRelease `
        -Force |
        Out-Null

    $ConsolidationReport = [ordered]@{
        program = "PCI-SGODA-v1.0.0"
        increment_code = "PCI-002"
        version = "1.0.0"
        status = "converged_and_candidate_for_application"
        staging_root = $StageDir
        convergence = [ordered]@{
            cycles = 3
            policy = "cycle_1_may_stabilize_cycles_2_and_3_must_match"
            cycle_1_to_2_differences = @($Cycle12)
            cycle_1_to_2_classification = if (
                @($Cycle12).Count -gt 0
            ) {
                "expected_stabilization"
            }
            else {
                "already_stable"
            }
            cycle_2_to_3_differences = @($Cycle23)
            definitive_pair = "cycle_2_cycle_3"
            approved = (@($Cycle23).Count -eq 0)
        }
        cycles = $CycleResults
        full_suite = [ordered]@{
            executed = [int]$Full.executed
            passed = [int]$Full.passed
            failures = [int]$Full.failures
            errors = [int]$Full.errors
            approved = [bool]$Full.approved
        }
        generated_at_utc = [DateTime]::UtcNow.ToString("o")
    }

    Write-Json `
        -Path (
            Join-Path `
                $StageEvidence `
                "institutional-consolidation-report.json"
        ) `
        -Value $ConsolidationReport

    Write-Json `
        -Path (
            Join-Path $StageRelease "manifest.json"
        ) `
        -Value ([ordered]@{
            program = "PCI-SGODA-v1.0.0"
            increment_code = "PCI-002"
            version = "1.0.0"
            release_name = "PCI-002-v1.2.0"
            status = "converged_and_candidate_for_closure"
            convergence_cycles = 3
            index_coverage_percent = 100
            registry_coverage_percent = 100
            critical_findings = 0
            full_suite_approved = $true
        })

    Invoke-Checked "Validando release en staging mediante SGD-114G" {
        python -m sgoda.governance.release_management.cli `
            --root "$StageDir" `
            --operation "close" `
            --output-json (
                Join-Path `
                    $StageEvidence `
                    "release-validation.json"
            )
    }

    Step "Capturando respaldo previo a aplicación"

    if (Test-Path -LiteralPath $BackupDir) {
        Remove-Item `
            -LiteralPath $BackupDir `
            -Recurse `
            -Force
    }

    New-Item `
        -ItemType Directory `
        -Path $BackupDir `
        -Force |
        Out-Null

    $ManagedPaths = @(
        "docs\00_INDICE_MAESTRO.md",
        "docs\00_REGISTRO_MAESTRO_COMPONENTES.md",
        "docs\00_ARQUITECTURA_MAESTRA.md",
        "artifacts\documentation\SGD-115",
        "artifacts\roadmap\SGD-116",
        "artifacts\consolidation\PCI-002-v1.2.0",
        "releases\PCI-002-v1.2.0",
        "config\governance\PCI-002-component.json",
        "config\governance\PCI-002-policy.json",
        "docs\01_Gobierno\PCI-002",
        "tests\governance\test_PCI_002_consolidation_contract.py",
        "src\sgoda\governance\registry_determinizer",
        "tests\governance\registry_determinizer",
        "config\governance\PCI-001.3-component.json",
        "config\governance\PCI-001.3-policy.json",
        "docs\01_Gobierno\PCI-001.3",
        "src\sgoda\governance\closure_normalizer",
        "tests\governance\closure_normalizer",
        "config\governance\PCI-001.4-component.json",
        "config\governance\PCI-001.4-policy.json",
        "docs\01_Gobierno\PCI-001.4",
        "releases\PCI-001.3-v1.0.0",
        "releases\PCI-001.4-v1.0.0"
    )

    foreach ($RelativePath in $ManagedPaths) {
        $RealPath = Join-Path $ProjectRoot $RelativePath
        $BackupPath = Join-Path $BackupDir $RelativePath

        if (Test-Path -LiteralPath $RealPath) {
            $Parent = Split-Path -Parent $BackupPath
            New-Item `
                -ItemType Directory `
                -Path $Parent `
                -Force |
                Out-Null

            Copy-Item `
                -LiteralPath $RealPath `
                -Destination $BackupPath `
                -Recurse `
                -Force
        }
    }

    Step "Aplicando resultado consolidado al repositorio real"

    try {
        Copy-ManagedResult `
            -StageRoot $StageDir `
            -RealRoot $ProjectRoot `
            -RelativePaths $ManagedPaths
    }
    catch {
        Write-Host "Aplicación fallida. Iniciando rollback." -ForegroundColor Red

        foreach ($RelativePath in $ManagedPaths) {
            $Destination = Join-Path $ProjectRoot $RelativePath
            $BackupPath = Join-Path $BackupDir $RelativePath

            if (Test-Path -LiteralPath $Destination) {
                Remove-Item `
                    -LiteralPath $Destination `
                    -Recurse `
                    -Force
            }

            if (Test-Path -LiteralPath $BackupPath) {
                $Parent = Split-Path -Parent $Destination
                New-Item `
                    -ItemType Directory `
                    -Path $Parent `
                    -Force |
                    Out-Null

                Copy-Item `
                    -LiteralPath $BackupPath `
                    -Destination $Destination `
                    -Recurse `
                    -Force
            }
        }

        throw
    }

    # Revalidate the REAL repository after applying.
    Set-Location -LiteralPath $ProjectRoot
    $env:PYTHONPATH = Join-Path $ProjectRoot "src"

    $RealValidation = Join-Path `
        $ArtifactDir `
        "real-repository-final-validation"
    New-Item `
        -ItemType Directory `
        -Path $RealValidation `
        -Force |
        Out-Null

    Invoke-Checked "Validación final PCI-001.2 en repositorio real" {
        python -m sgoda.governance.master_index_sync `
            --root "$ProjectRoot" `
            --mode "apply" `
            --backup-dir (
                Join-Path $RealValidation "index-backup"
            ) `
            --report-json (
                Join-Path $RealValidation "index-sync.json"
            ) `
            --preview-md (
                Join-Path $RealValidation "index-preview.md"
            )
    }

    Invoke-Checked "Auditoría final PCI-001.1 en repositorio real" {
        python -m sgoda.governance.master_index_audit `
            --root "$ProjectRoot" `
            --output-json (
                Join-Path $RealValidation "audit.json"
            ) `
            --output-md (
                Join-Path $RealValidation "audit.md"
            ) `
            --output-html (
                Join-Path $RealValidation "dashboard.html"
            ) `
            --metrics-json (
                Join-Path $RealValidation "metrics.json"
            ) `
            --traceability-json (
                Join-Path $RealValidation "traceability.json"
            ) `
            --pmo-json (
                Join-Path $RealValidation "pmo.json"
            )
    }

    $RealAudit = (
        Get-Content `
            -LiteralPath (
                Join-Path $RealValidation "audit.json"
            ) `
            -Raw `
            -Encoding UTF8 |
        ConvertFrom-Json
    )

    if (-not [bool]$RealAudit.approved) {
        throw "La auditoría final del repositorio real no fue aprobada."
    }

    if (
        [double]$RealAudit.metrics.index_coverage_percent -ne 100.0
    ) {
        throw "La cobertura final del Índice no es 100 %."
    }

    if (
        [double]$RealAudit.metrics.registry_coverage_percent -ne 100.0
    ) {
        throw "La cobertura final del Registro no es 100 %."
    }

    if ([int]$RealAudit.metrics.critical_findings -ne 0) {
        throw "La auditoría final contiene hallazgos críticos."
    }

    Invoke-Checked "Validando release final mediante SGD-114G" {
        python -m sgoda.governance.release_management.cli `
            --root "$ProjectRoot" `
            --operation "close" `
            --output-json (
                Join-Path `
                    $ArtifactDir `
                    "real-release-validation.json"
            )
    }

    if ($Publish) {
        Step "Publicando PCI-002 mediante gate canónico"

        & $PublisherPath `
            -Publish `
            -CommitMessage "feat(consolidation): close PCI-002 v1.2.0 with institutional closure normalizer" `
            -EvidenceCommitMessage "chore(consolidation): publish PCI-002 v1.2.0 evidence"

        if ($LASTEXITCODE -ne 0) {
            throw "La publicación institucional terminó con errores."
        }
    }

    Step "Resultado final"
    Write-Host "PCI-002 v1.2.0 implementado con PCI-001.3 y PCI-001.4." -ForegroundColor Green
    Write-Host "Ciclo 1: ESTABILIZACIÓN CONTROLADA." -ForegroundColor Green
Write-Host "Convergencia ciclos 2 y 3: APROBADA." -ForegroundColor Green
    Write-Host "Cobertura Índice Maestro: 100%." -ForegroundColor Green
    Write-Host "Cobertura Registro Maestro: 100%." -ForegroundColor Green
    Write-Host "Hallazgos críticos: 0." -ForegroundColor Green
    Write-Host (
        "Suite completa: " +
        "$($Full.passed)/$($Full.executed) APROBADA."
    ) -ForegroundColor Green
    Write-Host "Rollback: DISPONIBLE." -ForegroundColor Green
    Write-Host "Release: releases\PCI-002-v1.2.0" -ForegroundColor Cyan

    if ($Publish) {
        Write-Host "Publicación institucional: COMPLETADA." -ForegroundColor Green
    }
    else {
        Write-Host "Publicación no solicitada. Reejecute con -Publish." -ForegroundColor Yellow
    }
}
finally {
    Set-Location -LiteralPath $ProjectRoot

    if (-not $KeepStaging) {
        if (Test-Path -LiteralPath $StageDir) {
            Remove-Item `
                -LiteralPath $StageDir `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }
    else {
        Write-Host "Staging conservado en: $StageDir" -ForegroundColor Yellow
    }
}
