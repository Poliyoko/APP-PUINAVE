from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path


@dataclass(frozen=True)
class Gate:
    code: str
    name: str
    required: bool
    passed: bool
    evidence: str
    remediation: str = ""


@dataclass
class Decision:
    project: str = "SGODA-PUINAVE"
    milestone: str = "SPB-003.2"
    generated_at: str = field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )
    repository_root: str = ""
    gates: list[Gate] = field(default_factory=list)
    metadata: dict = field(default_factory=dict)

    @property
    def blockers(self):
        return [gate for gate in self.gates if gate.required and not gate.passed]

    @property
    def approved(self):
        return not self.blockers

    @property
    def verdict(self):
        return "APROBADO_PARA_CIERRE" if self.approved else "CIERRE_CONDICIONADO"

    def to_dict(self):
        data = asdict(self)
        data["approved"] = self.approved
        data["verdict"] = self.verdict
        data["blocking_gates"] = [asdict(gate) for gate in self.blockers]
        return data


class ClosureOrchestrator:
    AUDITS = (
        "artifacts/audit/spb-003.2/SGD-401-auditoria-integral.json",
        "artifacts/audit/spb-003.2/SGD-401-auditoria-repositorio.json",
        "artifacts/audit/SGD-401-auditoria-integral.json",
        "reports/audit/spb-003.2/SGD-401-auditoria-repositorio.json",
    )
    TERMS = ("SGD-100", "SGD-401", "ACT-003.2", "SPB-003.2")

    def __init__(self, root: Path, full_tests=False):
        self.root = root.resolve()
        self.full_tests = full_tests

    def run_cmd(self, command, cwd=None):
        try:
            process = subprocess.run(
                command,
                cwd=cwd or self.root,
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                check=False,
            )
            return process.returncode, (process.stdout + "\n" + process.stderr).strip()
        except OSError as exc:
            return 127, str(exc)

    def git(self, *args):
        code, output = self.run_cmd(["git", *args])
        return output if code == 0 else ""

    def audit_data(self):
        for relative in self.AUDITS:
            path = self.root / relative
            if path.is_file():
                try:
                    return path, json.loads(path.read_text(encoding="utf-8-sig"))
                except (OSError, json.JSONDecodeError):
                    return path, {}
        return None, {}

    def gate_docs(self):
        corpus = ""
        for base in (self.root / "docs", self.root / "artifacts"):
            if not base.is_dir():
                continue
            for path in base.rglob("*"):
                if path.is_file() and path.suffix.lower() in {
                    ".md", ".txt", ".json", ".yaml", ".yml"
                }:
                    try:
                        corpus += "\n" + path.read_text(encoding="utf-8")
                    except (OSError, UnicodeDecodeError):
                        pass
        found = {term: term.casefold() in corpus.casefold() for term in self.TERMS}
        return Gate(
            "GATE-004",
            "Documentación obligatoria",
            True,
            all(found.values()),
            json.dumps(found, ensure_ascii=False),
            "Incorporar o normalizar los documentos faltantes.",
        )

    def gate_tests(self):
        evidence = []
        pmo_code, pmo_output = self.run_cmd(
            [sys.executable, "-m", "pytest", "-q", "tests/pmo/audit"]
        )
        evidence.append(f"PMO exit={pmo_code}\n{pmo_output[-2500:]}")

        builder = self.root / "builder"
        builder_tests = builder / "tests"
        if builder_tests.is_dir():
            builder_code, builder_output = self.run_cmd(
                [sys.executable, "-m", "pytest", "-q"],
                cwd=builder,
            )
            evidence.append(
                f"Builder exit={builder_code}\n{builder_output[-2500:]}"
            )
        else:
            builder_code = 2
            evidence.append("Builder exit=2\nNo existe builder/tests.")

        passed = pmo_code == 0 and builder_code == 0
        return Gate(
            "GATE-005",
            "Suites PMO y Builder separadas",
            True,
            passed,
            "\n\n".join(evidence),
            "Corregir las suites fallidas y ejecutarlas en sus directorios.",
        )

    def execute(self):
        decision = Decision(repository_root=str(self.root))
        audit_path, audit = self.audit_data()
        verdict = str(audit.get("verdict", "")).upper()
        blockers = int(audit.get("blocking_findings", 0) or 0)
        audit_ok = bool(audit_path) and (
            audit.get("closure_ready") is True
            or verdict in {
                "APPROVED",
                "APTO_PARA_CIERRE",
                "APROBADO_PARA_CIERRE",
            }
        ) and blockers == 0

        auditor = next(
            (
                path
                for path in (
                    self.root / "src/sgoda/pmo/audit/native_repository_auditor.py",
                    self.root / "src/sgoda/pmo/audit/orchestrator.py",
                )
                if path.is_file()
            ),
            None,
        )
        status = self.git("status", "--porcelain")
        remote = self.git("remote", "get-url", "origin")
        workflows = list((self.root / ".github/workflows").glob("*.y*ml"))
        closure_workflows = [
            path
            for path in workflows
            if any(
                token in path.name.casefold()
                for token in ("003.2", "closure", "audit")
            )
        ]

        decision.gates = [
            Gate(
                "GATE-001",
                "Repositorio oficial válido",
                True,
                (self.root / ".git").exists()
                and (self.root / "README.md").is_file(),
                str(self.root),
                "Ejecutar desde la raíz oficial y crear README.md.",
            ),
            Gate(
                "GATE-002",
                "Auditor integrado al PMO",
                True,
                auditor is not None,
                str(auditor or "No localizado"),
                "Aplicar el Auditor modular.",
            ),
            Gate(
                "GATE-003",
                "SGD-401 favorable",
                True,
                audit_ok,
                f"{audit_path}; verdict={verdict}; blockers={blockers}",
                "Resolver hallazgos bloqueantes y regenerar SGD-401.",
            ),
            self.gate_docs(),
            self.gate_tests(),
            Gate(
                "GATE-006",
                "Árbol Git limpio",
                True,
                not status.strip(),
                status or "Sin cambios.",
                "Hacer commit o descartar cambios.",
            ),
            Gate(
                "GATE-007",
                "Remoto origin configurado",
                True,
                bool(remote),
                remote or "No configurado.",
                "Configurar origin.",
            ),
            Gate(
                "GATE-008",
                "Workflow de cierre",
                True,
                bool(closure_workflows),
                ", ".join(
                    str(path.relative_to(self.root))
                    for path in closure_workflows
                )
                or "No localizado.",
                "Incorporar workflow de cierre.",
            ),
        ]
        decision.metadata = {
            "branch": self.git("branch", "--show-current"),
            "head_commit": self.git("rev-parse", "HEAD"),
            "latest_tag": self.git("describe", "--tags", "--abbrev=0"),
        }
        return decision


