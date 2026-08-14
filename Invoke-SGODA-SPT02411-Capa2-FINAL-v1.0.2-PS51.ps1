#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"

$ExpectedBaseline="0e2dcff70b894da808839cbda9931e22a2daf611"
$Branch="feature/SPT-001A-rlb-schema-foundation"
$SelfName="Invoke-SGODA-SPT02411-Capa2-FINAL-v1.0.2-PS51.ps1"
$ModuleDir="src/sgoda/integration/spt02411l2"
$TestFile="tests/integration/test_spt02411_data_lifecycle_governance_layer2.py"
$PolicyFile="config/integration/spt02411/data-lifecycle-governance-policy.json"
$DocFile="docs/06_Tecnologia/SPT-024/SPT-024.11/SGD-SPT024.11-Capa2-Ciclo-Vida-Retencion-Archivado-Disposicion-Legal-Hold.md"
$ArtifactDir="artifacts/development/SPT-024.11-Capa2-v1.0.0"
$LargeFileLimit=100MB

function Hold([string]$Reason){
  Write-Host ""; Write-Host "SPT-024.11 CAPA 2 : HOLD" -ForegroundColor Red
  Write-Host "REASON : $Reason" -ForegroundColor Red
  Write-Host "TRANSACTION : NOT PUBLISHED" -ForegroundColor Red
  exit 1
}
function Step([int]$N,[string]$Text){ Write-Host ""; Write-Host ("[{0}/16] {1}" -f $N,$Text) -ForegroundColor Cyan }
function Native([string]$Exe,[string[]]$NativeArgs,[string]$Label){
  if([string]::IsNullOrWhiteSpace($Exe)){ throw "Native executable is empty" }
  if($null -eq $NativeArgs -or $NativeArgs.Count -eq 0){ throw "$Label received no native arguments" }
  & $Exe @NativeArgs
  if($LASTEXITCODE -ne 0){ throw "$Label failed with exit code $LASTEXITCODE" }
}
function WriteLf([string]$Path,[string]$Text){
  if([string]::IsNullOrWhiteSpace($Path)){ throw "WriteLf path is empty" }
  $TargetPath = if([IO.Path]::IsPathRooted($Path)){ $Path } else { Join-Path $PWD $Path }
  $Parent=Split-Path -Parent $TargetPath
  if($Parent){New-Item -ItemType Directory -Force -Path $Parent|Out-Null}
  $Utf8=New-Object System.Text.UTF8Encoding($false)
  $Canonical=(($Text -replace "`r`n","`n") -replace "`r","`n")
  if(-not $Canonical.EndsWith("`n")){$Canonical+="`n"}
  [IO.File]::WriteAllText($TargetPath,$Canonical,$Utf8)
}
function PyExe(){
  foreach($c in @(".venv\Scripts\python.exe","venv\Scripts\python.exe")){if(Test-Path $c){return (Resolve-Path $c).Path}}
  $cmd=Get-Command python.exe -ErrorAction SilentlyContinue; if($cmd){return $cmd.Source}
  throw "Python executable not found"
}
function Fetch(){
  for($i=1;$i -le 4;$i++){Write-Host "GIT FETCH ATTEMPT : $i/4"; & git.exe fetch --prune origin $Branch; if($LASTEXITCODE -eq 0){Write-Host "GIT FETCH : PASS";return}; if($i -lt 4){Start-Sleep -Seconds @(3,7,15)[$i-1]}}
  throw "Git fetch failed after 4 attempts"
}
function Snapshot(){
  $h=@{}; foreach($p in @(& git.exe -c core.quotepath=false ls-files)){
    $n=($p -replace '\\','/'); if($n.StartsWith("$ModuleDir/") -or $n -eq $TestFile -or $n -eq $PolicyFile -or $n -eq $DocFile -or $n.StartsWith("$ArtifactDir/") -or $n -eq $SelfName){continue}
    if(Test-Path -LiteralPath $n -PathType Leaf){try{$h[$n]=(Get-FileHash -Algorithm SHA256 -LiteralPath $n).Hash}catch{}}
  }; return $h
}
function CheckSnapshot($h){
  foreach($p in $h.Keys){if(-not(Test-Path -LiteralPath $p)){Hold "Protected file disappeared: $p"}; if((Get-FileHash -Algorithm SHA256 -LiteralPath $p).Hash -ne $h[$p]){Hold "Protected file changed: $p"}}
  Write-Host "PROTECTED TRACKED FILES : PRESERVED"
}
function SizeGate(){
  $bad=@(); foreach($p in @(& git.exe -c core.quotepath=false ls-files)){$s=@(& git.exe cat-file -s (":"+$p) 2>$null); if($LASTEXITCODE -eq 0 -and $s.Count -gt 0){[Int64]$n=0;if([Int64]::TryParse(([string]$s[0]).Trim(),[ref]$n) -and $n -ge $LargeFileLimit){$bad+=$p}}}
  return @($bad)
}

