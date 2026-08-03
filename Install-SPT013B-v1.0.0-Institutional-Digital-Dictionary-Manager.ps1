<#
.SYNOPSIS
    Instala SPT-013B v1.0.0 — Gestor Institucional del Diccionario Digital.

.DESCRIPTION
    Implementa el gestor institucional del diccionario para la Fase
    Tecnológica IV de SGODA-PUINAVE.

    Incluye:
      - modelos léxicos canónicos;
      - repositorio en memoria y persistencia JSON;
      - creación, actualización y consulta de entradas;
      - variantes dialectales;
      - categorías gramaticales;
      - familias léxicas;
      - sinónimos y antónimos;
      - ejemplos de uso;
      - búsqueda multilingüe;
      - validación institucional;
      - importación y exportación JSON;
      - CLI y demostración;
      - pruebas específicas;
      - suite completa;
      - SGD-114D, SGD-114E, SGD-115 y SGD-116;
      - evidencia, release y publicación condicionada.

.PARAMETER ProjectRoot
    Raíz del repositorio.

.PARAMETER SkipFullSuite
    Omite la suite completa. No recomendado.

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

$SourceDir = Join-Path $ProjectRoot "src\sgoda\dictionary_manager"
$TestsDir = Join-Path $ProjectRoot "tests\dictionary_manager"
$ConfigDir = Join-Path $ProjectRoot "config\dictionary_manager"
$DocsDir = Join-Path $ProjectRoot "docs\08_Fase_Tecnologica_IV\SPT-013B"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\dictionary_manager\SPT-013B"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-013B"
$ReleaseDir = Join-Path $ProjectRoot "releases\SPT-013B-v1.0.0"
$ScriptsDir = Join-Path $ProjectRoot "scripts"

$BackupDir = Join-Path `
    $PmoDir `
    ("backups\pre-SPT013B-" + (Get-Date -Format "yyyyMMdd-HHmmss"))

$ModelsPath = Join-Path $SourceDir "models.py"
$ValidationPath = Join-Path $SourceDir "validation.py"
$RepositoryPath = Join-Path $SourceDir "repository.py"
$ServicePath = Join-Path $SourceDir "service.py"
$ImportExportPath = Join-Path $SourceDir "import_export.py"
$CliPath = Join-Path $SourceDir "cli.py"
$InitPath = Join-Path $SourceDir "__init__.py"

$TestPath = Join-Path `
    $TestsDir `
    "test_SPT_013B_institutional_digital_dictionary_manager.py"

$ComponentPath = Join-Path `
    $ConfigDir `
    "SPT-013B-component.json"

$PolicyPath = Join-Path `
    $ConfigDir `
    "SPT-013B-policy.json"

$SchemaPath = Join-Path `
    $ConfigDir `
    "SPT-013B-entry-schema.json"

$InvokePath = Join-Path `
    $ScriptsDir `
    "Invoke-SPT013B-DictionaryManager.ps1"

$DemoInputPath = Join-Path $ArtifactsDir "demo-input.json"
$DemoOutputPath = Join-Path $ArtifactsDir "demo-output.json"
$DemoExportPath = Join-Path $ArtifactsDir "demo-export.json"

$PolicyJson = Join-Path $PmoDir "SPT-013B-policy-result.json"
$PolicyMd = Join-Path $PmoDir "SPT-013B-policy-result.md"
$NativeJson = Join-Path $PmoDir "SPT-013B-native-result.json"
$NativeMd = Join-Path $PmoDir "SPT-013B-native-result.md"
$EvidencePath = Join-Path $PmoDir "SPT-013B-implementation-evidence.json"

Write-Step "Validando línea base institucional"

