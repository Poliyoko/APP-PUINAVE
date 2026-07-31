[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Get-Location).Path,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Save-Utf8([string]$Path, [string]$Content) {
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    if ((Test-Path $Path) -and -not $Force) {
        Write-Host "[CONSERVADO] $Path" -ForegroundColor Yellow
        return
    }
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
    Write-Host "[CREADO] $Path" -ForegroundColor Green
}

$RepositoryRoot = [System.IO.Path]::GetFullPath($RepositoryRoot)
Set-Location $RepositoryRoot

Write-Host "Instalando Auditor del Repositorio para SPB-003.2..." -ForegroundColor Cyan

@(
    "src/sgoda/pmo/audit",
    "scripts",
    "tests/pmo/audit",
    "docs/04_Gobierno",
    "docs/05_Auditoria",
    "artifacts/audit",
    ".github/workflows"
) | ForEach-Object { New-Item -ItemType Directory -Path $_ -Force | Out-Null }

Save-Utf8 "src/sgoda/__init__.py" '"""SGODA-PUINAVE."""'
Save-Utf8 "src/sgoda/pmo/__init__.py" '"""PMO Digital."""'
Save-Utf8 "src/sgoda/pmo/audit/__init__.py" @'
from .repository_auditor import RepositoryAuditor
__all__ = ["RepositoryAuditor"]
'@

Save-Utf8 "src/sgoda/pmo/audit/repository_auditor.py" @'
from __future__ import annotations

import json
import re
import subprocess
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path


class RepositoryAuditor:
    REQUIRED = (
        ".github", "docs", "knowledge", "scripts", "src", "tests", "README.md"
    )

    PREFIXES = re.compile(
        r"\b(ADR|ACT|CAT|CCP|DMP|EVD|ODA|PGD|PMO|REL|SGD|SPB|TST)-?\d*(?:\.\d+)*\b"
    )

    def __init__(self, root: str | Path) -> None:
        self.root = Path(root).resolve()
        if not self.root.exists():
            raise FileNotFoundError(self.root)

    def _git(self, *args: str) -> tuple[bool, str]:
        try:
            p = subprocess.run(
                ["git", *args], cwd=self.root, capture_output=True,
                text=True, check=False
            )
        except FileNotFoundError:
            return False, "Git no disponible"
        return p.returncode == 0, (p.stdout or p.stderr).strip()

    def run(self) -> dict:
        started = datetime.now(timezone.utc).isoformat()
        checks: dict[str, bool] = {}
        findings: list[dict] = []
        inventory: dict = {}

        for item in self.REQUIRED:
            ok = (self.root / item).exists()
            checks[f"estructura:{item}"] = ok
            if not ok:
                findings.append({
                    "codigo": f"AIR-STR-{len(findings)+1:03d}",
                    "severidad": "ALTA",
                    "categoria": "ESTRUCTURA",
                    "hallazgo": f"Falta el elemento obligatorio: {item}",
                    "recomendacion": f"Crear o restaurar {item}"
                })

        is_git, value = self._git("rev-parse", "--is-inside-work-tree")
        checks["git:repositorio"] = is_git and value.lower() == "true"

        if checks["git:repositorio"]:
            _, branch = self._git("branch", "--show-current")
            _, status = self._git("status", "--porcelain")
            _, tags = self._git("tag", "--list")
            _, remote = self._git("remote", "-v")
            inventory["rama"] = branch
            inventory["cambios_sin_commit"] = status.splitlines()
            inventory["tags"] = tags.splitlines()
            inventory["remotos"] = remote.splitlines()
            checks["git:arbol_limpio"] = status == ""
            checks["git:remoto"] = bool(remote)
            checks["git:tag_cierre"] = any(
                t.lower() in {"spb-003.2", "v0.3.2", "v1.0.0-spb0032"}
                for t in tags.splitlines()
            )
            if status:
                findings.append({
                    "codigo": "AIR-GIT-002",
                    "severidad": "MEDIA",
                    "categoria": "GIT",
                    "hallazgo": "Existen cambios sin confirmar",
                    "recomendacion": "Revisar y confirmar los cambios antes del cierre"
                })
        else:
            findings.append({
                "codigo": "AIR-GIT-001",
                "severidad": "CRITICA",
                "categoria": "GIT",
                "hallazgo": "La carpeta no es un repositorio Git válido",
                "recomendacion": "Ejecutar desde la raíz oficial del repositorio"
            })

        ignored = {".git", ".venv", "venv", "__pycache__", "node_modules", "artifacts"}
        files = [
            p for p in self.root.rglob("*")
            if p.is_file() and not any(part in ignored for part in p.parts)
        ]
        inventory["total_archivos"] = len(files)
        inventory["tipos"] = dict(Counter(p.suffix.lower() or "[sin_extension]" for p in files))

        test_files = [p for p in files if p.name.startswith("test_") and p.suffix == ".py"]
        checks["pruebas:presentes"] = bool(test_files)
        inventory["archivos_prueba"] = len(test_files)

        norm = self.root / "docs/04_Gobierno/SGD-100-Norma-Institucional-Nomenclatura.md"
        checks["nomenclatura:norma"] = norm.exists()

        prefixes = Counter()
        for p in files:
            if p.suffix.lower() not in {".md", ".txt", ".py", ".json", ".yml", ".yaml"}:
                continue
            try:
                prefixes.update(m.group(1) for m in self.PREFIXES.finditer(
                    p.read_text(encoding="utf-8", errors="ignore")
                ))
            except OSError:
                pass
        inventory["nomenclatura_usada"] = dict(sorted(prefixes.items()))

        total = len(checks)
        passed = sum(checks.values())
        score = round(passed * 100 / total) if total else 0
        critical = any(f["severidad"] == "CRITICA" for f in findings)
        status = "NO_CONFORME" if critical else ("CONFORME" if score >= 80 else "CONDICIONAL")

        return {
            "repositorio": str(self.root),
            "inicio": started,
            "fin": datetime.now(timezone.utc).isoformat(),
            "estado": status,
            "puntaje": score,
            "verificaciones": checks,
            "inventario": inventory,
            "hallazgos": findings
        }

    @staticmethod
    def save(result: dict, destination: str | Path) -> None:
        path = Path(destination)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