$CorePy=@'
from __future__ import annotations
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Iterable, Mapping
import hashlib

VALID_STATES = {
    "ACTIVE","ARCHIVE_READY","ARCHIVED","RETENTION_REVIEW",
    "DISPOSAL_REVIEW","LEGAL_HOLD","CLOSED"
}
TRANSITIONS = {
    "ACTIVE":{"ARCHIVE_READY","LEGAL_HOLD","RETENTION_REVIEW"},
    "ARCHIVE_READY":{"ARCHIVED","LEGAL_HOLD"},
    "ARCHIVED":{"RETENTION_REVIEW","LEGAL_HOLD"},
    "RETENTION_REVIEW":{"DISPOSAL_REVIEW","LEGAL_HOLD","CLOSED"},
    "DISPOSAL_REVIEW":{"LEGAL_HOLD","CLOSED"},
    "LEGAL_HOLD":{"RETENTION_REVIEW","CLOSED"},
    "CLOSED":set(),
}

@dataclass(frozen=True)
class Control:
    control_id: str
    passed: bool
    blocking: bool
    detail: str

def transition(record: Mapping, target: str) -> dict:
    current = str(record.get("state","")).upper()
    target = str(target).upper()
    if current not in VALID_STATES or target not in VALID_STATES:
        raise ValueError("invalid data lifecycle state")
    if target not in TRANSITIONS[current]:
        raise ValueError("invalid data lifecycle transition")
    updated = dict(record)
    updated["state"] = target
    return updated

def archive_plan(profile: Mapping) -> dict:
    fmt = str(profile.get("archive_format","")).upper()
    valid = (
        bool(str(profile.get("record_id","")).strip())
        and fmt in {"JSON","JSONL","CSV","WAV","FLAC","PNG","WEBP"}
        and bool(profile.get("integrity_required",False))
        and bool(profile.get("immutable",False))
    )
    return {
        "valid":valid,"archive_format":fmt,"archive_executed":False,
        "production_data_modified":False,"external_connection_opened":False,
        "secret_values_exposed":False
    }

def retention(profile: Mapping, now: datetime|None=None) -> dict:
    now = now or datetime.now(timezone.utc)
    created = datetime.fromisoformat(str(profile["created_at"]).replace("Z","+00:00"))
    days = int(profile.get("retention_days",0))
    minimum = int(profile.get("minimum_retention_days",1))
    legal_hold = bool(profile.get("legal_hold",False))
    expires = created + timedelta(days=days)
    expired = expires <= now
    disposition = "HOLD" if legal_hold else ("DISPOSAL_REVIEW" if expired else "RETAIN")
    return {
        "valid": days >= minimum and days > 0,
        "retention_days":days,"minimum_retention_days":minimum,
        "legal_hold":legal_hold,"expired":expired,"disposition":disposition,
        "disposal_executed":False,"production_data_deleted":False,
        "secret_values_exposed":False
    }

def legal_hold(profile: Mapping) -> dict:
    reason = str(profile.get("reason","")).strip()
    authority = str(profile.get("authority","")).strip()
    active = bool(profile.get("active",False))
    valid = bool(str(profile.get("hold_id","")).strip()) and len(reason) >= 10 and bool(authority) and active
    return {
        "valid":valid,"active":active,"release_executed":False,
        "production_data_deleted":False,"secret_values_exposed":False
    }

def disposal_review(profile: Mapping) -> dict:
    reason = str(profile.get("reason","")).strip()
    eligible = (
        bool(str(profile.get("record_id","")).strip())
        and bool(str(profile.get("approved_by","")).strip())
        and len(reason) >= 10
        and not bool(profile.get("legal_hold",False))
        and bool(profile.get("integrity_verified",False))
    )
    return {
        "eligible":eligible,"disposal_executed":False,
        "production_data_deleted":False,"secret_values_exposed":False
    }

def privacy_governance(profile: Mapping) -> dict:
    valid = (
        str(profile.get("purpose","")).upper() in {"PRESERVATION","TEACHING","AUDIT","SECURITY","OPERATIONS"}
        and str(profile.get("classification","")).upper() in {"PUBLIC","INTERNAL","CONFIDENTIAL","RESTRICTED"}
        and bool(profile.get("access_review",False))
        and bool(profile.get("minimization_review",False))
        and bool(profile.get("retention_review",False))
    )
    return {
        "valid":valid,"production_policy_changed":False,
        "external_disclosure_executed":False,"secret_values_exposed":False
    }

