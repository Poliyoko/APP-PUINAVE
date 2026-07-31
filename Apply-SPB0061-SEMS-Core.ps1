param(
    [string]$RepositoryRoot = (Get-Location).Path,
    [switch]$Force
)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$RepositoryRoot = (Resolve-Path $RepositoryRoot).Path
Set-Location $RepositoryRoot
if (-not (Test-Path ".git")) { throw "La carpeta actual no es la raíz de un repositorio Git." }

$Files = [ordered]@{}

$Files["src/sgoda/pmo/evidence/__init__.py"] = @'
"""SGODA Evidence Management System (SEMS)."""
from .manager import EvidenceManager
from .models import EvidenceRecord, EvidenceStatus, EvidenceType, IntegrityResult
__all__ = ["EvidenceManager","EvidenceRecord","EvidenceStatus","EvidenceType","IntegrityResult"]
__version__ = "0.1.0"
'@

$Files["src/sgoda/pmo/evidence/__main__.py"] = @'
from .cli import main
if __name__ == "__main__":
    raise SystemExit(main())
'@

$Files["src/sgoda/pmo/evidence/exceptions.py"] = @'
class EvidenceError(Exception): pass
class EvidenceNotFoundError(EvidenceError): pass
class EvidenceIntegrityError(EvidenceError): pass
class EvidenceValidationError(EvidenceError): pass
class EvidenceConflictError(EvidenceError): pass
'@

$Files["src/sgoda/pmo/evidence/models.py"] = @'
from __future__ import annotations
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from enum import Enum
from pathlib import Path
from typing import Any
from uuid import uuid4

def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()

class EvidenceType(str, Enum):
    FILE="file"; DIRECTORY="directory"; REPORT="report"; MANIFEST="manifest"
    ARCHIVE="archive"; TEST_RESULT="test-result"; AUDIT="audit"; OTHER="other"

class EvidenceStatus(str, Enum):
    REGISTERED="registered"; ARCHIVED="archived"; VERIFIED="verified"
    FAILED="failed"; EXTERNALIZED="externalized"

@dataclass(frozen=True)
class IntegrityResult:
    valid: bool
    expected_sha256: str
    actual_sha256: str
    checked_at_utc: str = field(default_factory=utc_now_iso)
    details: str = ""
    def to_dict(self) -> dict[str, Any]: return asdict(self)

@dataclass
class EvidenceRecord:
    evidence_id: str
    name: str
    source_path: str
    evidence_type: EvidenceType
    status: EvidenceStatus
    sha256: str
    size_bytes: int
    created_at_utc: str
    registered_at_utc: str
    deliverable_id: str = ""
    commit: str = ""
    tag: str = ""
    archive_path: str = ""
    metadata: dict[str, Any] = field(default_factory=dict)

    @classmethod
    def create(cls, source_path: Path, evidence_type: EvidenceType, sha256: str,
               size_bytes: int, *, evidence_id: str|None=None,
               deliverable_id: str="", commit: str="", tag: str="",
               metadata: dict[str,Any]|None=None) -> "EvidenceRecord":
        stat=source_path.stat()
        created=datetime.fromtimestamp(stat.st_mtime,tz=timezone.utc).isoformat()
        return cls(evidence_id or f"EVD-{uuid4().hex[:12].upper()}",
                   source_path.name, source_path.as_posix(), evidence_type,
                   EvidenceStatus.REGISTERED, sha256, size_bytes, created,
                   utc_now_iso(), deliverable_id, commit, tag, "", metadata or {})

    def to_dict(self) -> dict[str, Any]:
        data=asdict(self); data["evidence_type"]=self.evidence_type.value
        data["status"]=self.status.value; return data

    @classmethod
    def from_dict(cls, data: dict[str,Any]) -> "EvidenceRecord":
        d=dict(data); d["evidence_type"]=EvidenceType(d["evidence_type"])
        d["status"]=EvidenceStatus(d["status"]); return cls(**d)
'@

$Files["src/sgoda/pmo/evidence/hasher.py"] = @'
from __future__ import annotations
import hashlib
from pathlib import Path
from typing import Iterable

def sha256_file(path: Path, chunk_size: int=1024*1024) -> str:
    digest=hashlib.sha256()
    with path.open("rb") as stream:
        while True:
            chunk=stream.read(chunk_size)
            if not chunk: break
            digest.update(chunk)
    return digest.hexdigest()

def iter_files(path: Path) -> Iterable[Path]:
    if path.is_file():
        yield path; return
    for candidate in sorted(path.rglob("*")):
        if candidate.is_file(): yield candidate

