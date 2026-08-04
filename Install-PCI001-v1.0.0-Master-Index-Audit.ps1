<#
.SYNOPSIS
    Instala PCI-001 v1.0.0 — Auditoría del Índice Maestro.
.DESCRIPTION
    Primer incremento del Programa de Consolidación Institucional SGODA v1.0.0.
    Compatible con Windows PowerShell 5.1.
#>
[CmdletBinding()]
param([string]$ProjectRoot=(Get-Location).Path,[switch]$Publish)
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"

function Step { param([string]$Message) Write-Host ""; Write-Host "==> $Message" -ForegroundColor Cyan }
function Require-File { param([string]$Path,[string]$Description) if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "Falta $Description`: $Path"}}
function Write-Utf8 { param([string]$Path,[string]$Content) $Parent=Split-Path -Parent $Path; if($Parent){New-Item -ItemType Directory -Path $Parent -Force|Out-Null}; [IO.File]::WriteAllText($Path,$Content,(New-Object Text.UTF8Encoding($false))); if((Get-Item -LiteralPath $Path).Length-le 0){throw "Archivo vacío: $Path"}; Write-Host "Creado/actualizado: $Path" -ForegroundColor Green }
function Write-Json { param([string]$Path,[object]$Value) Write-Utf8 $Path (($Value|ConvertTo-Json -Depth 100)+[Environment]::NewLine) }
function Run { param([string]$Description,[scriptblock]$Action) Step $Description; $global:LASTEXITCODE=0; & $Action; if($LASTEXITCODE-ne 0){throw "$Description terminó con errores. Código: $LASTEXITCODE"}}

$ProjectRoot=[IO.Path]::GetFullPath($ProjectRoot); Set-Location -LiteralPath $ProjectRoot; $env:PYTHONPATH=Join-Path $ProjectRoot "src"
$SourceDir=Join-Path $ProjectRoot "src\sgoda\governance\master_index_audit"
$TestsDir=Join-Path $ProjectRoot "tests\governance\master_index_audit"
$ConfigDir=Join-Path $ProjectRoot "config\governance"
$DocsDir=Join-Path $ProjectRoot "docs\01_Gobierno\PCI-001"
$ScriptsDir=Join-Path $ProjectRoot "scripts"
$PmoDir=Join-Path $ProjectRoot "artifacts\consolidation\PCI-001-v1.0.0"
$ReportsDir=Join-Path $PmoDir "test-reports"
$ReleaseDir=Join-Path $ProjectRoot "releases\PCI-001-v1.0.0"
$InitialJson=Join-Path $PmoDir "SGD-201A-initial-audit.json"; $InitialMd=Join-Path $PmoDir "SGD-201A-initial-audit.md"; $InitialHtml=Join-Path $PmoDir "SGD-201A-initial-audit.html"
$FinalJson=Join-Path $PmoDir "SGD-201A-final-audit.json"; $FinalMd=Join-Path $PmoDir "SGD-201A-final-audit.md"; $FinalHtml=Join-Path $PmoDir "SGD-201A-final-audit.html"
$MetricsJson=Join-Path $PmoDir "SGD-201A-metrics.json"; $TraceabilityJson=Join-Path $PmoDir "SGD-201A-traceability.json"; $EvidenceJson=Join-Path $PmoDir "implementation-evidence.json"; $EvidenceMd=Join-Path $PmoDir "implementation-evidence.md"; $ReleaseValidationJson=Join-Path $PmoDir "release-validation.json"
$SpecificXml=Join-Path $ReportsDir "specific.xml"; $SpecificJson=Join-Path $ReportsDir "specific-summary.json"; $SpecificMd=Join-Path $ReportsDir "specific-summary.md"
$FullXml=Join-Path $ReportsDir "full-suite.xml"; $FullJson=Join-Path $ReportsDir "full-suite-summary.json"; $FullMd=Join-Path $ReportsDir "full-suite-summary.md"
$RunnerPath=Join-Path $ScriptsDir "Invoke-InstitutionalPytest.ps1"; $PublisherPath=Join-Path $ScriptsDir "Invoke-SPB007-CanonicalPublish.ps1"

