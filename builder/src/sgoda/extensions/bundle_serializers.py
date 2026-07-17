"""Serialización de bundles y resultados."""

from __future__ import annotations

import json
from collections.abc import Iterable

from .bundle_models import BundleExecutionResult, ExtensionBundle


def bundles_to_json(bundles: Iterable[ExtensionBundle]) -> str:
    return json.dumps(
        [bundle.to_dict() for bundle in bundles],
        ensure_ascii=False,
        indent=2,
    )


def bundles_to_text(bundles: Iterable[ExtensionBundle]) -> str:
    rows = list(bundles)
    lines = ["Bundles SGODA", "-" * 60]
    for bundle in rows:
        lines.append(f"{bundle.name}: {len(bundle.items)} extensiones")
    lines.extend(["-" * 60, f"Bundles: {len(rows)}"])
    return "\n".join(lines)


def result_to_text(result: BundleExecutionResult) -> str:
    lines = [
        f"Bundle: {result.bundle}",
        f"Acción: {result.action}",
        f"Estado: {result.status}",
        f"Rollback: {'sí' if result.rolled_back else 'no'}",
    ]
    for operation in result.operations:
        lines.append(
            f"- {operation.item.key}: {operation.status}"
            + (f" ({operation.message})" if operation.message else "")
        )
    return "\n".join(lines)


def result_to_json(result: BundleExecutionResult) -> str:
    return json.dumps(result.to_dict(), ensure_ascii=False, indent=2)