def sha256_directory(path: Path) -> str:
    digest=hashlib.sha256(); base=path.resolve()
    for file_path in iter_files(base):
        relative=file_path.resolve().relative_to(base).as_posix()
        digest.update(relative.encode("utf-8")); digest.update(b"\0")
        digest.update(sha256_file(file_path).encode("ascii")); digest.update(b"\0")
    return digest.hexdigest()

def calculate_sha256(path: Path) -> str:
    if path.is_file(): return sha256_file(path)
    if path.is_dir(): return sha256_directory(path)
    raise FileNotFoundError(path)

def calculate_size(path: Path) -> int:
    if path.is_file(): return path.stat().st_size
    return sum(p.stat().st_size for p in iter_files(path))
'@

$Files["src/sgoda/pmo/evidence/manifest.py"] = @'
from __future__ import annotations
import json
from datetime import datetime, timezone
from pathlib import Path
from .hasher import iter_files, sha256_file

def build_manifest(source: Path) -> dict:
    source=source.resolve(); base=source if source.is_dir() else source.parent
    entries=[]
    for file_path in iter_files(source):
        stat=file_path.stat()
        entries.append({
            "relative_path": file_path.resolve().relative_to(base).as_posix(),
            "size_bytes": stat.st_size,
            "sha256": sha256_file(file_path),
            "modified_at_utc": datetime.fromtimestamp(stat.st_mtime,tz=timezone.utc).isoformat(),
        })
    return {"schema":"sgoda.sems.manifest/v1",
            "generated_at_utc":datetime.now(timezone.utc).isoformat(),
            "source":source.as_posix(),"file_count":len(entries),
            "total_bytes":sum(i["size_bytes"] for i in entries),
            "hash_algorithm":"SHA-256","entries":entries}

def write_manifest(source: Path, destination: Path) -> dict:
    manifest=build_manifest(source); destination.parent.mkdir(parents=True,exist_ok=True)
    destination.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    return manifest
'@

$Files["src/sgoda/pmo/evidence/registry.py"] = @'
from __future__ import annotations
import json
from pathlib import Path
from .exceptions import EvidenceConflictError, EvidenceNotFoundError
from .models import EvidenceRecord

class EvidenceRegistry:
    def __init__(self,path:Path)->None: self.path=path
    def _load_raw(self)->dict:
        if not self.path.exists(): return {"schema":"sgoda.sems.registry/v1","records":[]}
        return json.loads(self.path.read_text(encoding="utf-8"))
    def _save_raw(self,data:dict)->None:
        self.path.parent.mkdir(parents=True,exist_ok=True)
        tmp=self.path.with_suffix(self.path.suffix+".tmp")
        tmp.write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
        tmp.replace(self.path)
    def list(self)->list[EvidenceRecord]:
        return [EvidenceRecord.from_dict(i) for i in self._load_raw().get("records",[])]
    def get(self,evidence_id:str)->EvidenceRecord:
        for record in self.list():
            if record.evidence_id==evidence_id: return record
        raise EvidenceNotFoundError(f"No existe la evidencia: {evidence_id}")
    def add(self,record:EvidenceRecord)->EvidenceRecord:
        data=self._load_raw(); records=data.setdefault("records",[])
        if any(i.get("evidence_id")==record.evidence_id for i in records):
            raise EvidenceConflictError(f"Ya existe la evidencia: {record.evidence_id}")
        records.append(record.to_dict()); self._save_raw(data); return record
    def update(self,record:EvidenceRecord)->EvidenceRecord:
        data=self._load_raw(); records=data.setdefault("records",[])
        for idx,item in enumerate(records):
            if item.get("evidence_id")==record.evidence_id:
                records[idx]=record.to_dict(); self._save_raw(data); return record
        raise EvidenceNotFoundError(f"No existe la evidencia: {record.evidence_id}")
    def count(self)->int: return len(self.list())
'@

$Files["src/sgoda/pmo/evidence/archive.py"] = @'
from __future__ import annotations
import json, zipfile
from datetime import datetime, timezone
from pathlib import Path
from .hasher import iter_files, sha256_file
from .manifest import build_manifest

