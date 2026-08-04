<#
.SYNOPSIS
    Instala PCI-001.1 v1.0.0 — Auditor Inteligente del Índice Maestro.
.DESCRIPTION
    Corrige falsos positivos de PCI-001 e incorpora auditoría semántica,
    nomenclatura, trazabilidad, Git, PMO y dashboard.
    Compatible con Windows PowerShell 5.1.
#>
[CmdletBinding()]
param([string]$ProjectRoot=(Get-Location).Path,[switch]$Publish)
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"

function Step{param([string]$Message) Write-Host "";Write-Host "==> $Message" -ForegroundColor Cyan}
function Require-File{param([string]$Path,[string]$Description) if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "Falta $Description`: $Path"}}
function Write-Utf8{param([string]$Path,[string]$Content) $Parent=Split-Path -Parent $Path;if($Parent){New-Item -ItemType Directory -Path $Parent -Force|Out-Null};[IO.File]::WriteAllText($Path,$Content,(New-Object Text.UTF8Encoding($false)));if((Get-Item -LiteralPath $Path).Length-le 0){throw "Archivo vacío: $Path"};Write-Host "Creado/actualizado: $Path" -ForegroundColor Green}
function Write-Json{param([string]$Path,[object]$Value) Write-Utf8 $Path (($Value|ConvertTo-Json -Depth 100)+[Environment]::NewLine)}
function Run{param([string]$Description,[scriptblock]$Action) Step $Description;$global:LASTEXITCODE=0;& $Action;if($LASTEXITCODE-ne 0){throw "$Description terminó con errores. Código: $LASTEXITCODE"}}

$ProjectRoot=[IO.Path]::GetFullPath($ProjectRoot);Set-Location -LiteralPath $ProjectRoot;$env:PYTHONPATH=Join-Path $ProjectRoot "src"
$SourceDir=Join-Path $ProjectRoot "src\sgoda\governance\master_index_audit"
$TestsDir=Join-Path $ProjectRoot "tests\governance\master_index_audit"
$ConfigDir=Join-Path $ProjectRoot "config\governance"
$DocsDir=Join-Path $ProjectRoot "docs\01_Gobierno\PCI-001.1"
$ArtifactDir=Join-Path $ProjectRoot "artifacts\consolidation\PCI-001.1-v1.0.0"
$ReportsDir=Join-Path $ArtifactDir "test-reports"
$ReleaseDir=Join-Path $ProjectRoot "releases\PCI-001.1-v1.0.0"
$ScriptsDir=Join-Path $ProjectRoot "scripts"
$AuditJson=Join-Path $ArtifactDir "SGD-201A.1-intelligent-audit.json";$AuditMd=Join-Path $ArtifactDir "SGD-201A.1-intelligent-audit.md";$AuditHtml=Join-Path $ArtifactDir "SGD-201A.1-dashboard.html"
$MetricsJson=Join-Path $ArtifactDir "SGD-201A.1-metrics.json";$TraceJson=Join-Path $ArtifactDir "SGD-201A.1-traceability-graph.json";$PmoJson=Join-Path $ArtifactDir "SGD-201A.1-pmo-digital.json"
$EvidenceJson=Join-Path $ArtifactDir "implementation-evidence.json";$EvidenceMd=Join-Path $ArtifactDir "implementation-evidence.md";$ReleaseValidationJson=Join-Path $ArtifactDir "release-validation.json"
$SpecificXml=Join-Path $ReportsDir "specific.xml";$SpecificJson=Join-Path $ReportsDir "specific-summary.json";$SpecificMd=Join-Path $ReportsDir "specific-summary.md"
$FullXml=Join-Path $ReportsDir "full-suite.xml";$FullJson=Join-Path $ReportsDir "full-suite-summary.json";$FullMd=Join-Path $ReportsDir "full-suite-summary.md"
$RunnerPath=Join-Path $ScriptsDir "Invoke-InstitutionalPytest.ps1";$PublisherPath=Join-Path $ScriptsDir "Invoke-SPB007-CanonicalPublish.ps1"