foreach ($Required in @(
    (Join-Path $ProjectRoot "pytest.ini"),
    (Join-Path $ProjectRoot "src\sgoda\learning_foundation\service.py"),
    (Join-Path $ProjectRoot "src\sgoda\learning_platform\service.py"),
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

foreach ($Affected in @(
    $ModelsPath,
    $ValidationPath,
    $RepositoryPath,
    $ServicePath,
    $ImportExportPath,
    $CliPath,
    $InitPath,
    $TestPath,
    $ComponentPath,
    $PolicyPath,
    $SchemaPath,
    $InvokePath
)) {
    Backup-File `
        -Source $Affected `
        -BackupDirectory $BackupDir `
        -Root $ProjectRoot
}

$Models = @'
"""Modelos institucionales de SPT-013B."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class LexicalExample:
    language: str
    text: str
    translation: str | None = None


@dataclass(frozen=True, slots=True)
class LexicalEntry:
    entry_id: str
    puinave: str
    spanish: str
    english_us: str = ""
    italian: str = ""
    grammatical_category: str = ""
    lexical_family: str = ""
    dialectal_variants: tuple[str, ...] = ()
    synonyms: tuple[str, ...] = ()
    antonyms: tuple[str, ...] = ()
    examples: tuple[LexicalExample, ...] = ()
    validated: bool = False
    cultural_validation_required: bool = True
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class DictionaryCommand:
    operation: str
    payload: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class DictionaryResult:
    operation: str
    status: str
    data: dict[str, Any]
    warnings: tuple[str, ...] = ()
    no_invention: bool = True
'@

$Validation = @'
"""Validación institucional de entradas léxicas."""

from __future__ import annotations

import re
from typing import Any


_ENTRY_ID = re.compile(r"^LEX-\d{3,}$")


def normalize_text(value: Any) -> str:
    return " ".join(str(value or "").strip().split())


def normalize_list(value: Any) -> tuple[str, ...]:
    if value is None:
        return ()

    if isinstance(value, str):
        values = [value]
    elif isinstance(value, (list, tuple, set)):
        values = list(value)
    else:
        values = [value]

    normalized = []

    for item in values:
        text = normalize_text(item)

        if text and text not in normalized:
            normalized.append(text)

    return tuple(normalized)


def validate_entry_payload(
    payload: dict[str, Any],
) -> tuple[str, ...]:
    errors = []

    entry_id = normalize_text(payload.get("entry_id"))
    puinave = normalize_text(payload.get("puinave"))
    spanish = normalize_text(payload.get("spanish"))

    if not _ENTRY_ID.fullmatch(entry_id):
        errors.append(
            "entry_id debe cumplir el formato LEX-000."
        )

    if not puinave:
        errors.append("La forma Puinave es obligatoria.")

    if not spanish:
        errors.append("La traducción al español es obligatoria.")

    return tuple(errors)
'@

$Repository = @'
"""Repositorio institucional del diccionario."""

from __future__ import annotations

from dataclasses import replace

from .models import LexicalEntry


class DictionaryRepository:
    def __init__(self) -> None:
        self._entries: dict[str, LexicalEntry] = {}

    def add(self, entry: LexicalEntry) -> LexicalEntry:
        if entry.entry_id in self._entries:
            raise ValueError(
                f"La entrada ya existe: {entry.entry_id}"
            )

        self._entries[entry.entry_id] = entry
        return entry

    def upsert(self, entry: LexicalEntry) -> LexicalEntry:
        self._entries[entry.entry_id] = entry
        return entry

    def get(self, entry_id: str) -> LexicalEntry | None:
        return self._entries.get(str(entry_id or "").strip())

    def all(self) -> tuple[LexicalEntry, ...]:
        return tuple(
            self._entries[key]
            for key in sorted(self._entries)
        )

    def update(
        self,
        entry_id: str,
        **changes,
    ) -> LexicalEntry:
        current = self.get(entry_id)

        if current is None:
            raise KeyError(entry_id)

        updated = replace(current, **changes)
        self._entries[entry_id] = updated
        return updated

    def search(self, query: str) -> tuple[LexicalEntry, ...]:
        needle = str(query or "").strip().casefold()

        if not needle:
            return self.all()

        results = []

        for entry in self.all():
            haystack = " ".join(
                [
                    entry.puinave,
                    entry.spanish,
                    entry.english_us,
                    entry.italian,
                    entry.grammatical_category,
                    entry.lexical_family,
                    " ".join(entry.dialectal_variants),
                    " ".join(entry.synonyms),
                    " ".join(entry.antonyms),
                ]
            ).casefold()

            if needle in haystack:
                results.append(entry)

        return tuple(results)
'@

$ImportExport = @'
"""Importación y exportación JSON de SPT-013B."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .models import LexicalEntry, LexicalExample
from .validation import normalize_list, normalize_text


def entry_from_dict(payload: dict[str, Any]) -> LexicalEntry:
    examples = []

    for item in payload.get("examples", []) or []:
        if not isinstance(item, dict):
            continue

        examples.append(
            LexicalExample(
                language=normalize_text(item.get("language")),
                text=normalize_text(item.get("text")),
                translation=(
                    normalize_text(item.get("translation"))
                    or None
                ),
            )
        )

    return LexicalEntry(
        entry_id=normalize_text(payload.get("entry_id")),
        puinave=normalize_text(payload.get("puinave")),
        spanish=normalize_text(payload.get("spanish")),
        english_us=normalize_text(payload.get("english_us")),
        italian=normalize_text(payload.get("italian")),
        grammatical_category=normalize_text(
            payload.get("grammatical_category")
        ),
        lexical_family=normalize_text(
            payload.get("lexical_family")
        ),
        dialectal_variants=normalize_list(
            payload.get("dialectal_variants")
        ),
        synonyms=normalize_list(payload.get("synonyms")),
        antonyms=normalize_list(payload.get("antonyms")),
        examples=tuple(examples),
        validated=bool(payload.get("validated", False)),
        cultural_validation_required=bool(
            payload.get(
                "cultural_validation_required",
                True,
            )
        ),
        metadata=dict(payload.get("metadata") or {}),
    )


def entry_to_dict(entry: LexicalEntry) -> dict[str, Any]:
    return {
        "entry_id": entry.entry_id,
        "puinave": entry.puinave,
        "spanish": entry.spanish,
        "english_us": entry.english_us,
        "italian": entry.italian,
        "grammatical_category": entry.grammatical_category,
        "lexical_family": entry.lexical_family,
        "dialectal_variants": list(entry.dialectal_variants),
        "synonyms": list(entry.synonyms),
        "antonyms": list(entry.antonyms),
        "examples": [
            {
                "language": item.language,
                "text": item.text,
                "translation": item.translation,
            }
            for item in entry.examples
        ],
        "validated": entry.validated,
        "cultural_validation_required": (
            entry.cultural_validation_required
        ),
        "metadata": dict(entry.metadata),
    }


def load_entries(path: str | Path) -> tuple[LexicalEntry, ...]:
    payload = json.loads(
        Path(path).read_text(encoding="utf-8-sig")
    )

    records = (
        payload.get("entries", [])
        if isinstance(payload, dict)
        else payload
    )

    if not isinstance(records, list):
        raise ValueError(
            "El archivo debe contener una lista de entradas."
        )

    return tuple(
        entry_from_dict(item)
        for item in records
        if isinstance(item, dict)
    )


def export_entries(
    path: str | Path,
    entries: tuple[LexicalEntry, ...],
) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(
        json.dumps(
            {
                "schema": "SPT-013B",
                "version": "1.0.0",
                "entries": [
                    entry_to_dict(item)
                    for item in entries
                ],
            },
            indent=2,
            ensure_ascii=False,
        ) + "\n",
        encoding="utf-8",
    )
'@

$Service = @'
"""Servicio principal del gestor institucional del diccionario."""

from __future__ import annotations

from typing import Any

from .import_export import (
    entry_from_dict,
    entry_to_dict,
    export_entries,
    load_entries,
)
from .models import DictionaryCommand, DictionaryResult
from .repository import DictionaryRepository
from .validation import validate_entry_payload


class InstitutionalDictionaryManager:
    def __init__(
        self,
        repository: DictionaryRepository | None = None,
    ) -> None:
        self.repository = repository or DictionaryRepository()

    def execute(
        self,
        command: DictionaryCommand,
    ) -> DictionaryResult:
        handlers = {
            "create": self._create,
            "upsert": self._upsert,
            "get": self._get,
            "search": self._search,
            "list": self._list,
            "import_json": self._import_json,
            "export_json": self._export_json,
            "stats": self._stats,
        }

        handler = handlers.get(command.operation)

        if handler is None:
            return DictionaryResult(
                operation=command.operation,
                status="unsupported_operation",
                data={},
                warnings=("La operación no está soportada.",),
            )

        return handler(command.payload)

    def _create(
        self,
        payload: dict[str, Any],
    ) -> DictionaryResult:
        errors = validate_entry_payload(payload)

        if errors:
            return DictionaryResult(
                operation="create",
                status="invalid_entry",
                data={"errors": list(errors)},
                warnings=errors,
            )

        entry = entry_from_dict(payload)

        try:
            self.repository.add(entry)
        except ValueError as error:
            return DictionaryResult(
                operation="create",
                status="duplicate",
                data={"entry_id": entry.entry_id},
                warnings=(str(error),),
            )

        return DictionaryResult(
            operation="create",
            status="ok",
            data=entry_to_dict(entry),
            sources=(f"RLB:{entry.entry_id}",)
            if False
            else (),
        )

    def _upsert(
        self,
        payload: dict[str, Any],
    ) -> DictionaryResult:
        errors = validate_entry_payload(payload)

        if errors:
            return DictionaryResult(
                operation="upsert",
                status="invalid_entry",
                data={"errors": list(errors)},
                warnings=errors,
            )

        entry = self.repository.upsert(
            entry_from_dict(payload)
        )

        return DictionaryResult(
            operation="upsert",
            status="ok",
            data=entry_to_dict(entry),
        )

    def _get(
        self,
        payload: dict[str, Any],
    ) -> DictionaryResult:
        entry_id = str(payload.get("entry_id") or "").strip()
        entry = self.repository.get(entry_id)

        if entry is None:
            return DictionaryResult(
                operation="get",
                status="not_found",
                data={"entry_id": entry_id},
            )

        return DictionaryResult(
            operation="get",
            status="ok",
            data=entry_to_dict(entry),
        )

    def _search(
        self,
        payload: dict[str, Any],
    ) -> DictionaryResult:
        query = str(payload.get("query") or "")
        results = self.repository.search(query)

        return DictionaryResult(
            operation="search",
            status="ok",
            data={
                "query": query,
                "total": len(results),
                "results": [
                    entry_to_dict(item)
                    for item in results
                ],
            },
        )

    def _list(
        self,
        payload: dict[str, Any],
    ) -> DictionaryResult:
        entries = self.repository.all()

        return DictionaryResult(
            operation="list",
            status="ok",
            data={
                "total": len(entries),
                "entries": [
                    entry_to_dict(item)
                    for item in entries
                ],
            },
        )

    def _import_json(
        self,
        payload: dict[str, Any],
    ) -> DictionaryResult:
        path = str(payload.get("path") or "").strip()
        imported = 0
        rejected = []

        for entry in load_entries(path):
            raw = entry_to_dict(entry)
            errors = validate_entry_payload(raw)

            if errors:
                rejected.append(
                    {
                        "entry_id": entry.entry_id,
                        "errors": list(errors),
                    }
                )
                continue

            self.repository.upsert(entry)
            imported += 1

        return DictionaryResult(
            operation="import_json",
            status="ok",
            data={
                "imported": imported,
                "rejected": rejected,
            },
        )

    def _export_json(
        self,
        payload: dict[str, Any],
    ) -> DictionaryResult:
        path = str(payload.get("path") or "").strip()
        export_entries(path, self.repository.all())

        return DictionaryResult(
            operation="export_json",
            status="ok",
            data={
                "path": path,
                "total": len(self.repository.all()),
            },
        )

    def _stats(
        self,
        payload: dict[str, Any],
    ) -> DictionaryResult:
        entries = self.repository.all()

        return DictionaryResult(
            operation="stats",
            status="ok",
            data={
                "total": len(entries),
                "validated": sum(
                    1 for item in entries if item.validated
                ),
                "pending_validation": sum(
                    1 for item in entries if not item.validated
                ),
                "with_variants": sum(
                    1
                    for item in entries
                    if item.dialectal_variants
                ),
                "with_examples": sum(
                    1 for item in entries if item.examples
                ),
            },
        )
'@

# Fix accidental unsupported field before writing.
$Service = $Service.Replace(
    @'
        return DictionaryResult(
            operation="create",
            status="ok",
            data=entry_to_dict(entry),
            sources=(f"RLB:{entry.entry_id}",)
            if False
            else (),
        )
'@,
    @'
        return DictionaryResult(
            operation="create",
            status="ok",
            data=entry_to_dict(entry),
        )
'@
)

$Cli = @'
"""CLI de SPT-013B."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .models import DictionaryCommand
from .service import InstitutionalDictionaryManager


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--request-file", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    request = json.loads(
        Path(args.request_file).read_text(
            encoding="utf-8-sig"
        )
    )

    manager = InstitutionalDictionaryManager()
    response = manager.execute(
        DictionaryCommand(
            operation=str(request["operation"]),
            payload=dict(request.get("payload") or {}),
        )
    )

    result = {
        "operation": response.operation,
        "status": response.status,
        "data": response.data,
        "warnings": list(response.warnings),
        "no_invention": response.no_invention,
    }

    target = Path(args.output)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(
        json.dumps(
            result,
            indent=2,
            ensure_ascii=False,
        ) + "\n",
        encoding="utf-8",
    )

    print("SPT-013B ejecutado correctamente.")
    print(f"Operación: {response.operation}")
    print(f"Estado: {response.status}")
    print(f"Resultado: {target}")

    return 0 if response.status == "ok" else 2


if __name__ == "__main__":
    raise SystemExit(main())
'@

$Init = @'
"""SPT-013B — Gestor Institucional del Diccionario Digital."""

from .import_export import (
    entry_from_dict,
    entry_to_dict,
    export_entries,
    load_entries,
)
from .models import (
    DictionaryCommand,
    DictionaryResult,
    LexicalEntry,
    LexicalExample,
)
from .repository import DictionaryRepository
from .service import InstitutionalDictionaryManager

__all__ = [
    "DictionaryCommand",
    "DictionaryRepository",
    "DictionaryResult",
    "InstitutionalDictionaryManager",
    "LexicalEntry",
    "LexicalExample",
    "entry_from_dict",
    "entry_to_dict",
    "export_entries",
    "load_entries",
]
'@

$Tests = @'
from __future__ import annotations

import json
from pathlib import Path

from sgoda.dictionary_manager import (
    DictionaryCommand,
    InstitutionalDictionaryManager,
)


def _entry() -> dict:
    return {
        "entry_id": "LEX-001",
        "puinave": "AMDA",
        "spanish": "casa",
        "english_us": "house",
        "italian": "casa",
        "grammatical_category": "sustantivo",
        "lexical_family": "vivienda",
        "dialectal_variants": ["amda"],
        "synonyms": ["hogar"],
        "antonyms": [],
        "examples": [
            {
                "language": "pu",
                "text": "AMDA",
                "translation": "casa",
            }
        ],
        "validated": True,
    }


def test_SPT_013B_creates_entry() -> None:
    manager = InstitutionalDictionaryManager()
    result = manager.execute(
        DictionaryCommand(
            operation="create",
            payload=_entry(),
        )
    )

    assert result.status == "ok"
    assert result.data["entry_id"] == "LEX-001"


def test_SPT_013B_rejects_invalid_id() -> None:
    manager = InstitutionalDictionaryManager()
    payload = _entry()
    payload["entry_id"] = "BAD"

    result = manager.execute(
        DictionaryCommand(
            operation="create",
            payload=payload,
        )
    )

    assert result.status == "invalid_entry"


def test_SPT_013B_requires_puinave() -> None:
    manager = InstitutionalDictionaryManager()
    payload = _entry()
    payload["puinave"] = ""

    result = manager.execute(
        DictionaryCommand(
            operation="create",
            payload=payload,
        )
    )

    assert result.status == "invalid_entry"


def test_SPT_013B_requires_spanish() -> None:
    manager = InstitutionalDictionaryManager()
    payload = _entry()
    payload["spanish"] = ""

    result = manager.execute(
        DictionaryCommand(
            operation="create",
            payload=payload,
        )
    )

    assert result.status == "invalid_entry"


def test_SPT_013B_rejects_duplicate() -> None:
    manager = InstitutionalDictionaryManager()
    command = DictionaryCommand(
        operation="create",
        payload=_entry(),
    )
    manager.execute(command)

    result = manager.execute(command)

    assert result.status == "duplicate"


def test_SPT_013B_gets_entry() -> None:
    manager = InstitutionalDictionaryManager()
    manager.execute(
        DictionaryCommand(
            operation="create",
            payload=_entry(),
        )
    )

    result = manager.execute(
        DictionaryCommand(
            operation="get",
            payload={"entry_id": "LEX-001"},
        )
    )

    assert result.status == "ok"
    assert result.data["puinave"] == "AMDA"


def test_SPT_013B_searches_spanish() -> None:
    manager = InstitutionalDictionaryManager()
    manager.execute(
        DictionaryCommand(
            operation="create",
            payload=_entry(),
        )
    )

    result = manager.execute(
        DictionaryCommand(
            operation="search",
            payload={"query": "casa"},
        )
    )

    assert result.data["total"] == 1


def test_SPT_013B_searches_english() -> None:
    manager = InstitutionalDictionaryManager()
    manager.execute(
        DictionaryCommand(
            operation="create",
            payload=_entry(),
        )
    )

    result = manager.execute(
        DictionaryCommand(
            operation="search",
            payload={"query": "house"},
        )
    )

    assert result.data["total"] == 1


def test_SPT_013B_preserves_variants() -> None:
    manager = InstitutionalDictionaryManager()
    result = manager.execute(
        DictionaryCommand(
            operation="create",
            payload=_entry(),
        )
    )

    assert result.data["dialectal_variants"] == ["amda"]


def test_SPT_013B_preserves_examples() -> None:
    manager = InstitutionalDictionaryManager()
    result = manager.execute(
        DictionaryCommand(
            operation="create",
            payload=_entry(),
        )
    )

    assert len(result.data["examples"]) == 1


def test_SPT_013B_reports_stats() -> None:
    manager = InstitutionalDictionaryManager()
    manager.execute(
        DictionaryCommand(
            operation="create",
            payload=_entry(),
        )
    )

    result = manager.execute(
        DictionaryCommand(operation="stats")
    )

    assert result.data["total"] == 1
    assert result.data["validated"] == 1


def test_SPT_013B_imports_json(tmp_path: Path) -> None:
    source = tmp_path / "dictionary.json"
    source.write_text(
        json.dumps({"entries": [_entry()]}),
        encoding="utf-8",
    )

    manager = InstitutionalDictionaryManager()
    result = manager.execute(
        DictionaryCommand(
            operation="import_json",
            payload={"path": str(source)},
        )
    )

    assert result.status == "ok"
    assert result.data["imported"] == 1


def test_SPT_013B_exports_json(tmp_path: Path) -> None:
    manager = InstitutionalDictionaryManager()
    manager.execute(
        DictionaryCommand(
            operation="create",
            payload=_entry(),
        )
    )

    target = tmp_path / "export.json"
    result = manager.execute(
        DictionaryCommand(
            operation="export_json",
            payload={"path": str(target)},
        )
    )

    assert result.status == "ok"
    assert target.exists()


def test_SPT_013B_upserts_entry() -> None:
    manager = InstitutionalDictionaryManager()
    manager.execute(
        DictionaryCommand(
            operation="create",
            payload=_entry(),
        )
    )
    payload = _entry()
    payload["spanish"] = "hogar"

    result = manager.execute(
        DictionaryCommand(
            operation="upsert",
            payload=payload,
        )
    )

    assert result.data["spanish"] == "hogar"


def test_SPT_013B_preserves_no_invention() -> None:
    manager = InstitutionalDictionaryManager()
    result = manager.execute(
        DictionaryCommand(operation="list")
    )

    assert result.no_invention is True


def test_SPT_013B_rejects_unknown_operation() -> None:
    manager = InstitutionalDictionaryManager()
    result = manager.execute(
        DictionaryCommand(operation="unknown")
    )

    assert result.status == "unsupported_operation"
'@

$Component = @'
{
  "increment_code": "SPT-013B",
  "name": "Gestor Institucional del Diccionario Digital",
  "component_type": "institutional_dictionary_manager",
  "version": "1.0.0",
  "status": "implemented",
  "phase": "Fase Tecnológica IV",
  "native_ecosystem": true,
  "ecosystem_role": "native_component",
  "technology_policy": "free_open_optional_proprietary",
  "mandatory_proprietary_dependencies": [],
  "institutional_terminology": "integrado nativamente al ecosistema SGODA-PUINAVE",
  "dependencies": [
    "SPT-013A",
    "SPT-012",
    "SPT-007A",
    "SPT-007B",
    "SGD-114D",
    "SGD-114E",
    "SGD-115A",
    "SGD-116"
  ],
  "source": [
    "src/sgoda/dictionary_manager/models.py",
    "src/sgoda/dictionary_manager/validation.py",
    "src/sgoda/dictionary_manager/repository.py",
    "src/sgoda/dictionary_manager/import_export.py",
    "src/sgoda/dictionary_manager/service.py",
    "src/sgoda/dictionary_manager/cli.py"
  ],
  "tests": [
    "tests/dictionary_manager/test_SPT_013B_institutional_digital_dictionary_manager.py"
  ],
  "documentation": [
    "docs/08_Fase_Tecnologica_IV/SPT-013B/SPT-013B-Arquitectura.md",
    "docs/08_Fase_Tecnologica_IV/SPT-013B/SPT-013B-Modelo-Lexico.md",
    "docs/08_Fase_Tecnologica_IV/SPT-013B/SPT-013B-Importacion-Exportacion.md"
  ]
}
'@

$Policy = @'
{
  "component": "SPT-013B",
  "version": "1.0.0",
  "validated_entries_only_for_publication": true,
  "cultural_validation_required": true,
  "no_invention": true,
  "local_first": true,
  "free_open_technology": true,
  "mandatory_proprietary_dependencies": [],
  "supported_languages": [
    "pu",
    "es",
    "en-US",
    "it"
  ]
}
'@

$Schema = @'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "SPT-013B Lexical Entry",
  "type": "object",
  "required": [
    "entry_id",
    "puinave",
    "spanish"
  ],
  "properties": {
    "entry_id": {
      "type": "string",
      "pattern": "^LEX-[0-9]{3,}$"
    },
    "puinave": {
      "type": "string",
      "minLength": 1
    },
    "spanish": {
      "type": "string",
      "minLength": 1
    },
    "english_us": {
      "type": "string"
    },
    "italian": {
      "type": "string"
    },
    "validated": {
      "type": "boolean"
    }
  }
}
'@

$Docs = @{
    (Join-Path $DocsDir "SPT-013B-Arquitectura.md") = @'
# SPT-013B — Arquitectura

SPT-013B implementa el Gestor Institucional del Diccionario Digital sobre
SPT-013A y SPT-012.

El componente administra entradas léxicas, búsqueda, validación,
importación, exportación y trazabilidad bajo una arquitectura local-first.
'@

    (Join-Path $DocsDir "SPT-013B-Modelo-Lexico.md") = @'
# SPT-013B — Modelo léxico institucional

Cada entrada contiene:

- identificador LEX;
- forma Puinave;
- español;
- inglés americano;
- italiano;
- categoría gramatical;
- familia léxica;
- variantes dialectales;
- sinónimos;
- antónimos;
- ejemplos de uso;
- estado de validación;
- metadatos culturales.
'@

    (Join-Path $DocsDir "SPT-013B-Importacion-Exportacion.md") = @'
# SPT-013B — Importación y exportación

El formato de intercambio institucional es JSON UTF-8.

La importación valida los campos obligatorios. La exportación conserva
todas las relaciones léxicas y metadatos sin inventar información.
'@
}

$Invoke = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RequestFile,

    [string]$Output = "artifacts/dictionary_manager/SPT-013B/result.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

& python -m sgoda.dictionary_manager.cli `
    --request-file "$RequestFile" `
    --output "$Output"

exit $LASTEXITCODE
'@

Write-Step "Instalando SPT-013B"

Write-Utf8 -Path $ModelsPath -Content $Models
Write-Utf8 -Path $ValidationPath -Content $Validation
Write-Utf8 -Path $RepositoryPath -Content $Repository
Write-Utf8 -Path $ImportExportPath -Content $ImportExport
Write-Utf8 -Path $ServicePath -Content $Service
Write-Utf8 -Path $CliPath -Content $Cli
Write-Utf8 -Path $InitPath -Content $Init
Write-Utf8 -Path $TestPath -Content $Tests
Write-Utf8 -Path $ComponentPath -Content $Component
Write-Utf8 -Path $PolicyPath -Content $Policy
Write-Utf8 -Path $SchemaPath -Content $Schema
Write-Utf8 -Path $InvokePath -Content $Invoke

foreach ($Document in $Docs.GetEnumerator()) {
    Write-Utf8 `
        -Path $Document.Key `
        -Content $Document.Value
}

Invoke-Checked "Validando sintaxis Python" {
    python -m py_compile `
        "src/sgoda/dictionary_manager/models.py" `
        "src/sgoda/dictionary_manager/validation.py" `
        "src/sgoda/dictionary_manager/repository.py" `
        "src/sgoda/dictionary_manager/import_export.py" `
        "src/sgoda/dictionary_manager/service.py" `
        "src/sgoda/dictionary_manager/cli.py" `
        "src/sgoda/dictionary_manager/__init__.py" `
        "tests/dictionary_manager/test_SPT_013B_institutional_digital_dictionary_manager.py"
}

Invoke-Checked "Ejecutando 16 pruebas específicas SPT-013B" {
    python -m pytest `
        "tests/dictionary_manager/test_SPT_013B_institutional_digital_dictionary_manager.py" `
        -q
}

if (-not $SkipFullSuite) {
    Invoke-Checked "Ejecutando suite completa" {
        python -m pytest
    }
}

Write-Step "Ejecutando demostración institucional"

Write-Json `
    -Path $DemoInputPath `
    -Value ([ordered]@{
        operation = "create"
        payload = [ordered]@{
            entry_id = "LEX-001"
            puinave = "AMDA"
            spanish = "casa"
            english_us = "house"
            italian = "casa"
            grammatical_category = "sustantivo"
            lexical_family = "vivienda"
            dialectal_variants = @("amda")
            synonyms = @("hogar")
            antonyms = @()
            examples = @(
                [ordered]@{
                    language = "pu"
                    text = "AMDA"
                    translation = "casa"
                }
            )
            validated = $true
        }
    })

Invoke-Checked "Creando entrada demostrativa AMDA" {
    python -m sgoda.dictionary_manager.cli `
        --request-file "$DemoInputPath" `
        --output "$DemoOutputPath"
}

$Demo = Get-Content `
    -LiteralPath $DemoOutputPath `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if ($Demo.status -ne "ok") {
    throw "La demostración SPT-013B no fue aprobada."
}

if ($Demo.data.entry_id -ne "LEX-001") {
    throw "La demostración no generó LEX-001."
}

if ($Demo.data.puinave -ne "AMDA") {
    throw "La demostración no preservó AMDA."
}

Write-Step "Generando evidencia y release"

New-Item -ItemType Directory -Path $PmoDir -Force | Out-Null
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

Write-Json `
    -Path $EvidencePath `
    -Value ([ordered]@{
        increment_code = "SPT-013B"
        version = "1.0.0"
        status = "implemented_and_tested"
        generated_at_utc = [DateTime]::UtcNow.ToString("o")
        specific_tests = 16
        full_suite_executed = (-not $SkipFullSuite)
        demo_status = $Demo.status
        demo_entry_id = $Demo.data.entry_id
        demo_puinave = $Demo.data.puinave
        no_invention = [bool]$Demo.no_invention
        backup = $BackupDir
    })

foreach ($ReleaseFile in @(
    $ModelsPath,
    $ValidationPath,
    $RepositoryPath,
    $ImportExportPath,
    $ServicePath,
    $CliPath,
    $InitPath,
    $TestPath,
    $ComponentPath,
    $PolicyPath,
    $SchemaPath,
    $InvokePath,
    $DemoInputPath,
    $DemoOutputPath,
    $EvidencePath
)) {
    Require-File -Path $ReleaseFile

    Copy-Item `
        -LiteralPath $ReleaseFile `
        -Destination $ReleaseDir `
        -Force
}

foreach ($Document in $Docs.Keys) {
    Require-File -Path $Document

    Copy-Item `
        -LiteralPath $Document `
        -Destination $ReleaseDir `
        -Force
}

Write-Json `
    -Path (Join-Path $ReleaseDir "manifest.json") `
    -Value ([ordered]@{
        increment_code = "SPT-013B"
        version = "1.0.0"
        status = "implemented_and_tested"
        files = @(
            Get-ChildItem `
                -LiteralPath $ReleaseDir `
                -File |
            Select-Object -ExpandProperty Name
        )
    })

Write-Step "Evaluando SPT-013B mediante SGD-114D"

& python -m sgoda.governance.adaptive_policy_cli `
    --root "$ProjectRoot" `
    --increment "SPT-013B" `
    --output-json "$PolicyJson" `
    --output-md "$PolicyMd"

if ($LASTEXITCODE -ne 0) {
    throw "SGD-114D no aprobó SPT-013B."
}

Write-Step "Evaluando arquitectura nativa mediante SGD-114E"

& python -m sgoda.governance.native_ecosystem_cli `
    --root "$ProjectRoot" `
    --output-json "$NativeJson" `
    --output-md "$NativeMd"

if ($LASTEXITCODE -ne 0) {
    throw "SGD-114E no aprobó SPT-013B."
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
            "feat(dictionary): implement SPT-013B institutional dictionary manager"
        ) `
        -EvidenceCommitMessage (
            "chore(dictionary): publish SPT-013B evidence"
        )

    if ($LASTEXITCODE -ne 0) {
        throw "SPB-007 terminó con errores."
    }
}

Write-Step "Resultado final"

Write-Host "SPT-013B v1.0.0 implementado." -ForegroundColor Green
Write-Host "Gestor Institucional del Diccionario Digital: OPERATIVO." `
    -ForegroundColor Green
Write-Host "Modelo léxico institucional: IMPLEMENTADO." `
    -ForegroundColor Green
Write-Host "Búsqueda multilingüe: IMPLEMENTADA." `
    -ForegroundColor Green
Write-Host "Variantes, familias y relaciones léxicas: IMPLEMENTADAS." `
    -ForegroundColor Green
Write-Host "Importación y exportación JSON: IMPLEMENTADAS." `
    -ForegroundColor Green
Write-Host "Pruebas específicas: 16 APROBADAS." `
    -ForegroundColor Green

if (-not $SkipFullSuite) {
    Write-Host "Suite completa: APROBADA." `
        -ForegroundColor Green
}

Write-Host "Demostración AMDA: APROBADA." `
    -ForegroundColor Green
Write-Host "SGD-114D: APROBADO." -ForegroundColor Green
Write-Host "SGD-114E: APROBADO." -ForegroundColor Green
Write-Host "SGD-115: ACTUALIZADO." -ForegroundColor Green
Write-Host "SGD-116: ACTUALIZADO." -ForegroundColor Green
Write-Host "Release: releases\SPT-013B-v1.0.0" `
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
        "Publicación no solicitada. Reejecute el mismo " +
        "instalador con -Publish después de revisar el resultado."
    ) -ForegroundColor Yellow
}
