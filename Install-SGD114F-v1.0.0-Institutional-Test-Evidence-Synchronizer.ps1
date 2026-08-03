<#
.SYNOPSIS
    Instala SGD-114F v1.0.0 — Institutional Test Evidence Synchronizer.

.DESCRIPTION
    Sincroniza la evidencia institucional con los resultados reales de pytest.

    Implementa:
      - ejecución de pytest con salida JUnit XML;
      - lectura compatible con formatos testsuite y testsuites;
      - conteo real de pruebas ejecutadas, aprobadas, fallidas,
        omitidas, errores y duración;
      - generación de evidencia JSON y Markdown;
      - actualización controlada de evidencias existentes;
      - corrección de la evidencia de SPT-015;
      - utilidad PowerShell reutilizable por futuros instaladores;
      - pruebas específicas y suite completa;
      - evaluación SGD-114D, SGD-114E, SGD-115 y SGD-116;
      - release y publicación condicionada mediante SPB-007.

.PARAMETER ProjectRoot
    Raíz del repositorio.

.PARAMETER SkipFullSuite
    Omite la suite completa. Impide publicar.

.PARAMETER Publish
    Publica mediante SPB-007 únicamente si todos los gates aprueban.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipFullSuite,
    [switch]$Publish
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($Publish -and $SkipFullSuite) {
    throw "No se permite publicar con -SkipFullSuite."
}

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

    Write-Utf8 `
        -Path $Path `
        -Content (($Value | ConvertTo-Json -Depth 100) + [Environment]::NewLine)
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

$SourceDir = Join-Path $ProjectRoot "src\sgoda\governance\test_evidence"
$TestsDir = Join-Path $ProjectRoot "tests\governance"
$ConfigDir = Join-Path $ProjectRoot "config\governance"
$DocsDir = Join-Path $ProjectRoot "docs\01_Gobierno"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SGD-114F"
$ReportsDir = Join-Path $PmoDir "test-reports"
$ReleaseDir = Join-Path $ProjectRoot "releases\SGD-114F-v1.0.0"
$ScriptsDir = Join-Path $ProjectRoot "scripts"

$BackupDir = Join-Path `
    $PmoDir `
    ("backups\pre-SGD114F-" + (Get-Date -Format "yyyyMMdd-HHmmss"))

$ModelsPath = Join-Path $SourceDir "models.py"
$ParserPath = Join-Path $SourceDir "junit_parser.py"
$SynchronizerPath = Join-Path $SourceDir "synchronizer.py"
$CliPath = Join-Path $SourceDir "cli.py"
$InitPath = Join-Path $SourceDir "__init__.py"

$TestPath = Join-Path `
    $TestsDir `
    "test_SGD_114F_institutional_test_evidence_synchronizer.py"

$ComponentPath = Join-Path `
    $ConfigDir `
    "SGD-114F-component.json"

$PolicyPath = Join-Path `
    $ConfigDir `
    "SGD-114F-policy.json"

$InvokePath = Join-Path `
    $ScriptsDir `
    "Invoke-SGD114F-TestEvidenceSynchronizer.ps1"

$ReusableRunnerPath = Join-Path `
    $ScriptsDir `
    "Invoke-InstitutionalPytest.ps1"

$DocPath = Join-Path `
    $DocsDir `
    "SGD-114F-Institutional-Test-Evidence-Synchronizer.md"

$MigrationPath = Join-Path `
    $DocsDir `
    "SGD-114F-Migracion-Instaladores.md"

$SpecificXml = Join-Path $ReportsDir "SGD-114F-specific.xml"
$FullXml = Join-Path $ReportsDir "SGD-114F-full-suite.xml"
$SpecificJson = Join-Path $ReportsDir "SGD-114F-specific-summary.json"
$SpecificMd = Join-Path $ReportsDir "SGD-114F-specific-summary.md"
$FullJson = Join-Path $ReportsDir "SGD-114F-full-suite-summary.json"
$FullMd = Join-Path $ReportsDir "SGD-114F-full-suite-summary.md"

$EvidencePath = Join-Path `
    $PmoDir `
    "SGD-114F-implementation-evidence.json"

$Spt015EvidencePath = Join-Path `
    $ProjectRoot `
    "artifacts\pmo\SPT-015\SPT-015-implementation-evidence.json"

