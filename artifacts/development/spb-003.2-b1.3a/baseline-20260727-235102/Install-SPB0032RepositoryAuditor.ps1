[CmdletBinding()]
param(
  [string]$RepositoryPath = "C:\Users\Lida Silva Acevedo\Documents\PROYECTO MTM UD 2026\SGODA-PUINAVE"
)
$ErrorActionPreference = 'Stop'

function Write-Utf8File([string]$Path,[string]$Content){
  $parent = Split-Path -Parent $Path
  if(-not (Test-Path -LiteralPath $parent)){ New-Item -ItemType Directory -Path $parent -Force | Out-Null }
  [IO.File]::WriteAllText($Path,$Content,[Text.UTF8Encoding]::new($false))
}

if(-not (Test-Path -LiteralPath $RepositoryPath)){ throw "No existe: $RepositoryPath" }
if(-not (Test-Path -LiteralPath (Join-Path $RepositoryPath '.git'))){ throw 'La ruta no es un repositorio Git.' }
Set-Location -LiteralPath $RepositoryPath

$auditDir = Join-Path $RepositoryPath 'src\sgoda\pmo\audit'
$testDir  = Join-Path $RepositoryPath 'tests\pmo\audit'
$docsDir  = Join-Path $RepositoryPath 'docs\04_GOBIERNO\SPB-003.2'
$scripts  = Join-Path $RepositoryPath 'scripts'
@($auditDir,$testDir,$docsDir,$scripts,(Join-Path $RepositoryPath 'artifacts\audit')) | ForEach-Object {
  New-Item -ItemType Directory -Path $_ -Force | Out-Null
}

Write-Utf8File (Join-Path $auditDir '__init__.py') @'
from .repository_auditor import RepositoryAuditor
__all__ = ["RepositoryAuditor"]
'@

Write-Utf8File (Join-Path $auditDir 'repository_auditor.py') @'
from __future__ import annotations
import json, re, subprocess
from dataclasses import dataclass, asdict, field
from datetime import datetime, timezone
from pathlib import Path

@dataclass
class Check:
    code: str
    category: str
    name: str
    passed: bool
    details: str = ""

@dataclass
class Finding:
    code: str
    severity: str
    category: str
    title: str
    recommendation: str

@dataclass
class Result:
    project: str = "SGODA-PUINAVE"
    scope: str = "SPB-003.2 - Auditoría de Cierre"
    generated_at: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    checks: list[Check] = field(default_factory=list)
    findings: list[Finding] = field(default_factory=list)
    metrics: dict = field(default_factory=dict)
    verdict: str = "PENDING"

    def finish(self):
        high = any(f.severity in {"HIGH","CRITICAL"} for f in self.findings)
        failed = any(not c.passed for c in self.checks)
        self.verdict = "APPROVED" if not failed else ("NOT_APPROVED" if high else "APPROVED_WITH_ACTIONS")
        total = len(self.checks)
        passed = sum(c.passed for c in self.checks)
        self.metrics.update({
            "checks_total": total,
            "checks_passed": passed,
            "checks_failed": total-passed,
            "compliance_percentage": round((passed/total)*100,2) if total else 0,
            "findings_total": len(self.findings)
        })
        return self

