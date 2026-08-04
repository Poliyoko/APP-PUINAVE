
from __future__ import annotations
import argparse, html, json, re, subprocess
from collections import Counter
from pathlib import Path
from typing import Any

PREFIX = r"(?:ADR|CERT|PCI|SGD|SIB|SPA|SPB|SPT)"
EXACT = re.compile(
    rf"^{PREFIX}-[0-9]+(?:\.[0-9]+)*(?:[A-Z])?(?:-[A-Z][A-Z0-9]*)?$",
    re.I,
)
LINK = re.compile(r"\[[^\]]+\]\((?P<t>[^)]+)\)")
BACKTICK = re.compile(r"`(?P<c>[^`]+)`")
TABLE = re.compile(r"^\s*\|\s*(?P<c>[^|]+?)\s*\|")
HEADING = re.compile(r"^\s*#{1,6}\s+(?P<c>\S+)")
VERSIONED = re.compile(r"-V\d+(?:\.\d+){1,3}(?:-R\d+(?:\.\d+)*)?$", re.I)
FORBIDDEN = (".MD", ".JSON", ".PY", ".PS1", ".HTML", ".XML", ".YML", ".YAML")


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig", errors="replace") if path.is_file() else ""


def values(value: Any) -> list[str]:
    if isinstance(value, str):
        return [value] if value.strip() else []
    if isinstance(value, (list, tuple, set)):
        return [str(x) for x in value if str(x).strip()]
    return []


def valid_code(value: str) -> bool:
    candidate = value.strip().upper().strip("`:-")
    if candidate.endswith(FORBIDDEN) or VERSIONED.search(candidate):
        return False
    return bool(EXACT.fullmatch(candidate))


def extract_codes(text: str) -> set[str]:
    found: set[str] = set()
    for line in text.splitlines():
        candidates = [m.group("c") for m in BACKTICK.finditer(line)]
        table = TABLE.match(line)
        heading = HEADING.match(line)
        if table:
            candidates.append(table.group("c"))
        if heading:
            candidates.append(heading.group("c"))
        candidates.append(line.strip())
        for candidate in candidates:
            candidate = candidate.strip().strip("`:-").upper()
            if valid_code(candidate):
                found.add(candidate)
    return found


def scan_components(root: Path):
    components, invalid, ignored = [], [], []
    config = root / "config"
    if not config.is_dir():
        return components, invalid, ignored
    for path in sorted(config.rglob("*.json")):
        rel = path.relative_to(root).as_posix()
        try:
            payload = json.loads(path.read_text(encoding="utf-8-sig"))
        except (OSError, UnicodeError, json.JSONDecodeError):
            invalid.append(rel)
            continue
        if not path.name.lower().endswith("-component.json"):
            ignored.append(rel)
            continue
        if not isinstance(payload, dict):
            invalid.append(rel)
            continue
        code = str(
            payload.get("increment_code")
            or payload.get("component_code")
            or payload.get("code")
            or ""
        ).strip().upper()
        if not code:
            invalid.append(rel)
            continue
        status = str(payload.get("status", "unknown"))
        components.append({
            "code": code,
            "name": str(payload.get("name") or payload.get("title") or code),
            "version": str(payload.get("version", "")),
            "status": status,
            "descriptor_path": rel,
            "source_paths": values(payload.get("source") or payload.get("source_paths")),
            "test_paths": values(payload.get("tests") or payload.get("test_paths")),
            "documentation_paths": values(payload.get("documentation") or payload.get("documentation_paths") or payload.get("docs")),
            "dependencies": values(payload.get("dependencies")),
            "release_name": str(payload.get("release_name") or "") or None,
            "historical_increment": bool(VERSIONED.search(code))
                or status.casefold() in {"historical", "superseded", "archived", "deprecated"},
        })
    return components, invalid, ignored


def release_catalog(root: Path) -> list[dict[str, Any]]:
    result = []
    releases = root / "releases"
    if not releases.is_dir():
        return result
    for directory in sorted(releases.iterdir()):
        if not directory.is_dir():
            continue
        manifest = directory / "manifest.json"
        payload = {}
        if manifest.is_file():
            try:
                parsed = json.loads(manifest.read_text(encoding="utf-8-sig"))
                if isinstance(parsed, dict):
                    payload = parsed
            except Exception:
                payload = {}
        result.append({
            "directory": directory.name,
            "manifest": manifest.is_file(),
            "code": str(payload.get("increment_code") or payload.get("component_code") or payload.get("code") or "").upper(),
            "version": str(payload.get("version") or ""),
        })
    return result


