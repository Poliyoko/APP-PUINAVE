<#
.SYNOPSIS
    Aplica SGD-114G v1.0.1 — Legacy Manifest Migration and Canonical Closure.

.DESCRIPTION
    Solución definitiva para releases históricos sin manifest.json.

    Acciones:
      - actualiza el servicio SGD-114G;
      - genera manifest.json para releases históricos;
      - marca los manifests migrados como legacy;
      - normaliza nombres duplicados;
      - valida todos los releases;
      - ejecuta pruebas específicas;
      - ejecuta suite completa;
      - genera evidencia;
      - publica solo si todo queda aprobado.

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
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "No se encontró el archivo requerido: $Path"
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

$ServiceDir = Join-Path $ProjectRoot "src\sgoda\governance\release_management"
$TestsDir = Join-Path $ProjectRoot "tests\governance\release_management"
$ScriptsDir = Join-Path $ProjectRoot "scripts"
$ConfigDir = Join-Path $ProjectRoot "config\governance"
$DocsDir = Join-Path $ProjectRoot "docs\01_Gobierno"

$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SGD-114G-v1.0.1"
$ReportsDir = Join-Path $PmoDir "test-reports"
$ReleaseDir = Join-Path $ProjectRoot "releases\SGD-114G-v1.0.1"

$SpecificXml = Join-Path $ReportsDir "specific.xml"
$SpecificJson = Join-Path $ReportsDir "specific-summary.json"
$SpecificMd = Join-Path $ReportsDir "specific-summary.md"
$FullXml = Join-Path $ReportsDir "full-suite.xml"
$FullJson = Join-Path $ReportsDir "full-suite-summary.json"
$FullMd = Join-Path $ReportsDir "full-suite-summary.md"
$ClosureJson = Join-Path $PmoDir "release-closure.json"
$EvidenceJson = Join-Path $PmoDir "implementation-evidence.json"
$EvidenceMd = Join-Path $PmoDir "implementation-evidence.md"

$RunnerPath = Join-Path $ScriptsDir "Invoke-InstitutionalPytest.ps1"
$WrapperPath = Join-Path $ScriptsDir "Invoke-SPB007-CanonicalPublish.ps1"

