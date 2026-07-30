from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path


@dataclass(frozen=True)
class Finding:
    code: str
    category: str
    severity: str
    status: str
    message: str
    evidence: str = ""
    recommendation: str = ""


@dataclass
class Report:
    project: str
    audit_id: str
    generated_at: str
    repository_root: str
    findings: list[Finding] = field(default_factory=list)
    metrics: dict = field(default_factory=dict)

    @property
    def blockers(self):
        return [f for f in self.findings if f.severity in {"critical", "high"} and f.status != "compliant"]

    @property
    def closure_ready(self):
        return not self.blockers

    def to_dict(self):
        data = asdict(self)
        data["closure_ready"] = self.closure_ready
        data["blocking_findings"] = [asdict(f) for f in self.blockers]
        return data


class NativeRepositoryAuditor:
    REQUIRED_DIRS = ("docs", "src", "tests", "scripts", "knowledge", ".github/workflows")
    REQUIRED_FILES = ("README.md",)
    PREFIXES = {"ADR","ACT","API","APP","BL","CAT","CCP","CI","CD","DB","DGM","DMP","DSH","ESP","EVD","GUI","INF","KPI","MAN","MVP","ODA","PGD","PMO","PPT","PRC","RDM","REL","SGD","SPB","TST"}
    EXCLUDED = {".git", ".venv", "venv", "__pycache__", ".pytest_cache", "node_modules", "dist", "build"}

    def __init__(self, root: Path):
        self.root = root.resolve()
        if not self.root.is_dir():
            raise ValueError(f"No existe el repositorio: {self.root}")

    def run(self):
        report = Report("SGODA-PUINAVE", "SPB-003.2-CLOSURE-AUDIT", datetime.now(timezone.utc).isoformat(), str(self.root))
        report.findings += self.audit_structure()
        report.findings += self.audit_docs()
        report.findings += self.audit_code()
        report.findings += self.audit_tests()
        report.findings += self.audit_nomenclature()
        report.findings += self.audit_git()
        files = list(self.files())
        report.metrics = {
            "files_total": len(files),
            "python_files": sum(p.suffix.lower() == ".py" for p in files),
            "markdown_files": sum(p.suffix.lower() == ".md" for p in files),
            "test_files": sum(p.name.startswith("test_") and p.suffix == ".py" for p in files),
            "repository_sha256": self.digest(files),
            "blocking_findings": len(report.blockers),
        }
        return report

    def audit_structure(self):
        out = []
        for rel in self.REQUIRED_DIRS:
            ok = (self.root / rel).is_dir()
            out.append(Finding(f"STRUCT-{rel.replace('/','-').upper()}", "structure", "high", "compliant" if ok else "non_compliant", f"{'Existe' if ok else 'Falta'} el directorio {rel}", str(self.root / rel), f"Crear {rel}"))
        for rel in self.REQUIRED_FILES:
            ok = (self.root / rel).is_file()
            out.append(Finding(f"STRUCT-{rel.upper().replace('.','-')}", "structure", "high", "compliant" if ok else "non_compliant", f"{'Existe' if ok else 'Falta'} el archivo {rel}", str(self.root / rel), f"Crear {rel}"))
        return out

    def audit_docs(self):
        docs = self.root / "docs"
        md = list(docs.rglob("*.md")) if docs.is_dir() else []
        corpus = "\n".join(self.read(p) for p in md)
        out = [Finding("DOC-001", "documentation", "high", "compliant" if md else "non_compliant", f"Documentos Markdown detectados: {len(md)}", str(docs), "Mantener documentaciÃ³n versionada")]
        for term in ("SPB-003.2", "SGD-401", "SGD-100", "ACT-003.2"):
            ok = term.casefold() in corpus.casefold()
            out.append(Finding(f"DOC-{term.replace('.','-')}", "documentation", "high" if term == "SPB-003.2" else "medium", "compliant" if ok else "non_compliant", f"{'Se encontrÃ³' if ok else 'No se encontrÃ³'} {term}", str(docs), f"Incorporar {term}"))
        return out

    def audit_code(self):
        src = self.root / "src"
        py = list(src.rglob("*.py")) if src.is_dir() else []
        auditor = src / "sgoda" / "pmo" / "audit" / "native_repository_auditor.py"
        return [
            Finding("CODE-001", "source_code", "high", "compliant" if py else "non_compliant", f"Archivos Python en src: {len(py)}", str(src), "Mantener el cÃ³digo en src"),
            Finding("CODE-AUDITOR-001", "source_code", "high", "compliant" if auditor.is_file() else "non_compliant", "Auditor Nativo integrado" if auditor.is_file() else "Auditor Nativo ausente", str(auditor), "Integrar el auditor en el PMO Digital"),
        ]

    def audit_tests(self):
        tests = self.root / "tests"
        items = list(tests.rglob("test_*.py")) if tests.is_dir() else []
        return [Finding("TEST-001", "tests", "high", "compliant" if items else "non_compliant", f"Pruebas detectadas: {len(items)}", str(tests), "Crear y ejecutar pruebas")]

    def audit_nomenclature(self):
        pattern = re.compile(r"\b([A-Z]{2,5})-\d{2,4}(?:\.\d+)*\b")
        found = set()
        for p in self.files():
            if p.suffix.lower() in {".md", ".txt", ".json", ".yml", ".yaml", ".py"}:
                found.update(m.group(1) for m in pattern.finditer(self.read(p)))
        unknown = sorted(found - self.PREFIXES)
        return [Finding("NOM-001", "nomenclature", "medium", "compliant" if not unknown else "non_compliant", "Nomenclatura normalizada" if not unknown else f"Prefijos no normalizados: {', '.join(unknown)}", ", ".join(sorted(found)), "Actualizar SGD-100")]

    def audit_git(self):
        if not (self.root / ".git").exists():
            return [Finding("GIT-001", "git", "high", "non_compliant", "No es un repositorio Git", str(self.root / ".git"), "Inicializar o clonar Git")]
        branch = self.git("branch", "--show-current")
        status = self.git("status", "--porcelain")
        tags = self.git("tag", "--list")
        workflows = list((self.root / ".github" / "workflows").glob("*.y*ml"))
        return [
            Finding("GIT-002", "git", "medium", "compliant" if branch else "non_compliant", f"Rama activa: {branch or 'sin determinar'}", branch, "Usar rama gobernada"),
            Finding("GIT-003", "git", "low", "compliant" if tags else "non_compliant", f"Etiquetas detectadas: {len(tags.splitlines()) if tags else 0}", tags, "Crear tag tras aprobaciÃ³n"),
            Finding("GIT-004", "git", "medium", "compliant" if workflows else "non_compliant", f"Workflows detectados: {len(workflows)}", str(self.root / ".github" / "workflows"), "Mantener CI"),
            Finding("GIT-005", "git", "medium", "compliant" if not status.strip() else "non_compliant", "Ãrbol limpio" if not status.strip() else "Hay cambios sin confirmar", status, "Revisar git status"),
        ]

    def files(self):
        for p in self.root.rglob("*"):
            if p.is_file() and not any(part in self.EXCLUDED for part in p.parts):
                yield p

    def digest(self, files):
        h = hashlib.sha256()
        for p in sorted(files):
            try:
                h.update(p.relative_to(self.root).as_posix().encode())
                h.update(p.read_bytes())
            except OSError:
                pass
        return h.hexdigest()

    @staticmethod
    def read(path):
        try:
            return path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            return ""

    def git(self, *args):
        try:
            r = subprocess.run(["git", *args], cwd=self.root, capture_output=True, text=True, check=False)
            return r.stdout.strip()
        except OSError:
            return ""