def resolve_release(component: dict[str, Any], catalog: list[dict[str, Any]]):
    explicit = component.get("release_name")
    if explicit:
        for item in catalog:
            if item["directory"].casefold() == explicit.casefold():
                return item
    for item in catalog:
        if item["code"] == component["code"]:
            return item
    version = component.get("version")
    preferred = f"{component['code']}-v{version}" if version else component["code"]
    for item in catalog:
        if item["directory"].casefold() == preferred.casefold():
            return item
    candidates = [
        item for item in catalog
        if item["directory"].upper().startswith(component["code"] + "-V")
    ]
    return candidates[-1] if candidates else None


def broken_links(root: Path, index: Path, text: str):
    result = []
    for match in LINK.finditer(text):
        target = match.group("t").strip()
        if not target or target.startswith(("#", "http://", "https://")) or "://" in target:
            continue
        local = target.split("#", 1)[0]
        candidate = (index.parent / local).resolve()
        try:
            candidate.relative_to(root)
        except ValueError:
            result.append({"target": target, "reason": "outside_repository"})
            continue
        if not candidate.exists():
            result.append({"target": target, "reason": "not_found"})
    return result


def semantic(root: Path, item: dict[str, Any]) -> dict[str, Any]:
    docs = [root / p for p in item["documentation_paths"] if (root / p).is_file()]
    if not docs:
        return {"documents_checked": 0, "code_mentioned": False, "name_mentioned": False}
    text = "\n".join(read(p) for p in docs).casefold()
    return {
        "documents_checked": len(docs),
        "code_mentioned": item["code"].casefold() in text,
        "name_mentioned": item["name"].casefold() in text,
    }


def git_snapshot(root: Path) -> dict[str, Any]:
    def run(*args: str):
        try:
            p = subprocess.run(["git", *args], cwd=root, capture_output=True, text=True, timeout=10)
            return p.returncode, p.stdout.strip()
        except Exception:
            return 127, ""
    code, inside = run("rev-parse", "--is-inside-work-tree")
    if code != 0 or inside.lower() != "true":
        return {"available": False, "clean": None, "branch": None, "head": None, "tags": [], "remotes": []}
    _, status = run("status", "--porcelain")
    _, branch = run("branch", "--show-current")
    _, head = run("rev-parse", "HEAD")
    _, tags = run("tag", "--list")
    _, remotes = run("remote")
    return {
        "available": True,
        "clean": not bool(status),
        "branch": branch or None,
        "head": head or None,
        "tags": tags.splitlines() if tags else [],
        "remotes": remotes.splitlines() if remotes else [],
    }