class RepositoryAuditor:
    REQUIRED = ['.github','docs','knowledge','scripts','src','tests','README.md']
    PREFIXES = {'SPB','SGD','ADR','DMP','PMO','PGD','CCP','ODA','ACT','CAT','TST','EVD','REL','BL','GUI','MAN','PRC','RDM','DGM','INF','DSH','API','DB','APP','KPI','CI','CD','MVP'}
    IGNORE = {'.git','.venv','venv','__pycache__','.pytest_cache','node_modules','dist','build'}

    def __init__(self, repository: Path):
        self.root = repository.resolve()

    def git(self,*args):
        p = subprocess.run(['git',*args],cwd=self.root,capture_output=True,text=True,encoding='utf-8',errors='replace')
        return p.returncode == 0, (p.stdout or p.stderr).strip()

    def files(self):
        for p in self.root.rglob('*'):
            if p.is_file() and not any(x in self.IGNORE for x in p.parts):
                yield p

    def run(self):
        r = Result()
        for i,rel in enumerate(self.REQUIRED,1):
            ok = (self.root/rel).exists()
            r.checks.append(Check(f'STR-{i:03}','STRUCTURE',f'Existe {rel}',ok,str(self.root/rel)))
            if not ok:
                r.findings.append(Finding(f'F-STR-{i:03}','HIGH','STRUCTURE',f'Falta {rel}',f'Crear y documentar {rel}.'))

        ok,branch = self.git('branch','--show-current')
        r.checks.append(Check('GIT-001','GIT','Repositorio Git operativo',ok,branch))
        ok,status = self.git('status','--porcelain')
        clean = ok and not status
        r.checks.append(Check('GIT-002','GIT','Árbol de trabajo limpio',clean,status or 'Sin cambios pendientes'))
        if status:
            r.findings.append(Finding('F-GIT-001','MEDIUM','GIT','Cambios pendientes','Realizar commit o descartar cambios antes del cierre.'))

        ok,tags = self.git('tag','--list')
        has_tag = ok and any(('003.2' in t or '0.3.2' in t) for t in tags.splitlines())
        r.checks.append(Check('GIT-003','GIT','Etiqueta SPB-003.2',has_tag,tags or 'Sin etiquetas'))

        docs = [p for p in self.files() if 'docs' in p.parts and p.suffix.lower() in {'.md','.txt','.json','.yaml','.yml'}]
        tests = [p for p in self.files() if 'tests' in p.parts and p.name.startswith('test_') and p.suffix=='.py']
        src = [p for p in self.files() if 'src' in p.parts and p.suffix=='.py']
        r.checks.append(Check('DOC-001','DOCUMENTATION','Documentación presente',bool(docs),f'{len(docs)} documentos'))
        r.checks.append(Check('SRC-001','SOURCE','Código fuente presente',bool(src),f'{len(src)} archivos Python'))
        r.checks.append(Check('TST-001','TESTS','Pruebas automatizadas presentes',bool(tests),f'{len(tests)} pruebas'))
        if not tests:
            r.findings.append(Finding('F-TST-001','HIGH','TESTS','No se detectaron pruebas','Crear pruebas automatizadas.'))

        pattern = re.compile(r'\b([A-Z]{2,5})-\d{2,4}(?:\.\d+)*\b')
        found=set()
        for p in self.files():
            if p.suffix.lower() not in {'.md','.txt','.json','.yaml','.yml','.py','.ps1','.toml'}: continue
            try: text=p.read_text(encoding='utf-8',errors='ignore')
            except OSError: continue
            found.update(pattern.findall(text))
        unknown=sorted(found-self.PREFIXES)
        r.checks.append(Check('NOM-001','NOMENCLATURE','Nomenclatura normalizada',not unknown,', '.join(unknown) if unknown else 'Sin prefijos no autorizados'))
        for x in unknown:
            r.findings.append(Finding(f'F-NOM-{x}','MEDIUM','NOMENCLATURE',f'Prefijo no normalizado: {x}','Incorporar en SGD-100 o corregir.'))

        r.metrics.update({'documents':len(docs),'source_files':len(src),'test_files':len(tests)})
        return r.finish()

