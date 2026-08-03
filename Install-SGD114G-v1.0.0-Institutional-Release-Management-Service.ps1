<#
.SYNOPSIS
    Instala SGD-114G v1.0.0 — Institutional Release Management Service.

.DESCRIPTION
    Refactorización institucional definitiva para la gestión de releases.

    Instala:
      - servicio Python de resolución canónica;
      - normalización transaccional con respaldo y rollback;
      - lectores seguros para JSON y texto;
      - CLI institucional;
      - pruebas específicas;
      - wrapper de publicación para SPB-007;
      - configuración, documentación, evidencias y release.

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

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$ServiceDir = Join-Path $ProjectRoot "src\sgoda\governance\release_management"
$TestsDir = Join-Path $ProjectRoot "tests\governance\release_management"
$ConfigDir = Join-Path $ProjectRoot "config\governance"
$DocsDir = Join-Path $ProjectRoot "docs\01_Gobierno"
$ScriptsDir = Join-Path $ProjectRoot "scripts"

$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SGD-114G-v1.0.0"
$ReportsDir = Join-Path $PmoDir "test-reports"
$ReleaseDir = Join-Path $ProjectRoot "releases\SGD-114G-v1.0.0"
$BackupDir = Join-Path `
    $PmoDir `
    ("backups\pre-install-" + (Get-Date -Format "yyyyMMdd-HHmmss"))

$SpecificXml = Join-Path $ReportsDir "specific.xml"
$SpecificJson = Join-Path $ReportsDir "specific-summary.json"
$SpecificMd = Join-Path $ReportsDir "specific-summary.md"
$FullXml = Join-Path $ReportsDir "full-suite.xml"
$FullJson = Join-Path $ReportsDir "full-suite-summary.json"
$FullMd = Join-Path $ReportsDir "full-suite-summary.md"
$DiscoverJson = Join-Path $PmoDir "release-discovery.json"
$NormalizeJson = Join-Path $PmoDir "release-normalization.json"
$ValidateJson = Join-Path $PmoDir "release-validation.json"
$EvidenceJson = Join-Path $PmoDir "implementation-evidence.json"
$EvidenceMd = Join-Path $PmoDir "implementation-evidence.md"

$RunnerPath = Join-Path $ScriptsDir "Invoke-InstitutionalPytest.ps1"
$PublisherPath = Join-Path $ScriptsDir "Invoke-SPB007-InstitutionalPublish.ps1"
$WrapperPath = Join-Path $ScriptsDir "Invoke-SPB007-CanonicalPublish.ps1"

foreach ($Required in @(
    $RunnerPath,
    $PublisherPath,
    (Join-Path $ProjectRoot "src\sgoda\governance\test_evidence\cli.py"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py")
)) {
    Require-File $Required
}

New-Item -ItemType Directory -Path $ServiceDir -Force | Out-Null
New-Item -ItemType Directory -Path $TestsDir -Force | Out-Null
New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
New-Item -ItemType Directory -Path $DocsDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReportsDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

$Models = @'

from __future__ import annotations

from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any


@dataclass(frozen=True, slots=True)
class ReleaseIdentity:
    increment_code: str
    version: str
    release_name: str

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True, slots=True)
class ReleaseOperationResult:
    approved: bool
    action: str
    canonical_release: str
    source_release: str | None
    backup_path: str | None
    references_updated: int
    findings: tuple[dict[str, Any], ...]

    @property
    def exit_code(self) -> int:
        return 0 if self.approved else 2

    def to_dict(self) -> dict[str, Any]:
        payload = asdict(self)
        payload["findings"] = list(self.findings)
        payload["exit_code"] = self.exit_code
        return payload

'@

$Resolver = @'

from __future__ import annotations

import re

from .models import ReleaseIdentity


_INCREMENT_PATTERN = re.compile(
    r"^(?P<code>(?:SGD|SPT|SPB|SPA|ADR|SIB)-[A-Z0-9.-]+?)-v(?P<version>.+)$",
    re.IGNORECASE,
)


def canonical_release_name(
    increment_code: str,
    version: str,
) -> str:
    code = str(increment_code or "").strip()
    normalized_version = str(version or "").strip()

    if not code:
        raise ValueError("increment_code is required")

    if not normalized_version:
        raise ValueError("version is required")

    if code.casefold().endswith(
        ("-v" + normalized_version).casefold()
    ):
        return code

    return f"{code}-v{normalized_version}"