def intelligent_audit(root_value: str | Path) -> dict[str, Any]:
    root = Path(root_value).resolve()
    docs = root / "docs"
    index = docs / "00_INDICE_MAESTRO.md"
    registry = docs / "00_REGISTRO_MAESTRO_COMPONENTES.md"
    architecture = docs / "00_ARQUITECTURA_MAESTRA.md"
    index_codes = extract_codes(read(index))
    registry_codes = extract_codes(read(registry))
    components, invalid, ignored = scan_components(root)
    releases = release_catalog(root)
    findings = []
    masters = {"index": index.is_file(), "registry": registry.is_file(), "architecture": architecture.is_file()}

    for name, exists in masters.items():
        if not exists:
            findings.append({"code": "MASTER_DOCUMENT_MISSING", "severity": "critical", "subject": name, "message": "Falta documento maestro.", "evidence": []})
    for path in invalid:
        findings.append({"code": "INVALID_CONFIGURATION_JSON", "severity": "critical", "subject": path, "message": "JSON inválido.", "evidence": []})
    for code, count in Counter(c["code"] for c in components).items():
        if count > 1:
            findings.append({
                "code": "DUPLICATE_CANONICAL_DESCRIPTOR",
                "severity": "critical",
                "subject": code,
                "message": "Existen varios *-component.json para el código.",
                "evidence": [c["descriptor_path"] for c in components if c["code"] == code],
            })
    for item in broken_links(root, index, read(index)):
        findings.append({"code": "BROKEN_MASTER_INDEX_LINK", "severity": "critical", "subject": item["target"], "message": "Enlace local no resoluble.", "evidence": [item["reason"]]})

    roots = {name: (root / name).is_dir() for name in ("src", "tests", "docs", "config", "artifacts", "releases", "scripts")}
    for name, exists in roots.items():
        if not exists:
            findings.append({"code": "REPOSITORY_ROOT_MISSING", "severity": "critical", "subject": name, "message": "Falta raíz institucional.", "evidence": []})

    rows, graph_nodes, graph_edges = [], [], []
    active_codes = {c["code"] for c in components if not c["historical_increment"]}
    canonical_codes = {c["code"] for c in components}

    for c in components:
        historical = c["historical_increment"]
        source = any((root / p).exists() for p in c["source_paths"])
        tests = any((root / p).exists() for p in c["test_paths"])
        documentation = any((root / p).exists() for p in c["documentation_paths"])
        release = resolve_release(c, releases)
        registered = c["code"] in registry_codes
        indexed = c["code"] in index_codes
        sem = semantic(root, c)

        if not historical and not registered:
            findings.append({"code": "ACTIVE_COMPONENT_NOT_REGISTERED", "severity": "warning", "subject": c["code"], "message": "Componente activo ausente del Registro.", "evidence": [c["descriptor_path"]]})
        if not historical and not indexed:
            findings.append({"code": "ACTIVE_COMPONENT_NOT_INDEXED", "severity": "info", "subject": c["code"], "message": "Componente activo no citado estructuralmente en el Índice.", "evidence": [c["descriptor_path"]]})
        if documentation and not sem["code_mentioned"]:
            findings.append({"code": "DOCUMENT_SEMANTIC_CODE_GAP", "severity": "warning", "subject": c["code"], "message": "Documentación sin mención del código.", "evidence": c["documentation_paths"]})

        checks = (source, tests, documentation, release is not None) if historical else (source, tests, documentation, release is not None, registered, indexed)
        row = {
            **c,
            "release": release,
            "semantic": sem,
            "traceability": {"source": source, "tests": tests, "documentation": documentation, "release": release is not None, "registry": registered, "index": indexed},
            "completion_percent": round(100 * sum(bool(x) for x in checks) / len(checks), 2),
        }
        rows.append(row)
        graph_nodes.append({"id": c["code"], "type": "historical_increment" if historical else "component", "status": c["status"]})
        for dep in c["dependencies"]:
            graph_edges.append({"source": c["code"], "target": dep.upper(), "relation": "depends_on"})
        for p in c["source_paths"]:
            graph_edges.append({"source": c["code"], "target": p, "relation": "implemented_by"})
        for p in c["test_paths"]:
            graph_edges.append({"source": c["code"], "target": p, "relation": "verified_by"})
        for p in c["documentation_paths"]:
            graph_edges.append({"source": c["code"], "target": p, "relation": "documented_by"})
        if release:
            graph_edges.append({"source": c["code"], "target": release["directory"], "relation": "released_as"})

    for code in sorted(registry_codes - canonical_codes):
        findings.append({"code": "REGISTRY_CODE_WITHOUT_CANONICAL_DESCRIPTOR", "severity": "warning", "subject": code, "message": "Código estructural sin descriptor canónico.", "evidence": []})

    git = git_snapshot(root)
    if git["available"] and not git["clean"]:
        findings.append({"code": "GIT_WORKTREE_NOT_CLEAN", "severity": "info", "subject": "git", "message": "Árbol con cambios durante la instalación.", "evidence": []})

    critical = sum(f["severity"] == "critical" for f in findings)
    warning = sum(f["severity"] == "warning" for f in findings)
    info = sum(f["severity"] == "info" for f in findings)
    active_count = len(active_codes)
    registry_coverage = round(100 * len(active_codes & registry_codes) / active_count, 2) if active_count else 100.0
    index_coverage = round(100 * len(active_codes & index_codes) / active_count, 2) if active_count else 100.0
    metrics = {
        "canonical_components": len(components),
        "active_components": active_count,
        "historical_increments": len(components) - active_count,
        "ignored_non_component_json": len(ignored),
        "complete_active_components": sum(r["completion_percent"] == 100 for r in rows if not r["historical_increment"]),
        "registry_coverage_percent": registry_coverage,
        "index_coverage_percent": index_coverage,
        "critical_findings": critical,
        "warning_findings": warning,
        "informational_findings": info,
        "institutional_consistency_score": round(max(0, (registry_coverage + index_coverage) / 2 - critical * 10 - warning * .25), 2),
    }
    approved = critical == 0
    return {
        "program": "PCI-SGODA-v1.0.0",
        "increment_code": "PCI-001.1",
        "deliverable": "SGD-201A.1",
        "version": "1.0.0",
        "approved": approved,
        "result": "APROBADO" if approved else "NO APROBADO",
        "exit_code": 0 if approved else 2,
        "master_documents": masters,
        "repository_roots": roots,
        "git": git,
        "metrics": metrics,
        "components": rows,
        "findings": findings,
        "ignored_configuration_files": ignored,
        "traceability_graph": {"nodes": graph_nodes, "edges": graph_edges},
    }