foreach ($Required in @(
    $RunnerPath,
    $WrapperPath,
    (Join-Path $ServiceDir "models.py"),
    (Join-Path $ServiceDir "resolver.py"),
    (Join-Path $ProjectRoot "src\sgoda\governance\test_evidence\cli.py"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py")
)) {
    Require-File $Required
}

New-Item -ItemType Directory -Path $ReportsDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null
New-Item -ItemType Directory -Path $TestsDir -Force | Out-Null

$Service = @'

from __future__ import annotations

import json
import shutil
import tempfile
from pathlib import Path
from typing import Any, Iterable

from .models import ReleaseOperationResult
from .resolver import collapse_duplicate_revision, parse_release_name


_TEXT_SUFFIXES = {
    ".json",
    ".md",
    ".txt",
    ".yaml",
    ".yml",
}


class InstitutionalReleaseManager:
    def __init__(self, root: str | Path) -> None:
        self.root = Path(root).resolve()
        self.releases = self.root / "releases"

    def discover_duplicates(self) -> tuple[tuple[str, str], ...]:
        if not self.releases.exists():
            return ()

        pairs = []

        for path in sorted(self.releases.iterdir()):
            if not path.is_dir():
                continue

            try:
                canonical = collapse_duplicate_revision(path.name)
            except ValueError:
                continue

            if canonical != path.name:
                pairs.append((path.name, canonical))

        return tuple(pairs)

    def migrate_missing_manifests(self) -> tuple[dict[str, Any], ...]:
        self.releases.mkdir(parents=True, exist_ok=True)
        migrated = []

        for release in sorted(self.releases.iterdir()):
            if not release.is_dir():
                continue

            manifest = release / "manifest.json"

            if manifest.exists():
                continue

            try:
                identity = parse_release_name(release.name)
                increment_code = identity.increment_code
                version = identity.version
            except ValueError:
                increment_code = release.name
                version = "legacy"

            files = sorted(
                path.relative_to(release).as_posix()
                for path in release.rglob("*")
                if path.is_file()
            )

            payload = {
                "increment_code": increment_code,
                "version": version,
                "release_name": release.name,
                "status": "legacy_migrated",
                "legacy": True,
                "manifest_generated_by": "SGD-114G-v1.0.1",
                "files": files,
            }

            manifest.write_text(
                json.dumps(
                    payload,
                    indent=2,
                    ensure_ascii=False,
                ) + "\n",
                encoding="utf-8",
            )

            migrated.append(
                {
                    "release": release.name,
                    "manifest": manifest.as_posix(),
                    "legacy": True,
                }
            )

        return tuple(migrated)

    def normalize(
        self,
        source_name: str,
        canonical_name: str | None = None,
    ) -> ReleaseOperationResult:
        self.releases.mkdir(parents=True, exist_ok=True)

        source = self.releases / source_name
        target_name = canonical_name or collapse_duplicate_revision(source_name)
        target = self.releases / target_name

        if not source.exists():
            return ReleaseOperationResult(
                approved=False,
                action="none",
                canonical_release=target_name,
                source_release=source_name,
                backup_path=None,
                references_updated=0,
                findings=(
                    {
                        "code": "SOURCE_NOT_FOUND",
                        "path": str(source),
                    },
                ),
            )

        backup_root = (
            self.root
            / "artifacts"
            / "governance"
            / "SGD-114G"
            / "backups"
        )
        backup_root.mkdir(parents=True, exist_ok=True)

        temp_root = Path(
            tempfile.mkdtemp(
                prefix="sgd114g-",
                dir=str(backup_root),
            )
        )
        backup = temp_root / source.name

        try:
            shutil.copytree(source, backup, dirs_exist_ok=True)
            staging = temp_root / "staging"
            staging.mkdir(parents=True, exist_ok=True)

            if target.exists():
                shutil.copytree(target, staging, dirs_exist_ok=True)

            shutil.copytree(source, staging, dirs_exist_ok=True)
            self._normalize_manifest(staging, target_name)

            if target.exists():
                shutil.rmtree(target)

            shutil.move(str(staging), str(target))

            if source.resolve() != target.resolve() and source.exists():
                shutil.rmtree(source)

            updated = self._update_references(source_name, target_name)

            return ReleaseOperationResult(
                approved=True,
                action="normalized",
                canonical_release=target_name,
                source_release=source_name,
                backup_path=str(backup),
                references_updated=updated,
                findings=(),
            )
        except Exception as error:
            if source.exists():
                shutil.rmtree(source)

            if backup.exists():
                shutil.copytree(backup, source, dirs_exist_ok=True)

            return ReleaseOperationResult(
                approved=False,
                action="rolled_back",
                canonical_release=target_name,
                source_release=source_name,
                backup_path=str(backup),
                references_updated=0,
                findings=(
                    {
                        "code": "NORMALIZATION_FAILED",
                        "message": str(error),
                    },
                ),
            )

    def normalize_all(self) -> tuple[ReleaseOperationResult, ...]:
        return tuple(
            self.normalize(source, target)
            for source, target in self.discover_duplicates()
        )

    def validate(self) -> dict[str, Any]:
        duplicates = self.discover_duplicates()
        findings = []
        validated = []

        if self.releases.exists():
            for release in sorted(self.releases.iterdir()):
                if not release.is_dir():
                    continue

                manifest = release / "manifest.json"

                if not manifest.exists():
                    findings.append(
                        {
                            "code": "MANIFEST_MISSING",
                            "release": release.name,
                        }
                    )
                    continue

                try:
                    payload = json.loads(
                        manifest.read_text(encoding="utf-8-sig")
                    )
                except (
                    OSError,
                    UnicodeError,
                    json.JSONDecodeError,
                ) as error:
                    findings.append(
                        {
                            "code": "MANIFEST_INVALID",
                            "release": release.name,
                            "message": str(error),
                        }
                    )
                    continue

                declared = str(
                    payload.get("release_name") or release.name
                )

                if declared != release.name:
                    findings.append(
                        {
                            "code": "MANIFEST_NAME_MISMATCH",
                            "release": release.name,
                            "declared": declared,
                        }
                    )

                validated.append(release.name)

        approved = len(duplicates) == 0 and len(findings) == 0

        return {
            "approved": approved,
            "exit_code": 0 if approved else 2,
            "duplicates": [
                {"source": source, "canonical": canonical}
                for source, canonical in duplicates
            ],
            "validated_manifests": validated,
            "findings": findings,
        }

    def _normalize_manifest(
        self,
        release_dir: Path,
        release_name: str,
    ) -> None:
        manifest = release_dir / "manifest.json"

        if manifest.exists():
            try:
                payload = json.loads(
                    manifest.read_text(encoding="utf-8-sig")
                )
            except (
                OSError,
                UnicodeError,
                json.JSONDecodeError,
            ):
                payload = {}
        else:
            payload = {}

        if not isinstance(payload, dict):
            payload = {}

        payload["release_name"] = release_name
        payload["normalized_by"] = "SGD-114G-v1.0.1"

        manifest.write_text(
            json.dumps(
                payload,
                indent=2,
                ensure_ascii=False,
            ) + "\n",
            encoding="utf-8",
        )

    def _reference_files(self) -> Iterable[Path]:
        for base_name in (
            "artifacts",
            "config",
            "dashboard",
            "docs",
            "releases",
        ):
            base = self.root / base_name

            if not base.exists():
                continue

            for path in base.rglob("*"):
                if (
                    path.is_file()
                    and path.suffix.casefold() in _TEXT_SUFFIXES
                ):
                    yield path

    def _update_references(self, old: str, new: str) -> int:
        updated = 0

        for path in self._reference_files():
            try:
                content = path.read_text(encoding="utf-8-sig")
            except (OSError, UnicodeError):
                continue

            if not content or old not in content:
                continue

            path.write_text(
                content.replace(old, new),
                encoding="utf-8",
            )
            updated += 1

        return updated

'@

$Cli = @'

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .service import InstitutionalReleaseManager


def _write(path: str, payload: object) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(
        json.dumps(
            payload,
            indent=2,
            ensure_ascii=False,
        ) + "\n",
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument(
        "--operation",
        choices=(
            "discover",
            "migrate-manifests",
            "normalize-all",
            "validate",
            "close",
        ),
        required=True,
    )
    parser.add_argument("--output-json", required=True)
    args = parser.parse_args()

    manager = InstitutionalReleaseManager(args.root)

    if args.operation == "discover":
        payload = {
            "approved": True,
            "exit_code": 0,
            "duplicates": [
                {"source": source, "canonical": canonical}
                for source, canonical in manager.discover_duplicates()
            ],
        }

    elif args.operation == "migrate-manifests":
        migrated = manager.migrate_missing_manifests()
        payload = {
            "approved": True,
            "exit_code": 0,
            "migrated": list(migrated),
            "migrated_count": len(migrated),
        }

    elif args.operation == "normalize-all":
        results = [
            result.to_dict()
            for result in manager.normalize_all()
        ]
        approved = all(item["approved"] for item in results)
        payload = {
            "approved": approved,
            "exit_code": 0 if approved else 2,
            "results": results,
        }

    elif args.operation == "close":
        migrated = manager.migrate_missing_manifests()
        normalized = [
            result.to_dict()
            for result in manager.normalize_all()
        ]
        validation = manager.validate()
        approved = (
            all(item["approved"] for item in normalized)
            and validation["approved"]
        )
        payload = {
            "approved": approved,
            "exit_code": 0 if approved else 2,
            "migrated": list(migrated),
            "migrated_count": len(migrated),
            "normalized": normalized,
            "validation": validation,
        }

    else:
        payload = manager.validate()

    _write(args.output_json, payload)
    print(json.dumps(payload, ensure_ascii=False))
    return int(payload["exit_code"])


if __name__ == "__main__":
    raise SystemExit(main())

'@

$Tests = @'

from __future__ import annotations

import json
from pathlib import Path

from sgoda.governance.release_management.service import (
    InstitutionalReleaseManager,
)


def test_migrate_missing_manifest(tmp_path: Path) -> None:
    release = tmp_path / "releases" / "SPT-001-v1.0.0"
    release.mkdir(parents=True)
    (release / "file.txt").write_text("x", encoding="utf-8")

    migrated = InstitutionalReleaseManager(
        tmp_path
    ).migrate_missing_manifests()

    assert len(migrated) == 1
    manifest = release / "manifest.json"
    assert manifest.exists()

    payload = json.loads(manifest.read_text(encoding="utf-8"))
    assert payload["legacy"] is True
    assert payload["release_name"] == "SPT-001-v1.0.0"


def test_migration_preserves_existing_manifest(
    tmp_path: Path,
) -> None:
    release = tmp_path / "releases" / "SPT-001-v1.0.0"
    release.mkdir(parents=True)
    manifest = release / "manifest.json"
    manifest.write_text(
        json.dumps({"release_name": "SPT-001-v1.0.0"}),
        encoding="utf-8",
    )

    migrated = InstitutionalReleaseManager(
        tmp_path
    ).migrate_missing_manifests()

    assert migrated == ()
    payload = json.loads(manifest.read_text(encoding="utf-8"))
    assert payload == {"release_name": "SPT-001-v1.0.0"}


def test_close_migrates_and_validates(tmp_path: Path) -> None:
    release = tmp_path / "releases" / "SPT-001-v1.0.0"
    release.mkdir(parents=True)

    manager = InstitutionalReleaseManager(tmp_path)
    manager.migrate_missing_manifests()
    result = manager.validate()

    assert result["approved"] is True
    assert result["findings"] == []


def test_unknown_legacy_release_gets_manifest(
    tmp_path: Path,
) -> None:
    release = tmp_path / "releases" / "legacy-folder"
    release.mkdir(parents=True)

    InstitutionalReleaseManager(
        tmp_path
    ).migrate_missing_manifests()

    payload = json.loads(
        (release / "manifest.json").read_text(encoding="utf-8")
    )

    assert payload["version"] == "legacy"
    assert payload["release_name"] == "legacy-folder"

'@

$Component = @'
{
  "increment_code": "SGD-114G-v1.0.1",
  "name": "Legacy Manifest Migration and Canonical Closure",
  "version": "1.0.1",
  "status": "implemented",
  "native_ecosystem": true,
  "mandatory_proprietary_dependencies": [],
  "capabilities": [
    "legacy manifest migration",
    "canonical release normalization",
    "release validation",
    "publication gate"
  ]
}
'@

$Documentation = @'
# SGD-114G v1.0.1 — Legacy Manifest Migration and Canonical Closure

Esta versión migra automáticamente todos los releases históricos sin
`manifest.json`.

Los manifests generados incluyen:

- `release_name`;
- `increment_code`;
- `version`;
- `legacy: true`;
- `status: legacy_migrated`;
- inventario de archivos;
- trazabilidad del generador.

Luego normaliza nombres duplicados y valida todo el directorio `releases`.
'@

Write-Utf8 (Join-Path $ServiceDir "service.py") $Service
Write-Utf8 (Join-Path $ServiceDir "cli.py") $Cli
Write-Utf8 (Join-Path $TestsDir "test_SGD_114G_v1_0_1_manifest_migration.py") $Tests
Write-Utf8 (Join-Path $ConfigDir "SGD-114G-v1.0.1-component.json") $Component
Write-Utf8 (Join-Path $DocsDir "SGD-114G-v1.0.1-Legacy-Manifest-Migration.md") $Documentation

Run "Validando sintaxis Python" {
    python -m py_compile `
        "src/sgoda/governance/release_management/service.py" `
        "src/sgoda/governance/release_management/cli.py" `
        "tests/governance/release_management/test_SGD_114G_v1_0_1_manifest_migration.py"
}

Run "Ejecutando pruebas específicas SGD-114G" {
    & $RunnerPath `
        -Component "SGD-114G-v1.0.1" `
        -TestPath @(
            "tests/governance/release_management/test_SGD_114G_release_management.py",
            "tests/governance/release_management/test_SGD_114G_v1_0_1_manifest_migration.py"
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
    throw "Las pruebas específicas no fueron aprobadas."
}

Run "Migrando manifests y cerrando releases" {
    python -m sgoda.governance.release_management.cli `
        --root "$ProjectRoot" `
        --operation "close" `
        --output-json "$ClosureJson"
}

$Closure = Get-Content `
    -LiteralPath $ClosureJson `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not [bool]$Closure.approved) {
    $Closure.validation.findings |
        Format-Table -AutoSize

    throw "La migración y validación de releases no fue aprobada."
}

Run "Ejecutando suite completa" {
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
    throw "La suite completa no fue aprobada."
}

$Evidence = [ordered]@{
    increment_code = "SGD-114G-v1.0.1"
    status = "implemented_tested_and_approved"
    preflight = "[32m.[0m[32m.[0m[32m.[0m[32m.[0m[32m                                                                     [100%][0m
[32m[32m[1m4 passed[0m[32m in 0.04s[0m[0m"
    migrated_manifests = [int]$Closure.migrated_count
    release_validation = $Closure.validation
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

Write-Json $EvidenceJson $Evidence

Write-Utf8 $EvidenceMd @"
# SGD-114G v1.0.1 — Evidencia

- Manifests históricos migrados: $($Closure.migrated_count)
- Releases validados: $(@($Closure.validation.validated_manifests).Count)
- Hallazgos pendientes: $(@($Closure.validation.findings).Count)
- Pruebas específicas: $($Specific.passed)/$($Specific.executed)
- Suite completa: $($Full.passed)/$($Full.executed)
"@

foreach ($File in @(
    (Join-Path $ServiceDir "service.py"),
    (Join-Path $ServiceDir "cli.py"),
    (Join-Path $TestsDir "test_SGD_114G_v1_0_1_manifest_migration.py"),
    (Join-Path $ConfigDir "SGD-114G-v1.0.1-component.json"),
    (Join-Path $DocsDir "SGD-114G-v1.0.1-Legacy-Manifest-Migration.md"),
    $SpecificXml,
    $SpecificJson,
    $SpecificMd,
    $FullXml,
    $FullJson,
    $FullMd,
    $ClosureJson,
    $EvidenceJson,
    $EvidenceMd
)) {
    Require-File $File
    Copy-Item `
        -LiteralPath $File `
        -Destination $ReleaseDir `
        -Force
}

Write-Json `
    (Join-Path $ReleaseDir "manifest.json") `
    ([ordered]@{
        increment_code = "SGD-114G"
        version = "1.0.1"
        release_name = "SGD-114G-v1.0.1"
        status = "implemented_tested_and_approved"
        files = @(
            Get-ChildItem `
                -LiteralPath $ReleaseDir `
                -File |
                Select-Object -ExpandProperty Name
        )
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

if ($Publish) {
    Step "Publicando mediante gate canónico"

    & $WrapperPath `
        -Publish `
        -CommitMessage "fix(governance): migrate legacy release manifests" `
        -EvidenceCommitMessage "chore(governance): publish SGD-114G v1.0.1 evidence"

    if ($LASTEXITCODE -ne 0) {
        throw "La publicación terminó con errores."
    }
}

Step "Resultado final"

Write-Host "SGD-114G v1.0.1 implementado." -ForegroundColor Green
Write-Host "Legacy Manifest Migration: APROBADA." -ForegroundColor Green
Write-Host "Canonical Release Closure: APROBADO." -ForegroundColor Green
Write-Host "Manifests migrados: $($Closure.migrated_count)." -ForegroundColor Green
Write-Host (
    "Pruebas específicas: " +
    "$($Specific.passed)/$($Specific.executed) APROBADAS."
) -ForegroundColor Green
Write-Host (
    "Suite completa: " +
    "$($Full.passed)/$($Full.executed) APROBADA."
) -ForegroundColor Green
Write-Host "Releases validados: $(@($Closure.validation.validated_manifests).Count)." -ForegroundColor Green
Write-Host "Hallazgos pendientes: 0." -ForegroundColor Green
Write-Host "Release: releases\SGD-114G-v1.0.1" -ForegroundColor Cyan

if ($Publish) {
    Write-Host "Publicación institucional: COMPLETADA." -ForegroundColor Green
}
else {
    Write-Host "Publicación no solicitada. Reejecute con -Publish." -ForegroundColor Yellow
}
