from __future__ import annotations
import argparse, hashlib, json, subprocess, sys
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path

@dataclass(frozen=True)
class Gate:
    code:str; name:str; required:bool; passed:bool; evidence:str; remediation:str=''

@dataclass
class Decision:
    project:str='SGODA-PUINAVE'
    milestone:str='SPB-003.2.10'
    generated_at:str=field(default_factory=lambda:datetime.now(timezone.utc).isoformat())
    repository_root:str=''
    gates:list[Gate]=field(default_factory=list)
    metadata:dict=field(default_factory=dict)
    @property
    def blockers(self): return [g for g in self.gates if g.required and not g.passed]
    @property
    def approved(self): return not self.blockers
    @property
    def verdict(self): return 'APROBADO_PARA_CIERRE' if self.approved else 'CIERRE_CONDICIONADO'
    def to_dict(self):
        d=asdict(self); d['approved']=self.approved; d['verdict']=self.verdict; d['blocking_gates']=[asdict(g) for g in self.blockers]; return d

class ClosureOrchestrator:
    AUDITS=(
      'artifacts/audit/spb-003.2/SGD-401-auditoria-integral.json',
      'artifacts/audit/spb-003.2/SGD-401-auditoria-repositorio.json',
      'artifacts/audit/SGD-401-auditoria-integral.json',
      'reports/audit/spb-003.2/SGD-401-auditoria-repositorio.json')
    TERMS=('SGD-100','SGD-401','ACT-003.2','SPB-003.2')
    def __init__(self,root:Path,full_tests=False): self.root=root.resolve(); self.full_tests=full_tests
    def run_cmd(self,cmd):
        try:
            p=subprocess.run(cmd,cwd=self.root,capture_output=True,text=True,encoding='utf-8',errors='replace',check=False)
            return p.returncode,(p.stdout+'\n'+p.stderr).strip()
        except OSError as e:return 127,str(e)
    def git(self,*args):
        c,o=self.run_cmd(['git',*args]); return o if c==0 else ''
    def audit_data(self):
        for rel in self.AUDITS:
            p=self.root/rel
            if p.is_file():
                try:return p,json.loads(p.read_text(encoding='utf-8-sig'))
                except Exception:return p,{}
        return None,{}
    def gate_docs(self):
        corpus=''
        docs=self.root/'docs'
        if docs.is_dir():
            for p in docs.rglob('*'):
                if p.is_file() and p.suffix.lower() in {'.md','.txt','.json','.yaml','.yml'}:
                    try: corpus+='\n'+p.read_text(encoding='utf-8',errors='replace')
                    except OSError: pass
        found={t:t.casefold() in corpus.casefold() for t in self.TERMS}
        return Gate('GATE-004','DocumentaciÃ³n obligatoria',True,all(found.values()),json.dumps(found,ensure_ascii=False),'Incorporar documentos faltantes.')
    def gate_tests(self):
        targets=[] if self.full_tests else [p for p in ('tests/test_repository_auditor.py','tests/pmo/audit/test_repository_auditor.py','tests/test_spb_003_2_closure.py') if (self.root/p).is_file()]
        cmd=[sys.executable,'-m','pytest','-q',*targets]
        code,out=self.run_cmd(cmd)
        return Gate('GATE-005','Pruebas automatizadas',True,code==0,f'exit={code}\n{out[-3000:]}','Corregir pruebas fallidas.')
    def execute(self):
        d=Decision(repository_root=str(self.root))
        audit_path,audit=self.audit_data(); verdict=str(audit.get('verdict','')).upper(); blockers=audit.get('blocking_findings',0)
        audit_ok=bool(audit_path) and (audit.get('closure_ready') is True or verdict in {'APPROVED','APTO_PARA_CIERRE','APROBADO_PARA_CIERRE'} or blockers==0)
        auditor=next((p for p in (self.root/'src/sgoda/pmo/audit/native_repository_auditor.py',self.root/'src/sgoda/pmo/audit/repository_auditor.py') if p.is_file()),None)
        status=self.git('status','--porcelain'); remote=self.git('remote','get-url','origin')
        workflows=list((self.root/'.github/workflows').glob('*.y*ml'))
        closure_wf=[p for p in workflows if any(x in p.name.casefold() for x in ('003.2','closure','audit'))]
        d.gates=[
          Gate('GATE-001','Repositorio oficial vÃ¡lido',True,(self.root/'.git').exists() and (self.root/'README.md').is_file(),str(self.root),'Ejecutar desde la raÃ­z oficial.'),
          Gate('GATE-002','Auditor integrado al PMO',True,auditor is not None,str(auditor or 'No localizado'),'Aplicar el Auditor Nativo.'),
          Gate('GATE-003','SGD-401 favorable',True,audit_ok,f'{audit_path}; verdict={verdict}; blockers={blockers}','Resolver hallazgos bloqueantes.'),
          self.gate_docs(),self.gate_tests(),
          Gate('GATE-006','Ãrbol Git limpio',True,not status.strip(),status or 'Sin cambios','Hacer commit o descartar cambios.'),
          Gate('GATE-007','Remoto origin configurado',True,bool(remote),remote or 'No configurado','Configurar origin.'),
          Gate('GATE-008','Workflow de cierre',True,bool(closure_wf),','.join(str(p.relative_to(self.root)) for p in closure_wf) or 'No localizado','Incorporar workflow de cierre.')]
        d.metadata={'branch':self.git('branch','--show-current'),'head_commit':self.git('rev-parse','HEAD'),'latest_tag':self.git('describe','--tags','--abbrev=0')}
        return d