# Backward-compatible PCI-001 functions.
LEGACY_CODE = re.compile(
    r"\b(?:ADR|CERT|PCI|SGD|SIB|SPA|SPB|SPT)-"
    r"[0-9]+(?:\.[0-9]+)*(?:[A-Z])?"
    r"(?:-[A-Z][A-Z0-9]*)?\b",
    re.I,
)

LEGACY_FINDING_CODES = {
    "MASTER_DOCUMENT_MISSING",
    "INVALID_CONFIGURATION_JSON",
    "DUPLICATE_COMPONENT_DESCRIPTOR",
    "BROKEN_MASTER_INDEX_LINK",
    "COMPONENT_NOT_IN_MASTER_REGISTRY",
    "COMPONENT_NOT_IN_MASTER_INDEX",
    "REGISTRY_CODE_WITHOUT_DESCRIPTOR",
}


def code_set(text):
    return {
        match.group(0).upper()
        for match in LEGACY_CODE.finditer(str(text))
    }


def _legacy_duplicate_findings(root: Path):
    config = root / "config"
    identities = []
    if not config.is_dir():
        return []

    for path in sorted(config.rglob("*.json")):
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

        if code:
            identities.append(
                (
                    code,
                    path.relative_to(root).as_posix(),
                )
            )

    findings = []
    counts = Counter(code for code, _ in identities)
    for code, count in counts.items():
        if count <= 1:
            continue
        findings.append(
            {
                "code": "DUPLICATE_COMPONENT_DESCRIPTOR",
                "severity": "critical",
                "subject": code,
                "message": (
                    "Existen múltiples descriptores históricos "
                    "para el mismo componente."
                ),
                "evidence": [
                    path
                    for item_code, path in identities
                    if item_code == code
                ],
            }
        )
    return findings


def audit(root_value):
    root = Path(root_value).resolve()
    payload = intelligent_audit(root)
    findings = []

    for finding in payload["findings"]:
        code = finding["code"]

        if code in {
            "REPOSITORY_ROOT_MISSING",
            "GIT_WORKTREE_NOT_CLEAN",
            "DOCUMENT_SEMANTIC_CODE_GAP",
        }:
            continue

        item = dict(finding)

        if code == "ACTIVE_COMPONENT_NOT_REGISTERED":
            item["code"] = "COMPONENT_NOT_IN_MASTER_REGISTRY"
        elif code == "ACTIVE_COMPONENT_NOT_INDEXED":
            item["code"] = "COMPONENT_NOT_IN_MASTER_INDEX"
        elif code == "REGISTRY_CODE_WITHOUT_CANONICAL_DESCRIPTOR":
            item["code"] = "REGISTRY_CODE_WITHOUT_DESCRIPTOR"
        elif code == "DUPLICATE_CANONICAL_DESCRIPTOR":
            item["code"] = "DUPLICATE_COMPONENT_DESCRIPTOR"

        if item["code"] in LEGACY_FINDING_CODES:
            findings.append(item)

    duplicate_subjects = {
        item["subject"]
        for item in findings
        if item["code"] == "DUPLICATE_COMPONENT_DESCRIPTOR"
    }
    for item in _legacy_duplicate_findings(root):
        if item["subject"] not in duplicate_subjects:
            findings.append(item)

    critical = sum(
        item["severity"] == "critical"
        for item in findings
    )
    warning = sum(
        item["severity"] == "warning"
        for item in findings
    )
    informational = sum(
        item["severity"] == "info"
        for item in findings
    )

    compatible = dict(payload)
    compatible["findings"] = findings
    compatible["approved"] = critical == 0
    compatible["result"] = (
        "APROBADO" if critical == 0 else "NO APROBADO"
    )
    compatible["exit_code"] = 0 if critical == 0 else 2
    compatible["metrics"] = dict(payload["metrics"])
    compatible["metrics"]["critical_findings"] = critical
    compatible["metrics"]["warning_findings"] = warning
    compatible["metrics"]["informational_findings"] = informational
    return compatible