def create_archive(source:Path,destination:Path,*,metadata:dict|None=None)->tuple[Path,str]:
    source=source.resolve(); destination=destination.resolve()
    destination.parent.mkdir(parents=True,exist_ok=True)
    manifest=build_manifest(source); base=source if source.is_dir() else source.parent
    package={"schema":"sgoda.sems.archive/v1",
             "created_at_utc":datetime.now(timezone.utc).isoformat(),
             "source":source.as_posix(),"metadata":metadata or {}}
    with zipfile.ZipFile(destination,"w",compression=zipfile.ZIP_DEFLATED) as z:
        for file_path in iter_files(source):
            z.write(file_path,arcname=f"payload/{file_path.relative_to(base).as_posix()}")
        z.writestr("manifest.json",json.dumps(manifest,ensure_ascii=False,indent=2)+"\n")
        z.writestr("archive-metadata.json",json.dumps(package,ensure_ascii=False,indent=2)+"\n")
    return destination,sha256_file(destination)
'@

$Files["src/sgoda/pmo/evidence/verifier.py"] = @'
from __future__ import annotations
import hashlib, json, zipfile
from pathlib import Path
from .hasher import calculate_sha256
from .models import IntegrityResult

def verify_path(path:Path,expected_sha256:str)->IntegrityResult:
    actual=calculate_sha256(path); valid=actual.lower()==expected_sha256.lower()
    return IntegrityResult(valid,expected_sha256.lower(),actual.lower(),
                           details="integrity-ok" if valid else "sha256-mismatch")

def verify_archive_contents(path:Path)->tuple[bool,list[str]]:
    errors=[]
    with zipfile.ZipFile(path,"r") as z:
        bad=z.testzip()
        if bad: errors.append(f"crc-error:{bad}")
        names=set(z.namelist())
        if "manifest.json" not in names: return False,errors+["missing:manifest.json"]
        manifest=json.loads(z.read("manifest.json").decode("utf-8"))
        for entry in manifest.get("entries",[]):
            member=f"payload/{entry['relative_path']}"
            if member not in names: errors.append(f"missing:{member}"); continue
            actual=hashlib.sha256(z.read(member)).hexdigest()
            if actual.lower()!=entry["sha256"].lower(): errors.append(f"sha256-mismatch:{member}")
    return not errors,errors
'@

$Files["src/sgoda/pmo/evidence/manager.py"] = @'
from __future__ import annotations
from pathlib import Path
from typing import Any
from .archive import create_archive
from .exceptions import EvidenceValidationError
from .hasher import calculate_sha256, calculate_size
from .models import EvidenceRecord,EvidenceStatus,EvidenceType,IntegrityResult
from .registry import EvidenceRegistry
from .verifier import verify_archive_contents,verify_path

class EvidenceManager:
    def __init__(self,repository_root:Path,registry_path:Path|None=None)->None:
        self.repository_root=repository_root.resolve()
        self.sems_root=self.repository_root/"artifacts"/"pmo"/"SPB-006-SEMS"
        self.registry=EvidenceRegistry(registry_path or self.sems_root/"registry"/"evidence-registry.json")
    def register(self,source:Path,*,evidence_id:str|None=None,evidence_type:EvidenceType|None=None,
                 deliverable_id:str="",commit:str="",tag:str="",metadata:dict[str,Any]|None=None)->EvidenceRecord:
        source=source.resolve()
        if not source.exists(): raise EvidenceValidationError(f"No existe la ruta: {source}")
        selected=evidence_type or (EvidenceType.DIRECTORY if source.is_dir() else EvidenceType.FILE)
        record=EvidenceRecord.create(source,selected,calculate_sha256(source),calculate_size(source),
                                     evidence_id=evidence_id,deliverable_id=deliverable_id,
                                     commit=commit,tag=tag,metadata=metadata)
        return self.registry.add(record)
    def verify(self,evidence_id:str)->IntegrityResult:
        record=self.registry.get(evidence_id); source=Path(record.archive_path or record.source_path)
        result=verify_path(source,record.sha256)
        record.status=EvidenceStatus.VERIFIED if result.valid else EvidenceStatus.FAILED
        self.registry.update(record); return result
    def archive(self,evidence_id:str,destination:Path|None=None)->EvidenceRecord:
        record=self.registry.get(evidence_id); source=Path(record.source_path)
        destination=destination or self.sems_root/"archives"/f"{record.evidence_id}-{record.name}.zip"
        archive_path,archive_sha=create_archive(source,destination,metadata={
            "evidence_id":record.evidence_id,"deliverable_id":record.deliverable_id,
            "source_sha256":record.sha256,"commit":record.commit,"tag":record.tag})
        valid,errors=verify_archive_contents(archive_path)
        if not valid: raise EvidenceValidationError("ZIP inválido: "+", ".join(errors))
        record.archive_path=archive_path.as_posix(); record.sha256=archive_sha
        record.size_bytes=archive_path.stat().st_size; record.status=EvidenceStatus.ARCHIVED
        return self.registry.update(record)
    def status(self)->dict[str,Any]:
        records=self.registry.list(); by_status={}
        for record in records: by_status[record.status.value]=by_status.get(record.status.value,0)+1
        return {"schema":"sgoda.sems.status/v1","registry":self.registry.path.as_posix(),
                "records":len(records),"by_status":by_status}