def markdown(report):
    verdict = "APTO PARA CIERRE" if report.closure_ready else "NO APTO PARA CIERRE"
    lines = [
        "# SGD-401 â€” Informe de AuditorÃ­a Integral del Repositorio", "",
        f"- **Proyecto:** {report.project}",
        f"- **Fecha UTC:** {report.generated_at}",
        f"- **Repositorio:** `{report.repository_root}`",
        f"- **Dictamen:** **{verdict}**", "",
        "## MÃ©tricas", "",
    ]
    lines += [f"- **{k}:** {v}" for k, v in report.metrics.items()]
    lines += ["", "## Hallazgos", "", "| CÃ³digo | CategorÃ­a | Severidad | Estado | Hallazgo |", "|---|---|---|---|---|"]
    for f in report.findings:
        lines.append(f"| {f.code} | {f.category} | {f.severity} | {f.status} | {f.message.replace('|', '/')} |")
    lines += ["", "## ConclusiÃ³n", "", "La auditorÃ­a permite continuar con la aprobaciÃ³n formal." if report.closure_ready else "El cierre queda condicionado a resolver los hallazgos crÃ­ticos o altos.", ""]
    return "\n".join(lines)


def act(report):
    verdict = "APROBADO TÃ‰CNICAMENTE" if report.closure_ready else "CIERRE CONDICIONADO"
    return f"""# ACT-003.2 â€” Acta TÃ©cnica de Cierre de SPB-003.2

## Proyecto

SGODA-PUINAVE

## Evidencia

- Informe: SGD-401.
- Fecha UTC: {report.generated_at}.
- Huella SHA-256: `{report.metrics.get('repository_sha256','')}`.
- Hallazgos bloqueantes: {len(report.blockers)}.

## Dictamen

**{verdict}**

La aprobaciÃ³n institucional, el commit, el tag y la publicaciÃ³n de la release
requieren decisiÃ³n explÃ­cita de la DirecciÃ³n del Proyecto y de la PMO Digital.
"""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument("--output", default="artifacts/audit/spb-003.2")
    args = parser.parse_args()
    root = Path(args.root)
    out = root / args.output
    out.mkdir(parents=True, exist_ok=True)
    report = NativeRepositoryAuditor(root).run()
    (out / "SGD-401-auditoria-integral.json").write_text(json.dumps(report.to_dict(), ensure_ascii=False, indent=2), encoding="utf-8")
    (out / "SGD-401-informe-auditoria-integral.md").write_text(markdown(report), encoding="utf-8")
    (out / "ACT-003.2-acta-tecnica-cierre.md").write_text(act(report), encoding="utf-8")
    print(f"Informe: {out / 'SGD-401-informe-auditoria-integral.md'}")
    print(f"Acta: {out / 'ACT-003.2-acta-tecnica-cierre.md'}")
    print("DICTAMEN:", "APTO PARA CIERRE" if report.closure_ready else "NO APTO PARA CIERRE")
    return 0 if report.closure_ready else 2


if __name__ == "__main__":
    raise SystemExit(main())