$Spt015Xml = Join-Path $ReportsDir "SPT-015-specific.xml"
$Spt015SummaryJson = Join-Path $ReportsDir "SPT-015-specific-summary.json"
$Spt015SummaryMd = Join-Path $ReportsDir "SPT-015-specific-summary.md"

$PolicyJson = Join-Path $PmoDir "SGD-114F-policy-result.json"
$PolicyMd = Join-Path $PmoDir "SGD-114F-policy-result.md"
$NativeJson = Join-Path $PmoDir "SGD-114F-native-result.json"
$NativeMd = Join-Path $PmoDir "SGD-114F-native-result.md"

Write-Step "Validando línea base institucional"

foreach ($Required in @(
    (Join-Path $ProjectRoot "pytest.ini"),
    (Join-Path $ProjectRoot "tests\adaptive_assessment\test_SPT_015_adaptive_assessment_engine.py"),
    $Spt015EvidencePath,
    (Join-Path $ProjectRoot "src\sgoda\governance\adaptive_policy_cli.py"),
    (Join-Path $ProjectRoot "src\sgoda\governance\native_ecosystem_cli.py"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py"),
    (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1")
)) {
    Require-File -Path $Required
}

Write-Step "Creando respaldo institucional"

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReportsDir -Force | Out-Null

foreach ($Affected in @(
    $ModelsPath,
    $ParserPath,
    $SynchronizerPath,
    $CliPath,
    $InitPath,
    $TestPath,
    $ComponentPath,
    $PolicyPath,
    $InvokePath,
    $ReusableRunnerPath,
    $DocPath,
    $MigrationPath,
    $Spt015EvidencePath
)) {
    Backup-File `
        -Source $Affected `
        -BackupDirectory $BackupDir `
        -Root $ProjectRoot
}

$Models = @'
"""Modelos de evidencia de pruebas de SGD-114F."""

from __future__ import annotations

from dataclasses import dataclass, asdict
from typing import Any


@dataclass(frozen=True, slots=True)
class TestEvidenceSummary:
    component: str
    scope: str
    executed: int
    passed: int
    failures: int
    errors: int
    skipped: int
    duration_seconds: float
    approved: bool
    source_report: str

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)
'@

$Parser = @'
"""Lector robusto de reportes JUnit XML."""

from __future__ import annotations

from pathlib import Path
from xml.etree import ElementTree

from .models import TestEvidenceSummary


def _integer(value: str | None) -> int:
    try:
        return int(float(value or "0"))
    except (TypeError, ValueError):
        return 0


def _decimal(value: str | None) -> float:
    try:
        return float(value or "0")
    except (TypeError, ValueError):
        return 0.0


def parse_junit_report(
    path: str | Path,
    *,
    component: str,
    scope: str,
) -> TestEvidenceSummary:
    report = Path(path)
    root = ElementTree.parse(report).getroot()

    suites = (
        [root]
        if root.tag == "testsuite"
        else list(root.findall("testsuite"))
    )

    if not suites:
        suites = list(root.findall(".//testsuite"))

    executed = sum(
        _integer(suite.attrib.get("tests"))
        for suite in suites
    )
    failures = sum(
        _integer(suite.attrib.get("failures"))
        for suite in suites
    )
    errors = sum(
        _integer(suite.attrib.get("errors"))
        for suite in suites
    )
    skipped = sum(
        _integer(
            suite.attrib.get("skipped")
            or suite.attrib.get("disabled")
        )
        for suite in suites
    )
    duration = round(
        sum(
            _decimal(suite.attrib.get("time"))
            for suite in suites
        ),
        4,
    )

    passed = max(
        executed - failures - errors - skipped,
        0,
    )
    approved = (
        executed > 0
        and failures == 0
        and errors == 0
    )

    return TestEvidenceSummary(
        component=component,
        scope=scope,
        executed=executed,
        passed=passed,
        failures=failures,
        errors=errors,
        skipped=skipped,
        duration_seconds=duration,
        approved=approved,
        source_report=str(report),
    )
'@

$Synchronizer = @'
"""Sincronización de evidencias institucionales."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .models import TestEvidenceSummary


def write_summary(
    summary: TestEvidenceSummary,
    json_path: str | Path,
    markdown_path: str | Path,
) -> None:
    json_target = Path(json_path)
    markdown_target = Path(markdown_path)
    json_target.parent.mkdir(parents=True, exist_ok=True)
    markdown_target.parent.mkdir(parents=True, exist_ok=True)

    json_target.write_text(
        json.dumps(
            summary.to_dict(),
            indent=2,
            ensure_ascii=False,
        ) + "\n",
        encoding="utf-8",
    )

    markdown_target.write_text(
        "\n".join(
            [
                f"# Evidencia de pruebas — {summary.component}",
                "",
                f"- Alcance: {summary.scope}",
                f"- Ejecutadas: {summary.executed}",
                f"- Aprobadas: {summary.passed}",
                f"- Fallidas: {summary.failures}",
                f"- Errores: {summary.errors}",
                f"- Omitidas: {summary.skipped}",
                (
                    "- Duración: "
                    f"{summary.duration_seconds:.4f} segundos"
                ),
                (
                    "- Resultado: "
                    + ("APROBADO" if summary.approved else "NO APROBADO")
                ),
                f"- Fuente: `{summary.source_report}`",
                "",
            ]
        ),
        encoding="utf-8",
    )


def synchronize_evidence_file(
    evidence_path: str | Path,
    summary: TestEvidenceSummary,
    *,
    evidence_key: str = "specific_tests",
) -> dict[str, Any]:
    target = Path(evidence_path)

    if target.exists():
        payload = json.loads(
            target.read_text(encoding="utf-8-sig")
        )
    else:
        payload = {}

    payload[evidence_key] = {
        "executed": summary.executed,
        "passed": summary.passed,
        "failures": summary.failures,
        "errors": summary.errors,
        "skipped": summary.skipped,
        "duration_seconds": summary.duration_seconds,
        "approved": summary.approved,
        "source_report": summary.source_report,
    }
    payload[
        f"{evidence_key}_count"
    ] = summary.executed
    payload[
        f"{evidence_key}_passed"
    ] = summary.passed
    payload[
        f"{evidence_key}_synchronized"
    ] = True

    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(
        json.dumps(
            payload,
            indent=2,
            ensure_ascii=False,
        ) + "\n",
        encoding="utf-8",
    )

    return payload
'@

$Cli = @'
"""CLI de SGD-114F."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .junit_parser import parse_junit_report
from .synchronizer import (
    synchronize_evidence_file,
    write_summary,
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--junit", required=True)
    parser.add_argument("--component", required=True)
    parser.add_argument("--scope", required=True)
    parser.add_argument("--output-json", required=True)
    parser.add_argument("--output-md", required=True)
    parser.add_argument("--evidence")
    parser.add_argument(
        "--evidence-key",
        default="specific_tests",
    )
    args = parser.parse_args()

    summary = parse_junit_report(
        args.junit,
        component=args.component,
        scope=args.scope,
    )
    write_summary(
        summary,
        args.output_json,
        args.output_md,
    )

    if args.evidence:
        synchronize_evidence_file(
            args.evidence,
            summary,
            evidence_key=args.evidence_key,
        )

    print("SGD-114F ejecutado correctamente.")
    print(f"Componente: {summary.component}")
    print(f"Alcance: {summary.scope}")
    print(f"Ejecutadas: {summary.executed}")
    print(f"Aprobadas: {summary.passed}")
    print(f"Fallidas: {summary.failures}")
    print(f"Errores: {summary.errors}")
    print(f"Omitidas: {summary.skipped}")
    print(f"Resultado: {'APROBADO' if summary.approved else 'NO APROBADO'}")
    print(f"JSON: {Path(args.output_json)}")
    print(f"Markdown: {Path(args.output_md)}")

    return 0 if summary.approved else 2


if __name__ == "__main__":
    raise SystemExit(main())
'@

$Init = @'
"""SGD-114F — Institutional Test Evidence Synchronizer."""

from .junit_parser import parse_junit_report
from .models import TestEvidenceSummary
from .synchronizer import (
    synchronize_evidence_file,
    write_summary,
)

__all__ = [
    "TestEvidenceSummary",
    "parse_junit_report",
    "synchronize_evidence_file",
    "write_summary",
]
'@

$Tests = @'
from __future__ import annotations

import json
from pathlib import Path

from sgoda.governance.test_evidence import (
    parse_junit_report,
    synchronize_evidence_file,
    write_summary,
)


def _write_xml(
    path: Path,
    *,
    tests: int = 21,
    failures: int = 0,
    errors: int = 0,
    skipped: int = 0,
    time: float = 1.25,
) -> None:
    path.write_text(
        (
            '<testsuites>'
            f'<testsuite tests="{tests}" '
            f'failures="{failures}" '
            f'errors="{errors}" '
            f'skipped="{skipped}" '
            f'time="{time}">'
            '</testsuite>'
            '</testsuites>'
        ),
        encoding="utf-8",
    )


def test_SGD_114F_parses_executed_count(
    tmp_path: Path,
) -> None:
    xml = tmp_path / "result.xml"
    _write_xml(xml)

    summary = parse_junit_report(
        xml,
        component="SPT-015",
        scope="specific",
    )

    assert summary.executed == 21


def test_SGD_114F_calculates_passed_count(
    tmp_path: Path,
) -> None:
    xml = tmp_path / "result.xml"
    _write_xml(xml, tests=21, skipped=1)

    summary = parse_junit_report(
        xml,
        component="SPT-015",
        scope="specific",
    )

    assert summary.passed == 20


def test_SGD_114F_detects_failures(
    tmp_path: Path,
) -> None:
    xml = tmp_path / "result.xml"
    _write_xml(xml, failures=1)

    summary = parse_junit_report(
        xml,
        component="SPT-015",
        scope="specific",
    )

    assert summary.failures == 1
    assert summary.approved is False


def test_SGD_114F_detects_errors(
    tmp_path: Path,
) -> None:
    xml = tmp_path / "result.xml"
    _write_xml(xml, errors=1)

    summary = parse_junit_report(
        xml,
        component="SPT-015",
        scope="specific",
    )

    assert summary.errors == 1
    assert summary.approved is False


def test_SGD_114F_preserves_duration(
    tmp_path: Path,
) -> None:
    xml = tmp_path / "result.xml"
    _write_xml(xml, time=2.75)

    summary = parse_junit_report(
        xml,
        component="SPT-015",
        scope="specific",
    )

    assert summary.duration_seconds == 2.75


def test_SGD_114F_approves_clean_report(
    tmp_path: Path,
) -> None:
    xml = tmp_path / "result.xml"
    _write_xml(xml)

    summary = parse_junit_report(
        xml,
        component="SPT-015",
        scope="specific",
    )

    assert summary.approved is True


def test_SGD_114F_writes_json_summary(
    tmp_path: Path,
) -> None:
    xml = tmp_path / "result.xml"
    json_path = tmp_path / "summary.json"
    md_path = tmp_path / "summary.md"
    _write_xml(xml)

    summary = parse_junit_report(
        xml,
        component="SPT-015",
        scope="specific",
    )
    write_summary(summary, json_path, md_path)

    payload = json.loads(
        json_path.read_text(encoding="utf-8")
    )

    assert payload["executed"] == 21


def test_SGD_114F_writes_markdown_summary(
    tmp_path: Path,
) -> None:
    xml = tmp_path / "result.xml"
    json_path = tmp_path / "summary.json"
    md_path = tmp_path / "summary.md"
    _write_xml(xml)

    summary = parse_junit_report(
        xml,
        component="SPT-015",
        scope="specific",
    )
    write_summary(summary, json_path, md_path)

    text = md_path.read_text(encoding="utf-8")

    assert "Ejecutadas: 21" in text
    assert "Resultado: APROBADO" in text


def test_SGD_114F_updates_existing_evidence(
    tmp_path: Path,
) -> None:
    xml = tmp_path / "result.xml"
    evidence = tmp_path / "evidence.json"
    evidence.write_text(
        json.dumps(
            {
                "increment_code": "SPT-015",
                "specific_tests": 20,
            }
        ),
        encoding="utf-8",
    )
    _write_xml(xml)

    summary = parse_junit_report(
        xml,
        component="SPT-015",
        scope="specific",
    )
    synchronize_evidence_file(
        evidence,
        summary,
    )

    payload = json.loads(
        evidence.read_text(encoding="utf-8")
    )

    assert payload["increment_code"] == "SPT-015"
    assert payload["specific_tests"]["executed"] == 21


def test_SGD_114F_adds_compatibility_count(
    tmp_path: Path,
) -> None:
    xml = tmp_path / "result.xml"
    evidence = tmp_path / "evidence.json"
    _write_xml(xml)

    summary = parse_junit_report(
        xml,
        component="SPT-015",
        scope="specific",
    )
    synchronize_evidence_file(
        evidence,
        summary,
    )

    payload = json.loads(
        evidence.read_text(encoding="utf-8")
    )

    assert payload["specific_tests_count"] == 21


def test_SGD_114F_supports_single_testsuite(
    tmp_path: Path,
) -> None:
    xml = tmp_path / "result.xml"
    xml.write_text(
        (
            '<testsuite tests="3" failures="0" '
            'errors="0" skipped="0" time="0.4">'
            '</testsuite>'
        ),
        encoding="utf-8",
    )

    summary = parse_junit_report(
        xml,
        component="TEST",
        scope="specific",
    )

    assert summary.executed == 3
    assert summary.passed == 3


def test_SGD_114F_aggregates_multiple_suites(
    tmp_path: Path,
) -> None:
    xml = tmp_path / "result.xml"
    xml.write_text(
        (
            '<testsuites>'
            '<testsuite tests="2" failures="0" '
            'errors="0" skipped="0" time="0.2"/>'
            '<testsuite tests="3" failures="0" '
            'errors="0" skipped="1" time="0.3"/>'
            '</testsuites>'
        ),
        encoding="utf-8",
    )

    summary = parse_junit_report(
        xml,
        component="TEST",
        scope="full",
    )

    assert summary.executed == 5
    assert summary.passed == 4
    assert summary.skipped == 1
    assert summary.duration_seconds == 0.5
'@

$Component = @'
{
  "increment_code": "SGD-114F",
  "name": "Institutional Test Evidence Synchronizer",
  "component_type": "institutional_test_evidence_synchronizer",
  "version": "1.0.0",
  "status": "implemented",
  "phase": "Gobierno Digital",
  "native_ecosystem": true,
  "ecosystem_role": "native_component",
  "technology_policy": "free_open_optional_proprietary",
  "mandatory_proprietary_dependencies": [],
  "dependencies": [
    "SGD-114D",
    "SGD-114E",
    "SGD-115A",
    "SGD-116",
    "SPB-007"
  ],
  "source": [
    "src/sgoda/governance/test_evidence/models.py",
    "src/sgoda/governance/test_evidence/junit_parser.py",
    "src/sgoda/governance/test_evidence/synchronizer.py",
    "src/sgoda/governance/test_evidence/cli.py"
  ],
  "tests": [
    "tests/governance/test_SGD_114F_institutional_test_evidence_synchronizer.py"
  ],
  "documentation": [
    "docs/01_Gobierno/SGD-114F-Institutional-Test-Evidence-Synchronizer.md",
    "docs/01_Gobierno/SGD-114F-Migracion-Instaladores.md"
  ]
}
'@

$Policy = @'
{
  "component": "SGD-114F",
  "version": "1.0.0",
  "source_of_truth": "pytest_junit_xml",
  "manual_test_counts_forbidden": true,
  "required_metrics": [
    "executed",
    "passed",
    "failures",
    "errors",
    "skipped",
    "duration_seconds",
    "approved"
  ],
  "publication_requires_approved_tests": true,
  "mandatory_proprietary_dependencies": []
}
'@

$ReusableRunner = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Component,

    [Parameter(Mandatory = $true)]
    [string]$TestPath,

    [Parameter(Mandatory = $true)]
    [string]$ReportPath,

    [Parameter(Mandatory = $true)]
    [string]$SummaryJson,

    [Parameter(Mandatory = $true)]
    [string]$SummaryMarkdown,

    [string]$Scope = "specific",

    [string]$EvidencePath,

    [string]$EvidenceKey = "specific_tests"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

$ReportParent = Split-Path -Parent $ReportPath
if ($ReportParent) {
    New-Item -ItemType Directory -Path $ReportParent -Force | Out-Null
}

& python -m pytest `
    "$TestPath" `
    --junitxml="$ReportPath" `
    -q

if ($LASTEXITCODE -ne 0) {
    throw "pytest terminó con errores. Código: $LASTEXITCODE"
}

$Arguments = @(
    "-m",
    "sgoda.governance.test_evidence.cli",
    "--junit",
    $ReportPath,
    "--component",
    $Component,
    "--scope",
    $Scope,
    "--output-json",
    $SummaryJson,
    "--output-md",
    $SummaryMarkdown,
    "--evidence-key",
    $EvidenceKey
)

if ($EvidencePath) {
    $Arguments += @(
        "--evidence",
        $EvidencePath
    )
}

& python @Arguments

exit $LASTEXITCODE
'@

$Invoke = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Junit,

    [Parameter(Mandatory = $true)]
    [string]$Component,

    [Parameter(Mandatory = $true)]
    [string]$Scope,

    [Parameter(Mandatory = $true)]
    [string]$OutputJson,

    [Parameter(Mandatory = $true)]
    [string]$OutputMarkdown,

    [string]$Evidence,

    [string]$EvidenceKey = "specific_tests"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

$Arguments = @(
    "-m",
    "sgoda.governance.test_evidence.cli",
    "--junit",
    $Junit,
    "--component",
    $Component,
    "--scope",
    $Scope,
    "--output-json",
    $OutputJson,
    "--output-md",
    $OutputMarkdown,
    "--evidence-key",
    $EvidenceKey
)

if ($Evidence) {
    $Arguments += @(
        "--evidence",
        $Evidence
    )
}

& python @Arguments

exit $LASTEXITCODE
'@

$Doc = @'
# SGD-114F — Institutional Test Evidence Synchronizer

SGD-114F establece los reportes JUnit XML producidos por pytest como fuente
oficial de verdad para las métricas de pruebas.

El sincronizador registra:

- pruebas ejecutadas;
- pruebas aprobadas;
- fallos;
- errores;
- pruebas omitidas;
- duración;
- resultado institucional.

Los instaladores futuros deben usar `Invoke-InstitutionalPytest.ps1` y no
deben escribir manualmente cantidades de pruebas.
'@

$Migration = @'
# SGD-114F — Migración de instaladores

## Regla anterior

Los instaladores incluían textos fijos como:

`Pruebas específicas: 20 APROBADAS.`

## Regla institucional nueva

Cada instalador debe:

1. ejecutar pytest con `--junitxml`;
2. invocar SGD-114F;
3. leer el resumen JSON generado;
4. imprimir las métricas reales;
5. generar evidencias desde la misma fuente;
6. impedir la publicación si existen fallos o errores.

SPT-015 se sincroniza durante la instalación inicial de SGD-114F.
'@

Write-Step "Instalando SGD-114F"

Write-Utf8 -Path $ModelsPath -Content $Models
Write-Utf8 -Path $ParserPath -Content $Parser
Write-Utf8 -Path $SynchronizerPath -Content $Synchronizer
Write-Utf8 -Path $CliPath -Content $Cli
Write-Utf8 -Path $InitPath -Content $Init
Write-Utf8 -Path $TestPath -Content $Tests
Write-Utf8 -Path $ComponentPath -Content $Component
Write-Utf8 -Path $PolicyPath -Content $Policy
Write-Utf8 -Path $ReusableRunnerPath -Content $ReusableRunner
Write-Utf8 -Path $InvokePath -Content $Invoke
Write-Utf8 -Path $DocPath -Content $Doc
Write-Utf8 -Path $MigrationPath -Content $Migration

Invoke-Checked "Validando sintaxis Python" {
    python -m py_compile `
        "src/sgoda/governance/test_evidence/models.py" `
        "src/sgoda/governance/test_evidence/junit_parser.py" `
        "src/sgoda/governance/test_evidence/synchronizer.py" `
        "src/sgoda/governance/test_evidence/cli.py" `
        "src/sgoda/governance/test_evidence/__init__.py" `
        "tests/governance/test_SGD_114F_institutional_test_evidence_synchronizer.py"
}

Invoke-Checked "Ejecutando pruebas específicas SGD-114F con evidencia JUnit" {
    python -m pytest `
        "tests/governance/test_SGD_114F_institutional_test_evidence_synchronizer.py" `
        --junitxml="$SpecificXml" `
        -q
}

Invoke-Checked "Sincronizando evidencia específica SGD-114F" {
    python -m sgoda.governance.test_evidence.cli `
        --junit "$SpecificXml" `
        --component "SGD-114F" `
        --scope "specific" `
        --output-json "$SpecificJson" `
        --output-md "$SpecificMd"
}

$SpecificSummary = Get-Content `
    -LiteralPath $SpecificJson `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not [bool]$SpecificSummary.approved) {
    throw "Las pruebas específicas SGD-114F no fueron aprobadas."
}

Write-Step "Corrigiendo evidencia institucional de SPT-015"

Invoke-Checked "Reejecutando pruebas específicas reales de SPT-015" {
    python -m pytest `
        "tests/adaptive_assessment/test_SPT_015_adaptive_assessment_engine.py" `
        --junitxml="$Spt015Xml" `
        -q
}

Invoke-Checked "Sincronizando evidencia real de SPT-015" {
    python -m sgoda.governance.test_evidence.cli `
        --junit "$Spt015Xml" `
        --component "SPT-015" `
        --scope "specific" `
        --output-json "$Spt015SummaryJson" `
        --output-md "$Spt015SummaryMd" `
        --evidence "$Spt015EvidencePath" `
        --evidence-key "specific_tests"
}

$Spt015Summary = Get-Content `
    -LiteralPath $Spt015SummaryJson `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not [bool]$Spt015Summary.approved) {
    throw "La evidencia de SPT-015 no pudo aprobarse."
}

if ([int]$Spt015Summary.executed -ne 21) {
    throw (
        "Se esperaban 21 pruebas específicas reales para SPT-015, " +
        "pero pytest reportó $($Spt015Summary.executed)."
    )
}

if (-not $SkipFullSuite) {
    Invoke-Checked "Ejecutando suite completa con evidencia JUnit" {
        python -m pytest `
            --junitxml="$FullXml"
    }

    Invoke-Checked "Sincronizando evidencia de suite completa" {
        python -m sgoda.governance.test_evidence.cli `
            --junit "$FullXml" `
            --component "SGODA-PUINAVE" `
            --scope "full_suite" `
            --output-json "$FullJson" `
            --output-md "$FullMd"
    }

    $FullSummary = Get-Content `
        -LiteralPath $FullJson `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

    if (-not [bool]$FullSummary.approved) {
        throw "La suite completa no fue aprobada."
    }
}

Write-Step "Generando evidencia institucional y release"

New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

$FullExecuted = $null
$FullPassed = $null
$FullFailures = $null
$FullErrors = $null
$FullSkipped = $null
$FullDuration = $null
$FullApproved = $null

if (-not $SkipFullSuite) {
    $FullExecuted = [int]$FullSummary.executed
    $FullPassed = [int]$FullSummary.passed
    $FullFailures = [int]$FullSummary.failures
    $FullErrors = [int]$FullSummary.errors
    $FullSkipped = [int]$FullSummary.skipped
    $FullDuration = [double]$FullSummary.duration_seconds
    $FullApproved = [bool]$FullSummary.approved
}

Write-Json `
    -Path $EvidencePath `
    -Value ([ordered]@{
        increment_code = "SGD-114F"
        version = "1.0.0"
        status = "implemented_and_tested"
        generated_at_utc = [DateTime]::UtcNow.ToString("o")
        source_of_truth = "pytest_junit_xml"
        specific_tests = [ordered]@{
            executed = [int]$SpecificSummary.executed
            passed = [int]$SpecificSummary.passed
            failures = [int]$SpecificSummary.failures
            errors = [int]$SpecificSummary.errors
            skipped = [int]$SpecificSummary.skipped
            duration_seconds = [double]$SpecificSummary.duration_seconds
            approved = [bool]$SpecificSummary.approved
            report = $SpecificXml
        }
        spt_015_correction = [ordered]@{
            executed = [int]$Spt015Summary.executed
            passed = [int]$Spt015Summary.passed
            failures = [int]$Spt015Summary.failures
            errors = [int]$Spt015Summary.errors
            skipped = [int]$Spt015Summary.skipped
            duration_seconds = [double]$Spt015Summary.duration_seconds
            approved = [bool]$Spt015Summary.approved
            evidence = $Spt015EvidencePath
            report = $Spt015Xml
        }
        full_suite = [ordered]@{
            executed = $FullExecuted
            passed = $FullPassed
            failures = $FullFailures
            errors = $FullErrors
            skipped = $FullSkipped
            duration_seconds = $FullDuration
            approved = $FullApproved
            report = $FullXml
        }
        manual_test_counts_forbidden = $true
        reusable_runner = "scripts/Invoke-InstitutionalPytest.ps1"
        backup = $BackupDir
    })

foreach ($ReleaseFile in @(
    $ModelsPath,
    $ParserPath,
    $SynchronizerPath,
    $CliPath,
    $InitPath,
    $TestPath,
    $ComponentPath,
    $PolicyPath,
    $ReusableRunnerPath,
    $InvokePath,
    $DocPath,
    $MigrationPath,
    $SpecificXml,
    $SpecificJson,
    $SpecificMd,
    $Spt015Xml,
    $Spt015SummaryJson,
    $Spt015SummaryMd,
    $EvidencePath
)) {
    Require-File -Path $ReleaseFile

    Copy-Item `
        -LiteralPath $ReleaseFile `
        -Destination $ReleaseDir `
        -Force
}

if (-not $SkipFullSuite) {
    foreach ($FullReleaseFile in @(
        $FullXml,
        $FullJson,
        $FullMd
    )) {
        Require-File -Path $FullReleaseFile

        Copy-Item `
            -LiteralPath $FullReleaseFile `
            -Destination $ReleaseDir `
            -Force
    }
}