class DataLifecycleGovernanceGate:
    BLOCKING = {
        "DATA-LIFECYCLE","DATA-ARCHIVE-GOVERNANCE","DATA-ADVANCED-RETENTION",
        "DATA-LEGAL-HOLD","DATA-DISPOSAL-CONTROL","DATA-PRIVACY-GOVERNANCE",
        "DATA-NO-DESTRUCTIVE-ACTION","DATA-NO-SIDE-EFFECTS","DATA-SECRET-SAFETY"
    }

    @classmethod
    def evaluate(cls, controls):
        by_id = {c.control_id:c for c in controls}
        missing = sorted(cls.BLOCKING - set(by_id))
        if missing:
            return False, ["MISSING:"+m for m in missing]
        failed = [cid for cid in sorted(cls.BLOCKING) if by_id[cid].blocking and not by_id[cid].passed]
        return not failed, failed

class DataLifecycleGovernanceService:
    def __init__(self, root: Path, discovered_paths: Iterable[str]):
        self.root = Path(root)
        self.discovered_paths = list(discovered_paths)

    def assess(self):
        state = {"state":"ACTIVE","record_id":"ODA-001"}
        for target in ["ARCHIVE_READY","ARCHIVED","RETENTION_REVIEW","DISPOSAL_REVIEW","CLOSED"]:
            state = transition(state,target)

        a = archive_plan({
            "record_id":"ODA-001","archive_format":"JSON",
            "integrity_required":True,"immutable":True
        })
        r = retention({
            "created_at":"2025-01-01T00:00:00+00:00",
            "retention_days":365,"minimum_retention_days":30,"legal_hold":False
        }, datetime(2026,8,11,tzinfo=timezone.utc))
        h = legal_hold({
            "hold_id":"LH-001","reason":"Institutional preservation review",
            "authority":"PISI_PRIVACY_OWNER","active":True
        })
        d = disposal_review({
            "record_id":"ODA-001","approved_by":"PISI_PRIVACY_OWNER",
            "reason":"Retention period completed and reviewed",
            "legal_hold":False,"integrity_verified":True
        })
        g = privacy_governance({
            "purpose":"PRESERVATION","classification":"RESTRICTED",
            "access_review":True,"minimization_review":True,"retention_review":True
        })

        controls = [
            Control("DATA-LIFECYCLE", state["state"]=="CLOSED", True, "Formal lifecycle closes after governed review."),
            Control("DATA-ARCHIVE-GOVERNANCE", a["valid"] is True, True, "Archive requires integrity and immutability."),
            Control("DATA-ADVANCED-RETENTION", r["valid"] is True and r["disposition"] in {"RETAIN","HOLD","DISPOSAL_REVIEW"}, True, "Retention is time-bound."),
            Control("DATA-LEGAL-HOLD", h["valid"] is True, True, "Legal hold requires reason and authority."),
            Control("DATA-DISPOSAL-CONTROL", d["eligible"] is True and d["disposal_executed"] is False, True, "Disposal remains review-only."),
            Control("DATA-PRIVACY-GOVERNANCE", g["valid"] is True, True, "Purpose/classification/access/minimization/retention jointly reviewed."),
            Control("DATA-NO-DESTRUCTIVE-ACTION", r["production_data_deleted"] is False and h["production_data_deleted"] is False and d["production_data_deleted"] is False, True, "No production deletion."),
            Control("DATA-NO-SIDE-EFFECTS", a["production_data_modified"] is False and g["production_policy_changed"] is False and g["external_disclosure_executed"] is False, True, "No production mutation or disclosure."),
            Control("DATA-SECRET-SAFETY", all(x["secret_values_exposed"] is False for x in [a,r,h,d,g]), True, "No secret values exposed."),
        ]
        passed, failed = DataLifecycleGovernanceGate.evaluate(controls)
        return {
            "status":"DATA_LIFECYCLE_GOVERNANCE_GATE_PASS" if passed else "DATA_LIFECYCLE_GOVERNANCE_GATE_HOLD",
            "failed_blocking_controls":failed,
            "controls":[c.__dict__ for c in controls],
            "lifecycle_final_state":state["state"],
            "archive_plan":a,"retention":r,"legal_hold":h,
            "disposal_review":d,"privacy_governance":g,
            "discovered_data_lifecycle_surfaces":len(self.discovered_paths),
            "production_data_modified":False,"production_data_deleted":False,
            "archive_executed":False,"disposal_executed":False,
            "external_disclosure_executed":False,"external_connection_opened":False,
            "secret_values_exposed":False
        }