def render(d):
    rows=['# SGD-406 â€” Informe de DecisiÃ³n de Cierre SPB-003.2','',f'- **Proyecto:** {d.project}',f'- **Hito:** {d.milestone}',f'- **Fecha UTC:** {d.generated_at}',f'- **Dictamen:** **{d.verdict}**','', '| CÃ³digo | Control | Estado | Evidencia |','|---|---|---|---|']
    for g in d.gates: rows.append(f"| {g.code} | {g.name} | {'APROBADA' if g.passed else 'NO CONFORME'} | {g.evidence.replace('|','/').replace(chr(10),'<br>')} |")
    rows+=['','## ConclusiÃ³n','', 'La DirecciÃ³n puede autorizar el cierre formal.' if d.approved else 'El cierre queda condicionado hasta resolver las compuertas obligatorias.','']
    return '\n'.join(rows)

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--root',default='.'); ap.add_argument('--output',default='artifacts/closure/spb-003.2'); ap.add_argument('--full-tests',action='store_true'); a=ap.parse_args()
    root=Path(a.root).resolve(); out=root/a.output; out.mkdir(parents=True,exist_ok=True)
    d=ClosureOrchestrator(root,a.full_tests).execute()
    (out/'SGD-406-decision-cierre.json').write_text(json.dumps(d.to_dict(),ensure_ascii=False,indent=2),encoding='utf-8')
    (out/'SGD-406-informe-decision-cierre.md').write_text(render(d),encoding='utf-8')
    act=f"# ACT-003.2 â€” Acta de Cierre Candidata\n\n**Dictamen:** {d.verdict}\n\n**Commit:** `{d.metadata.get('head_commit','')}`\n"
    (out/'ACT-003.2-acta-cierre-candidata.md').write_text(act,encoding='utf-8')
    manifest=[]
    for p in sorted(out.glob('*')):
        if p.is_file(): manifest.append({'file':p.name,'size_bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
    (out/'REL-003.2-manifiesto-evidencias.json').write_text(json.dumps({'schema_version':'1.0','project':d.project,'milestone':'SPB-003.2','verdict':d.verdict,'artifacts':manifest},ensure_ascii=False,indent=2),encoding='utf-8')
    print('Dictamen:',d.verdict); print('Expediente:',out); return 0 if d.approved else 2
if __name__=='__main__': raise SystemExit(main())