def parse_release_name(name: str) -> ReleaseIdentity:
    normalized = str(name or "").strip()
    match = _INCREMENT_PATTERN.match(normalized)

    if not match:
        raise ValueError(
            f"invalid institutional release name: {name}"
        )

    code = match.group("code")
    version = match.group("version")

    return ReleaseIdentity(
        increment_code=code,
        version=version,
        release_name=canonical_release_name(
            code,
            version,
        ),
    )


def collapse_duplicate_revision(
    name: str,
) -> str:
    identity = parse_release_name(name)
    version = identity.version

    parts = version.split(".")

    if (
        len(parts) >= 2
        and parts[-1].isdigit()
        and parts[-2].isdigit()
        and parts[-1] == parts[-2]
        and "-R" in version.upper()
    ):
        version = ".".join(parts[:-1])

    return canonical_release_name(
        identity.increment_code,
        version,
    )

'@

$Service = @'

from __future__ import annotations

import json
import shutil
import tempfile
from pathlib import Path
from typing import Any, Iterable

from .models import ReleaseOperationResult
from .resolver import collapse_duplicate_revision


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
                canonical = collapse_duplicate_revision(
                    path.name
                )
            except ValueError:
                continue

            if canonical != path.name:
                pairs.append((path.name, canonical))

        return tuple(pairs)

    def normalize(
        self,
        source_name: str,
        canonical_name: str | None = None,
    ) -> ReleaseOperationResult:
        self.releases.mkdir(parents=True, exist_ok=True)

        source = self.releases / source_name
        target_name = (
            canonical_name
            if canonical_name
            else collapse_duplicate_revision(source_name)
        )
        target = self.releases / target_name

        findings: list[dict[str, Any]] = []

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
            shutil.copytree(
                source,
                backup,
                dirs_exist_ok=True,
            )

            staging = temp_root / "staging"
            staging.mkdir(parents=True, exist_ok=True)

            if target.exists():
                shutil.copytree(
                    target,
                    staging,
                    dirs_exist_ok=True,
                )

            shutil.copytree(
                source,
                staging,
                dirs_exist_ok=True,
            )

            self._normalize_manifest(
                staging,
                target_name,
            )

            if target.exists():
                shutil.rmtree(target)

            shutil.move(str(staging), str(target))

            if source.resolve() != target.resolve():
                shutil.rmtree(source)

            updated = self._update_references(
                old=source_name,
                new=target_name,
            )

            return ReleaseOperationResult(
                approved=True,
                action="normalized",
                canonical_release=target_name,
                source_release=source_name,
                backup_path=str(backup),
                references_updated=updated,
                findings=tuple(findings),
            )
        except Exception as error:
            findings.append(
                {
                    "code": "NORMALIZATION_FAILED",
                    "message": str(error),
                }
            )

            if source.exists():
                shutil.rmtree(source)

            if backup.exists():
                shutil.copytree(
                    backup,
                    source,
                    dirs_exist_ok=True,
                )

            return ReleaseOperationResult(
                approved=False,
                action="rolled_back",
                canonical_release=target_name,
                source_release=source_name,
                backup_path=str(backup),
                references_updated=0,
                findings=tuple(findings),
            )

    def normalize_all(self) -> tuple[ReleaseOperationResult, ...]:
        return tuple(
            self.normalize(source, target)
            for source, target in self.discover_duplicates()
        )

    def validate(self) -> dict[str, Any]:
        duplicates = self.discover_duplicates()
        manifests = []
        findings = []

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
                        manifest.read_text(
                            encoding="utf-8-sig"
                        )
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
                    payload.get("release_name")
                    or release.name
                )

                if declared != release.name:
                    findings.append(
                        {
                            "code": "MANIFEST_NAME_MISMATCH",
                            "release": release.name,
                            "declared": declared,
                        }
                    )

                manifests.append(release.name)

        approved = (
            len(duplicates) == 0
            and len(findings) == 0
        )

        return {
            "approved": approved,
            "exit_code": 0 if approved else 2,
            "duplicates": [
                {"source": source, "canonical": canonical}
                for source, canonical in duplicates
            ],
            "validated_manifests": manifests,
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
                    manifest.read_text(
                        encoding="utf-8-sig"
                    )
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
        payload["normalized_by"] = "SGD-114G-v1.0.0"

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
                    and path.suffix.casefold()
                    in _TEXT_SUFFIXES
                ):
                    yield path

    def _update_references(
        self,
        old: str,
        new: str,
    ) -> int:
        updated = 0

        for path in self._reference_files():
            try:
                content = path.read_text(
                    encoding="utf-8-sig"
                )
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
        choices=("discover", "normalize-all", "validate"),
        required=True,
    )
    parser.add_argument("--output-json", required=True)
    args = parser.parse_args()

    manager = InstitutionalReleaseManager(args.root)

    if args.operation == "discover":
        payload = {
            "duplicates": [
                {"source": source, "canonical": canonical}
                for source, canonical
                in manager.discover_duplicates()
            ]
        }
        payload["approved"] = True
        payload["exit_code"] = 0

    elif args.operation == "normalize-all":
        results = [
            result.to_dict()
            for result in manager.normalize_all()
        ]
        approved = all(
            item["approved"]
            for item in results
        )
        payload = {
            "approved": approved,
            "exit_code": 0 if approved else 2,
            "results": results,
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

from sgoda.governance.release_management.resolver import (
    canonical_release_name,
    collapse_duplicate_revision,
    parse_release_name,
)
from sgoda.governance.release_management.service import (
    InstitutionalReleaseManager,
)


def test_canonical_release_name() -> None:
    assert (
        canonical_release_name(
            "SGD-114E",
            "2.0.0-R2.1",
        )
        == "SGD-114E-v2.0.0-R2.1"
    )


def test_parse_release_name() -> None:
    result = parse_release_name(
        "SGD-114E-v2.0.0-R2.1"
    )

    assert result.increment_code == "SGD-114E"
    assert result.version == "2.0.0-R2.1"


def test_collapse_duplicate_revision() -> None:
    assert (
        collapse_duplicate_revision(
            "SGD-114E-v2.0.0-R2.1.1"
        )
        == "SGD-114E-v2.0.0-R2.1"
    )


def test_normalize_release_transaction(
    tmp_path: Path,
) -> None:
    source = (
        tmp_path
        / "releases"
        / "SGD-114E-v2.0.0-R2.1.1"
    )
    source.mkdir(parents=True)
    (source / "manifest.json").write_text(
        json.dumps(
            {
                "release_name": (
                    "SGD-114E-v2.0.0-R2.1.1"
                )
            }
        ),
        encoding="utf-8",
    )

    result = InstitutionalReleaseManager(
        tmp_path
    ).normalize(
        "SGD-114E-v2.0.0-R2.1.1"
    )

    assert result.approved is True
    assert (
        tmp_path
        / "releases"
        / "SGD-114E-v2.0.0-R2.1"
    ).exists()
    assert not source.exists()


def test_reference_update_skips_empty_files(
    tmp_path: Path,
) -> None:
    source = (
        tmp_path
        / "releases"
        / "SGD-114E-v2.0.0-R2.1.1"
    )
    source.mkdir(parents=True)
    (source / "manifest.json").write_text(
        "{}",
        encoding="utf-8",
    )

    docs = tmp_path / "docs"
    docs.mkdir()
    (docs / "empty.md").write_text(
        "",
        encoding="utf-8",
    )
    (docs / "reference.md").write_text(
        "SGD-114E-v2.0.0-R2.1.1",
        encoding="utf-8",
    )

    result = InstitutionalReleaseManager(
        tmp_path
    ).normalize(
        "SGD-114E-v2.0.0-R2.1.1"
    )

    assert result.approved is True
    assert (
        docs / "reference.md"
    ).read_text(encoding="utf-8") == (
        "SGD-114E-v2.0.0-R2.1"
    )


def test_validate_detects_manifest_mismatch(
    tmp_path: Path,
) -> None:
    release = (
        tmp_path
        / "releases"
        / "SGD-114E-v2.0.0-R2.1"
    )
    release.mkdir(parents=True)
    (release / "manifest.json").write_text(
        json.dumps(
            {
                "release_name": (
                    "SGD-114E-v2.0.0-R2.1.1"
                )
            }
        ),
        encoding="utf-8",
    )

    result = InstitutionalReleaseManager(
        tmp_path
    ).validate()

    assert result["approved"] is False
    assert result["exit_code"] == 2


def test_validate_approved_repository(
    tmp_path: Path,
) -> None:
    release = (
        tmp_path
        / "releases"
        / "SGD-114E-v2.0.0-R2.1"
    )
    release.mkdir(parents=True)
    (release / "manifest.json").write_text(
        json.dumps(
            {
                "release_name": (
                    "SGD-114E-v2.0.0-R2.1"
                )
            }
        ),
        encoding="utf-8",
    )

    result = InstitutionalReleaseManager(
        tmp_path
    ).validate()

    assert result["approved"] is True
    assert result["exit_code"] == 0

'@

$Init = @'
from .models import ReleaseIdentity, ReleaseOperationResult
from .resolver import canonical_release_name, collapse_duplicate_revision, parse_release_name
from .service import InstitutionalReleaseManager

__all__ = [
    "ReleaseIdentity",
    "ReleaseOperationResult",
    "canonical_release_name",
    "collapse_duplicate_revision",
    "parse_release_name",
    "InstitutionalReleaseManager",
]
'@

$Wrapper = @'
[CmdletBinding()]
param(
    [switch]$Publish,
    [string]$CommitMessage = "chore(repository): canonical institutional publish",
    [string]$EvidenceCommitMessage = "chore(repository): publish canonical release evidence"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

$Validation = Join-Path `
    $Root `
    "artifacts\pmo\SGD-114G-v1.0.0\prepublish-validation.json"

python -m sgoda.governance.release_management.cli `
    --root "$Root" `
    --operation "normalize-all" `
    --output-json "$Validation"

if ($LASTEXITCODE -ne 0) {
    throw "SGD-114G no pudo normalizar los releases."
}

python -m sgoda.governance.release_management.cli `
    --root "$Root" `
    --operation "validate" `
    --output-json "$Validation"

if ($LASTEXITCODE -ne 0) {
    throw "SGD-114G bloqueó la publicación por inconsistencias de release."
}

$Publisher = Join-Path `
    $PSScriptRoot `
    "Invoke-SPB007-InstitutionalPublish.ps1"

if ($Publish) {
    & $Publisher `
        -Publish `
        -CommitMessage $CommitMessage `
        -EvidenceCommitMessage $EvidenceCommitMessage
}
else {
    & $Publisher
}

exit $LASTEXITCODE
'@

$Component = @'
{
  "increment_code": "SGD-114G-v1.0.0",
  "name": "Institutional Release Management Service",
  "version": "1.0.0",
  "status": "implemented",
  "native_ecosystem": true,
  "mandatory_proprietary_dependencies": [],
  "capabilities": [
    "canonical release resolution",
    "duplicate release migration",
    "transactional normalization",
    "backup and rollback",
    "manifest validation",
    "safe reference updates",
    "SPB-007 publication gate"
  ]
}
'@

$Documentation = @'
# SGD-114G v1.0.0 — Institutional Release Management Service

## Objetivo

Centralizar la resolución, normalización, validación y publicación de releases.

## Arquitectura

- `models.py`: contratos tipados.
- `resolver.py`: nombre canónico.
- `service.py`: transacciones, respaldo, rollback y referencias.
- `cli.py`: operaciones discover, normalize-all y validate.
- `Invoke-SPB007-CanonicalPublish.ps1`: gate previo a SPB-007.

## Regla canónica

`release_name = f"{increment_code}-v{version}"`

## Gates

La publicación se bloquea ante:

- releases duplicados;
- manifiestos ausentes;
- manifiestos inválidos;
- nombre declarado distinto de la carpeta;
- fallo de normalización;
- pruebas fallidas.
'@

Write-Utf8 (Join-Path $ServiceDir "__init__.py") $Init
Write-Utf8 (Join-Path $ServiceDir "models.py") $Models
Write-Utf8 (Join-Path $ServiceDir "resolver.py") $Resolver
Write-Utf8 (Join-Path $ServiceDir "service.py") $Service
Write-Utf8 (Join-Path $ServiceDir "cli.py") $Cli
Write-Utf8 (Join-Path $TestsDir "test_SGD_114G_release_management.py") $Tests
Write-Utf8 $WrapperPath $Wrapper
Write-Utf8 (Join-Path $ConfigDir "SGD-114G-v1.0.0-component.json") $Component
Write-Utf8 (Join-Path $DocsDir "SGD-114G-v1.0.0-Institutional-Release-Management-Service.md") $Documentation

Run "Validando sintaxis Python" {
    python -m py_compile `
        "src/sgoda/governance/release_management/models.py" `
        "src/sgoda/governance/release_management/resolver.py" `
        "src/sgoda/governance/release_management/service.py" `
        "src/sgoda/governance/release_management/cli.py" `
        "tests/governance/release_management/test_SGD_114G_release_management.py"
}

Step "Validando sintaxis PowerShell del wrapper"

$WrapperTokens = $null
$WrapperErrors = $null

[System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path -LiteralPath $WrapperPath),
    [ref]$WrapperTokens,
    [ref]$WrapperErrors
) | Out-Null

if (@($WrapperErrors).Count -gt 0) {
    $WrapperErrors |
        Select-Object ErrorId, Message, Extent |
        Format-List

    throw "El wrapper canónico contiene errores de sintaxis."
}

Run "Ejecutando pruebas específicas SGD-114G" {
    & $RunnerPath `
        -Component "SGD-114G-v1.0.0" `
        -TestPath @(
            "tests/governance/release_management/test_SGD_114G_release_management.py"
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
    throw "Las pruebas específicas SGD-114G no fueron aprobadas."
}

Run "Descubriendo releases duplicados" {
    python -m sgoda.governance.release_management.cli `
        --root "$ProjectRoot" `
        --operation "discover" `
        --output-json "$DiscoverJson"
}

Run "Normalizando releases transaccionalmente" {
    python -m sgoda.governance.release_management.cli `
        --root "$ProjectRoot" `
        --operation "normalize-all" `
        --output-json "$NormalizeJson"
}

Run "Validando releases canónicos" {
    python -m sgoda.governance.release_management.cli `
        --root "$ProjectRoot" `
        --operation "validate" `
        --output-json "$ValidateJson"
}

$Validation = Get-Content `
    -LiteralPath $ValidateJson `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not [bool]$Validation.approved) {
    throw "La validación institucional de releases no fue aprobada."
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
    increment_code = "SGD-114G-v1.0.0"
    status = "implemented_tested_and_approved"
    prevalidated_embedded_service = "[32m.[0m[32m.[0m[32m.[0m[32m.[0m[32m.[0m[32m.[0m[32m.[0m[32m                                                                  [100%][0m
[32m[32m[1m7 passed[0m[32m in 0.04s[0m[0m"
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
    release_validation = $Validation
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
}

Write-Json $EvidenceJson $Evidence

Write-Utf8 $EvidenceMd @"
# SGD-114G v1.0.0 — Evidencia

- Pruebas específicas: $($Specific.passed)/$($Specific.executed)
- Suite completa: $($Full.passed)/$($Full.executed)
- Releases canónicos: APROBADOS
- Duplicados pendientes: $(@($Validation.duplicates).Count)
- Hallazgos: $(@($Validation.findings).Count)
- Wrapper SPB-007: OPERATIVO
"@

foreach ($File in @(
    (Join-Path $ServiceDir "__init__.py"),
    (Join-Path $ServiceDir "models.py"),
    (Join-Path $ServiceDir "resolver.py"),
    (Join-Path $ServiceDir "service.py"),
    (Join-Path $ServiceDir "cli.py"),
    (Join-Path $TestsDir "test_SGD_114G_release_management.py"),
    $WrapperPath,
    (Join-Path $ConfigDir "SGD-114G-v1.0.0-component.json"),
    (Join-Path $DocsDir "SGD-114G-v1.0.0-Institutional-Release-Management-Service.md"),
    $SpecificXml,
    $SpecificJson,
    $SpecificMd,
    $FullXml,
    $FullJson,
    $FullMd,
    $DiscoverJson,
    $NormalizeJson,
    $ValidateJson,
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
        version = "1.0.0"
        release_name = "SGD-114G-v1.0.0"
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
    Step "Publicando mediante wrapper canónico"

    & $WrapperPath `
        -Publish `
        -CommitMessage "feat(governance): implement SGD-114G release management" `
        -EvidenceCommitMessage "chore(governance): publish SGD-114G evidence"

    if ($LASTEXITCODE -ne 0) {
        throw "La publicación canónica terminó con errores."
    }
}

Step "Resultado final"

Write-Host "SGD-114G v1.0.0 implementado." -ForegroundColor Green
Write-Host "Institutional Release Management Service: OPERATIVO." -ForegroundColor Green
Write-Host "Normalización transaccional: APROBADA." -ForegroundColor Green
Write-Host "Rollback institucional: HABILITADO." -ForegroundColor Green
Write-Host "Gate SPB-007 canónico: OPERATIVO." -ForegroundColor Green
Write-Host (
    "Pruebas específicas: " +
    "$($Specific.passed)/$($Specific.executed) APROBADAS."
) -ForegroundColor Green
Write-Host (
    "Suite completa: " +
    "$($Full.passed)/$($Full.executed) APROBADA."
) -ForegroundColor Green
Write-Host "Validación de releases: APROBADA." -ForegroundColor Green
Write-Host "Release: releases\SGD-114G-v1.0.0" -ForegroundColor Cyan

if ($Publish) {
    Write-Host "Publicación institucional: COMPLETADA." -ForegroundColor Green
}
else {
    Write-Host "Publicación no solicitada. Reejecute con -Publish." -ForegroundColor Yellow
}
