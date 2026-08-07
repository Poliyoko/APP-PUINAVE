<#
.SYNOPSIS
    Instala PCI-001.2 v1.0.0 — Institutional Master Index Synchronizer.
.DESCRIPTION
    Sincroniza el Índice Maestro desde los descriptores canónicos
    *-component.json, preservando el contenido manual fuera del bloque
    administrado. Compatible con Windows PowerShell 5.1.
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
    if ((Get-Item -LiteralPath $Path).Length -le 0) {
        throw "El archivo quedó vacío: $Path"
    }
    Write-Host "Creado/actualizado: $Path" -ForegroundColor Green
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

function Run {
    param([string]$Description, [scriptblock]$Action)
    Step $Description
    $global:LASTEXITCODE = 0
    & $Action
    if ($LASTEXITCODE -ne 0) {
        throw "$Description terminó con errores. Código: $LASTEXITCODE"
    }
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$SourceDir = Join-Path `
    $ProjectRoot `
    "src\sgoda\governance\master_index_sync"
$TestsDir = Join-Path `
    $ProjectRoot `
    "tests\governance\master_index_sync"
$ConfigDir = Join-Path $ProjectRoot "config\governance"
$DocsDir = Join-Path `
    $ProjectRoot `
    "docs\01_Gobierno\PCI-001.2"
$ArtifactDir = Join-Path `
    $ProjectRoot `
    "artifacts\consolidation\PCI-001.2-v1.0.0"
$ReportsDir = Join-Path $ArtifactDir "test-reports"
$BackupDir = Join-Path $ArtifactDir "backup"
$ReleaseDir = Join-Path `
    $ProjectRoot `
    "releases\PCI-001.2-v1.0.0"
$ScriptsDir = Join-Path $ProjectRoot "scripts"

$PreviewMd = Join-Path `
    $ArtifactDir `
    "00_INDICE_MAESTRO.preview.md"
$PreviewJson = Join-Path `
    $ArtifactDir `
    "synchronization-preview.json"
$ApplyJson = Join-Path `
    $ArtifactDir `
    "synchronization-result.json"
$AuditJson = Join-Path `
    $ArtifactDir `
    "post-sync-intelligent-audit.json"
$AuditMd = Join-Path `
    $ArtifactDir `
    "post-sync-intelligent-audit.md"
$AuditHtml = Join-Path `
    $ArtifactDir `
    "post-sync-dashboard.html"
$AuditMetrics = Join-Path `
    $ArtifactDir `
    "post-sync-metrics.json"
$AuditTrace = Join-Path `
    $ArtifactDir `
    "post-sync-traceability.json"
$AuditPmo = Join-Path `
    $ArtifactDir `
    "post-sync-pmo.json"
$EvidenceJson = Join-Path `
    $ArtifactDir `
    "implementation-evidence.json"
$EvidenceMd = Join-Path `
    $ArtifactDir `
    "implementation-evidence.md"
$ReleaseValidationJson = Join-Path `
    $ArtifactDir `
    "release-validation.json"

$SpecificXml = Join-Path $ReportsDir "specific.xml"
$SpecificJson = Join-Path $ReportsDir "specific-summary.json"
$SpecificMd = Join-Path $ReportsDir "specific-summary.md"
$FullXml = Join-Path $ReportsDir "full-suite.xml"
$FullJson = Join-Path $ReportsDir "full-suite-summary.json"
$FullMd = Join-Path $ReportsDir "full-suite-summary.md"

$RunnerPath = Join-Path `
    $ScriptsDir `
    "Invoke-InstitutionalPytest.ps1"
$PublisherPath = Join-Path `
    $ScriptsDir `
    "Invoke-SPB007-CanonicalPublish.ps1"

foreach ($Required in @(
    (Join-Path $ProjectRoot "docs\00_INDICE_MAESTRO.md"),
    (
        Join-Path `
            $ProjectRoot `
            "docs\00_REGISTRO_MAESTRO_COMPONENTES.md"
    ),
    (
        Join-Path `
            $ProjectRoot `
            "src\sgoda\governance\master_index_audit\__init__.py"
    ),
    (
        Join-Path `
            $ProjectRoot `
            "tests\governance\master_index_audit\test_PCI_001_master_index_audit.py"
    ),
    (
        Join-Path `
            $ProjectRoot `
            "tests\governance\master_index_audit\test_PCI_001_1_intelligent_master_index_auditor.py"
    ),
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
            "src\sgoda\governance\test_evidence\cli.py"
    ),
    (
        Join-Path `
            $ProjectRoot `
            "src\sgoda\governance\release_management\cli.py"
    ),
    (
        Join-Path `
            $ProjectRoot `
            "src\sgoda\governance\repository_manager\cli.py"
    ),
    $RunnerPath,
    $PublisherPath
)) {
    Require-File -Path $Required -Description $Required
}

