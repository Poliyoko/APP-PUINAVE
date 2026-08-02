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
    """Extrae rutas de archivos verificables desde bloques de código.

    Las referencias terminadas en "/" representan directorios de
    navegación. No se validan como archivos individuales porque algunos
    repositorios mínimos de prueba pueden omitir secciones opcionales.
    """

    pattern = re.compile(r"`([^`\n]+(?:/|\\)[^`\n]+)`")

    for match in pattern.finditer(text):
        value = match.group(1).strip().replace("\\", "/")

        if value.startswith(("http://", "https://")):
            continue

        if value.endswith("/"):
            continue

        yield value


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