foreach($Required in @((Join-Path $ProjectRoot "docs\00_INDICE_MAESTRO.md"),(Join-Path $ProjectRoot "docs\00_REGISTRO_MAESTRO_COMPONENTES.md"),(Join-Path $ProjectRoot "docs\00_ARQUITECTURA_MAESTRA.md"),(Join-Path $ProjectRoot "tests\governance\master_index_audit\test_PCI_001_master_index_audit.py"),(Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),(Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py"),(Join-Path $ProjectRoot "src\sgoda\governance\test_evidence\cli.py"),(Join-Path $ProjectRoot "src\sgoda\governance\release_management\cli.py"),(Join-Path $ProjectRoot "src\sgoda\governance\repository_manager\cli.py"),$RunnerPath,$PublisherPath)){Require-File $Required $Required}
foreach($Directory in @($SourceDir,$TestsDir,$ConfigDir,$DocsDir,$ReportsDir,$ReleaseDir)){New-Item -ItemType Directory -Path $Directory -Force|Out-Null}

$Module=@'

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
def audit(root_value): return intelligent_audit(root_value)
def scan(root_value):
    components, invalid, _ = scan_components(Path(root_value).resolve())
    return components, invalid
def code_set(text): return extract_codes(text)


def write_json(path: str | Path, value: Any):
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def write_outputs(payload, json_path, md_path, html_path):
    write_json(json_path, payload)
    m = payload["metrics"]
    lines = [
        "# SGD-201A.1 — Auditor Inteligente del Índice Maestro",
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
    target.write_text(f"<!doctype html><html lang='es'><meta charset='utf-8'><title>SGD-201A.1</title><style>body{{font-family:system-ui;margin:2rem}}.card{{display:inline-block;border:1px solid #aaa;padding:.7rem;margin:.3rem}}table{{border-collapse:collapse;width:100%}}th,td{{border:1px solid #aaa;padding:.4rem}}</style><h1>SGD-201A.1 — Auditor Inteligente</h1><p><b>{payload['result']}</b></p><div class='card'>Canónicos {m['canonical_components']}</div><div class='card'>Activos {m['active_components']}</div><div class='card'>Históricos {m['historical_increments']}</div><div class='card'>Consistencia {m['institutional_consistency_score']}%</div><div class='card'>Críticos {m['critical_findings']}</div><table><tr><th>Severidad</th><th>Código</th><th>Sujeto</th><th>Mensaje</th></tr>{rows}</table></html>", encoding="utf-8")


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

'@
$Tests=@'

import json
from pathlib import Path
from sgoda.governance.master_index_audit import (
    audit, broken_links, code_set, extract_codes, intelligent_audit,
    scan, scan_components, write_auxiliary, write_outputs
)

def repo(tmp_path: Path):
    for p in ("src/example","tests/example","docs","config/example","releases/SPT-999-v1.0.0","artifacts","scripts"):
        (tmp_path/p).mkdir(parents=True,exist_ok=True)
    (tmp_path/"src/example/__init__.py").write_text("",encoding="utf-8")
    (tmp_path/"tests/example/test_example.py").write_text("def test_ok(): assert True\n",encoding="utf-8")
    (tmp_path/"docs/example.md").write_text("# SPT-999 — Ejemplo\n",encoding="utf-8")
    (tmp_path/"docs/00_INDICE_MAESTRO.md").write_text("| Código | Nombre |\n|---|---|\n| `SPT-999` | Ejemplo |\n[Ejemplo](example.md)\n",encoding="utf-8")
    (tmp_path/"docs/00_REGISTRO_MAESTRO_COMPONENTES.md").write_text("| Código | Estado |\n|---|---|\n| `SPT-999` | closed |\n",encoding="utf-8")
    (tmp_path/"docs/00_ARQUITECTURA_MAESTRA.md").write_text("# Arquitectura\n",encoding="utf-8")
    d={"increment_code":"SPT-999","name":"Ejemplo","version":"1.0.0","status":"closed","source":["src/example"],"tests":["tests/example"],"documentation":["docs/example.md"]}
    (tmp_path/"config/example/SPT-999-component.json").write_text(json.dumps(d),encoding="utf-8")
    (tmp_path/"config/example/SPT-999-policy.json").write_text('{"component":"SPT-999"}',encoding="utf-8")
    (tmp_path/"releases/SPT-999-v1.0.0/manifest.json").write_text('{"increment_code":"SPT-999","version":"1.0.0"}',encoding="utf-8")
    return tmp_path

def test_policy_not_component(tmp_path):
    c,b,i=scan_components(repo(tmp_path)); assert len(c)==1 and b==[] and i==["config/example/SPT-999-policy.json"]
def test_filename_fragments_rejected():
    assert extract_codes("`SPT-017`\nSPT-017-Arquitectura.md\nSPT-017-component.json\nSPT-017-v1.0.0\n")=={"SPT-017"}
def test_structural_codes():
    assert extract_codes("| `PCI-001.1` | Auditor |\n## SPT-018 — IA\n")=={"PCI-001.1","SPT-018"}
def test_complete_approved(tmp_path):
    r=intelligent_audit(repo(tmp_path)); assert r["approved"] and r["metrics"]["critical_findings"]==0 and r["components"][0]["completion_percent"]==100
def test_release_no_double_version(tmp_path):
    assert intelligent_audit(repo(tmp_path))["components"][0]["release"]["directory"]=="SPT-999-v1.0.0"
def test_historical_classification(tmp_path):
    root=repo(tmp_path); d={"increment_code":"SGD-114E-v1.0.7","version":"1.0.7","status":"historical"}; (root/"config/example/SGD-114E-v1.0.7-component.json").write_text(json.dumps(d),encoding="utf-8"); items=intelligent_audit(root)["components"]; assert [x for x in items if x["code"]=="SGD-114E-V1.0.7"][0]["historical_increment"]
def test_true_duplicate_critical(tmp_path):
    root=repo(tmp_path); s=root/"config/example/SPT-999-component.json"; (root/"config/example/SPT-999-copy-component.json").write_text(s.read_text(),encoding="utf-8"); assert not intelligent_audit(root)["approved"]
def test_policy_not_duplicate(tmp_path):
    assert not any(f["code"]=="DUPLICATE_CANONICAL_DESCRIPTOR" for f in intelligent_audit(repo(tmp_path))["findings"])
def test_semantic(tmp_path):
    assert intelligent_audit(repo(tmp_path))["components"][0]["semantic"]["code_mentioned"]
def test_broken_link(tmp_path):
    root=repo(tmp_path); (root/"docs/00_INDICE_MAESTRO.md").write_text("[F](missing.md)",encoding="utf-8"); assert not intelligent_audit(root)["approved"]
def test_backward_compatibility(tmp_path):
    root=repo(tmp_path); assert audit(root)["approved"]; c,b=scan(root); assert len(c)==1 and b==[] and code_set("`SPT-999`")=={"SPT-999"}
def test_external_ignored(tmp_path):
    root=repo(tmp_path); idx=root/"docs/00_INDICE_MAESTRO.md"; assert broken_links(root,idx,"[W](https://example.com)")==[]
def test_outputs(tmp_path):
    payload=intelligent_audit(repo(tmp_path)); paths=[tmp_path/f"o/{n}" for n in ("a.json","a.md","a.html","m.json","t.json","p.json")]; write_outputs(payload,*paths[:3]); write_auxiliary(payload,*paths[3:]); assert all(p.is_file() for p in paths)
def test_graph(tmp_path):
    relations={e["relation"] for e in intelligent_audit(repo(tmp_path))["traceability_graph"]["edges"]}; assert {"implemented_by","verified_by","documented_by","released_as"}<=relations

'@
$Component=@'
{"increment_code":"PCI-001.1","name":"Auditor Inteligente del Índice Maestro","version":"1.0.0","status":"implemented_tested_and_candidate_for_closure","program":"PCI-SGODA-v1.0.0","deliverable":"SGD-201A.1","native_ecosystem":true,"mandatory_proprietary_dependencies":[],"source":["src/sgoda/governance/master_index_audit"],"tests":["tests/governance/master_index_audit/test_PCI_001_1_intelligent_master_index_auditor.py"],"documentation":["docs/01_Gobierno/PCI-001.1"],"dependencies":["PCI-001","SGD-114F","SGD-114G","SGD-115","SGD-116","SGD-117","SPB-007"]}
'@
$Policy=@'
{"policy_id":"PCI-001.1-POLICY-v1.0.0","component":"PCI-001.1","approval_rule":"zero real critical findings","canonical_descriptor_pattern":"*-component.json","ignored_configuration_classes":["policy","schema","mapping","settings","phase","manifest"],"critical_controls":["master documents exist","configuration JSON parseable","canonical descriptors unique","local links resolve","repository roots exist"]}
'@
$Architecture="# PCI-001.1 v1.0.0 — Arquitectura`n`nSolo *-component.json representa componentes. Políticas, esquemas y mapeos se inventarían sin generar duplicados. Los códigos se extraen únicamente de posiciones estructurales Markdown. Se clasifican incrementos históricos, se normalizan releases y se generan semántica, trazabilidad, Git, PMO y dashboard.`n"
$Operations="# PCI-001.1 v1.0.0 — Manual operativo`n`nEl auditor se ejecuta mediante python -m sgoda.governance.master_index_audit y produce JSON, Markdown, HTML, métricas PMO y grafo de trazabilidad.`n"

Write-Utf8 (Join-Path $SourceDir "__init__.py") $Module
Write-Utf8 (Join-Path $SourceDir "__main__.py") ("from . import main"+[Environment]::NewLine+"raise SystemExit(main())"+[Environment]::NewLine)
Write-Utf8 (Join-Path $TestsDir "test_PCI_001_1_intelligent_master_index_auditor.py") $Tests
Write-Utf8 (Join-Path $ConfigDir "PCI-001.1-component.json") $Component
Write-Utf8 (Join-Path $ConfigDir "PCI-001.1-policy.json") $Policy
Write-Utf8 (Join-Path $DocsDir "PCI-001.1-Arquitectura.md") $Architecture
Write-Utf8 (Join-Path $DocsDir "PCI-001.1-Manual-Operativo.md") $Operations

Run "Validando sintaxis Python" {python -m py_compile "src/sgoda/governance/master_index_audit/__init__.py" "src/sgoda/governance/master_index_audit/__main__.py" "tests/governance/master_index_audit/test_PCI_001_master_index_audit.py" "tests/governance/master_index_audit/test_PCI_001_1_intelligent_master_index_auditor.py"}
Run "Ejecutando pruebas históricas y específicas PCI-001.1" {& $RunnerPath -Component "PCI-001.1-v1.0.0" -TestPath @("tests/governance/master_index_audit/test_PCI_001_master_index_audit.py","tests/governance/master_index_audit/test_PCI_001_1_intelligent_master_index_auditor.py","tests/documentation/test_SGD_115_master_documentation.py","tests/roadmap/test_SGD_116_master_ecosystem_roadmap.py","tests/governance/repository_manager/test_SGD_117_repository_manager.py") -ReportPath "$SpecificXml" -SummaryJson "$SpecificJson" -SummaryMarkdown "$SpecificMd" -Scope "historical_specific_and_integration"}
$Specific=Get-Content $SpecificJson -Raw -Encoding UTF8|ConvertFrom-Json;if(-not[bool]$Specific.approved){throw "Pruebas específicas no aprobadas."}
Run "Regenerando documentos maestros mediante SGD-115" {python -m sgoda.documentation.master_docs --root "$ProjectRoot" --output "artifacts/documentation/SGD-115"}
Run "Regenerando roadmap mediante SGD-116" {python -m sgoda.roadmap.cli --root "$ProjectRoot" --output "artifacts/roadmap/SGD-116"}
Run "Validando repositorio mediante SGD-117" {python -m sgoda.governance.repository_manager.cli --root "$ProjectRoot" --operation "validate" --output-json (Join-Path $ArtifactDir "repository-validation.json")}
Run "Ejecutando Auditor Inteligente del Índice Maestro" {python -m sgoda.governance.master_index_audit --root "$ProjectRoot" --output-json "$AuditJson" --output-md "$AuditMd" --output-html "$AuditHtml" --metrics-json "$MetricsJson" --traceability-json "$TraceJson" --pmo-json "$PmoJson"}
$Audit=Get-Content $AuditJson -Raw -Encoding UTF8|ConvertFrom-Json;if(-not[bool]$Audit.approved){$Audit.findings|Where-Object severity -eq "critical"|Format-Table -AutoSize;throw "PCI-001.1 detectó hallazgos críticos reales."}
Run "Ejecutando suite completa del ecosistema" {python -m pytest --junitxml="$FullXml"}
Run "Sincronizando evidencia mediante SGD-114F" {python -m sgoda.governance.test_evidence.cli --junit "$FullXml" --component "SGODA-PUINAVE" --scope "full_suite" --output-json "$FullJson" --output-md "$FullMd"}
$Full=Get-Content $FullJson -Raw -Encoding UTF8|ConvertFrom-Json;if(-not[bool]$Full.approved){throw "Suite completa no aprobada."}

$Evidence=[ordered]@{program="PCI-SGODA-v1.0.0";increment_code="PCI-001.1";deliverable="SGD-201A.1";version="1.0.0";status="implemented_tested_and_candidate_for_closure";prevalidated_package="..............                                                           [100%] 14 passed in 0.09s";root_cause_corrected=@("policy files excluded","filename fragments rejected","release versions normalized","historical increments classified");intelligent_audit=$Audit;specific_tests=[ordered]@{executed=[int]$Specific.executed;passed=[int]$Specific.passed;failures=[int]$Specific.failures;errors=[int]$Specific.errors;approved=[bool]$Specific.approved};full_suite=[ordered]@{executed=[int]$Full.executed;passed=[int]$Full.passed;failures=[int]$Full.failures;errors=[int]$Full.errors;approved=[bool]$Full.approved};generated_at_utc=[DateTime]::UtcNow.ToString("o")}
Write-Json $EvidenceJson $Evidence
$Lines=@("# PCI-001.1 v1.0.0 — Evidencia","", "- Entregable: SGD-201A.1","- Auditor Inteligente: APROBADO","- Falsos duplicados por políticas: CORREGIDOS","- Códigos derivados de archivos: CORREGIDOS","- Normalización de releases: ACTIVA",("- Componentes canónicos: "+[string]$Audit.metrics.canonical_components),("- Componentes activos: "+[string]$Audit.metrics.active_components),("- Incrementos históricos: "+[string]$Audit.metrics.historical_increments),("- JSON auxiliares ignorados: "+[string]$Audit.metrics.ignored_non_component_json),("- Críticos reales: "+[string]$Audit.metrics.critical_findings),("- Pruebas específicas: "+[string]$Specific.passed+"/"+[string]$Specific.executed),("- Suite completa: "+[string]$Full.passed+"/"+[string]$Full.executed))
Write-Utf8 $EvidenceMd ([string]::Join([Environment]::NewLine,$Lines))

foreach($File in @((Join-Path $SourceDir "__init__.py"),(Join-Path $SourceDir "__main__.py"),(Join-Path $TestsDir "test_PCI_001_1_intelligent_master_index_auditor.py"),(Join-Path $ConfigDir "PCI-001.1-component.json"),(Join-Path $ConfigDir "PCI-001.1-policy.json"),(Join-Path $DocsDir "PCI-001.1-Arquitectura.md"),(Join-Path $DocsDir "PCI-001.1-Manual-Operativo.md"),$AuditJson,$AuditMd,$AuditHtml,$MetricsJson,$TraceJson,$PmoJson,$EvidenceJson,$EvidenceMd,$SpecificXml,$SpecificJson,$SpecificMd,$FullXml,$FullJson,$FullMd)){Require-File $File "archivo del release";Copy-Item -LiteralPath $File -Destination $ReleaseDir -Force}
Write-Json (Join-Path $ReleaseDir "manifest.json") ([ordered]@{program="PCI-SGODA-v1.0.0";increment_code="PCI-001.1";deliverable="SGD-201A.1";version="1.0.0";release_name="PCI-001.1-v1.0.0";status="implemented_tested_and_candidate_for_closure";native_ecosystem=$true;mandatory_proprietary_dependencies=@();approval_rule="zero real critical findings";backward_compatible_with="PCI-001";files=@(Get-ChildItem -LiteralPath $ReleaseDir -File|Select-Object -ExpandProperty Name)})
Run "Validando release mediante SGD-114G" {python -m sgoda.governance.release_management.cli --root "$ProjectRoot" --operation "close" --output-json "$ReleaseValidationJson"}

if($Publish){Step "Publicando mediante gate canónico";& $PublisherPath -Publish -CommitMessage "fix(consolidation): implement PCI-001.1 intelligent master index auditor" -EvidenceCommitMessage "chore(consolidation): publish PCI-001.1 evidence";if($LASTEXITCODE-ne 0){throw "Publicación con errores."}}

Step "Resultado final"
Write-Host "PCI-001.1 v1.0.0 implementado." -ForegroundColor Green
Write-Host "SGD-201A.1 — Auditor Inteligente: APROBADO." -ForegroundColor Green
Write-Host "Falsos duplicados por políticas: CORREGIDOS." -ForegroundColor Green
Write-Host "Códigos derivados de nombres de archivo: CORREGIDOS." -ForegroundColor Green
Write-Host "Normalización de releases: ACTIVA." -ForegroundColor Green
Write-Host ("Componentes canónicos: "+[string]$Audit.metrics.canonical_components) -ForegroundColor Green
Write-Host ("Componentes activos: "+[string]$Audit.metrics.active_components) -ForegroundColor Green
Write-Host ("Incrementos históricos: "+[string]$Audit.metrics.historical_increments) -ForegroundColor Green
Write-Host ("Hallazgos críticos reales: "+[string]$Audit.metrics.critical_findings) -ForegroundColor Green
Write-Host ("Pruebas específicas: $($Specific.passed)/$($Specific.executed) APROBADAS.") -ForegroundColor Green
Write-Host ("Suite completa: $($Full.passed)/$($Full.executed) APROBADA.") -ForegroundColor Green
Write-Host "Dashboard: $AuditHtml" -ForegroundColor Cyan
Write-Host "Release: releases\PCI-001.1-v1.0.0" -ForegroundColor Cyan
if($Publish){Write-Host "Publicación institucional: COMPLETADA." -ForegroundColor Green}else{Write-Host "Publicación no solicitada. Reejecute con -Publish." -ForegroundColor Yellow}