Write-Json `
    -Path (Join-Path $ReleaseDir "manifest.json") `
    -Value ([ordered]@{
        increment_code = "SGD-114F"
        version = "1.0.0"
        status = "implemented_and_tested"
        files = @(
            Get-ChildItem `
                -LiteralPath $ReleaseDir `
                -File |
            Select-Object -ExpandProperty Name
        )
    })

Write-Step "Evaluando SGD-114F mediante SGD-114D"

& python -m sgoda.governance.adaptive_policy_cli `
    --root "$ProjectRoot" `
    --increment "SGD-114F" `
    --output-json "$PolicyJson" `
    --output-md "$PolicyMd"

if ($LASTEXITCODE -ne 0) {
    throw "SGD-114D no aprobó SGD-114F."
}

Write-Step "Evaluando arquitectura nativa mediante SGD-114E"

& python -m sgoda.governance.native_ecosystem_cli `
    --root "$ProjectRoot" `
    --output-json "$NativeJson" `
    --output-md "$NativeMd"

if ($LASTEXITCODE -ne 0) {
    throw "SGD-114E no aprobó SGD-114F."
}

Invoke-Checked "Regenerando SGD-115" {
    python -m sgoda.documentation.master_docs `
        --root "$ProjectRoot" `
        --output "artifacts/documentation/SGD-115"
}

Invoke-Checked "Regenerando SGD-116" {
    python -m sgoda.roadmap.cli `
        --root "$ProjectRoot" `
        --output "artifacts/roadmap/SGD-116"
}

if ($Publish) {
    Write-Step "Publicando mediante SPB-007"

    & (Join-Path `
        $ProjectRoot `
        "scripts\Invoke-SPB007-InstitutionalPublish.ps1") `
        -Publish `
        -CommitMessage (
            "feat(governance): implement SGD-114F test evidence synchronizer"
        ) `
        -EvidenceCommitMessage (
            "chore(governance): publish SGD-114F synchronized evidence"
        )

    if ($LASTEXITCODE -ne 0) {
        throw "SPB-007 terminó con errores."
    }
}