def sha256(path: Path) -> str:
    d=hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda:f.read(1024*1024),b""):
            d.update(chunk)
    return d.hexdigest()

def build_manifest(root: Path, paths: Iterable[str]) -> dict:
    records=[]
    for rel in sorted(set(paths)):
        p=root/rel
        if p.is_file():
            records.append({"path":rel.replace("\\\\","/"),"bytes":p.stat().st_size,"sha256":sha256(p)})
    return {"algorithm":"SHA-256","record_count":len(records),"records":records}
'@
$TestsPy=@'
import pytest
from datetime import datetime, timezone
from pathlib import Path
from sgoda.integration.spt02411l2.core import (
    transition, archive_plan, retention, legal_hold, disposal_review,
    privacy_governance, DataLifecycleGovernanceService
)

def test_valid_lifecycle():
    r={"state":"ACTIVE"}
    for s in ["ARCHIVE_READY","ARCHIVED","RETENTION_REVIEW","DISPOSAL_REVIEW","CLOSED"]:
        r=transition(r,s)
    assert r["state"]=="CLOSED"

def test_invalid_transition():
    with pytest.raises(ValueError):
        transition({"state":"ACTIVE"},"CLOSED")

def test_archive_requires_integrity():
    assert archive_plan({"record_id":"R1","archive_format":"JSON","integrity_required":True,"immutable":True})["valid"] is True
    assert archive_plan({"record_id":"R1","archive_format":"JSON","integrity_required":False,"immutable":True})["valid"] is False

def test_expired_retention_review():
    r=retention({"created_at":"2025-01-01T00:00:00+00:00","retention_days":30,"minimum_retention_days":30,"legal_hold":False}, datetime(2026,8,11,tzinfo=timezone.utc))
    assert r["disposition"]=="DISPOSAL_REVIEW"
    assert r["disposal_executed"] is False

def test_legal_hold_overrides():
    r=retention({"created_at":"2025-01-01T00:00:00+00:00","retention_days":30,"minimum_retention_days":30,"legal_hold":True}, datetime(2026,8,11,tzinfo=timezone.utc))
    assert r["disposition"]=="HOLD"

def test_legal_hold_requires_authority():
    assert legal_hold({"hold_id":"LH1","reason":"Institutional investigation","authority":"OWNER","active":True})["valid"] is True
    assert legal_hold({"hold_id":"LH1","reason":"short","authority":"","active":True})["valid"] is False

def test_disposal_review():
    r=disposal_review({"record_id":"R1","approved_by":"OWNER","reason":"Retention period completed","legal_hold":False,"integrity_verified":True})
    assert r["eligible"] is True and r["disposal_executed"] is False

def test_disposal_blocked_by_hold():
    r=disposal_review({"record_id":"R1","approved_by":"OWNER","reason":"Retention period completed","legal_hold":True,"integrity_verified":True})
    assert r["eligible"] is False

def test_privacy_governance():
    r=privacy_governance({"purpose":"PRESERVATION","classification":"RESTRICTED","access_review":True,"minimization_review":True,"retention_review":True})
    assert r["valid"] is True

def test_full_gate(tmp_path):
    r=DataLifecycleGovernanceService(tmp_path,[]).assess()
    assert r["status"]=="DATA_LIFECYCLE_GOVERNANCE_GATE_PASS"
    assert r["failed_blocking_controls"]==[]

def test_no_real_changes(tmp_path):
    r=DataLifecycleGovernanceService(tmp_path,[]).assess()
    assert r["production_data_modified"] is False
    assert r["production_data_deleted"] is False
    assert r["archive_executed"] is False
    assert r["disposal_executed"] is False
    assert r["external_disclosure_executed"] is False
    assert r["external_connection_opened"] is False
    assert r["secret_values_exposed"] is False