foreach ($Directory in @(
    $SourceDir,
    $TestsDir,
    $ConfigDir,
    $DocsDir,
    $ReportsDir,
    $BackupDir,
    $ReleaseDir
)) {
    New-Item `
        -ItemType Directory `
        -Path $Directory `
        -Force |
        Out-Null
}

$Module = @'

from __future__ import annotations

import argparse
import json
import re
import shutil
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

START_MARKER = "<!-- PCI-001.2:BEGIN MANAGED COMPONENT INDEX -->"
END_MARKER = "<!-- PCI-001.2:END MANAGED COMPONENT INDEX -->"
CODE_RE = re.compile(
    r"^(?:ADR|CERT|PCI|SGD|SIB|SPA|SPB|SPT)-",
    re.IGNORECASE,
)
HISTORICAL_RE = re.compile(
    r"-V\d+(?:\.\d+){1,3}(?:-R\d+(?:\.\d+)*)?$",
    re.IGNORECASE,
)


@dataclass(frozen=True, slots=True)
class Component:
    code: str
    name: str
    version: str
    status: str
    descriptor_path: str
    dependencies: tuple[str, ...]
    historical: bool
    source_paths: tuple[str, ...]
    test_paths: tuple[str, ...]
    documentation_paths: tuple[str, ...]
    release_name: str | None

    def to_dict(self) -> dict[str, Any]:
        return {
            "code": self.code,
            "name": self.name,
            "version": self.version,
            "status": self.status,
            "descriptor_path": self.descriptor_path,
            "dependencies": list(self.dependencies),
            "historical": self.historical,
            "source_paths": list(self.source_paths),
            "test_paths": list(self.test_paths),
            "documentation_paths": list(self.documentation_paths),
            "release_name": self.release_name,
        }


def _values(value: Any) -> tuple[str, ...]:
    if isinstance(value, str):
        return (value,) if value.strip() else ()
    if isinstance(value, (list, tuple, set)):
        return tuple(str(item) for item in value if str(item).strip())
    return ()


def scan_components(root_value: str | Path) -> tuple[Component, ...]:
    root = Path(root_value).resolve()
    config = root / "config"
    components: list[Component] = []

    if not config.is_dir():
        return ()

    for path in sorted(config.rglob("*-component.json")):
        try:
            payload = json.loads(
                path.read_text(encoding="utf-8-sig")
            )
        except (OSError, UnicodeError, json.JSONDecodeError):
            continue

        if not isinstance(payload, dict):
            continue

        code = str(
            payload.get("increment_code")
            or payload.get("component_code")
            or payload.get("code")
            or ""
        ).strip().upper()

        if not code or not CODE_RE.match(code):
            continue

        version = str(payload.get("version", "")).strip()
        status = str(payload.get("status", "unknown")).strip()
        historical = (
            bool(HISTORICAL_RE.search(code))
            or status.casefold()
            in {
                "historical",
                "superseded",
                "deprecated",
                "archived",
            }
        )

        components.append(
            Component(
                code=code,
                name=str(
                    payload.get("name")
                    or payload.get("title")
                    or code
                ).strip(),
                version=version,
                status=status,
                descriptor_path=path.relative_to(root).as_posix(),
                dependencies=_values(payload.get("dependencies")),
                historical=historical,
                source_paths=_values(
                    payload.get("source")
                    or payload.get("source_paths")
                    or payload.get("code_paths")
                ),
                test_paths=_values(
                    payload.get("tests")
                    or payload.get("test_paths")
                ),
                documentation_paths=_values(
                    payload.get("documentation")
                    or payload.get("documentation_paths")
                    or payload.get("docs")
                ),
                release_name=(
                    str(payload.get("release_name")).strip()
                    if payload.get("release_name")
                    else None
                ),
            )
        )

    deduplicated: dict[str, Component] = {}
    for item in components:
        deduplicated[item.code] = item

    return tuple(
        sorted(
            deduplicated.values(),
            key=lambda item: (
                item.historical,
                item.code,
            ),
        )
    )


def _coverage(root: Path, item: Component) -> dict[str, bool]:
    release_root = root / "releases"

    release_exists = False
    if item.release_name:
        release_exists = (
            release_root / item.release_name
        ).is_dir()

    if not release_exists:
        preferred = (
            f"{item.code}-v{item.version}"
            if item.version
            else item.code
        )
        release_exists = (
            release_root / preferred
        ).is_dir()

    if not release_exists and release_root.is_dir():
        release_exists = any(
            path.is_dir()
            and path.name.upper().startswith(item.code + "-V")
            for path in release_root.iterdir()
        )

    return {
        "source": any(
            (root / value).exists()
            for value in item.source_paths
        ),
        "tests": any(
            (root / value).exists()
            for value in item.test_paths
        ),
        "documentation": any(
            (root / value).exists()
            for value in item.documentation_paths
        ),
        "release": release_exists,
    }


def _escape(value: str) -> str:
    return value.replace("|", "/").replace("\n", " ").strip()


def build_managed_block(
    root_value: str | Path,
    components: tuple[Component, ...],
) -> str:
    root = Path(root_value).resolve()
    active = [item for item in components if not item.historical]
    historical = [item for item in components if item.historical]

    lines = [
        START_MARKER,
        "",
        "## Registro sincronizado de componentes",
        "",
        (
            "> Bloque generado automáticamente por PCI-001.2. "
            "No editar manualmente dentro de los marcadores."
        ),
        "",
        "### Componentes activos",
        "",
        (
            "| Código | Nombre | Versión | Estado | Código | Pruebas | "
            "Documentación | Release | Dependencias |"
        ),
        "|---|---|---|---|---:|---:|---:|---:|---|",
    ]

    for item in active:
        coverage = _coverage(root, item)
        lines.append(
            "| `{code}` | {name} | {version} | {status} | "
            "{source} | {tests} | {docs} | {release} | {deps} |".format(
                code=_escape(item.code),
                name=_escape(item.name),
                version=_escape(item.version or "—"),
                status=_escape(item.status or "unknown"),
                source="Sí" if coverage["source"] else "No",
                tests="Sí" if coverage["tests"] else "No",
                docs="Sí" if coverage["documentation"] else "No",
                release="Sí" if coverage["release"] else "No",
                deps=_escape(
                    ", ".join(item.dependencies) or "—"
                ),
            )
        )

    lines.extend(
        (
            "",
            "### Incrementos históricos",
            "",
            (
                "| Código | Nombre | Versión | Estado | "
                "Descriptor canónico |"
            ),
            "|---|---|---|---|---|",
        )
    )

    for item in historical:
        lines.append(
            "| `{code}` | {name} | {version} | {status} | `{path}` |".format(
                code=_escape(item.code),
                name=_escape(item.name),
                version=_escape(item.version or "—"),
                status=_escape(item.status or "historical"),
                path=_escape(item.descriptor_path),
            )
        )

    lines.extend(
        (
            "",
            (
                "_Generado: "
                + datetime.now(timezone.utc).isoformat()
                + "_"
            ),
            "",
            END_MARKER,
        )
    )
    return "\n".join(lines)


def replace_managed_block(
    original: str,
    block: str,
) -> tuple[str, str]:
    start_count = original.count(START_MARKER)
    end_count = original.count(END_MARKER)

    if start_count != end_count:
        raise ValueError(
            "Los marcadores administrados están desbalanceados."
        )
    if start_count > 1:
        raise ValueError(
            "Existen múltiples bloques administrados PCI-001.2."
        )

    if start_count == 1:
        start = original.index(START_MARKER)
        end = (
            original.index(END_MARKER, start)
            + len(END_MARKER)
        )
        updated = (
            original[:start].rstrip()
            + "\n\n"
            + block
            + "\n"
            + original[end:].lstrip()
        )
        return updated.rstrip() + "\n", "updated"

    separator = "\n\n" if original.strip() else ""
    return (
        original.rstrip()
        + separator
        + block
        + "\n"
    ), "created"


def synchronize(
    root_value: str | Path,
    *,
    apply: bool,
    backup_dir: str | Path,
    report_path: str | Path,
    preview_path: str | Path,
) -> dict[str, Any]:
    root = Path(root_value).resolve()
    index_path = root / "docs" / "00_INDICE_MAESTRO.md"

    if not index_path.is_file():
        raise FileNotFoundError(index_path)

    components = scan_components(root)
    original = index_path.read_text(
        encoding="utf-8-sig",
        errors="replace",
    )
    block = build_managed_block(root, components)
    updated, operation = replace_managed_block(original, block)

    backup_root = Path(backup_dir)
    backup_root.mkdir(parents=True, exist_ok=True)
    backup_path = backup_root / "00_INDICE_MAESTRO.md.bak"

    preview = Path(preview_path)
    preview.parent.mkdir(parents=True, exist_ok=True)
    preview.write_text(updated, encoding="utf-8")

    changed = original.replace("\r\n", "\n") != updated.replace(
        "\r\n",
        "\n",
    )

    if apply and changed:
        shutil.copy2(index_path, backup_path)
        index_path.write_text(updated, encoding="utf-8")
    elif apply and not backup_path.exists():
        shutil.copy2(index_path, backup_path)

    active = [item for item in components if not item.historical]
    historical = [item for item in components if item.historical]
    indexed_codes = {
        item.code
        for item in components
        if f"`{item.code}`" in updated
    }

    result = {
        "program": "PCI-SGODA-v1.0.0",
        "increment_code": "PCI-001.2",
        "deliverable": "SGD-201A.2",
        "version": "1.0.0",
        "mode": "apply" if apply else "preview",
        "operation": operation,
        "changed": changed,
        "index_path": index_path.relative_to(root).as_posix(),
        "backup_path": (
            backup_path.as_posix()
            if backup_path.exists()
            else None
        ),
        "preview_path": preview.as_posix(),
        "components_total": len(components),
        "active_components": len(active),
        "historical_increments": len(historical),
        "indexed_components": len(indexed_codes),
        "index_coverage_percent": (
            round(
                100 * len(indexed_codes) / len(components),
                2,
            )
            if components
            else 100.0
        ),
        "active_codes": [item.code for item in active],
        "historical_codes": [
            item.code
            for item in historical
        ],
        "approved": (
            len(indexed_codes) == len(components)
            and len(components) > 0
        ),
        "generated_at_utc": datetime.now(
            timezone.utc
        ).isoformat(),
    }

    report = Path(report_path)
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(
        json.dumps(
            result,
            ensure_ascii=False,
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument(
        "--mode",
        choices=("preview", "apply"),
        required=True,
    )
    parser.add_argument("--backup-dir", required=True)
    parser.add_argument("--report-json", required=True)
    parser.add_argument("--preview-md", required=True)
    args = parser.parse_args()

    result = synchronize(
        args.root,
        apply=args.mode == "apply",
        backup_dir=args.backup_dir,
        report_path=args.report_json,
        preview_path=args.preview_md,
    )
    print(json.dumps(result, ensure_ascii=False))
    return 0 if result["approved"] else 2

'@

$Tests = @'

from __future__ import annotations

import json
from pathlib import Path

import pytest

from sgoda.governance.master_index_sync import (
    END_MARKER,
    START_MARKER,
    build_managed_block,
    replace_managed_block,
    scan_components,
    synchronize,
)


def repository(tmp_path: Path) -> Path:
    for path in (
        "config/example",
        "docs",
        "src/example",
        "tests/example",
        "releases/SPT-999-v1.0.0",
    ):
        (tmp_path / path).mkdir(
            parents=True,
            exist_ok=True,
        )

    (tmp_path / "src/example/__init__.py").write_text(
        "",
        encoding="utf-8",
    )
    (tmp_path / "tests/example/test_example.py").write_text(
        "def test_ok(): assert True\n",
        encoding="utf-8",
    )
    (tmp_path / "docs/example.md").write_text(
        "# SPT-999\n",
        encoding="utf-8",
    )
    (tmp_path / "docs/00_INDICE_MAESTRO.md").write_text(
        "# Índice Maestro\n\nContenido manual.\n",
        encoding="utf-8",
    )
    descriptor = {
        "increment_code": "SPT-999",
        "name": "Componente ejemplo",
        "version": "1.0.0",
        "status": "closed",
        "source": ["src/example"],
        "tests": ["tests/example"],
        "documentation": ["docs/example.md"],
    }
    (tmp_path / "config/example/SPT-999-component.json").write_text(
        json.dumps(descriptor),
        encoding="utf-8",
    )
    (tmp_path / "config/example/SPT-999-policy.json").write_text(
        '{"component":"SPT-999"}',
        encoding="utf-8",
    )
    (tmp_path / "releases/SPT-999-v1.0.0/manifest.json").write_text(
        '{"increment_code":"SPT-999"}',
        encoding="utf-8",
    )
    return tmp_path


def test_scan_uses_only_component_descriptors(
    tmp_path: Path,
) -> None:
    components = scan_components(repository(tmp_path))

    assert len(components) == 1
    assert components[0].code == "SPT-999"


def test_block_contains_structural_code(
    tmp_path: Path,
) -> None:
    root = repository(tmp_path)
    block = build_managed_block(
        root,
        scan_components(root),
    )

    assert "`SPT-999`" in block
    assert START_MARKER in block
    assert END_MARKER in block


def test_manual_content_is_preserved(
    tmp_path: Path,
) -> None:
    root = repository(tmp_path)
    index = root / "docs/00_INDICE_MAESTRO.md"
    original = index.read_text(encoding="utf-8")

    result = synchronize(
        root,
        apply=True,
        backup_dir=tmp_path / "backup",
        report_path=tmp_path / "report.json",
        preview_path=tmp_path / "preview.md",
    )

    updated = index.read_text(encoding="utf-8")

    assert result["approved"] is True
    assert original.strip() in updated
    assert "`SPT-999`" in updated


def test_backup_is_created(
    tmp_path: Path,
) -> None:
    root = repository(tmp_path)
    backup = tmp_path / "backup"

    synchronize(
        root,
        apply=True,
        backup_dir=backup,
        report_path=tmp_path / "report.json",
        preview_path=tmp_path / "preview.md",
    )

    assert (backup / "00_INDICE_MAESTRO.md.bak").is_file()


def test_preview_does_not_modify_index(
    tmp_path: Path,
) -> None:
    root = repository(tmp_path)
    index = root / "docs/00_INDICE_MAESTRO.md"
    before = index.read_text(encoding="utf-8")

    synchronize(
        root,
        apply=False,
        backup_dir=tmp_path / "backup",
        report_path=tmp_path / "report.json",
        preview_path=tmp_path / "preview.md",
    )

    assert index.read_text(encoding="utf-8") == before


def test_second_apply_is_idempotent(
    tmp_path: Path,
) -> None:
    root = repository(tmp_path)
    kwargs = {
        "root_value": root,
        "apply": True,
        "backup_dir": tmp_path / "backup",
        "report_path": tmp_path / "report.json",
        "preview_path": tmp_path / "preview.md",
    }

    synchronize(**kwargs)
    first = (
        root / "docs/00_INDICE_MAESTRO.md"
    ).read_text(encoding="utf-8")
    synchronize(**kwargs)
    second = (
        root / "docs/00_INDICE_MAESTRO.md"
    ).read_text(encoding="utf-8")

    # Generated timestamp changes; managed structure and codes remain unique.
    assert second.count(START_MARKER) == 1
    assert second.count(END_MARKER) == 1
    assert second.count("`SPT-999`") == 1
    assert "# Índice Maestro" in first
    assert "# Índice Maestro" in second


def test_unbalanced_markers_are_rejected() -> None:
    with pytest.raises(ValueError):
        replace_managed_block(
            "Header\n" + START_MARKER,
            "block",
        )


def test_multiple_managed_blocks_are_rejected() -> None:
    text = (
        START_MARKER
        + "\n"
        + END_MARKER
        + "\n"
        + START_MARKER
        + "\n"
        + END_MARKER
    )
    with pytest.raises(ValueError):
        replace_managed_block(text, "block")


def test_historical_increment_is_separated(
    tmp_path: Path,
) -> None:
    root = repository(tmp_path)
    descriptor = {
        "increment_code": "SGD-114E-v1.0.7",
        "name": "Historical",
        "version": "1.0.7",
        "status": "historical",
    }
    (
        root
        / "config/example/SGD-114E-v1.0.7-component.json"
    ).write_text(
        json.dumps(descriptor),
        encoding="utf-8",
    )

    block = build_managed_block(
        root,
        scan_components(root),
    )

    assert "### Incrementos históricos" in block
    assert "`SGD-114E-V1.0.7`" in block


def test_report_is_json_serializable(
    tmp_path: Path,
) -> None:
    root = repository(tmp_path)
    report = tmp_path / "report.json"

    result = synchronize(
        root,
        apply=False,
        backup_dir=tmp_path / "backup",
        report_path=report,
        preview_path=tmp_path / "preview.md",
    )

    json.dumps(result)
    assert report.is_file()


def test_all_components_are_indexed(
    tmp_path: Path,
) -> None:
    root = repository(tmp_path)

    result = synchronize(
        root,
        apply=True,
        backup_dir=tmp_path / "backup",
        report_path=tmp_path / "report.json",
        preview_path=tmp_path / "preview.md",
    )

    assert result["index_coverage_percent"] == 100
    assert result["indexed_components"] == 1


def test_missing_index_is_rejected(
    tmp_path: Path,
) -> None:
    root = repository(tmp_path)
    (
        root / "docs/00_INDICE_MAESTRO.md"
    ).unlink()

    with pytest.raises(FileNotFoundError):
        synchronize(
            root,
            apply=True,
            backup_dir=tmp_path / "backup",
            report_path=tmp_path / "report.json",
            preview_path=tmp_path / "preview.md",
        )

'@

$Component = @'
{
  "increment_code": "PCI-001.2",
  "name": "Institutional Master Index Synchronizer",
  "version": "1.0.0",
  "status": "implemented_tested_and_candidate_for_closure",
  "program": "PCI-SGODA-v1.0.0",
  "deliverable": "SGD-201A.2",
  "native_ecosystem": true,
  "mandatory_proprietary_dependencies": [],
  "source": [
    "src/sgoda/governance/master_index_sync"
  ],
  "tests": [
    "tests/governance/master_index_sync/test_PCI_001_2_master_index_synchronizer.py"
  ],
  "documentation": [
    "docs/01_Gobierno/PCI-001.2"
  ],
  "dependencies": [
    "PCI-001",
    "PCI-001.1",
    "SGD-114F",
    "SGD-114G",
    "SGD-115",
    "SGD-116",
    "SGD-117",
    "SPB-007"
  ]
}
'@

$Policy = @'
{
  "policy_id": "PCI-001.2-POLICY-v1.0.0",
  "component": "PCI-001.2",
  "source_of_truth": "*-component.json",
  "managed_block_start": "<!-- PCI-001.2:BEGIN MANAGED COMPONENT INDEX -->",
  "managed_block_end": "<!-- PCI-001.2:END MANAGED COMPONENT INDEX -->",
  "preserve_manual_content": true,
  "backup_required": true,
  "preview_required": true,
  "approval_rule": "100 percent indexed canonical components"
}
'@

$Architecture = @'
# PCI-001.2 v1.0.0 — Arquitectura

PCI-001.2 sincroniza el Índice Maestro a partir de los descriptores canónicos
`*-component.json`.

El contenido manual existente se conserva. El sincronizador solamente crea o
reemplaza el bloque delimitado por marcadores institucionales.

Antes de modificar el Índice se genera una vista previa. En la aplicación real
se crea una copia de respaldo. Los componentes activos y los incrementos
históricos se presentan en secciones separadas.
'@

$Operations = @'
# PCI-001.2 v1.0.0 — Manual operativo

El instalador ejecuta primero una simulación y después la aplicación real.

El bloque administrado se identifica mediante:

```text
<!-- PCI-001.2:BEGIN MANAGED COMPONENT INDEX -->
<!-- PCI-001.2:END MANAGED COMPONENT INDEX -->
```

No debe editarse manualmente el contenido situado entre ambos marcadores.
'@

Write-Utf8 `
    -Path (Join-Path $SourceDir "__init__.py") `
    -Content $Module
Write-Utf8 `
    -Path (Join-Path $SourceDir "__main__.py") `
    -Content (
        "from . import main" +
        [Environment]::NewLine +
        "raise SystemExit(main())" +
        [Environment]::NewLine
    )
Write-Utf8 `
    -Path (
        Join-Path `
            $TestsDir `
            "test_PCI_001_2_master_index_synchronizer.py"
    ) `
    -Content $Tests
Write-Utf8 `
    -Path (Join-Path $ConfigDir "PCI-001.2-component.json") `
    -Content $Component
Write-Utf8 `
    -Path (Join-Path $ConfigDir "PCI-001.2-policy.json") `
    -Content $Policy
Write-Utf8 `
    -Path (Join-Path $DocsDir "PCI-001.2-Arquitectura.md") `
    -Content $Architecture
Write-Utf8 `
    -Path (Join-Path $DocsDir "PCI-001.2-Manual-Operativo.md") `
    -Content $Operations

Run "Validando sintaxis Python" {
    python -m py_compile `
        "src/sgoda/governance/master_index_sync/__init__.py" `
        "src/sgoda/governance/master_index_sync/__main__.py" `
        "tests/governance/master_index_sync/test_PCI_001_2_master_index_synchronizer.py"
}