Write-Step "Resultado final"

Write-Host "SGD-114F v1.0.0 implementado." -ForegroundColor Green
Write-Host "Institutional Test Evidence Synchronizer: OPERATIVO." `
    -ForegroundColor Green
Write-Host "Fuente oficial: PYTEST JUNIT XML." `
    -ForegroundColor Green
Write-Host (
    "Pruebas específicas SGD-114F: " +
    "$($SpecificSummary.passed)/$($SpecificSummary.executed) APROBADAS."
) -ForegroundColor Green
Write-Host (
    "Pruebas específicas SPT-015 sincronizadas: " +
    "$($Spt015Summary.passed)/$($Spt015Summary.executed) APROBADAS."
) -ForegroundColor Green

if (-not $SkipFullSuite) {
    Write-Host (
        "Suite completa sincronizada: " +
        "$($FullSummary.passed)/$($FullSummary.executed) APROBADAS."
    ) -ForegroundColor Green
}

Write-Host "Conteos manuales: PROHIBIDOS POR POLÍTICA." `
    -ForegroundColor Green
Write-Host "SGD-114D: APROBADO." -ForegroundColor Green
Write-Host "SGD-114E: APROBADO." -ForegroundColor Green
Write-Host "SGD-115: ACTUALIZADO." -ForegroundColor Green
Write-Host "SGD-116: ACTUALIZADO." -ForegroundColor Green
Write-Host "Release: releases\SGD-114F-v1.0.0" `
    -ForegroundColor Cyan
Write-Host "Evidencia: $EvidencePath" `
    -ForegroundColor Cyan
Write-Host "Respaldo: $BackupDir" `
    -ForegroundColor Cyan

if ($Publish) {
    Write-Host "SPB-007: PUBLICACIÓN COMPLETADA." `
        -ForegroundColor Green
}
else {
    Write-Host ""
    Write-Host (
        "Publicación no solicitada. Reejecute el instalador " +
        "con -Publish después de revisar el resultado."
    ) -ForegroundColor Yellow
}
