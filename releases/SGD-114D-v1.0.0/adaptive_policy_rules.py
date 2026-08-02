"""Reglas adaptativas de SGD-114D."""

from __future__ import annotations

from pathlib import Path

from .adaptive_policy_models import AdaptiveRuleResult
from .adaptive_policy_resolver import (
    resolve_evidence_directory,
    resolve_release_directory,
)


def evaluate_release_rule(
    root: str | Path,
    increment_code: str,
) -> AdaptiveRuleResult:
    resolved = resolve_release_directory(
        root,
        increment_code,
    )

    return AdaptiveRuleResult(
        rule_code="SGD114D-R003",
        name="Release técnico adaptativo",
        passed=resolved.found,
        blocking=True,
        message=(
            f"Release detectado: {resolved.path}"
            if resolved.found
            else (
                "No existe release versionado para "
                f"{increment_code} ni su familia canónica."
            )
        ),
        remediation=(
            ""
            if resolved.found
            else "Genere un release técnico versionado y no vacío."
        ),
        evidence=(
            (str(resolved.path),)
            if resolved.path is not None
            else ()
        ),
        metadata={
            "strategy": resolved.strategy,
            "candidates": list(resolved.candidates),
        },
    )


def evaluate_evidence_rule(
    root: str | Path,
    increment_code: str,
) -> AdaptiveRuleResult:
    resolved = resolve_evidence_directory(
        root,
        increment_code,
    )

    return AdaptiveRuleResult(
        rule_code="SGD114D-R007",
        name="Evidencia institucional adaptativa",
        passed=resolved.found,
        blocking=True,
        message=(
            f"Evidencia detectada: {resolved.path}"
            if resolved.found
            else (
                "No existe evidencia no vacía para "
                f"{increment_code} ni su familia canónica."
            )
        ),
        remediation=(
            ""
            if resolved.found
            else "Genere evidencia técnica legítima antes del gate."
        ),
        evidence=(
            (str(resolved.path),)
            if resolved.path is not None
            else ()
        ),
        metadata={
            "strategy": resolved.strategy,
            "candidates": list(resolved.candidates),
        },
    )