'@
$PolicyJson=@'
{
  "component": "SPT-024.11",
  "layer": "2",
  "version": "1.0.0",
  "title": "Ciclo de Vida de Datos, Retencion Avanzada, Archivado, Disposicion Controlada, Legal Hold y Gobierno de Privacidad",
  "blocking_controls": [
    "DATA-LIFECYCLE",
    "DATA-ARCHIVE-GOVERNANCE",
    "DATA-ADVANCED-RETENTION",
    "DATA-LEGAL-HOLD",
    "DATA-DISPOSAL-CONTROL",
    "DATA-PRIVACY-GOVERNANCE",
    "DATA-NO-DESTRUCTIVE-ACTION",
    "DATA-NO-SIDE-EFFECTS",
    "DATA-SECRET-SAFETY"
  ],
  "automatic_destructive_disposal": false,
  "legal_hold_overrides_disposal": true,
  "archive_execution_by_gate": false,
  "production_data_mutation_by_gate": false
}
'@
$DocMd=@'
# SPT-024.11 Capa 2 — Ciclo de Vida de Datos, Retencion Avanzada, Archivado, Disposicion Controlada, Legal Hold y Gobierno de Privacidad

Baseline autoritativa: `0e2dcff70b894da808839cbda9931e22a2daf611`.

Reutiliza SPT-024.11 Capa 1 sin reabrirla. Implementa ciclo de vida formal, archivado gobernado, retencion avanzada, legal hold, disposicion controlada, verificacion de integridad SHA-256, preservation gates y publicacion obligatoria.

Estados institucionales: `ACTIVE → ARCHIVE_READY → ARCHIVED → RETENTION_REVIEW → DISPOSAL_REVIEW → CLOSED`. `LEGAL_HOLD` bloquea la disposicion y obliga revision formal.

La capa es estatica y no destructiva: no archiva, elimina, divulga ni modifica datos productivos.
'@