def save(result: Result, output: Path):
    output.mkdir(parents=True,exist_ok=True)
    data=asdict(result)
    (output/'SGD-401-auditoria-integral.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf-8')
    lines=['# SGD-401 — Informe de Auditoría Integral','',f'- **Proyecto:** {result.project}',f'- **Alcance:** {result.scope}',f'- **Fecha UTC:** {result.generated_at}',f'- **Dictamen:** {result.verdict}',f'- **Cumplimiento:** {result.metrics.get("compliance_percentage",0)} %','','## Verificaciones','','| Código | Categoría | Verificación | Estado | Detalle |','|---|---|---|---|---|']
    for c in result.checks:
        lines.append(f'| {c.code} | {c.category} | {c.name} | {"APROBADO" if c.passed else "NO CONFORME"} | {c.details.replace("|","/").replace(chr(10)," ")} |')
    lines += ['', '## Hallazgos','', '| Código | Severidad | Categoría | Hallazgo | Recomendación |','|---|---|---|---|---|']
    if result.findings:
        for f in result.findings: lines.append(f'| {f.code} | {f.severity} | {f.category} | {f.title} | {f.recommendation} |')
    else: lines.append('| — | — | — | Sin hallazgos abiertos | — |')
    (output/'SGD-401-auditoria-integral.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
'@

Write-Utf8File (Join-Path $auditDir 'cli.py') @'
from pathlib import Path
from .repository_auditor import RepositoryAuditor, save

def main():
    root=Path.cwd()
    result=RepositoryAuditor(root).run()
    save(result,root/'artifacts'/'audit')
    print(f'Dictamen: {result.verdict}')
    print(f'Cumplimiento: {result.metrics.get("compliance_percentage",0)} %')
    print('Informe: artifacts/audit/SGD-401-auditoria-integral.md')
    return 0 if result.verdict=='APPROVED' else 2

if __name__=='__main__':
    raise SystemExit(main())
'@

Write-Utf8File (Join-Path $testDir 'test_repository_auditor.py') @'
from pathlib import Path
from sgoda.pmo.audit.repository_auditor import RepositoryAuditor

def test_auditor_returns_checks(tmp_path: Path):
    result=RepositoryAuditor(tmp_path).run()
    assert result.checks
    assert result.verdict in {'APPROVED','APPROVED_WITH_ACTIONS','NOT_APPROVED'}
'@

Write-Utf8File (Join-Path $scripts 'Invoke-SPB0032Audit.ps1') @'
[CmdletBinding()]
param([string]$RepositoryPath=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path)
$ErrorActionPreference='Stop'
Set-Location -LiteralPath $RepositoryPath
$env:PYTHONPATH=Join-Path $RepositoryPath 'src'
python -m sgoda.pmo.audit.cli
exit $LASTEXITCODE
'@

Write-Utf8File (Join-Path $scripts 'Invoke-SPB0032Closure.ps1') @'
[CmdletBinding()]
param(
 [string]$RepositoryPath=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
 [switch]$CreateTag
)
$ErrorActionPreference='Stop'
Set-Location -LiteralPath $RepositoryPath
& (Join-Path $PSScriptRoot 'Invoke-SPB0032Audit.ps1') -RepositoryPath $RepositoryPath
if($LASTEXITCODE -ne 0){ Write-Warning 'Auditoría no aprobada. Revise SGD-401.'; exit 2 }
$env:PYTHONPATH=Join-Path $RepositoryPath 'src'
python -m pytest -q
if($LASTEXITCODE -ne 0){ throw 'Las pruebas fallaron.' }
$status=git status --porcelain
if($status){ Write-Warning 'Existen cambios pendientes. Realice commit antes del cierre.'; $status; exit 3 }
if($CreateTag){
 $tag='spb-003.2-baseline-v1.0'
 if(-not (git tag --list $tag)){ git tag -a $tag -m 'Cierre SPB-003.2 - Baseline v1.0' }
 Write-Host "Etiqueta disponible: $tag" -ForegroundColor Green
 Write-Host "Publicar con: git push origin $tag"
}
Write-Host 'Controles técnicos de SPB-003.2 aprobados.' -ForegroundColor Green
'@

Write-Utf8File (Join-Path $docsDir 'SGD-100-Norma-Institucional-Nomenclatura.md') @'
# SGD-100 — Norma Institucional de Nomenclatura

Prefijos oficiales: SPB, SGD, ADR, DMP, PMO, PGD, CCP, ODA, ACT, CAT, TST, EVD, REL, BL, GUI, MAN, PRC, RDM, DGM, INF, DSH, API, DB, APP, KPI, CI, CD y MVP.

Regla general: `PREFIJO-NÚMERO-NOMBRE-CORTO`.

Todo nuevo prefijo debe aprobarse antes de utilizarse.
'@

Write-Utf8File (Join-Path $docsDir 'ACT-003.2-Acta-Cierre.md') @'
# ACT-003.2 — Acta Oficial de Cierre

## Estado

PENDIENTE DE APROBACIÓN FINAL.

## Criterios

- Auditor del Repositorio incorporado al PMO Digital.
- SGD-401 generado con dictamen APPROVED.
- Pruebas automatizadas aprobadas.
- Árbol Git limpio.
- Etiqueta `spb-003.2-baseline-v1.0` creada y publicada.

## Evidencias

- `artifacts/audit/SGD-401-auditoria-integral.md`
- `artifacts/audit/SGD-401-auditoria-integral.json`
- salida de pytest
- historial y etiqueta Git
'@

$env:PYTHONPATH=Join-Path $RepositoryPath 'src'
python -m py_compile (Join-Path $auditDir 'repository_auditor.py') (Join-Path $auditDir 'cli.py')
if($LASTEXITCODE -ne 0){ throw 'Error de sintaxis Python.' }

Write-Host 'Auditor del Repositorio instalado correctamente.' -ForegroundColor Green
Write-Host 'Ejecute:' -ForegroundColor Yellow
Write-Host '  .\scripts\Invoke-SPB0032Audit.ps1'
Write-Host 'Luego, tras corregir hallazgos y hacer commit:'
Write-Host '  .\scripts\Invoke-SPB0032Closure.ps1 -CreateTag'