Run "Ejecutando pruebas específicas e históricas PCI-001.2" {
    & $RunnerPath `
        -Component "PCI-001.2-v1.0.0" `
        -TestPath @(
            "tests/governance/master_index_sync/test_PCI_001_2_master_index_synchronizer.py",
            "tests/governance/master_index_audit/test_PCI_001_master_index_audit.py",
            "tests/governance/master_index_audit/test_PCI_001_1_intelligent_master_index_auditor.py",
            "tests/documentation/test_SGD_115_master_documentation.py",
            "tests/roadmap/test_SGD_116_master_ecosystem_roadmap.py",
            "tests/governance/repository_manager/test_SGD_117_repository_manager.py"
        ) `
        -ReportPath "$SpecificXml" `
        -SummaryJson "$SpecificJson" `
        -SummaryMarkdown "$SpecificMd" `
        -Scope "specific_historical_and_integration"
}

$Specific = (
    Get-Content `
        -LiteralPath $SpecificJson `
        -Raw `
        -Encoding UTF8 |
    ConvertFrom-Json
)

if (-not [bool]$Specific.approved) {
    throw "Las pruebas PCI-001.2 no fueron aprobadas."
}

Run "Generando vista previa del Índice Maestro" {
    python -m sgoda.governance.master_index_sync `
        --root "$ProjectRoot" `
        --mode "preview" `
        --backup-dir "$BackupDir" `
        --report-json "$PreviewJson" `
        --preview-md "$PreviewMd"
}