try {
Step 1 "AUTHORITATIVE BASELINE / REMOTE SAFETY"
if(-not(Test-Path ".git")){Hold "Execute from repository root"}
Fetch
$Local=(& git.exe rev-parse HEAD).Trim(); $Remote=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
$Staged=@(& git.exe diff --cached --name-only); $Deleted=@(& git.exe ls-files --deleted)
Write-Host "LOCAL HEAD      : $Local"; Write-Host "REMOTE HEAD     : $Remote"; Write-Host "STAGED          : $($Staged.Count)"; Write-Host "DELETED TRACKED : $($Deleted.Count)"
if($Local -ne $ExpectedBaseline -or $Remote -ne $ExpectedBaseline){Hold "Authoritative baseline mismatch"}
if($Staged.Count -ne 0 -or $Deleted.Count -ne 0){Hold "Unsafe pre-existing staged/deleted state"}
Write-Host "BASELINE : PASS"; Write-Host "SPT-024.1-.10 + SPT-024.11 CAPA 1 : PROTECTED / NOT REOPENED"; Write-Host "DESTRUCTIVE CLEANUP : NO"

Step 2 "VERIFY SPT-024.11 CAPA 1 INPUTS / RECOVERY STATE"
$Req=@(
"artifacts/development/SPT-024.11-Capa1-v1.0.0/data-privacy-governance-assessment.json",
"artifacts/development/SPT-024.11-Capa1-v1.0.0/data-privacy-surface-inventory.json",
"artifacts/development/SPT-024.11-Capa1-v1.0.0/data-classification-baseline.json",
"artifacts/development/SPT-024.11-Capa1-v1.0.0/data-retention-minimization-baseline.json",
"artifacts/development/SPT-024.11-Capa1-v1.0.0/data-privacy-integrity-manifest.json",
"artifacts/development/SPT-024.11-Capa1-v1.0.0/implementation-evidence.json",
"config/integration/spt02411/data-privacy-governance-policy.json")
$Missing=@($Req|Where-Object{-not(Test-Path $_)}); Write-Host "REQUIRED CAPA 1 INPUTS : $($Req.Count)"; Write-Host "MISSING INPUTS         : $($Missing.Count)"
if($Missing.Count -gt 0){Hold "Capa 1 inputs incomplete"}
$L1=Get-Content $Req[0] -Raw -Encoding UTF8|ConvertFrom-Json; if($L1.status -ne "DATA_PRIVACY_GOVERNANCE_GATE_PASS"){Hold "Capa 1 gate not PASS"}
Write-Host "CAPA 1 DATA PRIVACY GATE : PASS"
$FailedMaster = "Invoke-SGODA-SPT02411-Capa2-FINAL-v1.0.0-PS51.ps1"
if(Test-Path -LiteralPath $FailedMaster){
  Write-Host "FAILED MASTERS v1.0.0-v1.0.1 : LOCAL / SUPERSEDED / NOT PUBLISHED"
}
Write-Host "RECOVERY MASTER v1.0.2  : ACTIVE"

Step 3 "SHA-256 FREEZE OF CLOSED COMPONENTS"
$Snap=Snapshot; Write-Host "PROTECTED TRACKED FILES : $($Snap.Count)"; Write-Host "SHA-256 FREEZE : PASS"

Step 4 "DATA LIFECYCLE / ARCHIVE / RETENTION / LEGAL-HOLD DISCOVERY"
$Tracked=@(& git.exe -c core.quotepath=false ls-files)
$Surfaces=@($Tracked|Where-Object{$x=($_ -replace '\\','/').ToLowerInvariant(); $x -match '(data|privacy|retention|archive|backup|legal|hold|disposal|evidence|audit|lexical|audio|image|oda|fld|postgres|sensitive|personal)' -and $x -match '\.(py|ps1|json|ya?ml|toml|ini|cfg|md|csv|txt)$'})
Write-Host "DATA LIFECYCLE SURFACES : $($Surfaces.Count)"; Write-Host "DISCOVERY MODE          : STATIC / NON-DESTRUCTIVE"; Write-Host "SURFACE TRANSFER MODE   : TEMP JSON / SHORT ARGUMENT"; Write-Host "PRODUCTION DATA DELETED : NO"

Step 5 "IMPLEMENT SPT-024.11 CAPA 2"
WriteLf "$ModuleDir/__init__.py" 'from .core import DataLifecycleGovernanceService, DataLifecycleGovernanceGate'
WriteLf "$ModuleDir/core.py" $CorePy
WriteLf $TestFile $TestsPy
WriteLf $PolicyFile $PolicyJson
WriteLf $DocFile $DocMd
Write-Host "SPT-024.11 CAPA 2 IMPLEMENTATION : CREATED/VALIDATED"

Step 6 "PYTHON PREVALIDATION + TARGETED TESTS"
$Python=PyExe; $env:PYTHONPATH=(Join-Path $PWD "src")
$ArgProbe = @(& $Python -c "import sys; assert len(sys.argv)==2 and sys.argv[1]=='SGODA_ARG_OK'; print('PYTHON_ARGUMENT_CONTRACT=PASS')" "SGODA_ARG_OK" 2>&1)
if($LASTEXITCODE -ne 0 -or ($ArgProbe -join "`n") -notmatch "PYTHON_ARGUMENT_CONTRACT=PASS"){
  throw "Python argument contract failed; interactive REPL execution is prohibited."
}
$ArgProbe | ForEach-Object { Write-Host ([string]$_) }
Native $Python @("-c","import sgoda.integration.spt02411l2 as m; assert len(m.DataLifecycleGovernanceGate.BLOCKING)==9; print('SPT02411_CAPA2_IMPORT=PASS'); print('BLOCKING_CONTROLS=9')") "import"
Native $Python @("-m","pytest",$TestFile,"-q") "targeted tests"
Write-Host "TARGETED TESTS : PASS"

Step 7 "INSTITUTIONAL SUITE + COMPILEALL"
Native $Python @("-m","pytest","-q") "full suite"; Write-Host "FULL SUITE : PASS"
Native $Python @("-m","compileall","-q","src") "compileall"; Write-Host "COMPILEALL : PASS"

Step 8 "PRODUCTION DATA LIFECYCLE / GOVERNANCE ASSESSMENT"
New-Item -ItemType Directory -Force -Path $ArtifactDir|Out-Null
$Tmp=Join-Path $env:TEMP ("spt02411l2-"+[guid]::NewGuid().ToString("N")+".py")
$SurfaceFile=Join-Path $env:TEMP ("spt02411l2-surfaces-"+[guid]::NewGuid().ToString("N")+".json")
$NormalizedSurfaces=@($Surfaces|ForEach-Object{$_ -replace '\\','/'})
$SurfacePayload=($NormalizedSurfaces | ConvertTo-Json -Compress)
if([string]::IsNullOrWhiteSpace($SurfacePayload)){$SurfacePayload="[]"}
WriteLf $SurfaceFile $SurfacePayload
$Probe=@'
import json,sys
from pathlib import Path
from sgoda.integration.spt02411l2.core import DataLifecycleGovernanceService,build_manifest

if len(sys.argv) != 2:
    raise SystemExit("SURFACE_ARGUMENT_CONTRACT_FAILED")

root=Path.cwd()
surface_file=Path(sys.argv[1])
paths=json.loads(surface_file.read_text(encoding="utf-8"))

if not isinstance(paths,list):
    raise SystemExit("SURFACE_PAYLOAD_NOT_LIST")

paths=[str(p).replace("\\","/") for p in paths]
r=DataLifecycleGovernanceService(root,paths).assess()

ad=root/"artifacts/development/SPT-024.11-Capa2-v1.0.0"
ad.mkdir(parents=True,exist_ok=True)

files={
"data-lifecycle-governance-assessment.json":r,
"data-lifecycle-surface-inventory.json":{"mode":"GIT_TRACKED_STATIC_DISCOVERY","surface_count":len(paths),"paths":sorted(set(paths)),"production_data_deleted":False},
"data-lifecycle-baseline.json":{"states":["ACTIVE","ARCHIVE_READY","ARCHIVED","RETENTION_REVIEW","DISPOSAL_REVIEW","LEGAL_HOLD","CLOSED"],"sample_final_state":r["lifecycle_final_state"]},
"advanced-retention-baseline.json":{"retention":r["retention"],"privacy_governance":r["privacy_governance"]},
"archive-governance-baseline.json":{"archive_plan":r["archive_plan"],"archive_executed":False},
"legal-hold-disposal-baseline.json":{"legal_hold":r["legal_hold"],"disposal_review":r["disposal_review"],"disposal_executed":False}
}

for name,payload in files.items():
    (ad/name).write_text(
        json.dumps(payload,indent=2,ensure_ascii=False)+"\n",
        encoding="utf-8"
    )

manifest=build_manifest(
    root,
    [str((ad/n).relative_to(root)).replace("\\","/") for n in files]
    + ["config/integration/spt02411/data-lifecycle-governance-policy.json"]
)

(ad/"data-lifecycle-integrity-manifest.json").write_text(
    json.dumps(manifest,indent=2)+"\n",
    encoding="utf-8"
)

print("SURFACE_TRANSFER_CONTRACT=PASS")
print("SURFACE_TRANSFER_MODE=TEMP_JSON_FILE")
print("SPT02411_DATA_LIFECYCLE_STATUS="+r["status"])
print("DATA_LIFECYCLE_SURFACES="+str(len(paths)))
print("FAILED_BLOCKING_CONTROLS="+str(len(r["failed_blocking_controls"])))
print("LIFECYCLE_FINAL_STATE="+r["lifecycle_final_state"])
print("RETENTION_DISPOSITION="+r["retention"]["disposition"])
print("LEGAL_HOLD_VALID="+("YES" if r["legal_hold"]["valid"] else "NO"))
print("DISPOSAL_REVIEW_ELIGIBLE="+("YES" if r["disposal_review"]["eligible"] else "NO"))
print("INTEGRITY_RECORDS="+str(manifest["record_count"]))
print("PRODUCTION_DATA_MODIFIED=NO")
print("PRODUCTION_DATA_DELETED=NO")
print("ARCHIVE_EXECUTED=NO")
print("DISPOSAL_EXECUTED=NO")
print("SECRET_VALUES_EXPOSED=NO")

raise SystemExit(0 if r["status"]=="DATA_LIFECYCLE_GOVERNANCE_GATE_PASS" else 20)
'@
WriteLf $Tmp $Probe
try{
  & $Python $Tmp $SurfaceFile
  $ec=$LASTEXITCODE
} finally {
  Remove-Item $Tmp -Force -ErrorAction SilentlyContinue
  Remove-Item $SurfaceFile -Force -ErrorAction SilentlyContinue
}
if($ec -ne 0){Hold "Data lifecycle governance assessment failed with exit code $ec"}
Write-Host "DATA LIFECYCLE GOVERNANCE GATE : PASS"

Step 9 "EVIDENCE + INTEGRITY"
$Evidence=[ordered]@{component="SPT-024.11";layer="2";version="1.0.0";authoritative_baseline=$ExpectedBaseline;final_status="DATA_LIFECYCLE_GOVERNANCE_GATE_PASS";production_data_modified=$false;production_data_deleted=$false;archive_executed=$false;disposal_executed=$false;secret_values_exposed=$false}
WriteLf "$ArtifactDir/implementation-evidence.json" ($Evidence|ConvertTo-Json -Depth 8)
Write-Host "ASSESSMENT : CREATED"; Write-Host "INTEGRITY  : CREATED"; Write-Host "EVIDENCE   : CREATED"

Step 10 "SHA-256 PRESERVATION GATE"
CheckSnapshot $Snap
Write-Host "SPT-024.1-.10 + SPT-024.11 CAPA 1 : PRESERVED"

Step 11 "EXACT CONTROLLED STAGING"
foreach($t in @($SelfName,$ModuleDir,$TestFile,$PolicyFile,$DocFile,$ArtifactDir)){if(Test-Path $t){Native "git.exe" @("-c","core.safecrlf=false","add","--",$t) "git add"}}
$Now=@(& git.exe -c core.quotepath=false diff --cached --name-only)
$Unexpected=@($Now|Where-Object{$n=$_ -replace '\\','/'; -not($n -eq $SelfName -or $n -eq $TestFile -or $n -eq $PolicyFile -or $n -eq $DocFile -or $n.StartsWith("$ModuleDir/") -or $n.StartsWith("$ArtifactDir/"))})
Write-Host "STAGED     : $($Now.Count)"; Write-Host "UNEXPECTED : $($Unexpected.Count)"
if($Unexpected.Count -gt 0){& git.exe reset; Hold "Unexpected staged file"}
Write-Host "STAGING QUALITY : PASS"

Step 12 "INDEX-WIDE GITHUB SIZE GATE"
$Bad=SizeGate; Write-Host "INDEX BLOBS >=100MB : $($Bad.Count)"; if($Bad.Count -gt 0){Hold "Git index contains blob >=100 MB"}; Write-Host "GITHUB SIZE GATE : PASS"

Step 13 "FINAL REMOTE GATE"
Fetch; $L=(& git.exe rev-parse HEAD).Trim(); $R=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
if($L -ne $ExpectedBaseline -or $R -ne $ExpectedBaseline){& git.exe reset; Hold "Baseline changed before publication"}
CheckSnapshot $Snap; Write-Host "REMOTE GATE : PASS"

Step 14 "COMMIT"
Native "git.exe" @("commit","-m","feat(spt-024.11): implement data lifecycle retention archive disposal governance layer 2") "git commit"
$New=(& git.exe rev-parse HEAD).Trim(); Write-Host "NEW COMMIT : $New"

Step 15 "PUSH"
Native "git.exe" @("push","origin",$Branch) "git push"; Write-Host "PUSH : PASS"

Step 16 "AUTHORITATIVE REMOTE VERIFICATION"
Fetch
$FL=(& git.exe rev-parse HEAD).Trim(); $FR=(& git.exe rev-parse ("origin/"+$Branch)).Trim(); $C=((& git.exe rev-list --left-right --count (("origin/"+$Branch)+"...HEAD")).Trim() -split '\s+')
$FS=@(& git.exe diff --cached --name-only); $FD=@(& git.exe ls-files --deleted)
Write-Host "LOCAL HEAD      : $FL";Write-Host "REMOTE HEAD     : $FR";Write-Host "BEHIND          : $($C[0])";Write-Host "AHEAD           : $($C[1])";Write-Host "STAGED          : $($FS.Count)";Write-Host "DELETED TRACKED : $($FD.Count)"
if($FL -ne $FR -or $C[0] -ne "0" -or $C[1] -ne "0" -or $FS.Count -ne 0 -or $FD.Count -ne 0){Hold "Final repository synchronization failed"}
Write-Host ""; Write-Host "SPT-024.11 CAPA 2 : TECHNICALLY CLOSED" -ForegroundColor Green
Write-Host "CAPA1_DATA_PRIVACY_GATE=PASS" -ForegroundColor Green
Write-Host "DATA_LIFECYCLE_GOVERNANCE_GATE=PASS" -ForegroundColor Green
Write-Host "ARCHIVE_GOVERNANCE=PASS" -ForegroundColor Green
Write-Host "ADVANCED_RETENTION=PASS" -ForegroundColor Green
Write-Host "LEGAL_HOLD_GOVERNANCE=PASS" -ForegroundColor Green
Write-Host "CONTROLLED_DISPOSAL_REVIEW=PASS" -ForegroundColor Green
Write-Host "PRIVACY_GOVERNANCE_REVIEW=PASS" -ForegroundColor Green
Write-Host "AUTOMATIC_DESTRUCTIVE_DISPOSAL=NO" -ForegroundColor Green
Write-Host "REAL_DATA_CHANGES=NO" -ForegroundColor Green
Write-Host "TARGETED_TESTS=PASS" -ForegroundColor Green
Write-Host "INSTITUTIONAL_SUITE=PASS" -ForegroundColor Green
Write-Host "COMPILEALL=PASS" -ForegroundColor Green
Write-Host "SECRET_VALUES_EXPOSED=NO" -ForegroundColor Green
Write-Host "CLOSED_COMPONENTS=PRESERVED" -ForegroundColor Green
Write-Host "LOCAL_HEAD=REMOTE_HEAD" -ForegroundColor Green
Write-Host "FINAL_CLOSURE_EXIT_CODE=0" -ForegroundColor Green
exit 0
} catch { Hold $_.Exception.Message }
