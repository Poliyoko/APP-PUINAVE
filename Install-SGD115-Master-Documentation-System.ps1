<#
.SYNOPSIS
    Implementa SGD-115 — Sistema Maestro de Documentación del Proyecto.

.DESCRIPTION
    Instala desde un solo archivo:
      - Índice Maestro del repositorio;
      - Documento Maestro de Arquitectura;
      - Registro Maestro de Componentes;
      - inventario automático de componentes;
      - validación de enlaces y rutas documentales;
      - validación de trazabilidad;
      - pruebas automatizadas;
      - documentación institucional;
      - evidencias, dashboard, release y quality gate SGD-114.

.PARAMETER ProjectRoot
    Ruta raíz del repositorio SGODA-PUINAVE.

.PARAMETER SkipFullSuite
    Omite la suite completa. Las pruebas específicas siempre se ejecutan.

.EXAMPLE
    .\Install-SGD115-Master-Documentation-System.ps1
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipFullSuite
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

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)

    $Parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se pudo crear: $Path"
    }

    $Info = Get-Item -LiteralPath $Path
    if ($Info.Length -le 0) {
        throw "El archivo quedó vacío: $Path"
    }

    Write-Host "Creado: $Path ($($Info.Length) bytes)" -ForegroundColor Green
}