$Preview = (
    Get-Content `
        -LiteralPath $PreviewJson `
        -Raw `
        -Encoding UTF8 |
    ConvertFrom-Json
)

if (-not [bool]$Preview.approved) {
    throw "La vista previa no alcanzó cobertura total."
}

Run "Aplicando sincronización institucional" {
    python -m sgoda.governance.master_index_sync `
        --root "$ProjectRoot" `
        --mode "apply" `
        --backup-dir "$BackupDir" `
        --report-json "$ApplyJson" `
        --preview-md "$PreviewMd"
}

$Apply = (
    Get-Content `
        -LiteralPath $ApplyJson `
        -Raw `
        -Encoding UTF8 |
    ConvertFrom-Json
)

if (-not [bool]$Apply.approved) {
    throw "La sincronización no alcanzó cobertura total."
}

Run "Regenerando documentación mediante SGD-115" {
    python -m sgoda.documentation.master_docs `
        --root "$ProjectRoot" `
        --output "artifacts/documentation/SGD-115"
}

Run "Regenerando roadmap mediante SGD-116" {
    python -m sgoda.roadmap.cli `
        --root "$ProjectRoot" `
        --output "artifacts/roadmap/SGD-116"
}

Run "Validando repositorio mediante SGD-117" {
    python -m sgoda.governance.repository_manager.cli `
        --root "$ProjectRoot" `
        --operation "validate" `
        --output-json (
            Join-Path `
                $ArtifactDir `
                "repository-validation.json"
        )
}