foreach($Required in @((Join-Path $ProjectRoot "docs\00_INDICE_MAESTRO.md"),(Join-Path $ProjectRoot "docs\00_REGISTRO_MAESTRO_COMPONENTES.md"),(Join-Path $ProjectRoot "docs\00_ARQUITECTURA_MAESTRA.md"),(Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),(Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py"),(Join-Path $ProjectRoot "src\sgoda\governance\test_evidence\cli.py"),(Join-Path $ProjectRoot "src\sgoda\governance\release_management\cli.py"),(Join-Path $ProjectRoot "src\sgoda\governance\repository_manager\cli.py"),$RunnerPath,$PublisherPath)){Require-File $Required $Required}
foreach($Directory in @($SourceDir,$TestsDir,$ConfigDir,$DocsDir,$ReportsDir,$ReleaseDir)){New-Item -ItemType Directory -Path $Directory -Force|Out-Null}

$Module=@'

from __future__ import annotations
import argparse, html, json, re
from collections import Counter
from pathlib import Path
from typing import Any

CODE_RE = re.compile(r"\b(?:ADR|CERT|PCI|SGD|SIB|SPA|SPB|SPT)-[A-Z0-9]+(?:[A-Z.-]*[A-Z0-9])?\b", re.I)
LINK_RE = re.compile(r"\[[^\]]+\]\((?P<t>[^)]+)\)")
CODE_KEYS = ("increment_code", "component_code", "code", "id")

def read(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig", errors="replace") if path.is_file() else ""

def strings(value: Any) -> tuple[str, ...]:
    if isinstance(value, str): return (value,)
    if isinstance(value, (list, tuple, set)):
        return tuple(str(x) for x in value if str(x).strip())
    return ()

def first(payload: dict[str, Any]) -> str:
    for key in CODE_KEYS:
        value = payload.get(key)
        if value is not None and str(value).strip(): return str(value).strip()
    return ""

def scan(root: Path):
    descriptors, invalid = [], []
    config = root / "config"
    if not config.is_dir(): return descriptors, invalid
    for path in sorted(config.rglob("*.json")):
        try:
            payload = json.loads(path.read_text(encoding="utf-8-sig"))
        except (OSError, UnicodeError, json.JSONDecodeError):
            invalid.append(path.relative_to(root).as_posix()); continue
        if not isinstance(payload, dict): continue
        code = first(payload)
        if not code: continue
        version = str(payload.get("version", "")).strip()
        release = str(payload.get("release_name") or "").strip() or (f"{code}-v{version}" if version else "")
        descriptors.append({
            "code": code,
            "name": str(payload.get("name") or payload.get("title") or code),
            "version": version,
            "status": str(payload.get("status", "unknown")),
            "descriptor_path": path.relative_to(root).as_posix(),
            "source_paths": list(strings(payload.get("source") or payload.get("source_paths") or payload.get("code_paths"))),
            "test_paths": list(strings(payload.get("tests") or payload.get("test_paths"))),
            "documentation_paths": list(strings(payload.get("documentation") or payload.get("documentation_paths") or payload.get("docs"))),
            "dependencies": list(strings(payload.get("dependencies"))),
            "release_name": release or None,
        })
    return descriptors, invalid

def code_set(text: str) -> set[str]:
    return {m.group(0).upper() for m in CODE_RE.finditer(text)}

def broken_links(root: Path, index: Path, text: str):
    result = []
    for match in LINK_RE.finditer(text):
        target = match.group("t").strip()
        if not target or target.startswith(("#", "http://", "https://")) or "://" in target: continue
        local = target.split("#", 1)[0]
        candidate = (index.parent / local).resolve()
        try: candidate.relative_to(root)
        except ValueError:
            result.append({"target": target, "reason": "outside_repository"}); continue
        if not candidate.exists(): result.append({"target": target, "reason": "not_found"})
    return result

def audit(root_value: str | Path) -> dict[str, Any]:
    root = Path(root_value).resolve()
    index = root / "docs/00_INDICE_MAESTRO.md"
    registry = root / "docs/00_REGISTRO_MAESTRO_COMPONENTES.md"
    architecture = root / "docs/00_ARQUITECTURA_MAESTRA.md"
    index_text, registry_text = read(index), read(registry)
    descriptors, invalid = scan(root)
    d_codes = [d["code"].upper() for d in descriptors]
    d_set, i_set, r_set = set(d_codes), code_set(index_text), code_set(registry_text)
    releases_dir = root / "releases"
    releases = {p.name for p in releases_dir.iterdir() if p.is_dir()} if releases_dir.is_dir() else set()
    findings = []

    masters = {"index": index.is_file(), "registry": registry.is_file(), "architecture": architecture.is_file()}
    for name, exists in masters.items():
        if not exists: findings.append({"code":"MASTER_DOCUMENT_MISSING","severity":"critical","subject":name,"message":f"Falta el documento maestro: {name}.","evidence":[]})
    for path in invalid:
        findings.append({"code":"INVALID_CONFIGURATION_JSON","severity":"critical","subject":path,"message":"JSON de configuración inválido.","evidence":[]})
    for code, count in Counter(d_codes).items():
        if count > 1:
            findings.append({"code":"DUPLICATE_COMPONENT_DESCRIPTOR","severity":"critical","subject":code,"message":"Existen descriptores duplicados.","evidence":[d["descriptor_path"] for d in descriptors if d["code"].upper()==code]})
    for item in broken_links(root, index, index_text):
        findings.append({"code":"BROKEN_MASTER_INDEX_LINK","severity":"critical","subject":item["target"],"message":"Enlace local no resoluble en el Índice Maestro.","evidence":[item["reason"]]})
    for code in sorted(d_set-r_set):
        findings.append({"code":"COMPONENT_NOT_IN_MASTER_REGISTRY","severity":"warning","subject":code,"message":"Componente no explícito en el Registro Maestro.","evidence":[]})
    for code in sorted(d_set-i_set):
        findings.append({"code":"COMPONENT_NOT_IN_MASTER_INDEX","severity":"info","subject":code,"message":"Componente no explícito en el Índice Maestro.","evidence":[]})
    for code in sorted(r_set-d_set):
        findings.append({"code":"REGISTRY_CODE_WITHOUT_DESCRIPTOR","severity":"warning","subject":code,"message":"Código del Registro sin descriptor localizado.","evidence":[]})

    rows, complete = [], 0
    for d in descriptors:
        source = any((root/p).exists() for p in d["source_paths"])
        tests = any((root/p).exists() for p in d["test_paths"])
        docs = any((root/p).exists() for p in d["documentation_paths"])
        release = bool(d["release_name"] and d["release_name"] in releases)
        registered, indexed = d["code"].upper() in r_set, d["code"].upper() in i_set
        pct = round(100*sum(map(bool,(source,tests,docs,release,registered)))/5,2)
        if pct == 100: complete += 1
        rows.append({**d,"source_exists":source,"tests_exist":tests,"documentation_exists":docs,"release_exists":release,"registered":registered,"indexed":indexed,"completion_percent":pct})

    critical = sum(f["severity"]=="critical" for f in findings)
    count = len(descriptors)
    metrics = {
        "component_descriptors": count,
        "complete_components": complete,
        "registry_coverage_percent": round(100*len(d_set&r_set)/count,2) if count else 100.0,
        "index_coverage_percent": round(100*len(d_set&i_set)/count,2) if count else 100.0,
        "markdown_documents": len(list((root/"docs").rglob("*.md"))) if (root/"docs").is_dir() else 0,
        "test_files": len(list((root/"tests").rglob("test_*.py"))) if (root/"tests").is_dir() else 0,
        "releases": len(releases),
        "critical_findings": critical,
        "warning_findings": sum(f["severity"]=="warning" for f in findings),
        "informational_findings": sum(f["severity"]=="info" for f in findings),
    }
    return {"program":"PCI-SGODA-v1.0.0","increment_code":"PCI-001","deliverable":"SGD-201A","version":"1.0.0","approved":critical==0,"exit_code":0 if critical==0 else 2,"master_documents":masters,"metrics":metrics,"components":rows,"findings":findings}

def write_outputs(payload, jp, mp, hp):
    jp, mp, hp = Path(jp), Path(mp), Path(hp)
    for p in (jp,mp,hp): p.parent.mkdir(parents=True, exist_ok=True)
    jp.write_text(json.dumps(payload,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    m=payload["metrics"]
    lines=["# SGD-201A — Auditoría del Índice Maestro","",f"- Resultado: {'APROBADO' if payload['approved'] else 'NO APROBADO'}",f"- Componentes: {m['component_descriptors']}",f"- Cobertura Registro Maestro: {m['registry_coverage_percent']}%",f"- Cobertura Índice Maestro: {m['index_coverage_percent']}%",f"- Hallazgos críticos: {m['critical_findings']}","", "## Hallazgos","", "| Severidad | Código | Sujeto | Mensaje |","|---|---|---|---|"]
    for f in payload["findings"]: lines.append(f"| {f['severity'].upper()} | {f['code']} | {str(f['subject']).replace('|','/')} | {str(f['message']).replace('|','/')} |")
    if not payload["findings"]: lines.append("| — | — | — | Sin hallazgos |")
    mp.write_text("\n".join(lines)+"\n",encoding="utf-8")
    rows="".join("<tr><td>{}</td><td>{}</td><td>{}</td><td>{}</td></tr>".format(html.escape(f["severity"]),html.escape(f["code"]),html.escape(str(f["subject"])),html.escape(f["message"])) for f in payload["findings"]) or "<tr><td colspan='4'>Sin hallazgos</td></tr>"
    hp.write_text(f"<!doctype html><html lang='es'><meta charset='utf-8'><title>SGD-201A</title><style>body{{font-family:system-ui;margin:2rem}}table{{border-collapse:collapse;width:100%}}th,td{{border:1px solid #aaa;padding:.4rem}}</style><h1>SGD-201A — Auditoría del Índice Maestro</h1><p><b>Resultado:</b> {'APROBADO' if payload['approved'] else 'NO APROBADO'}</p><p>Componentes: {m['component_descriptors']} | Registro: {m['registry_coverage_percent']}% | Índice: {m['index_coverage_percent']}% | Críticos: {m['critical_findings']}</p><table><tr><th>Severidad</th><th>Código</th><th>Sujeto</th><th>Mensaje</th></tr>{rows}</table></html>",encoding="utf-8")

def main():
    p=argparse.ArgumentParser(); p.add_argument("--root",required=True); p.add_argument("--output-json",required=True); p.add_argument("--output-md",required=True); p.add_argument("--output-html",required=True); a=p.parse_args()
    payload=audit(a.root); write_outputs(payload,a.output_json,a.output_md,a.output_html); print(json.dumps(payload,ensure_ascii=False)); return int(payload["exit_code"])

'@
$Tests=@'

import json
from pathlib import Path
from sgoda.governance.master_index_audit import audit, broken_links, code_set, scan, write_outputs

def repo(tmp_path: Path):
    for p in ("src/example","tests/example","docs","config/example","releases/SPT-999-v1.0.0"): (tmp_path/p).mkdir(parents=True,exist_ok=True)
    (tmp_path/"src/example/__init__.py").write_text("",encoding="utf-8")
    (tmp_path/"tests/example/test_example.py").write_text("def test_ok(): assert True\n",encoding="utf-8")
    (tmp_path/"docs/example.md").write_text("# Ejemplo\n",encoding="utf-8")
    (tmp_path/"docs/00_INDICE_MAESTRO.md").write_text("# Índice\n[Ejemplo](example.md)\nSPT-999\n",encoding="utf-8")
    (tmp_path/"docs/00_REGISTRO_MAESTRO_COMPONENTES.md").write_text("# Registro\nSPT-999\n",encoding="utf-8")
    (tmp_path/"docs/00_ARQUITECTURA_MAESTRA.md").write_text("# Arquitectura\n",encoding="utf-8")
    d={"increment_code":"SPT-999","name":"Ejemplo","version":"1.0.0","status":"closed","source":["src/example"],"tests":["tests/example"],"documentation":["docs/example.md"]}
    (tmp_path/"config/example/SPT-999-component.json").write_text(json.dumps(d),encoding="utf-8")
    (tmp_path/"releases/SPT-999-v1.0.0/manifest.json").write_text('{"release_name":"SPT-999-v1.0.0"}',encoding="utf-8")
    return tmp_path

def test_codes(): assert code_set("PCI-001 SPT-018")=={"PCI-001","SPT-018"}
def test_scan(tmp_path): items,bad=scan(repo(tmp_path)); assert len(items)==1 and items[0]["code"]=="SPT-999" and bad==[]
def test_complete(tmp_path): r=audit(repo(tmp_path)); assert r["approved"] and r["components"][0]["completion_percent"]==100
def test_missing_master(tmp_path): root=repo(tmp_path); (root/"docs/00_INDICE_MAESTRO.md").unlink(); assert not audit(root)["approved"]
def test_invalid_json(tmp_path): root=repo(tmp_path); (root/"config/example/bad.json").write_text("{bad",encoding="utf-8"); assert not audit(root)["approved"]
def test_duplicate(tmp_path): root=repo(tmp_path); s=root/"config/example/SPT-999-component.json"; (root/"config/example/dup.json").write_text(s.read_text(),encoding="utf-8"); assert not audit(root)["approved"]
def test_registry_gap_warning(tmp_path): root=repo(tmp_path); (root/"docs/00_REGISTRO_MAESTRO_COMPONENTES.md").write_text("# Registro\n",encoding="utf-8"); r=audit(root); assert r["approved"] and r["metrics"]["warning_findings"]==1
def test_broken_link(tmp_path): root=repo(tmp_path); idx=root/"docs/00_INDICE_MAESTRO.md"; text="[F](missing.md)"; assert broken_links(root,idx,text)==[{"target":"missing.md","reason":"not_found"}]
def test_external_link(tmp_path): root=repo(tmp_path); idx=root/"docs/00_INDICE_MAESTRO.md"; assert broken_links(root,idx,"[W](https://example.com)")==[]
def test_reports(tmp_path): payload=audit(repo(tmp_path)); j,m,h=tmp_path/"a.json",tmp_path/"a.md",tmp_path/"a.html"; write_outputs(payload,j,m,h); assert j.is_file() and m.is_file() and h.is_file()
def test_metrics(tmp_path): m=audit(repo(tmp_path))["metrics"]; json.dumps(m); assert m["registry_coverage_percent"]==100
def test_unknown_registry(tmp_path): root=repo(tmp_path); (root/"docs/00_REGISTRO_MAESTRO_COMPONENTES.md").write_text("SPT-999\nSPT-998\n",encoding="utf-8"); r=audit(root); assert any(f["code"]=="REGISTRY_CODE_WITHOUT_DESCRIPTOR" for f in r["findings"])

'@
$Component=@'
{"increment_code":"PCI-001","name":"Auditoría del Índice Maestro","version":"1.0.0","status":"implemented_tested_and_candidate_for_closure","program":"PCI-SGODA-v1.0.0","deliverable":"SGD-201A","native_ecosystem":true,"mandatory_proprietary_dependencies":[],"source":["src/sgoda/governance/master_index_audit"],"tests":["tests/governance/master_index_audit"],"documentation":["docs/01_Gobierno/PCI-001"],"dependencies":["SGD-114F","SGD-114G","SGD-115","SGD-116","SGD-117","SPB-007"]}
'@
$Policy=@'
{"policy_id":"PCI-001-POLICY-v1.0.0","component":"PCI-001","approval_rule":"zero critical findings","critical_controls":["master documents exist","configuration JSON is valid","component descriptors are unique","local links in master index resolve"],"non_blocking_controls":["registry coverage","index explicit component coverage","descriptor traceability completeness"]}
'@
$Architecture="# PCI-001 v1.0.0 — Arquitectura`n`nPCI-001 contrasta el Índice Maestro con descriptores, Registro Maestro, documentación, pruebas, releases y estructura física.`n`nLa aprobación exige cero hallazgos críticos. Las brechas de cobertura alimentan PCI-002 y PCI-003.`n"
$Operations="# PCI-001 v1.0.0 — Manual operativo`n`nEjecute python -m sgoda.governance.master_index_audit con las salidas JSON, Markdown y HTML institucionales.`n"

Write-Utf8 (Join-Path $SourceDir "__init__.py") $Module
Write-Utf8 (Join-Path $SourceDir "__main__.py") "from . import main`nraise SystemExit(main())`n"
Write-Utf8 (Join-Path $TestsDir "test_PCI_001_master_index_audit.py") $Tests
Write-Utf8 (Join-Path $ConfigDir "PCI-001-component.json") $Component
Write-Utf8 (Join-Path $ConfigDir "PCI-001-policy.json") $Policy
Write-Utf8 (Join-Path $DocsDir "PCI-001-Arquitectura.md") $Architecture
Write-Utf8 (Join-Path $DocsDir "PCI-001-Manual-Operativo.md") $Operations

Run "Validando sintaxis Python" { python -m py_compile "src/sgoda/governance/master_index_audit/__init__.py" "src/sgoda/governance/master_index_audit/__main__.py" "tests/governance/master_index_audit/test_PCI_001_master_index_audit.py" }
Run "Ejecutando pruebas específicas PCI-001" { & $RunnerPath -Component "PCI-001-v1.0.0" -TestPath @("tests/governance/master_index_audit/test_PCI_001_master_index_audit.py","tests/documentation/test_SGD_115_master_documentation.py","tests/roadmap/test_SGD_116_master_ecosystem_roadmap.py","tests/governance/repository_manager/test_SGD_117_repository_manager.py") -ReportPath "$SpecificXml" -SummaryJson "$SpecificJson" -SummaryMarkdown "$SpecificMd" -Scope "specific_and_integration" }
$Specific=Get-Content $SpecificJson -Raw -Encoding UTF8|ConvertFrom-Json; if(-not[bool]$Specific.approved){throw "Pruebas PCI-001 no aprobadas."}

Step "Ejecutando auditoría inicial del Índice Maestro"
python -m sgoda.governance.master_index_audit --root "$ProjectRoot" --output-json "$InitialJson" --output-md "$InitialMd" --output-html "$InitialHtml"
$InitialExitCode=$LASTEXITCODE

Run "Regenerando documentos maestros mediante SGD-115" { python -m sgoda.documentation.master_docs --root "$ProjectRoot" --output "artifacts/documentation/SGD-115" }
Run "Regenerando roadmap mediante SGD-116" { python -m sgoda.roadmap.cli --root "$ProjectRoot" --output "artifacts/roadmap/SGD-116" }
Run "Validando repositorio mediante SGD-117" { python -m sgoda.governance.repository_manager.cli --root "$ProjectRoot" --operation "validate" --output-json (Join-Path $PmoDir "repository-validation.json") }
Run "Ejecutando auditoría final del Índice Maestro" { python -m sgoda.governance.master_index_audit --root "$ProjectRoot" --output-json "$FinalJson" --output-md "$FinalMd" --output-html "$FinalHtml" }
$Final=Get-Content $FinalJson -Raw -Encoding UTF8|ConvertFrom-Json; if(-not[bool]$Final.approved){$Final.findings|Where-Object severity -eq "critical"|Format-Table -AutoSize; throw "PCI-001 detectó hallazgos críticos."}
Write-Json $MetricsJson $Final.metrics
Write-Json $TraceabilityJson ([ordered]@{increment_code="PCI-001";deliverable="SGD-201A";components=$Final.components;findings=$Final.findings;generated_at_utc=[DateTime]::UtcNow.ToString("o")})

Run "Ejecutando suite completa del ecosistema" { python -m pytest --junitxml="$FullXml" }
Run "Sincronizando evidencia mediante SGD-114F" { python -m sgoda.governance.test_evidence.cli --junit "$FullXml" --component "SGODA-PUINAVE" --scope "full_suite" --output-json "$FullJson" --output-md "$FullMd" }
$Full=Get-Content $FullJson -Raw -Encoding UTF8|ConvertFrom-Json; if(-not[bool]$Full.approved){throw "Suite completa no aprobada."}

$Evidence=[ordered]@{program="PCI-SGODA-v1.0.0";increment_code="PCI-001";deliverable="SGD-201A";version="1.0.0";status="implemented_tested_and_candidate_for_closure";prevalidated_package="[32m.[0m[32m.[0m[32m.[0m[32m.[0m[32m.[0m[32m.[0m[32m.[0m[32m.[0m[32m.[0m[32m.[0m[32m.[0m[32m.[0m[32m                                                             [100%][0m [32m[32m[1m12 passed[0m[32m in 0.06s[0m[0m";initial_audit_exit_code=[int]$InitialExitCode;final_audit=$Final;specific_tests=[ordered]@{executed=[int]$Specific.executed;passed=[int]$Specific.passed;failures=[int]$Specific.failures;errors=[int]$Specific.errors;skipped=[int]$Specific.skipped;approved=[bool]$Specific.approved};full_suite=[ordered]@{executed=[int]$Full.executed;passed=[int]$Full.passed;failures=[int]$Full.failures;errors=[int]$Full.errors;skipped=[int]$Full.skipped;approved=[bool]$Full.approved};generated_at_utc=[DateTime]::UtcNow.ToString("o")}
Write-Json $EvidenceJson $Evidence
$Lines=@("# PCI-001 v1.0.0 — Evidencia","", "- Entregable: SGD-201A","- Auditoría final: APROBADA",("- Componentes auditados: "+[string]$Final.metrics.component_descriptors),("- Cobertura Registro Maestro: "+[string]$Final.metrics.registry_coverage_percent+"%"),("- Cobertura Índice Maestro: "+[string]$Final.metrics.index_coverage_percent+"%"),("- Hallazgos críticos: "+[string]$Final.metrics.critical_findings),("- Pruebas específicas: "+[string]$Specific.passed+"/"+[string]$Specific.executed),("- Suite completa: "+[string]$Full.passed+"/"+[string]$Full.executed))
Write-Utf8 $EvidenceMd ([string]::Join([Environment]::NewLine,$Lines))

foreach($File in @((Join-Path $SourceDir "__init__.py"),(Join-Path $SourceDir "__main__.py"),(Join-Path $TestsDir "test_PCI_001_master_index_audit.py"),(Join-Path $ConfigDir "PCI-001-component.json"),(Join-Path $ConfigDir "PCI-001-policy.json"),(Join-Path $DocsDir "PCI-001-Arquitectura.md"),(Join-Path $DocsDir "PCI-001-Manual-Operativo.md"),$InitialJson,$InitialMd,$InitialHtml,$FinalJson,$FinalMd,$FinalHtml,$MetricsJson,$TraceabilityJson,$SpecificXml,$SpecificJson,$SpecificMd,$FullXml,$FullJson,$FullMd,$EvidenceJson,$EvidenceMd)){Require-File $File "archivo del release"; Copy-Item -LiteralPath $File -Destination $ReleaseDir -Force}
Write-Json (Join-Path $ReleaseDir "manifest.json") ([ordered]@{program="PCI-SGODA-v1.0.0";increment_code="PCI-001";deliverable="SGD-201A";version="1.0.0";release_name="PCI-001-v1.0.0";status="implemented_tested_and_candidate_for_closure";native_ecosystem=$true;mandatory_proprietary_dependencies=@();approval_rule="zero critical findings";files=@(Get-ChildItem -LiteralPath $ReleaseDir -File|Select-Object -ExpandProperty Name)})
Run "Validando release mediante SGD-114G" { python -m sgoda.governance.release_management.cli --root "$ProjectRoot" --operation "close" --output-json "$ReleaseValidationJson" }

if($Publish){Step "Publicando mediante gate canónico"; & $PublisherPath -Publish -CommitMessage "feat(consolidation): implement PCI-001 master index audit" -EvidenceCommitMessage "chore(consolidation): publish PCI-001 evidence"; if($LASTEXITCODE-ne 0){throw "Publicación institucional con errores."}}

Step "Resultado final"
Write-Host "PCI-001 v1.0.0 implementado." -ForegroundColor Green
Write-Host "SGD-201A — Auditoría del Índice Maestro: APROBADA." -ForegroundColor Green
Write-Host ("Componentes auditados: "+[string]$Final.metrics.component_descriptors) -ForegroundColor Green
Write-Host ("Cobertura Registro Maestro: "+[string]$Final.metrics.registry_coverage_percent+"%.") -ForegroundColor Green
Write-Host ("Cobertura Índice Maestro: "+[string]$Final.metrics.index_coverage_percent+"%.") -ForegroundColor Green
Write-Host "Hallazgos críticos: 0." -ForegroundColor Green
Write-Host ("Pruebas específicas: $($Specific.passed)/$($Specific.executed) APROBADAS.") -ForegroundColor Green
Write-Host ("Suite completa: $($Full.passed)/$($Full.executed) APROBADA.") -ForegroundColor Green
Write-Host "Release: releases\PCI-001-v1.0.0" -ForegroundColor Cyan
if($Publish){Write-Host "Publicación institucional: COMPLETADA." -ForegroundColor Green}else{Write-Host "Publicación no solicitada. Reejecute con -Publish." -ForegroundColor Yellow}
