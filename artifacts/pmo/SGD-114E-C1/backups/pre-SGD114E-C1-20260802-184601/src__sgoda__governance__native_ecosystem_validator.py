"""Validador institucional SGD-114E."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Iterable

from .native_ecosystem_models import (
    NativePolicyFinding,
    NativePolicyResult,
)
from .native_ecosystem_policy import (
    FORBIDDEN_TERMS,
    is_native_spt,
)


_TEXT_SUFFIXES = {
    ".md",
    ".json",
    ".py",
    ".ps1",
    ".txt",
    ".yaml",
    ".yml",
}


def _iter_text_files(root: Path) -> Iterable[Path]:
    ignored = {
        ".git",
        ".venv",
        "__pycache__",
        ".pytest_cache",
    }

    for path in root.rglob("*"):
        if not path.is_file():
            continue

        if any(part in ignored for part in path.parts):
            continue

        if path.suffix.casefold() not in _TEXT_SUFFIXES:
            continue

        yield path


def _component_files(root: Path) -> Iterable[Path]:
    for path in root.glob("config/**/*component.json"):
        if path.is_file():
            yield path


def evaluate_native_ecosystem(
    root: str | Path,
) -> NativePolicyResult:
    base = Path(root).resolve()
    findings: list[NativePolicyFinding] = []
    component_count = 0
    proprietary_count = 0
    forbidden_count = 0

    for path in _component_files(base):
        try:
            payload = json.loads(
                path.read_text(encoding="utf-8-sig")
            )
        except (OSError, json.JSONDecodeError) as error:
            findings.append(
                NativePolicyFinding(
                    rule_code="SGD114E-R001",
                    passed=False,
                    blocking=True,
                    message=(
                        "No fue posible leer el componente: "
                        f"{error}"
                    ),
                    path=str(path.relative_to(base)),
                    remediation=(
                        "Corrija el JSON del componente."
                    ),
                )
            )
            continue

        if not isinstance(payload, dict):
            continue

        code = str(
            payload.get("increment_code") or ""
        ).strip().upper()

        if not is_native_spt(code):
            continue

        component_count += 1
        native = bool(
            payload.get("native_ecosystem", False)
        )
        role = str(
            payload.get("ecosystem_role") or ""
        ).strip()

        if not native or role != "native_component":
            findings.append(
                NativePolicyFinding(
                    rule_code="SGD114E-R002",
                    passed=False,
                    blocking=True,
                    message=(
                        f"{code} no está declarado como "
                        "componente nativo."
                    ),
                    path=str(path.relative_to(base)),
                    remediation=(
                        "Agregue native_ecosystem=true y "
                        "ecosystem_role=native_component."
                    ),
                )
            )

        proprietary = payload.get(
            "mandatory_proprietary_dependencies",
            [],
        )

        if not isinstance(proprietary, list):
            proprietary = [str(proprietary)]

        proprietary = [
            str(item).strip()
            for item in proprietary
            if str(item).strip()
        ]

        if proprietary:
            proprietary_count += len(proprietary)
            findings.append(
                NativePolicyFinding(
                    rule_code="SGD114E-R003",
                    passed=False,
                    blocking=True,
                    message=(
                        f"{code} declara dependencias "
                        f"propietarias obligatorias: {proprietary}"
                    ),
                    path=str(path.relative_to(base)),
                    remediation=(
                        "Elimine la obligatoriedad o documente "
                        "una alternativa gratuita y abierta."
                    ),
                )
            )

    for path in _iter_text_files(base):
        relative = str(path.relative_to(base)).replace("\\", "/")

        if relative.startswith("artifacts/pmo/SGD-114E/backups/"):
            continue

        try:
            text = path.read_text(
                encoding="utf-8-sig",
                errors="replace",
            ).casefold()
        except OSError:
            continue

        for term in FORBIDDEN_TERMS:
            if term.casefold() in text:
                forbidden_count += 1
                findings.append(
                    NativePolicyFinding(
                        rule_code="SGD114E-R004",
                        passed=False,
                        blocking=True,
                        message=(
                            "Terminología no permitida: "
                            f"{term}"
                        ),
                        path=relative,
                        remediation=(
                            "Use 'integrado nativamente al "
                            "ecosistema SGODA-PUINAVE'."
                        ),
                    )
                )

    approved = not any(
        finding.blocking and not finding.passed
        for finding in findings
    )

    if approved:
        findings.append(
            NativePolicyFinding(
                rule_code="SGD114E-R000",
                passed=True,
                blocking=False,
                message=(
                    "Arquitectura nativa y política tecnológica "
                    "aprobadas."
                ),
            )
        )

    return NativePolicyResult(
        approved=approved,
        exit_code=0 if approved else 2,
        component_count=component_count,
        findings=tuple(findings),
        forbidden_term_count=forbidden_count,
        proprietary_dependency_count=proprietary_count,
    )