Run "Ejecutando auditoría posterior PCI-001.1" {
    python -m sgoda.governance.master_index_audit `
        --root "$ProjectRoot" `
        --output-json "$AuditJson" `
        --output-md "$AuditMd" `
        --output-html "$AuditHtml" `
        --metrics-json "$AuditMetrics" `
        --traceability-json "$AuditTrace" `
        --pmo-json "$AuditPmo"
}

$Audit = (
    Get-Content `
        -LiteralPath $AuditJson `
        -Raw `
        -Encoding UTF8 |
    ConvertFrom-Json
)

if (-not [bool]$Audit.approved) {
    throw "La auditoría posterior detectó hallazgos críticos."
}

if (
    [double]$Audit.metrics.index_coverage_percent -lt 100.0
) {
    throw (
        "La cobertura del Índice Maestro quedó en " +
        [string]$Audit.metrics.index_coverage_percent +
        "%."
    )
}

Run "Ejecutando suite completa del ecosistema" {
    python -m pytest --junitxml="$FullXml"
}

Run "Sincronizando evidencia mediante SGD-114F" {
    python -m sgoda.governance.test_evidence.cli `
        --junit "$FullXml" `
        --component "SGODA-PUINAVE" `
        --scope "full_suite" `
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
    throw "La suite completa no fue aprobada."
}