def scan(root_value):
    components, invalid, _ = scan_components(
        Path(root_value).resolve()
    )
    return components, invalid

def write_json(path: str | Path, value: Any):
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_outputs(payload, json_path, md_path, html_path):
    write_json(json_path, payload)
    m = payload["metrics"]
    lines = [
        "# SGD-201A.1-R3 — Auditor Inteligente del Índice Maestro",
        "",
        f"- Resultado: {payload['result']}",
        f"- Componentes canónicos: {m['canonical_components']}",
        f"- Componentes activos: {m['active_components']}",
        f"- Incrementos históricos: {m['historical_increments']}",
        f"- JSON auxiliares ignorados: {m['ignored_non_component_json']}",
        f"- Cobertura Registro: {m['registry_coverage_percent']}%",
        f"- Cobertura Índice: {m['index_coverage_percent']}%",
        f"- Consistencia: {m['institutional_consistency_score']}%",
        f"- Críticos: {m['critical_findings']}",
        "",
        "## Hallazgos",
        "",
        "| Severidad | Código | Sujeto | Mensaje |",
        "|---|---|---|---|",
    ]
    for f in payload["findings"]:
        lines.append(f"| {f['severity'].upper()} | {f['code']} | {str(f['subject']).replace('|','/')} | {str(f['message']).replace('|','/')} |")
    if not payload["findings"]:
        lines.append("| — | — | — | Sin hallazgos |")
    md = Path(md_path)
    md.parent.mkdir(parents=True, exist_ok=True)
    md.write_text("\n".join(lines) + "\n", encoding="utf-8")
    rows = "".join("<tr><td>{}</td><td>{}</td><td>{}</td><td>{}</td></tr>".format(html.escape(f["severity"]), html.escape(f["code"]), html.escape(str(f["subject"])), html.escape(f["message"])) for f in payload["findings"]) or "<tr><td colspan='4'>Sin hallazgos</td></tr>"
    target = Path(html_path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(f"<!doctype html><html lang='es'><meta charset='utf-8'><title>SGD-201A.1</title><style>body{{font-family:system-ui;margin:2rem}}.card{{display:inline-block;border:1px solid #aaa;padding:.7rem;margin:.3rem}}table{{border-collapse:collapse;width:100%}}th,td{{border:1px solid #aaa;padding:.4rem}}</style><h1>SGD-201A.1-R3 — Auditor Inteligente</h1><p><b>{payload['result']}</b></p><div class='card'>Canónicos {m['canonical_components']}</div><div class='card'>Activos {m['active_components']}</div><div class='card'>Históricos {m['historical_increments']}</div><div class='card'>Consistencia {m['institutional_consistency_score']}%</div><div class='card'>Críticos {m['critical_findings']}</div><table><tr><th>Severidad</th><th>Código</th><th>Sujeto</th><th>Mensaje</th></tr>{rows}</table></html>", encoding="utf-8")


def write_auxiliary(payload, metrics, trace, pmo):
    write_json(metrics, payload["metrics"])
    write_json(trace, payload["traceability_graph"])
    write_json(pmo, {
        "source": "PCI-001.1",
        "approved": payload["approved"],
        "result": payload["result"],
        "metrics": payload["metrics"],
    })


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--root", required=True)
    p.add_argument("--output-json", required=True)
    p.add_argument("--output-md", required=True)
    p.add_argument("--output-html", required=True)
    p.add_argument("--metrics-json", required=True)
    p.add_argument("--traceability-json", required=True)
    p.add_argument("--pmo-json", required=True)
    a = p.parse_args()
    payload = intelligent_audit(a.root)
    write_outputs(payload, a.output_json, a.output_md, a.output_html)
    write_auxiliary(payload, a.metrics_json, a.traceability_json, a.pmo_json)
    print(json.dumps(payload, ensure_ascii=False))
    return int(payload["exit_code"])
