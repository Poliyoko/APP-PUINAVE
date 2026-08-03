
from __future__ import annotations
import json, re
from pathlib import Path
from typing import Any
from .native_ecosystem_models import NativeEcosystemFinding, NativeEcosystemValidationResult

_CONTRACT_VERSION = "1.0.3"
_ATTRIBUTE_VERSION = "1.0.5"
_IMPLEMENTATION_VERSION = "1.0.7"
_FORBIDDEN_TERMS = (
    "integrado por contrato", "integrada por contrato",
    "integrados por contrato", "integradas por contrato",
    "contract-based integration", "contract integration",
)
_SPT_PATTERN = re.compile(r"^SPT-(\d+)")

def _read_json(path: Path) -> dict[str, Any] | None:
    try:
        payload = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError):
        return None
    return payload if isinstance(payload, dict) else None

def _component_files(root: Path) -> tuple[Path, ...]:
    config = root / "config"
    if not config.exists():
        return ()
    return tuple(sorted(
        p for p in config.rglob("*.json")
        if "component" in p.name.casefold() or "metadata" in p.name.casefold()
    ))

def _code(payload: dict[str, Any], path: Path) -> str:
    return str(payload.get("increment_code") or payload.get("component") or path.stem)

def _governed(code: str) -> bool:
    normalized = str(code or "").strip().upper()
    match = _SPT_PATTERN.match(normalized)
    if match:
        return int(match.group(1)) >= 7
    return normalized.startswith(("SGD-", "SPB-", "SPA-"))

def _forbidden(root: Path):
    findings = []
    for base in (root / "config", root / "docs", root / "src"):
        if not base.exists():
            continue
        for path in sorted(base.rglob("*")):
            if not path.is_file() or path.suffix.casefold() not in {
                ".json", ".md", ".py", ".ps1", ".txt", ".yaml", ".yml"
            }:
                continue
            try:
                text = path.read_text(encoding="utf-8-sig", errors="replace").casefold()
            except OSError:
                continue
            for term in _FORBIDDEN_TERMS:
                if term in text:
                    findings.append(NativeEcosystemFinding(
                        "SGD114E-R003",
                        "Se detectó terminología institucional prohibida.",
                        path.as_posix(),
                        value=term,
                    ))
    return tuple(findings)

def evaluate_native_ecosystem(root: str | Path) -> NativeEcosystemValidationResult:
    project_root = Path(root).resolve()
    native_components = []
    proprietary = []
    structural = []
    findings = []
    governed_count = 0

    for path in _component_files(project_root):
        payload = _read_json(path)
        if payload is None:
            structural.append({"path": path.as_posix(), "error": "invalid_or_unreadable_json"})
            findings.append(NativeEcosystemFinding("SGD114E-R004", "JSON de componente inválido.", path.as_posix()))
            continue

        code = _code(payload, path)
        if not _governed(code):
            continue
        governed_count += 1

        if "native_ecosystem" not in payload or payload.get("native_ecosystem") is not True:
            findings.append(NativeEcosystemFinding(
                "SGD114E-R002",
                "El componente gobernado debe declararse como nativo.",
                path.as_posix(),
                component=code,
            ))
        else:
            native_components.append(code)

        deps = payload.get("mandatory_proprietary_dependencies", [])
        if deps is None:
            deps = []
        if not isinstance(deps, list):
            structural.append({"path": path.as_posix(), "error": "mandatory_proprietary_dependencies must be a list"})
            findings.append(NativeEcosystemFinding(
                "SGD114E-R004",
                "mandatory_proprietary_dependencies debe ser una lista.",
                path.as_posix(),
                component=code,
            ))
            continue
        for dep in deps:
            value = str(dep).strip()
            if value:
                proprietary.append({"component": code, "dependency": value, "path": path.as_posix()})
                findings.append(NativeEcosystemFinding(
                    "SGD114E-R001",
                    "Se detectó una dependencia propietaria obligatoria.",
                    path.as_posix(),
                    component=code,
                    value=value,
                ))

    forbidden = list(_forbidden(project_root))
    findings.extend(forbidden)

    # Historical v1.0.3 criterion is informational and must exist.
    # Empty repositories remain approved by the original contract.
    has_native_components = len(native_components) > 0
    approved = len(findings) == 0

    criteria = {
        "has_native_components": has_native_components,
        "all_governed_components_are_native": not any(
            item.rule_code == "SGD114E-R002" for item in findings
        ),
        "no_forbidden_terms": len(forbidden) == 0,
        "no_mandatory_proprietary_dependencies": len(proprietary) == 0,
        "no_structural_errors": len(structural) == 0,
        "empty_repository_allowed": governed_count == 0,
    }

    return NativeEcosystemValidationResult({
        "policy": "SGD-114E",
        "version": _CONTRACT_VERSION,
        "attribute_version": _ATTRIBUTE_VERSION,
        "implementation_version": _IMPLEMENTATION_VERSION,
        "approved": approved,
        "exit_code": 0 if approved else 2,
        "result": "APROBADO" if approved else "NO APROBADO",
        "criteria": criteria,
        "native_component_count": len(native_components),
        "component_count": len(native_components),
        "native_components": sorted(set(native_components)),
        "forbidden_term_count": len(forbidden),
        "forbidden_terms": [x.to_dict() for x in forbidden],
        "mandatory_proprietary_dependency_count": len(proprietary),
        "proprietary_dependency_count": len(proprietary),
        "mandatory_proprietary_dependencies": proprietary,
        "structural_error_count": len(structural),
        "structural_errors": structural,
        "findings": findings,
        "decision_rule": "approved = no institutional findings",
    })