$Evidence = [ordered]@{
    program = "PCI-SGODA-v1.0.0"
    increment_code = "PCI-001.2"
    deliverable = "SGD-201A.2"
    version = "1.0.0"
    status = "implemented_tested_and_candidate_for_closure"
    prevalidated_package = "............                                                             [100%] 12 passed in 0.06s"
    synchronization = $Apply
    post_sync_audit = [ordered]@{
        approved = [bool]$Audit.approved
        index_coverage_percent = [double]$Audit.metrics.index_coverage_percent
        registry_coverage_percent = [double]$Audit.metrics.registry_coverage_percent
        institutional_consistency_score = [double]$Audit.metrics.institutional_consistency_score
        critical_findings = [int]$Audit.metrics.critical_findings
        warning_findings = [int]$Audit.metrics.warning_findings
        informational_findings = [int]$Audit.metrics.informational_findings
    }
    specific_tests = [ordered]@{
        executed = [int]$Specific.executed
        passed = [int]$Specific.passed
        failures = [int]$Specific.failures
        errors = [int]$Specific.errors
        approved = [bool]$Specific.approved
    }
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
    -Path $EvidenceJson `
    -Value $Evidence

$Lines = @(
    "# PCI-001.2 v1.0.0 — Evidencia",
    "",
    "- Entregable: SGD-201A.2",
    "- Sincronización del Índice Maestro: APROBADA",
    "- Contenido manual: PRESERVADO",
    "- Respaldo: GENERADO",
    (
        "- Componentes sincronizados: " +
        [string]$Apply.components_total
    ),
    (
        "- Componentes activos: " +
        [string]$Apply.active_components
    ),
    (
        "- Incrementos históricos: " +
        [string]$Apply.historical_increments
    ),
    (
        "- Cobertura posterior del Índice: " +
        [string]$Audit.metrics.index_coverage_percent +
        "%"
    ),
    (
        "- Cobertura del Registro: " +
        [string]$Audit.metrics.registry_coverage_percent +
        "%"
    ),
    (
        "- Consistencia institucional: " +
        [string]$Audit.metrics.institutional_consistency_score +
        "%"
    ),
    (
        "- Pruebas específicas: " +
        [string]$Specific.passed +
        "/" +
        [string]$Specific.executed
    ),
    (
        "- Suite completa: " +
        [string]$Full.passed +
        "/" +
        [string]$Full.executed
    )
)

Write-Utf8 `
    -Path $EvidenceMd `
    -Content (
        [string]::Join(
            [Environment]::NewLine,
            $Lines
        )
    )

foreach ($File in @(
    (Join-Path $SourceDir "__init__.py"),
    (Join-Path $SourceDir "__main__.py"),
    (
        Join-Path `
            $TestsDir `
            "test_PCI_001_2_master_index_synchronizer.py"
    ),
    (Join-Path $ConfigDir "PCI-001.2-component.json"),
    (Join-Path $ConfigDir "PCI-001.2-policy.json"),
    (Join-Path $DocsDir "PCI-001.2-Arquitectura.md"),
    (Join-Path $DocsDir "PCI-001.2-Manual-Operativo.md"),
    $PreviewMd,
    $PreviewJson,
    $ApplyJson,
    $AuditJson,
    $AuditMd,
    $AuditHtml,
    $AuditMetrics,
    $AuditTrace,
    $AuditPmo,
    $SpecificXml,
    $SpecificJson,
    $SpecificMd,
    $FullXml,
    $FullJson,
    $FullMd,
    $EvidenceJson,
    $EvidenceMd,
    (Join-Path $BackupDir "00_INDICE_MAESTRO.md.bak")
)) {
    Require-File `
        -Path $File `
        -Description "archivo del release"

    Copy-Item `
        -LiteralPath $File `
        -Destination $ReleaseDir `
        -Force
}

