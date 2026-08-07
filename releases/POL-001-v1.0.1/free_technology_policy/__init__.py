
from __future__ import annotations

import argparse
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any


APPROVED = "approved"
REVIEW = "review_required"
PROHIBITED = "prohibited"


@dataclass(frozen=True, slots=True)
class Finding:
    source: str
    technology: str
    classification: str
    reason: str
    adr_required: bool

    def to_dict(self) -> dict[str, Any]:
        return {
            "source": self.source,
            "technology": self.technology,
            "classification": self.classification,
            "reason": self.reason,
            "adr_required": self.adr_required,
        }


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def normalize_name(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.casefold())


def technology_index(registry: dict[str, Any]) -> dict[str, dict[str, Any]]:
    index: dict[str, dict[str, Any]] = {}
    for item in registry.get("technologies", []):
        if not isinstance(item, dict):
            continue
        aliases = [item.get("name", ""), *item.get("aliases", [])]
        for alias in aliases:
            if str(alias).strip():
                index[normalize_name(str(alias))] = item
    return index


def classify(
    technology: str,
    registry: dict[str, Any],
) -> tuple[str, str, bool]:
    item = technology_index(registry).get(normalize_name(technology))
    if item is None:
        return (
            REVIEW,
            "Tecnología no registrada; requiere evaluación institucional.",
            True,
        )
    return (
        str(item.get("classification", REVIEW)),
        str(item.get("reason", "Clasificación institucional.")),
        bool(item.get("adr_required", False)),
    )


def requirement_names(path: Path) -> list[str]:
    names: list[str] = []
    for raw in path.read_text(
        encoding="utf-8-sig",
        errors="replace",
    ).splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or line.startswith(("-", "--")):
            continue
        name = re.split(r"[<>=!~;\[\]\s]", line, maxsplit=1)[0].strip()
        if name:
            names.append(name)
    return names


def package_json_names(path: Path) -> list[str]:
    payload = load_json(path)
    names: list[str] = []
    if not isinstance(payload, dict):
        return names
    for section in ("dependencies", "devDependencies", "optionalDependencies"):
        value = payload.get(section, {})
        if isinstance(value, dict):
            names.extend(str(item) for item in value)
    return names


def compose_images(path: Path) -> list[str]:
    content = path.read_text(
        encoding="utf-8-sig",
        errors="replace",
    )
    return [
        value.strip().strip("'\"")
        for value in re.findall(
            r"(?im)^\s*image\s*:\s*([^\s#]+)",
            content,
        )
    ]


def workflow_node_types(path: Path) -> list[str]:
    payload = load_json(path)
    nodes = payload.get("nodes", []) if isinstance(payload, dict) else []
    return sorted(
        {
            str(node.get("type", "")).strip()
            for node in nodes
            if isinstance(node, dict) and str(node.get("type", "")).strip()
        }
    )


def adr_exceptions(root: Path) -> set[str]:
    approved: set[str] = set()
    adr_dir = root / "docs/03_ADR"
    if not adr_dir.is_dir():
        return approved

    for path in sorted(adr_dir.glob("*.md")):
        content = path.read_text(
            encoding="utf-8-sig",
            errors="replace",
        )
        if not re.search(
            r"(?im)^\s*(estado|status)\s*:\s*(aprobado|approved)\s*$",
            content,
        ):
            continue
        for match in re.findall(
            r"(?im)^\s*(?:tecnología|technology)\s*:\s*(.+?)\s*$",
            content,
        ):
            approved.add(normalize_name(match))
    return approved


def scan_repository(
    root_value: str | Path,
    registry_value: str | Path,
) -> dict[str, Any]:
    root = Path(root_value).resolve()
    registry_path = Path(registry_value)
    if not registry_path.is_absolute():
        registry_path = root / registry_path

    registry = load_json(registry_path)
    exceptions = adr_exceptions(root)
    findings: list[Finding] = []

    def add(source: Path, technology: str) -> None:
        classification, reason, adr_required = classify(
            technology,
            registry,
        )
        if (
            classification in {REVIEW, PROHIBITED}
            and normalize_name(technology) in exceptions
        ):
            classification = APPROVED
            reason = "Excepción aprobada mediante ADR institucional."
            adr_required = False

        findings.append(
            Finding(
                source=source.relative_to(root).as_posix(),
                technology=technology,
                classification=classification,
                reason=reason,
                adr_required=adr_required,
            )
        )

    for filename in ("requirements.txt", "requirements-dev.txt"):
        path = root / filename
        if path.is_file():
            for name in requirement_names(path):
                add(path, name)

    for path in sorted(root.rglob("package.json")):
        if any(part in {"node_modules", ".git", ".venv"} for part in path.parts):
            continue
        for name in package_json_names(path):
            add(path, name)

    for path in sorted(root.rglob("docker-compose*.yml")) + sorted(
        root.rglob("docker-compose*.yaml")
    ):
        if any(part in {".git", ".venv"} for part in path.parts):
            continue
        for image in compose_images(path):
            add(path, image.split("@", 1)[0].split(":", 1)[0])

    workflows = root / "automation/n8n/workflows"
    if workflows.is_dir():
        for path in sorted(workflows.glob("*.json")):
            for node_type in workflow_node_types(path):
                add(path, node_type)

    counts = {
        APPROVED: sum(item.classification == APPROVED for item in findings),
        REVIEW: sum(item.classification == REVIEW for item in findings),
        PROHIBITED: sum(item.classification == PROHIBITED for item in findings),
    }
    approved = counts[PROHIBITED] == 0 and counts[REVIEW] == 0

    return {
        "policy": "POL-001",
        "version": "1.0.1",
        "registry": registry_path.relative_to(root).as_posix(),
        "findings": [item.to_dict() for item in findings],
        "counts": counts,
        "approved": approved,
    }


def write_reports(
    report: dict[str, Any],
    output_dir_value: str | Path,
) -> None:
    output_dir = Path(output_dir_value)
    output_dir.mkdir(parents=True, exist_ok=True)

    (output_dir / "institutional-compliance.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    lines = [
        "# POL-001 — Informe de cumplimiento",
        "",
        f"- Aprobadas: {report['counts'][APPROVED]}",
        f"- Requieren revisión: {report['counts'][REVIEW]}",
        f"- Prohibidas: {report['counts'][PROHIBITED]}",
        f"- Resultado: {'APROBADO' if report['approved'] else 'NO APROBADO'}",
        "",
        "| Fuente | Tecnología | Clasificación | Motivo |",
        "|---|---|---|---|",
    ]
    for item in report["findings"]:
        lines.append(
            "| `{}` | `{}` | {} | {} |".format(
                item["source"],
                item["technology"],
                item["classification"],
                item["reason"].replace("|", "/"),
            )
        )

    (output_dir / "institutional-compliance.md").write_text(
        "\n".join(lines).rstrip() + "\n",
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--registry", required=True)
    parser.add_argument("--output-dir", required=True)
    args = parser.parse_args()

    report = scan_repository(args.root, args.registry)
    write_reports(report, args.output_dir)
    print(json.dumps(report, ensure_ascii=False))
    return 0 if report["approved"] else 2