'@

$Files["src/sgoda/pmo/evidence/cli.py"] = @'
from __future__ import annotations
import argparse,json,subprocess
from pathlib import Path
from .manager import EvidenceManager
from .models import EvidenceType

def git_value(root:Path,*args:str)->str:
    try:
        return subprocess.run(["git",*args],cwd=root,check=True,capture_output=True,text=True).stdout.strip()
    except (OSError,subprocess.CalledProcessError): return ""

def build_parser()->argparse.ArgumentParser:
    parser=argparse.ArgumentParser(prog="sgoda-sems",description="SGODA Evidence Management System")
    parser.add_argument("--root",default=".")
    sub=parser.add_subparsers(dest="command",required=True)
    register=sub.add_parser("register"); register.add_argument("source")
    register.add_argument("--id",dest="evidence_id"); register.add_argument("--type",choices=[i.value for i in EvidenceType])
    register.add_argument("--deliverable",default=""); register.add_argument("--commit",default=""); register.add_argument("--tag",default="")
    verify=sub.add_parser("verify"); verify.add_argument("evidence_id")
    archive=sub.add_parser("archive"); archive.add_argument("evidence_id"); archive.add_argument("--destination")
    sub.add_parser("status"); sub.add_parser("list"); return parser

def main(argv:list[str]|None=None)->int:
    args=build_parser().parse_args(argv); root=Path(args.root).resolve(); manager=EvidenceManager(root)
    if args.command=="register":
        record=manager.register(Path(args.source),evidence_id=args.evidence_id,
            evidence_type=EvidenceType(args.type) if args.type else None,
            deliverable_id=args.deliverable,commit=args.commit or git_value(root,"rev-parse","HEAD"),tag=args.tag)
        print(json.dumps(record.to_dict(),ensure_ascii=False,indent=2)); return 0
    if args.command=="verify":
        result=manager.verify(args.evidence_id); print(json.dumps(result.to_dict(),ensure_ascii=False,indent=2))
        return 0 if result.valid else 2
    if args.command=="archive":
        record=manager.archive(args.evidence_id,Path(args.destination).resolve() if args.destination else None)
        print(json.dumps(record.to_dict(),ensure_ascii=False,indent=2)); return 0
    if args.command=="status":
        print(json.dumps(manager.status(),ensure_ascii=False,indent=2)); return 0
    if args.command=="list":
        print(json.dumps([r.to_dict() for r in manager.registry.list()],ensure_ascii=False,indent=2)); return 0
    return 2
'@

$Files["tests/pmo/evidence/test_sems_core.py"] = @'
from pathlib import Path
import pytest
from sgoda.pmo.evidence.archive import create_archive
from sgoda.pmo.evidence.exceptions import EvidenceConflictError
from sgoda.pmo.evidence.hasher import calculate_sha256
from sgoda.pmo.evidence.manager import EvidenceManager
from sgoda.pmo.evidence.manifest import build_manifest
from sgoda.pmo.evidence.models import EvidenceStatus
from sgoda.pmo.evidence.verifier import verify_archive_contents

def test_manifest_and_hash(tmp_path:Path)->None:
    source=tmp_path/"source"; source.mkdir(); (source/"ñ.txt").write_text("Puinave",encoding="utf-8")
    manifest=build_manifest(source)
    assert manifest["file_count"]==1 and len(calculate_sha256(source))==64

def test_archive_integrity(tmp_path:Path)->None:
    source=tmp_path/"source"; source.mkdir(); (source/"a.txt").write_text("A",encoding="utf-8")
    archive,sha=create_archive(source,tmp_path/"evidence.zip")
    valid,errors=verify_archive_contents(archive)
    assert len(sha)==64 and valid and errors==[]

def test_manager_lifecycle(tmp_path:Path)->None:
    repo=tmp_path/"repo"; repo.mkdir(); sample=repo/"evidence.txt"; sample.write_text("SGODA",encoding="utf-8")
    manager=EvidenceManager(repo)
    record=manager.register(sample,evidence_id="EVD-SPB006-001",deliverable_id="SPB-006.1")
    assert record.status is EvidenceStatus.REGISTERED
    assert manager.verify(record.evidence_id).valid
    archived=manager.archive(record.evidence_id)
    assert archived.status is EvidenceStatus.ARCHIVED and Path(archived.archive_path).exists()