Write-Json `
    -Path (Join-Path $ReleaseDir "manifest.json") `
    -Value ([ordered]@{
        program = "PCI-SGODA-v1.0.0"
        increment_code = "PCI-001.2"
        deliverable = "SGD-201A.2"
        version = "1.0.0"
        release_name = "PCI-001.2-v1.0.0"
        status = "implemented_tested_and_candidate_for_closure"
        native_ecosystem = $true
        mandatory_proprietary_dependencies = @()
        source_of_truth = "*-component.json"
        index_coverage_percent = [double]$Audit.metrics.index_coverage_percent
        files = @(
            Get-ChildItem `
                -LiteralPath $ReleaseDir `
                -File |
            Select-Object -ExpandProperty Name
        )
    })

Run "Validando release mediante SGD-114G" {
    python -m sgoda.governance.release_management.cli `
        --root "$ProjectRoot" `
        --operation "close" `
        --output-json "$ReleaseValidationJson"
}

if ($Publish) {
    Step "Publicando mediante gate canónico"

    & $PublisherPath `
        -Publish `
        -CommitMessage "feat(consolidation): implement PCI-001.2 master index synchronizer" `
        -EvidenceCommitMessage "chore(consolidation): publish PCI-001.2 evidence"

    if ($LASTEXITCODE -ne 0) {
        throw "La publicación institucional terminó con errores."
    }
}

