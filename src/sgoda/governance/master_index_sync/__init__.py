
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