'@

Save-Utf8 "scripts/audit_repository.py" @'
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "src"))

from sgoda.pmo.audit import RepositoryAuditor


def main() -> int:
    result = RepositoryAuditor(ROOT).run()
    json_path = ROOT / "artifacts/audit/repository-audit.json"
    md_path = ROOT / "docs/05_Auditoria/SGD-401-Informe-Auditoria-Integral.md"
    RepositoryAuditor.save(result, json_path)

    rows = "\n".join(
        f"| {f['codigo']} | {f['severidad']} | {f['categoria']} | {f['hallazgo']} |"
        for f in result["hallazgos"]
    ) or "| — | — | — | Sin hallazgos |"

    checks = "\n".join(
        f"- [{'x' if ok else ' '}] `{name}`"
        for name, ok in sorted(result["verificaciones"].items())
    )

    md_path.write_text(f"""# SGD-401 — Informe de Auditoría Integral

- **Repositorio:** `{result['repositorio']}`
- **Estado:** **{result['estado']}**
- **Puntaje:** **{result['puntaje']} %**
- **Fecha:** {result['fin']}

## Verificaciones

{checks}

## Hallazgos

| Código | Severidad | Categoría | Hallazgo |
|---|---|---|---|
{rows}

## Inventario

```json
{json.dumps(result['inventario'], ensure_ascii=False, indent=2)}
```
""", encoding="utf-8")

    print(json.dumps({
        "estado": result["estado"],
        "puntaje": result["puntaje"],
        "hallazgos": len(result["hallazgos"]),
        "informe": str(md_path),
        "evidencia": str(json_path)
    }, ensure_ascii=False, indent=2))

    return 0 if result["estado"] == "CONFORME" else 2


if __name__ == "__main__":
    raise SystemExit(main())
'@

Save-Utf8 "tests/pmo/audit/test_repository_auditor.py" @'
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "src"))

from sgoda.pmo.audit import RepositoryAuditor


def test_auditor_executes() -> None:
    result = RepositoryAuditor(ROOT).run()
    assert result["repositorio"] == str(ROOT.resolve())
    assert 0 <= result["puntaje"] <= 100
    assert "estructura:src" in result["verificaciones"]
'@

Save-Utf8 "docs/04_Gobierno/SGD-100-Norma-Institucional-Nomenclatura.md" @'
# SGD-100 — Norma Institucional de Nomenclatura

| Prefijo | Denominación oficial |
|---|---|
| SPB | SGODA Project Builder |
| SGD | Sistema General de Documentación |
| ADR | Architecture Decision Record |
| ACT | Acta |
| CAT | Catálogo |
| EVD | Evidencia |
| TST | Prueba |
| REL | Release |
| DMP | Documento Maestro del Proyecto |
| PMO | Project Management Office |
| PGD | Plataforma de Gobierno Documental |
| CCP | Centro de Conocimiento Puinave |
| ODA | Objeto Digital de Aprendizaje |

Toda nueva sigla debe incorporarse a esta norma antes de utilizarse en una
línea base oficial.
'@

Save-Utf8 "docs/05_Auditoria/ACT-003.2-Acta-Cierre.md" @'
# ACT-003.2 — Acta Oficial de Cierre

**Estado inicial:** PENDIENTE DE APROBACIÓN.

El estado podrá cambiar a **APROBADO Y CERRADO** cuando:

- el Auditor emita estado `CONFORME`;
- no existan hallazgos críticos;
- las pruebas estén aprobadas;
- Git tenga un árbol limpio;
- exista etiqueta y Release oficial;
- se conserve el informe SGD-401 y su evidencia JSON.
'@

Save-Utf8 ".github/workflows/spb-003-2-audit.yml" @'
name: SPB-003.2 Repository Audit

on:
  push:
    branches: [main, develop]
  pull_request:
  workflow_dispatch:

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - run: python -m pip install pytest
      - run: python -m pytest
      - run: python scripts/audit_repository.py
      - if: always()
        uses: actions/upload-artifact@v4
        with:
          name: spb-003-2-audit
          path: |
            artifacts/audit/
            docs/05_Auditoria/SGD-401-Informe-Auditoria-Integral.md
'@

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command py -ErrorAction SilentlyContinue }
if (-not $python) {
    Write-Host "Archivos instalados, pero Python no está disponible en PATH." -ForegroundColor Yellow
    exit 1
}

$exe = $python.Source
$argsBase = @()
if ($python.Name -like "py*") { $argsBase = @("-3") }

& $exe @argsBase -m pip install pytest
& $exe @argsBase -m pytest
& $exe @argsBase ".\scripts\audit_repository.py"

Write-Host ""
Write-Host "Revise ahora:" -ForegroundColor Cyan
Write-Host "  docs\05_Auditoria\SGD-401-Informe-Auditoria-Integral.md"
Write-Host "  artifacts\audit\repository-audit.json"
Write-Host ""
Write-Host "Después ejecute:"
Write-Host '  git status'