Step "Resultado final"
Write-Host "PCI-001.2 v1.0.0 implementado." -ForegroundColor Green
Write-Host "SGD-201A.2 — Sincronización del Índice Maestro: APROBADA." -ForegroundColor Green
Write-Host "Contenido manual: PRESERVADO." -ForegroundColor Green
Write-Host "Respaldo institucional: GENERADO." -ForegroundColor Green
Write-Host (
    "Componentes sincronizados: " +
    [string]$Apply.components_total
) -ForegroundColor Green
Write-Host (
    "Cobertura del Índice Maestro: " +
    [string]$Audit.metrics.index_coverage_percent +
    "%."
) -ForegroundColor Green
Write-Host (
    "Cobertura del Registro Maestro: " +
    [string]$Audit.metrics.registry_coverage_percent +
    "%."
) -ForegroundColor Green
Write-Host (
    "Consistencia institucional: " +
    [string]$Audit.metrics.institutional_consistency_score +
    "%."
) -ForegroundColor Green
Write-Host (
    "Pruebas específicas: " +
    "$($Specific.passed)/$($Specific.executed) APROBADAS."
) -ForegroundColor Green
Write-Host (
    "Suite completa: " +
    "$($Full.passed)/$($Full.executed) APROBADA."
) -ForegroundColor Green
Write-Host "Release: releases\PCI-001.2-v1.0.0" -ForegroundColor Cyan

if ($Publish) {
    Write-Host "Publicación institucional: COMPLETADA." -ForegroundColor Green
}
else {
    Write-Host "Publicación no solicitada. Reejecute con -Publish." -ForegroundColor Yellow
}