def render(decision):
    rows = [
        "# SGD-406 — Informe de Decisión de Cierre SPB-003.2",
        "",
        f"- **Proyecto:** {decision.project}",
        f"- **Hito:** {decision.milestone}",
        f"- **Fecha UTC:** {decision.generated_at}",
        f"- **Dictamen:** **{decision.verdict}**",
        "",
        "| Código | Control | Estado | Evidencia |",
        "|---|---|---|---|",
    ]
    for gate in decision.gates:
        evidence = gate.evidence.replace("|", "/").replace("\n", "<br>")
        rows.append(
            f"| {gate.code} | {gate.name} | "
            f"{'APROBADA' if gate.passed else 'NO CONFORME'} | {evidence} |"
        )
    rows.extend(
        [
            "",
            "## Conclusión",
            "",
            "La Dirección puede autorizar el cierre formal."
            if decision.approved
            else "El cierre queda condicionado hasta resolver las compuertas obligatorias.",
            "",
        ]
    )
    return "\n".join(rows)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=".")
    parser.add_argument("--output", default="artifacts/closure/spb-003.2")
    parser.add_argument("--full-tests", action="store_true")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    output = root / args.output
    output.mkdir(parents=True, exist_ok=True)
    decision = ClosureOrchestrator(root, args.full_tests).execute()

    (output / "SGD-406-decision-cierre.json").write_text(
        json.dumps(decision.to_dict(), ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    (output / "SGD-406-informe-decision-cierre.md").write_text(
        render(decision),
        encoding="utf-8",
    )
    act = (
        "# ACT-003.2 — Acta de Cierre Candidata\n\n"
        f"**Dictamen:** {decision.verdict}\n\n"
        f"**Commit:** `{decision.metadata.get('head_commit', '')}`\n"
    )
    (output / "ACT-003.2-acta-cierre-candidata.md").write_text(
        act,
        encoding="utf-8",
    )

    manifest = []
    for path in sorted(output.glob("*")):
        if path.is_file():
            manifest.append(
                {
                    "file": path.name,
                    "size_bytes": path.stat().st_size,
                    "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                }
            )
    (output / "REL-003.2-manifiesto-evidencias.json").write_text(
        json.dumps(
            {
                "schema_version": "1.0",
                "project": decision.project,
                "milestone": "SPB-003.2",
                "verdict": decision.verdict,
                "artifacts": manifest,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )

    print("Dictamen:", decision.verdict)
    print("Expediente:", output)
    return 0 if decision.approved else 2


if __name__ == "__main__":
    raise SystemExit(main())