function Write-JsonUtf8 {
    param([string]$Path, [object]$Data)

    $Parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    $Json = $Data | ConvertTo-Json -Depth 50
    [System.IO.File]::WriteAllText(
        $Path,
        $Json + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$SourceDir = Join-Path $ProjectRoot "src\sgoda\documentation"
$TestsDir = Join-Path $ProjectRoot "tests\documentation"
$ConfigDir = Join-Path $ProjectRoot "config\governance"
$DocsRoot = Join-Path $ProjectRoot "docs"
$GovDocsDir = Join-Path $DocsRoot "01_Gobierno"
$ScriptsDir = Join-Path $ProjectRoot "scripts"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\documentation\SGD-115"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SGD-115"
$DashboardDir = Join-Path $ProjectRoot "dashboard"
$ReleaseDir = Join-Path $ProjectRoot "releases\SGD-115-v1.0.0"

$ModulePath = Join-Path $SourceDir "master_docs.py"
$InitPath = Join-Path $SourceDir "__init__.py"
$TestPath = Join-Path $TestsDir "test_SGD_115_master_documentation.py"
$PolicyPath = Join-Path $ConfigDir "SGD-115-master-documentation-policy.json"
$ComponentPath = Join-Path $ConfigDir "SGD-115-component.json"
$IndexPath = Join-Path $DocsRoot "00_INDICE_MAESTRO.md"
$ArchitecturePath = Join-Path $DocsRoot "00_ARQUITECTURA_MAESTRA.md"
$RegistryPath = Join-Path $DocsRoot "00_REGISTRO_MAESTRO_COMPONENTES.md"
$ImplementationDocPath = Join-Path $GovDocsDir "SGD-115-Sistema-Maestro-Documentacion.md"
$InvokePath = Join-Path $ScriptsDir "Invoke-SGD115-MasterDocumentation.ps1"
$EvidencePath = Join-Path $PmoDir "implementation-evidence.json"
$TracePath = Join-Path $PmoDir "traceability-SGD-115.json"
$GatePath = Join-Path $PmoDir "SGD-115-quality-gate.json"
$DashboardPath = Join-Path $DashboardDir "SGD-115-dashboard.json"

Write-Step "Validando línea base institucional"

foreach ($Required in @(
    (Join-Path $ProjectRoot "docs"),
    (Join-Path $ProjectRoot "config"),
    (Join-Path $ProjectRoot "src"),
    (Join-Path $ProjectRoot "tests"),
    (Join-Path $ProjectRoot "releases"),
    (Join-Path $ProjectRoot "artifacts"),
    (Join-Path $ProjectRoot "config\governance\sgd-114-policy.json"),
    (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1"),
    (Join-Path $ProjectRoot "pytest.ini"),
    (Join-Path $ProjectRoot ".git")
)) {
    Assert-Path -Path $Required -Description $Required
}

$GitStatus = @(
    git status --porcelain |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
)

$AllowedPatterns = @(
    '^\?\? Install-SGD115-Master-Documentation-System\.ps1$',
    '^\?\? Repair-SGD115-v[0-9.]+-.*\.ps1$',
    '^\?\? SGD115-.*\.zip$',
    '^\?\? LEAME-SGD115.*\.txt$'
)

$Unexpected = @(
    foreach ($Entry in $GitStatus) {
        $Allowed = $false
        foreach ($Pattern in $AllowedPatterns) {
            if ($Entry -match $Pattern) {
                $Allowed = $true
                break
            }
        }
        if (-not $Allowed) {
            $Entry
        }
    }
)

if ($Unexpected.Count -gt 0) {
    Write-Host "Cambios Git no permitidos antes de SGD-115:" -ForegroundColor Red
    $Unexpected | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Red
    }
    throw "La línea base contiene cambios ajenos a SGD-115."
}

$ModuleContent = @'
"""SGD-115: sistema maestro de documentación SGODA-PUINAVE."""

from __future__ import annotations

import argparse
import json
import re
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


VERSION = "1.0.0"

MASTER_DOCUMENTS = {
    "index": "docs/00_INDICE_MAESTRO.md",
    "architecture": "docs/00_ARQUITECTURA_MAESTRA.md",
    "registry": "docs/00_REGISTRO_MAESTRO_COMPONENTES.md",
}


@dataclass(slots=True)
class ComponentRecord:
    code: str
    name: str
    version: str
    status: str
    component_type: str
    config_path: str
    source_paths: list[str]
    test_paths: list[str]
    documentation_paths: list[str]
    release_paths: list[str]
    evidence_paths: list[str]


@dataclass(slots=True)
class ValidationResult:
    passed: bool
    master_documents_present: bool
    component_count: int
    broken_paths: list[str]
    duplicate_codes: list[str]
    missing_required_sections: dict[str, list[str]]
    generated_at_utc: str


def _relative(path: Path, root: Path) -> str:
    return path.resolve().relative_to(root.resolve()).as_posix()


def _as_list(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, list):
        return [str(item) for item in value if str(item).strip()]
    return [str(value)]


def _discover_documentation(
    root: Path,
    code: str,
) -> list[str]:
    docs_root = root / "docs"
    if not docs_root.is_dir():
        return []

    normalized = code.casefold().replace("_", "-")
    matches: list[str] = []

    for path in docs_root.rglob("*.md"):
        name = path.name.casefold().replace("_", "-")
        text_match = normalized in name
        if not text_match:
            continue
        matches.append(_relative(path, root))

    return sorted(set(matches))


def _discover_releases(
    root: Path,
    code: str,
) -> list[str]:
    releases_root = root / "releases"
    if not releases_root.is_dir():
        return []

    normalized = code.casefold().replace("_", "-")
    matches = [
        _relative(path, root)
        for path in releases_root.iterdir()
        if path.is_dir()
        and normalized in path.name.casefold().replace("_", "-")
    ]
    return sorted(matches)


def _discover_evidence(
    root: Path,
    code: str,
) -> list[str]:
    artifacts_root = root / "artifacts"
    if not artifacts_root.is_dir():
        return []

    normalized = code.casefold().replace("_", "-")
    matches: list[str] = []

    for path in artifacts_root.rglob("*"):
        if not path.is_file():
            continue
        relative = _relative(path, root)
        if normalized in relative.casefold().replace("_", "-"):
            matches.append(relative)

    return sorted(matches)


def discover_components(root: str | Path) -> list[ComponentRecord]:
    repository_root = Path(root).resolve()
    config_root = repository_root / "config"
    records: list[ComponentRecord] = []

    if not config_root.is_dir():
        return records

    candidates = sorted(
        path
        for path in config_root.rglob("*.json")
        if "component" in path.name.casefold()
    )

    for path in candidates:
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError):
            continue

        code = str(
            payload.get("increment_code")
            or payload.get("component_code")
            or payload.get("code")
            or ""
        ).strip()

        if not code:
            continue

        source_paths = _as_list(
            payload.get("source")
            or payload.get("source_paths")
        )
        test_paths = _as_list(
            payload.get("tests")
            or payload.get("test_paths")
        )

        documentation_paths = _as_list(
            payload.get("documentation")
            or payload.get("documentation_paths")
        )
        documentation_paths.extend(
            _discover_documentation(repository_root, code)
        )

        release_paths = _as_list(
            payload.get("release")
            or payload.get("release_paths")
        )
        release_paths.extend(
            _discover_releases(repository_root, code)
        )

        evidence_paths = _as_list(
            payload.get("evidence")
            or payload.get("evidence_paths")
        )
        evidence_paths.extend(
            _discover_evidence(repository_root, code)
        )

        records.append(
            ComponentRecord(
                code=code,
                name=str(
                    payload.get("name")
                    or payload.get("policy_name")
                    or payload.get("component_type")
                    or code
                ),
                version=str(payload.get("version") or "no declarada"),
                status=str(payload.get("status") or "no declarado"),
                component_type=str(
                    payload.get("component_type") or "no declarado"
                ),
                config_path=_relative(path, repository_root),
                source_paths=sorted(set(source_paths)),
                test_paths=sorted(set(test_paths)),
                documentation_paths=sorted(set(documentation_paths)),
                release_paths=sorted(set(release_paths)),
                evidence_paths=sorted(set(evidence_paths)),
            )
        )

    return sorted(records, key=lambda record: record.code.casefold())


def _markdown_link(path: str) -> str:
    return f"[`{path}`](../{path})"


def render_index(
    records: list[ComponentRecord],
) -> str:
    sections = [
        "# Índice Maestro del Proyecto SGODA-PUINAVE",
        "",
        "> Documento rector para navegar la documentación, el código, las "
        "pruebas, las evidencias y los releases del proyecto.",
        "",
        "## 1. Documentos maestros",
        "",
        "- [Arquitectura Maestra](00_ARQUITECTURA_MAESTRA.md)",
        "- [Registro Maestro de Componentes](00_REGISTRO_MAESTRO_COMPONENTES.md)",
        "",
        "## 2. Gobierno y políticas",
        "",
        "- [`docs/01_Gobierno/`](01_Gobierno/)",
        "- [`config/governance/`](../config/governance/)",
        "",
        "## 3. Arquitectura y decisiones",
        "",
        "- [`docs/03_ADR/`](03_ADR/)",
        "",
        "## 4. Fase tecnológica",
        "",
        "- [`docs/05_Fase_Tecnologica/`](05_Fase_Tecnologica/)",
        "",
        "## 5. Historial y cierres",
        "",
        "- [`docs/15_Historial/`](15_Historial/)",
        "",
        "## 6. Código fuente",
        "",
        "- [`src/sgoda/`](../src/sgoda/)",
        "",
        "## 7. Pruebas",
        "",
        "- [`tests/`](../tests/)",
        "",
        "## 8. Configuración",
        "",
        "- [`config/`](../config/)",
        "",
        "## 9. Evidencias y auditorías",
        "",
        "- [`artifacts/`](../artifacts/)",
        "",
        "## 10. Releases",
        "",
        "- [`releases/`](../releases/)",
        "",
        "## 11. Dashboard",
        "",
        "- [`dashboard/`](../dashboard/)",
        "",
        "## 12. Automatización",
        "",
        "- [`scripts/`](../scripts/)",
        "",
        "## 13. Componentes registrados",
        "",
        f"Total identificado automáticamente: **{len(records)}**.",
        "",
    ]

    for record in records:
        sections.append(
            f"- **{record.code}** — {record.name} "
            f"(v{record.version}; {record.status})"
        )

    sections.extend(
        [
            "",
            "## 14. Política de actualización",
            "",
            "Este índice debe regenerarse o validarse cada vez que un "
            "incremento sea publicado mediante SPB-007.",
            "",
        ]
    )

    return "\n".join(sections)


def render_architecture(
    records: list[ComponentRecord],
) -> str:
    return "\n".join(
        [
            "# Arquitectura Maestra SGODA-PUINAVE",
            "",
            "## 1. Propósito",
            "",
            "Definir la arquitectura integral del ecosistema para preservar, "
            "gestionar, enseñar y ampliar digitalmente la lengua Puinave.",
            "",
            "## 2. Vista integral",
            "",
            "```text",
            "Repositorio Léxico Base en Excel",
            "        │",
            "        ▼",
            "RLB Canónico — SPT-001B",
            "        │",
            "        ▼",
            "Motor ODA — SPT-002",
            "        │",
            "        ▼",
            "Repositorio Multimedia RMR — ADR-010",
            "        │",
            "        ▼",
            "Orquestador Multimedia — SPT-003A",
            "        │",
            "        ▼",
            "Adaptadores IA y Multimedia — SPT-003B",
            "        │",
            "        ├── Imágenes IA",
            "        ├── TTS español",
            "        ├── TTS inglés",
            "        ├── Grabaciones Puinave",
            "        ├── n8n",
            "        └── Almacenamiento RMR",
            "        │",
            "        ▼",
            "API FastAPI / PostgreSQL",
            "        │",
            "        ▼",
            "Portal web y aplicación Flutter",
            "```",
            "",
            "## 3. Capas arquitectónicas",
            "",
            "### 3.1 Gobierno y PMO Digital",
            "",
            "- SGD-114: evidencias, repositorio y trazabilidad.",
            "- SGD-115: documentación maestra.",
            "- SPB-007: publicación institucional.",
            "- Auditor del Repositorio.",
            "",
            "### 3.2 Datos lingüísticos",
            "",
            "- Repositorio Léxico Base.",
            "- Esquema extensible y versionado.",
            "- Repositorio canónico.",
            "- Trazabilidad hasta el Excel oficial.",
            "",
            "### 3.3 Objetos Digitales de Aprendizaje",
            "",
            "- ODA por entrada léxica.",
            "- Slots de imagen y audio.",
            "- Metadatos pedagógicos, culturales y étnicos.",
            "",
            "### 3.4 Multimedia e IA",
            "",
            "- RMR escalable.",
            "- Cola transaccional.",
            "- Adaptadores de proveedores.",
            "- Revisión humana y cultural.",
            "- Eventos compatibles con n8n.",
            "",
            "### 3.5 Aplicaciones",
            "",
            "- Backend FastAPI.",
            "- PostgreSQL.",
            "- Portal web.",
            "- Cliente Flutter.",
            "- Dashboard PMO Digital.",
            "",
            "## 4. Arquitectura basada en eventos",
            "",
            "Los componentes publican eventos institucionales para evitar "
            "acoplamiento directo y permitir automatización mediante n8n.",
            "",
            "Eventos principales:",
            "",
            "- `RepositoryImported`",
            "- `MultimediaJobsPlanned`",
            "- `MultimediaJobCompleted`",
            "- `MultimediaJobFailed`",
            "- `InstitutionalRepositoryAudited`",
            "",
            "## 5. Escalabilidad",
            "",
            "- Repositorio multimedia probado para 120.000 recursos.",
            "- Cola multimedia probada para 120.000 trabajos.",
            "- Procesamiento desacoplado por lotes.",
            "- Proveedores intercambiables.",
            "",
            "## 6. Seguridad y soberanía cultural",
            "",
            "- Credenciales solo mediante variables de entorno.",
            "- Revisión humana obligatoria.",
            "- Validación cultural y étnica.",
            "- Preservación de evidencias.",
            "- No modificación destructiva del Excel oficial.",
            "",
            "## 7. Componentes inventariados",
            "",
            f"El registro automático identifica **{len(records)}** "
            "componentes institucionales.",
            "",
            "## 8. Evolución prevista",
            "",
            "- SPT-003C: operación piloto con proveedor real.",
            "- API funcional.",
            "- Persistencia PostgreSQL.",
            "- Portal web.",
            "- Aplicación Flutter.",
            "- PMO Digital event-driven.",
            "",
        ]
    )


def render_registry(
    records: list[ComponentRecord],
) -> str:
    lines = [
        "# Registro Maestro de Componentes SGODA-PUINAVE",
        "",
        "> Inventario generado a partir de archivos `*component*.json`, "
        "documentación, código, pruebas, evidencias y releases.",
        "",
        "| Código | Nombre/Tipo | Versión | Estado | Configuración | Código | "
        "Pruebas | Documentación | Release | Evidencias |",
        "|---|---|---:|---|---|---:|---:|---:|---:|---:|",
    ]

    for record in records:
        lines.append(
            "| "
            + " | ".join(
                [
                    record.code,
                    record.name.replace("|", "/"),
                    record.version,
                    record.status,
                    f"`{record.config_path}`",
                    str(len(record.source_paths)),
                    str(len(record.test_paths)),
                    str(len(record.documentation_paths)),
                    str(len(record.release_paths)),
                    str(len(record.evidence_paths)),
                ]
            )
            + " |"
        )

    lines.extend(
        [
            "",
            "## Detalle por componente",
            "",
        ]
    )

    for record in records:
        lines.extend(
            [
                f"### {record.code} — {record.name}",
                "",
                f"- **Versión:** {record.version}",
                f"- **Estado:** {record.status}",
                f"- **Tipo:** {record.component_type}",
                f"- **Configuración:** `{record.config_path}`",
                "- **Código:** "
                + (
                    ", ".join(f"`{item}`" for item in record.source_paths)
                    if record.source_paths
                    else "No declarado."
                ),
                "- **Pruebas:** "
                + (
                    ", ".join(f"`{item}`" for item in record.test_paths)
                    if record.test_paths
                    else "No declaradas."
                ),
                "- **Documentación:** "
                + (
                    ", ".join(
                        f"`{item}`"
                        for item in record.documentation_paths[:20]
                    )
                    if record.documentation_paths
                    else "No identificada."
                ),
                "- **Releases:** "
                + (
                    ", ".join(f"`{item}`" for item in record.release_paths)
                    if record.release_paths
                    else "No identificados."
                ),
                "- **Evidencias:** "
                + (
                    f"{len(record.evidence_paths)} archivo(s) identificado(s)."
                    if record.evidence_paths
                    else "No identificadas."
                ),
                "",
            ]
        )

    return "\n".join(lines)


def write_master_documents(
    root: str | Path,
) -> dict[str, Path]:
    repository_root = Path(root).resolve()
    records = discover_components(repository_root)

    outputs = {
        "index": repository_root / MASTER_DOCUMENTS["index"],
        "architecture": repository_root / MASTER_DOCUMENTS["architecture"],
        "registry": repository_root / MASTER_DOCUMENTS["registry"],
    }

    outputs["index"].write_text(
        render_index(records) + "\n",
        encoding="utf-8",
    )
    outputs["architecture"].write_text(
        render_architecture(records) + "\n",
        encoding="utf-8",
    )
    outputs["registry"].write_text(
        render_registry(records) + "\n",
        encoding="utf-8",
    )

    return outputs


def _extract_code_paths(text: str) -> Iterable[str]:
    pattern = re.compile(r"`([^`\n]+(?:/|\\)[^`\n]+)`")
    for match in pattern.finditer(text):
        value = match.group(1).strip()
        if value.startswith(("http://", "https://")):
            continue
        yield value.replace("\\", "/")


def validate_master_documents(
    root: str | Path,
) -> ValidationResult:
    repository_root = Path(root).resolve()
    records = discover_components(repository_root)

    master_paths = {
        name: repository_root / relative
        for name, relative in MASTER_DOCUMENTS.items()
    }

    required_sections = {
        "index": [
            "# Índice Maestro",
            "## 1. Documentos maestros",
            "## 13. Componentes registrados",
        ],
        "architecture": [
            "# Arquitectura Maestra",
            "## 2. Vista integral",
            "## 3. Capas arquitectónicas",
            "## 6. Seguridad y soberanía cultural",
        ],
        "registry": [
            "# Registro Maestro de Componentes",
            "## Detalle por componente",
        ],
    }

    missing_sections: dict[str, list[str]] = {}
    broken_paths: list[str] = []

    for name, path in master_paths.items():
        if not path.is_file():
            missing_sections[name] = required_sections[name]
            continue

        text = path.read_text(encoding="utf-8")
        missing = [
            section
            for section in required_sections[name]
            if section not in text
        ]
        if missing:
            missing_sections[name] = missing

        for relative in _extract_code_paths(text):
            candidate = repository_root / relative
            if not candidate.exists():
                broken_paths.append(
                    f"{_relative(path, repository_root)} -> {relative}"
                )

    codes = [record.code for record in records]
    duplicate_codes = sorted(
        {
            code
            for code in codes
            if codes.count(code) > 1
        }
    )

    result = ValidationResult(
        passed=(
            all(path.is_file() for path in master_paths.values())
            and not broken_paths
            and not duplicate_codes
            and not missing_sections
            and len(records) > 0
        ),
        master_documents_present=all(
            path.is_file() for path in master_paths.values()
        ),
        component_count=len(records),
        broken_paths=sorted(set(broken_paths)),
        duplicate_codes=duplicate_codes,
        missing_required_sections=missing_sections,
        generated_at_utc=datetime.now(timezone.utc).isoformat(),
    )

    return result


def publish_artifacts(
    root: str | Path,
    output_dir: str | Path,
) -> dict[str, Path]:
    repository_root = Path(root).resolve()
    output = Path(output_dir)
    output.mkdir(parents=True, exist_ok=True)

    records = discover_components(repository_root)
    validation = validate_master_documents(repository_root)

    inventory_path = output / "component-inventory.json"
    inventory_path.write_text(
        json.dumps(
            [asdict(record) for record in records],
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    validation_path = output / "master-documentation-validation.json"
    validation_path.write_text(
        json.dumps(
            asdict(validation),
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    event_path = output / "master-documentation-updated-event.json"
    event_path.write_text(
        json.dumps(
            {
                "event_type": "MasterDocumentationUpdated",
                "occurred_at_utc": validation.generated_at_utc,
                "source": "sgoda.documentation",
                "increment": "SGD-115",
                "component_count": validation.component_count,
                "validation_passed": validation.passed,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    return {
        "inventory": inventory_path,
        "validation": validation_path,
        "event": event_path,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument(
        "--output",
        default="artifacts/documentation/SGD-115",
    )
    parser.add_argument(
        "--validate-only",
        action="store_true",
    )
    args = parser.parse_args()

    if not args.validate_only:
        write_master_documents(args.root)

    artifacts = publish_artifacts(args.root, args.output)
    validation = json.loads(
        artifacts["validation"].read_text(encoding="utf-8")
    )

    print("SGD-115 ejecutado correctamente.")
    print(f"Componentes: {validation['component_count']}")
    print(f"Validación: {'APROBADA' if validation['passed'] else 'NO APROBADA'}")
    print(f"Evidencia: {artifacts['validation']}")

    return 0 if validation["passed"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
'@

$InitContent = @'
"""Sistema Maestro de Documentación SGODA-PUINAVE."""

from .master_docs import (
    ComponentRecord,
    ValidationResult,
    discover_components,
    publish_artifacts,
    validate_master_documents,
    write_master_documents,
)

__all__ = [
    "ComponentRecord",
    "ValidationResult",
    "discover_components",
    "publish_artifacts",
    "validate_master_documents",
    "write_master_documents",
]
'@

$TestContent = @'
"""Pruebas SGD-115 del sistema maestro de documentación."""

import json
from pathlib import Path

from sgoda.documentation.master_docs import (
    discover_components,
    publish_artifacts,
    validate_master_documents,
    write_master_documents,
)


def _repository(tmp_path: Path) -> Path:
    root = tmp_path
    (root / "config" / "sample").mkdir(parents=True)
    (root / "docs" / "01_Gobierno").mkdir(parents=True)
    (root / "docs" / "03_ADR").mkdir(parents=True)
    (root / "docs" / "05_Fase_Tecnologica").mkdir(parents=True)
    (root / "docs" / "15_Historial").mkdir(parents=True)
    (root / "src" / "sgoda" / "sample").mkdir(parents=True)
    (root / "tests" / "sample").mkdir(parents=True)
    (root / "artifacts" / "pmo" / "SPT-TEST").mkdir(parents=True)
    (root / "releases" / "SPT-TEST-v1.0.0").mkdir(parents=True)
    (root / "dashboard").mkdir()
    (root / "scripts").mkdir()

    component = {
        "increment_code": "SPT-TEST",
        "component_type": "sample_component",
        "version": "1.0.0",
        "status": "technically_completed",
        "source": ["src/sgoda/sample/module.py"],
        "tests": ["tests/sample/test_module.py"],
    }

    (root / "config" / "sample" / "SPT-TEST-component.json").write_text(
        json.dumps(component),
        encoding="utf-8",
    )
    (root / "src" / "sgoda" / "sample" / "module.py").write_text(
        "VALUE = 1\n",
        encoding="utf-8",
    )
    (root / "tests" / "sample" / "test_module.py").write_text(
        "def test_value(): assert True\n",
        encoding="utf-8",
    )
    (
        root
        / "docs"
        / "05_Fase_Tecnologica"
        / "SPT-TEST-Implementacion.md"
    ).write_text(
        "# SPT-TEST\n",
        encoding="utf-8",
    )
    (
        root
        / "artifacts"
        / "pmo"
        / "SPT-TEST"
        / "evidence.json"
    ).write_text(
        "{}\n",
        encoding="utf-8",
    )

    return root


def test_SGD_115_descubre_componentes(tmp_path: Path) -> None:
    root = _repository(tmp_path)
    records = discover_components(root)

    assert len(records) == 1
    assert records[0].code == "SPT-TEST"
    assert records[0].version == "1.0.0"


def test_SGD_115_genera_tres_documentos(tmp_path: Path) -> None:
    root = _repository(tmp_path)
    outputs = write_master_documents(root)

    assert set(outputs) == {"index", "architecture", "registry"}
    assert all(path.is_file() for path in outputs.values())


def test_SGD_115_indice_contiene_componente(tmp_path: Path) -> None:
    root = _repository(tmp_path)
    outputs = write_master_documents(root)

    text = outputs["index"].read_text(encoding="utf-8")

    assert "SPT-TEST" in text
    assert "Arquitectura Maestra" in text


def test_SGD_115_arquitectura_contiene_capas(tmp_path: Path) -> None:
    root = _repository(tmp_path)
    outputs = write_master_documents(root)

    text = outputs["architecture"].read_text(encoding="utf-8")

    assert "## 3. Capas arquitectónicas" in text
    assert "## 6. Seguridad y soberanía cultural" in text


def test_SGD_115_registro_contiene_trazabilidad(
    tmp_path: Path,
) -> None:
    root = _repository(tmp_path)
    outputs = write_master_documents(root)

    text = outputs["registry"].read_text(encoding="utf-8")

    assert "src/sgoda/sample/module.py" in text
    assert "tests/sample/test_module.py" in text
    assert "SPT-TEST-v1.0.0" in text


def test_SGD_115_validacion_aprobada(tmp_path: Path) -> None:
    root = _repository(tmp_path)
    write_master_documents(root)

    result = validate_master_documents(root)

    assert result.passed is True
    assert result.component_count == 1
    assert result.broken_paths == []


def test_SGD_115_detecta_documento_faltante(
    tmp_path: Path,
) -> None:
    root = _repository(tmp_path)
    outputs = write_master_documents(root)
    outputs["architecture"].unlink()

    result = validate_master_documents(root)

    assert result.passed is False
    assert "architecture" in result.missing_required_sections


def test_SGD_115_publica_inventario_evento_y_validacion(
    tmp_path: Path,
) -> None:
    root = _repository(tmp_path)
    write_master_documents(root)

    artifacts = publish_artifacts(
        root,
        root / "artifacts" / "documentation" / "SGD-115",
    )

    assert artifacts["inventory"].is_file()
    assert artifacts["validation"].is_file()
    assert artifacts["event"].is_file()

    validation = json.loads(
        artifacts["validation"].read_text(encoding="utf-8")
    )
    assert validation["passed"] is True
'@

$PolicyContent = @'
{
  "increment_code": "SGD-115",
  "version": "1.0.0",
  "policy_name": "Sistema Maestro de Documentación del Proyecto",
  "mandatory_documents": [
    "docs/00_INDICE_MAESTRO.md",
    "docs/00_ARQUITECTURA_MAESTRA.md",
    "docs/00_REGISTRO_MAESTRO_COMPONENTES.md"
  ],
  "required_registry_sources": [
    "config/**/*component*.json",
    "docs/**/*.md",
    "src/**/*",
    "tests/**/*",
    "artifacts/**/*",
    "releases/**/*"
  ],
  "validation_rules": {
    "utf8": true,
    "required_sections": true,
    "broken_paths": false,
    "duplicate_component_codes": false,
    "component_inventory_required": true
  },
  "update_event": "MasterDocumentationUpdated",
  "governed_by": "SGD-114-v2.0.1"
}
'@

$ComponentContent = @'
{
  "increment_code": "SGD-115",
  "name": "Sistema Maestro de Documentación del Proyecto",
  "component_type": "master_documentation_system",
  "version": "1.0.0",
  "status": "technically_completed",
  "entrypoint": "sgoda.documentation.master_docs",
  "source": [
    "src/sgoda/documentation/master_docs.py"
  ],
  "tests": [
    "tests/documentation/test_SGD_115_master_documentation.py"
  ],
  "documentation": [
    "docs/00_INDICE_MAESTRO.md",
    "docs/00_ARQUITECTURA_MAESTRA.md",
    "docs/00_REGISTRO_MAESTRO_COMPONENTES.md",
    "docs/01_Gobierno/SGD-115-Sistema-Maestro-Documentacion.md"
  ],
  "governed_by": "SGD-114-v2.0.1"
}
'@

$ImplementationDocContent = @'
# SGD-115 — Sistema Maestro de Documentación del Proyecto

## Objetivo

Consolidar en el repositorio una fuente documental central, navegable,
auditable y regenerable para todo SGODA-PUINAVE.

## Documentos rectores

- `docs/00_INDICE_MAESTRO.md`
- `docs/00_ARQUITECTURA_MAESTRA.md`
- `docs/00_REGISTRO_MAESTRO_COMPONENTES.md`

## Funcionamiento

El sistema examina:

- archivos de componentes en `config/`;
- código en `src/`;
- pruebas en `tests/`;
- documentación en `docs/`;
- evidencias en `artifacts/`;
- releases en `releases/`.

A partir de estas fuentes genera el inventario y valida:

- presencia de documentos;
- secciones obligatorias;
- rutas referenciadas;
- duplicidad de códigos;
- trazabilidad de componentes.

## Integración institucional

SGD-115 debe ejecutarse después de cada incremento tecnológico y antes de
su publicación definitiva mediante SPB-007.
'@

$InvokeContent = @'
[CmdletBinding()]
param(
    [switch]$ValidateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

$Arguments = @(
    "-m",
    "sgoda.documentation.master_docs",
    "--root",
    $Root,
    "--output",
    "artifacts/documentation/SGD-115"
)

if ($ValidateOnly) {
    $Arguments += "--validate-only"
}

& python @Arguments

if ($LASTEXITCODE -ne 0) {
    throw "SGD-115 terminó con errores."
}
'@

Write-Step "Instalando SGD-115"

Write-Utf8NoBom -Path $ModulePath -Content $ModuleContent
Write-Utf8NoBom -Path $InitPath -Content $InitContent
Write-Utf8NoBom -Path $TestPath -Content $TestContent
Write-Utf8NoBom -Path $PolicyPath -Content $PolicyContent
Write-Utf8NoBom -Path $ComponentPath -Content $ComponentContent
Write-Utf8NoBom -Path $ImplementationDocPath -Content $ImplementationDocContent
Write-Utf8NoBom -Path $InvokePath -Content $InvokeContent

Write-Step "Generando documentos maestros iniciales"

& python -m sgoda.documentation.master_docs `
    --root "$ProjectRoot" `
    --output "artifacts/documentation/SGD-115"

if ($LASTEXITCODE -ne 0) {
    throw "La generación inicial de documentos maestros falló."
}

foreach ($Required in @(
    $IndexPath,
    $ArchitecturePath,
    $RegistryPath,
    (Join-Path $ArtifactsDir "component-inventory.json"),
    (Join-Path $ArtifactsDir "master-documentation-validation.json"),
    (Join-Path $ArtifactsDir "master-documentation-updated-event.json")
)) {
    Assert-Path -Path $Required -Description $Required
}

Write-Step "Generando evidencia y trazabilidad"

$Timestamp = [DateTime]::UtcNow.ToString("o")

$Evidence = [ordered]@{
    increment_code = "SGD-115"
    version = "1.0.0"
    status = "implemented"
    generated_at_utc = $Timestamp
    master_documents = @(
        "docs/00_INDICE_MAESTRO.md",
        "docs/00_ARQUITECTURA_MAESTRA.md",
        "docs/00_REGISTRO_MAESTRO_COMPONENTES.md"
    )
    source = @(
        "src/sgoda/documentation/master_docs.py"
    )
    tests = @(
        "tests/documentation/test_SGD_115_master_documentation.py"
    )
}
Write-JsonUtf8 -Path $EvidencePath -Data $Evidence

$Trace = [ordered]@{
    increment_code = "SGD-115"
    generated_at_utc = $Timestamp
    source = @(
        "src/sgoda/documentation/master_docs.py",
        "config/governance/SGD-115-master-documentation-policy.json",
        "config/governance/SGD-115-component.json"
    )
    tests = @(
        "tests/documentation/test_SGD_115_master_documentation.py"
    )
    documentation = @(
        "docs/00_INDICE_MAESTRO.md",
        "docs/00_ARQUITECTURA_MAESTRA.md",
        "docs/00_REGISTRO_MAESTRO_COMPONENTES.md",
        "docs/01_Gobierno/SGD-115-Sistema-Maestro-Documentacion.md"
    )
    evidence = @(
        "artifacts/documentation/SGD-115/component-inventory.json",
        "artifacts/documentation/SGD-115/master-documentation-validation.json",
        "artifacts/documentation/SGD-115/master-documentation-updated-event.json",
        "artifacts/pmo/SGD-115/implementation-evidence.json"
    )
}
Write-JsonUtf8 -Path $TracePath -Data $Trace

Write-Step "Validando importaciones"

& python -c "from sgoda.documentation import discover_components, validate_master_documents; print(discover_components.__name__, validate_master_documents.__name__)"

if ($LASTEXITCODE -ne 0) {
    throw "Falló la importación de SGD-115."
}

Write-Step "Ejecutando 8 pruebas específicas SGD-115"

& python -m pytest `
    "tests/documentation/test_SGD_115_master_documentation.py" `
    -q

if ($LASTEXITCODE -ne 0) {
    throw "Las pruebas específicas SGD-115 fallaron."
}

if (-not $SkipFullSuite) {
    Write-Step "Ejecutando suite completa"

    & python -m pytest

    if ($LASTEXITCODE -ne 0) {
        throw "La suite completa terminó con errores."
    }
}

Write-Step "Regenerando y validando documentación real"

& python -m sgoda.documentation.master_docs `
    --root "$ProjectRoot" `
    --output "artifacts/documentation/SGD-115"

if ($LASTEXITCODE -ne 0) {
    throw "La validación real SGD-115 no fue aprobada."
}

$ValidationPath = Join-Path $ArtifactsDir "master-documentation-validation.json"
$InventoryPath = Join-Path $ArtifactsDir "component-inventory.json"

$Validation = Get-Content -LiteralPath $ValidationPath -Raw |
    ConvertFrom-Json
$Inventory = Get-Content -LiteralPath $InventoryPath -Raw |
    ConvertFrom-Json

if (-not $Validation.passed) {
    throw "SGD-115 no contiene passed=true."
}

if ([int]$Validation.component_count -le 0) {
    throw "SGD-115 no identificó componentes."
}

Write-Step "Publicando release institucional"

if (-not (Test-Path -LiteralPath $ReleaseDir)) {
    New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null
}

foreach ($Artifact in @(
    $IndexPath,
    $ArchitecturePath,
    $RegistryPath,
    $ImplementationDocPath,
    $PolicyPath,
    $ComponentPath,
    $ValidationPath,
    $InventoryPath,
    (Join-Path $ArtifactsDir "master-documentation-updated-event.json")
)) {
    Copy-Item `
        -LiteralPath $Artifact `
        -Destination (Join-Path $ReleaseDir (Split-Path $Artifact -Leaf)) `
        -Force
}

Write-Step "Ejecutando quality gate SGD-114"

& python -m sgoda.governance.evidence_policy `
    --root "$ProjectRoot" `
    --policy "config/governance/sgd-114-policy.json" `
    --increment "SGD-115" `
    --status "technically_completed" `
    --output "$GatePath"

if ($LASTEXITCODE -ne 0) {
    throw "El quality gate SGD-115 no fue aprobado."
}

$Gate = Get-Content -LiteralPath $GatePath -Raw |
    ConvertFrom-Json

if (-not $Gate.passed) {
    throw "El quality gate SGD-115 no contiene passed=true."
}

$Dashboard = [ordered]@{
    increment_code = "SGD-115"
    version = "1.0.0"
    status = "technically_completed"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    master_documents = 3
    components_registered = $Validation.component_count
    broken_paths = @($Validation.broken_paths).Count
    duplicate_codes = @($Validation.duplicate_codes).Count
    missing_sections = @(
        $Validation.missing_required_sections.PSObject.Properties
    ).Count
    validation = if ($Validation.passed) { "approved" } else { "rejected" }
    specific_tests = 8
    expected_total_tests = 129
    quality_gate = "approved"
    release = "SGD-115-v1.0.0"
}
Write-JsonUtf8 -Path $DashboardPath -Data $Dashboard

Write-Step "Resultado final"

Write-Host "SGD-115 implementado y validado." -ForegroundColor Green
Write-Host "Índice Maestro: GENERADO." -ForegroundColor Green
Write-Host "Arquitectura Maestra: GENERADA." -ForegroundColor Green
Write-Host "Registro Maestro: GENERADO." -ForegroundColor Green
Write-Host "Componentes registrados: $($Validation.component_count)" -ForegroundColor Cyan
Write-Host "Rutas rotas: $(@($Validation.broken_paths).Count)" -ForegroundColor Green
Write-Host "Códigos duplicados: $(@($Validation.duplicate_codes).Count)" -ForegroundColor Green
Write-Host "Pruebas específicas: 8 APROBADAS." -ForegroundColor Green
Write-Host "Suite total esperada desde 121: 129 pruebas." -ForegroundColor Cyan
Write-Host "Quality gate: APROBADO." -ForegroundColor Green
Write-Host "Release: releases\SGD-115-v1.0.0" -ForegroundColor Cyan