def test_duplicate_rejected(tmp_path:Path)->None:
    repo=tmp_path/"repo"; repo.mkdir(); sample=repo/"e.txt"; sample.write_text("x",encoding="utf-8")
    manager=EvidenceManager(repo); manager.register(sample,evidence_id="EVD-1")
    with pytest.raises(EvidenceConflictError): manager.register(sample,evidence_id="EVD-1")
'@

$Files["docs/03_ADR/ADR-010-Evidence-Management-System.md"] = @'
# ADR-010 — SGODA Evidence Management System
## Estado
Aceptada.
## Decisión
Implementar SEMS como subsistema del PMO Digital bajo `sgoda.pmo.evidence`.
El núcleo utiliza biblioteca estándar de Python, registro JSON UTF-8,
SHA-256, manifiestos, paquetes ZIP verificables y CLI institucional.
## Consecuencias
La evidencia consolidada permanece en Git; respaldos voluminosos pueden
externalizarse conservando manifiestos, hashes y referencias.
'@

$Files["docs/standards/Evidence-Management-Standard.md"] = @'
# SGODA Evidence Management Standard
1. Toda evidencia tendrá identificador único.
2. Toda evidencia tendrá hash SHA-256.
3. Todo archivo externo tendrá manifiesto.
4. Todo ZIP deberá superar verificación CRC y SHA-256.
5. El registro institucional será JSON UTF-8.
6. Los registros se vincularán con entregable, commit y tag cuando aplique.
7. SPB-006.1 no implementa eliminación.
'@

$Files["docs/01_Gobierno/SGD-111-Ciclo-de-Vida-de-Evidencias.md"] = @'
# SGD-111 — Ciclo de Vida de Evidencias
Estados: `registered`, `verified`, `archived`, `externalized`, `failed`.
Flujo inicial: Origen → Registro → SHA-256 → Manifiesto → ZIP →
Verificación → Registro actualizado.
Retención, restauración, cifrado y eliminación autorizada quedan diferidos.
'@

$Files["artifacts/pmo/SPB-006-SEMS/README.md"] = @'
# SPB-006 — SEMS Artifacts
- `registry/`: registro JSON.
- `archives/`: paquetes ZIP.
- `manifests/`: manifiestos.
- `reports/`: resultados.
- `integrity/`: verificaciones.
'@

$Files["artifacts/pmo/SPB-006-SEMS/implementation-manifest.json"] = @'
{
  "schema": "sgoda.spb.implementation/v1",
  "deliverable": "SPB-006.1",
  "name": "SEMS Core",
  "version": "0.1.0",
  "status": "implemented",
  "capabilities": ["register","list","status","verify","archive","sha256","manifest","json-registry"],
  "deferred": ["retention","restore","external-storage","encryption","authorized-delete"]
}
'@

function Write-Utf8NoBom {
    param([string]$Path,[string]$Content)
    $FullPath=Join-Path $RepositoryRoot $Path
    New-Item -ItemType Directory -Force -Path (Split-Path $FullPath -Parent) | Out-Null
    if ((Test-Path $FullPath) -and (-not $Force)) { throw "El archivo ya existe: $Path. Use -Force." }
    [System.IO.File]::WriteAllText($FullPath,$Content,(New-Object System.Text.UTF8Encoding($false)))
    Write-Host "CREADO: $Path"
}

Write-Host "`n====================================================="
Write-Host " SPB-006.1 - SGODA SEMS Core"
Write-Host "=====================================================`n"
foreach ($Entry in $Files.GetEnumerator()) { Write-Utf8NoBom $Entry.Key $Entry.Value }

$env:PYTHONPATH="src"
python -c "from sgoda.pmo.evidence import EvidenceManager; print('SEMS import: OK')"
if ($LASTEXITCODE -ne 0) { throw "Falló la importación de SEMS." }
python -m pytest tests/pmo/evidence -q
if ($LASTEXITCODE -ne 0) { throw "Fallaron las pruebas de SPB-006.1." }
python -m sgoda.pmo.evidence --root . status
if ($LASTEXITCODE -ne 0) { throw "Falló la CLI de SEMS." }
Write-Host "`nSPB-006.1 IMPLEMENTADO. Revise con: git status --short"
Write-Host "No ejecute git add ."
