"""Auditor institucional de políticas SGD-114."""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


PASS_KEYS = {
    "passed",
    "approved",
    "compliant",
    "authorized",
    "valid",
    "exists",
    "present",
    "clean",
}

FAIL_LIST_HINTS = {
    "missing",
    "failed",
    "broken",
    "violations",
    "errors",
    "warnings",
    "unmet",
    "unauthorized",
    "invalid",
}


@dataclass(slots=True)
class Finding:
    severity: str
    code: str
    path: str
    message: str
    value: Any
    recommendation: str


@dataclass(slots=True)
class AuditResult:
    increment: str
    passed: bool
    finding_count: int
    blocking_count: int
    findings: list[Finding]
    generated_at_utc: str


def _key_tokens(path: str) -> set[str]:
    normalized = path.replace("[", ".").replace("]", "")
    return {
        token.lower()
        for token in normalized.replace("-", "_").split(".")
        if token
    }


def _walk(value: Any, path: str = "$"):
    yield path, value

    if isinstance(value, dict):
        for key, child in value.items():
            yield from _walk(child, f"{path}.{key}")

    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from _walk(child, f"{path}[{index}]")


def _looks_blocking_boolean(path: str, value: bool) -> bool:
    if value is not False:
        return False

    tokens = _key_tokens(path)
    return bool(tokens & PASS_KEYS)


def _looks_failure_list(path: str, value: list[Any]) -> bool:
    if not value:
        return False

    tokens = _key_tokens(path)
    return any(
        any(hint in token for hint in FAIL_LIST_HINTS)
        for token in tokens
    )


def _path_candidates(payload: Any) -> list[str]:
    candidates: list[str] = []

    for path, value in _walk(payload):
        if not isinstance(value, str):
            continue

        lower_path = path.lower()
        if any(
            hint in lower_path
            for hint in (
                "path",
                "file",
                "document",
                "evidence",
                "artifact",
                "release",
                "source",
                "test",
            )
        ):
            candidates.append(value)

    return sorted(set(candidates))


def audit_policy_gate(
    root: str | Path,
    policy: dict[str, Any],
    gate: dict[str, Any],
    increment: str,
) -> AuditResult:
    repository = Path(root)
    findings: list[Finding] = []

    for path, value in _walk(gate):
        if isinstance(value, bool) and _looks_blocking_boolean(path, value):
            findings.append(
                Finding(
                    severity="blocking",
                    code="BOOLEAN_RULE_FAILED",
                    path=path,
                    message="La regla booleana institucional no fue aprobada.",
                    value=value,
                    recommendation=(
                        "Revise la regla, la evidencia asociada y el estado "
                        "institucional del incremento."
                    ),
                )
            )

        elif isinstance(value, list) and _looks_failure_list(path, value):
            findings.append(
                Finding(
                    severity="blocking",
                    code="NON_EMPTY_FAILURE_LIST",
                    path=path,
                    message="La colección de incumplimientos no está vacía.",
                    value=value,
                    recommendation=(
                        "Resuelva cada elemento listado y regenere la evidencia."
                    ),
                )
            )

    for candidate in _path_candidates(policy) + _path_candidates(gate):
        clean = candidate.strip().replace("\\", "/")

        if not clean:
            continue

        if "://" in clean:
            continue

        absolute = repository / clean.rstrip("/")

        if not absolute.exists():
            findings.append(
                Finding(
                    severity="blocking",
                    code="MISSING_REFERENCED_PATH",
                    path=clean,
                    message="La ruta referenciada no existe en el repositorio.",
                    value=clean,
                    recommendation=(
                        "Cree la evidencia legítima o corrija la referencia "
                        "en el descriptor correspondiente."
                    ),
                )
            )

    component_descriptors = sorted(
        repository.glob(f"config/**/*{increment}*component*.json")
    )

    if not component_descriptors:
        findings.append(
            Finding(
                severity="blocking",
                code="COMPONENT_DESCRIPTOR_MISSING",
                path="config/**",
                message=f"No se encontró descriptor para {increment}.",
                value=increment,
                recommendation=(
                    "Cree un descriptor institucional del componente con "
                    "código, versión, dependencias, fuentes, pruebas y documentos."
                ),
            )
        )

    release_matches = sorted(
        (repository / "releases").glob(f"{increment}-v*")
    )

    if not release_matches:
        findings.append(
            Finding(
                severity="blocking",
                code="RELEASE_MISSING",
                path="releases/",
                message=f"No se encontró release versionado para {increment}.",
                value=increment,
                recommendation=(
                    "Genere el release técnico antes de solicitar cierre."
                ),
            )
        )

    blocking = [
        item
        for item in findings
        if item.severity == "blocking"
    ]

    return AuditResult(
        increment=increment,
        passed=not blocking,
        finding_count=len(findings),
        blocking_count=len(blocking),
        findings=findings,
        generated_at_utc=datetime.now(timezone.utc).isoformat(),
    )


def write_reports(
    result: AuditResult,
    json_path: str | Path,
    markdown_path: str | Path,
) -> None:
    json_target = Path(json_path)
    md_target = Path(markdown_path)

    json_target.parent.mkdir(parents=True, exist_ok=True)
    md_target.parent.mkdir(parents=True, exist_ok=True)

    payload = asdict(result)
    json_target.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    lines = [
        f"# Auditoría de Política SGD-114 — {result.increment}",
        "",
        f"- Resultado: {'APROBADO' if result.passed else 'NO APROBADO'}",
        f"- Hallazgos: {result.finding_count}",
        f"- Bloqueantes: {result.blocking_count}",
        f"- Generado: {result.generated_at_utc}",
        "",
        "## Hallazgos",
        "",
    ]

    if not result.findings:
        lines.append("No se encontraron incumplimientos.")

    for index, finding in enumerate(result.findings, start=1):
        lines.extend(
            [
                f"### {index}. {finding.code}",
                "",
                f"- Severidad: {finding.severity}",
                f"- Ruta: `{finding.path}`",
                f"- Mensaje: {finding.message}",
                f"- Valor: `{finding.value!r}`",
                f"- Recomendación: {finding.recommendation}",
                "",
            ]
        )

    md_target.write_text(
        "\n".join(lines).rstrip() + "\n",
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument("--policy", required=True)
    parser.add_argument("--gate", required=True)
    parser.add_argument("--increment", required=True)
    parser.add_argument("--output-json", required=True)
    parser.add_argument("--output-md", required=True)
    args = parser.parse_args()

    policy = json.loads(
        Path(args.policy).read_text(encoding="utf-8-sig")
    )
    gate = json.loads(
        Path(args.gate).read_text(encoding="utf-8-sig")
    )

    result = audit_policy_gate(
        args.root,
        policy,
        gate,
        args.increment,
    )

    write_reports(
        result,
        args.output_json,
        args.output_md,
    )

    print("SGD-114 Policy Auditor completado.")
    print("Resultado:", "APROBADO" if result.passed else "NO APROBADO")
    print("Hallazgos:", result.finding_count)
    print("Bloqueantes:", result.blocking_count)
    print("JSON:", args.output_json)
    print("Markdown:", args.output_md)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())