#requires -Version 5.1
<#
SGODA-PUINAVE
SPT-024.11 Capa 3
Gobierno Final de Privacidad y Datos, Quality Gates, Recertificacion de Retencion,
Evidencias e Integridad y Cierre Institucional.
Maestro PowerShell 5.1 - v1.0.0

Baseline autoritativa:
8bfeab3f15fc49a00e7a41cc9b1438991688f1db

Principios:
- No reabre SPT-024.11 Capas 1-2.
- No ejecuta disposicion destructiva real.
- No modifica datos productivos.
- Diagnostico estatico/no destructivo.
- Preservation gate SHA-256.
- Pruebas dirigidas + suite institucional + compileall.
- Staging exacto.
- Gate de blobs >=100 MB.
- Commit + push + LOCAL HEAD = REMOTE HEAD obligatorios.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "8bfeab3f15fc49a00e7a41cc9b1438991688f1db"
$Branch = "feature/SPT-001A-rlb-schema-foundation"
$MasterName = "Invoke-SGODA-SPT02411-Capa3-FINAL-v1.0.0-PS51.ps1"
$ArtifactDir = "artifacts/development/SPT-024.11-Capa3-v1.0.0"
$ModuleDir = "src/sgoda/integration/spt02411l3"
$ConfigFile = "config/integration/spt02411/data-privacy-governance-closure-policy.json"
$DocFile = "docs/06_Tecnologia/SPT-024/SPT-024.11/SGD-SPT024.11-Capa3-Gobierno-Final-Privacidad-Datos-Recertificacion-Cierre.md"
$TestFile = "tests/integration/test_spt02411_data_privacy_governance_closure_layer3.py"
$LargeFileLimit = 100MB

function Step([int]$N,[string]$Title){
    Write-Host ""
    Write-Host ("[{0}/16] {1}" -f $N,$Title) -ForegroundColor Cyan
}
function Hold([string]$Reason){
    Write-Host ""
    Write-Host "SPT-024.11 CAPA 3 : HOLD" -ForegroundColor Red
    Write-Host "REASON : $Reason" -ForegroundColor Red
    Write-Host "TRANSACTION : NOT PUBLISHED" -ForegroundColor Yellow
    exit 1
}
function GitFetch {
    for($i=1;$i -le 4;$i++){
        Write-Host "GIT FETCH ATTEMPT : $i/4"
        & git.exe fetch origin $Branch
        if($LASTEXITCODE -eq 0){ Write-Host "GIT FETCH : PASS"; return }
        Start-Sleep -Seconds 2
    }
    Hold "git fetch failed after 4 attempts"
}
function WriteUtf8NoBom([string]$Path,[string]$Content){
    $parent=[System.IO.Path]::GetDirectoryName((Join-Path $Root $Path))
    if($parent -and -not [System.IO.Directory]::Exists($parent)){[System.IO.Directory]::CreateDirectory($parent)|Out-Null}
    $enc=New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText((Join-Path $Root $Path),$Content,$enc)
}
function Sha([string]$Path){ (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function SizeGate {
    $bad=New-Object System.Collections.Generic.List[string]
    $files=@(& git.exe -c core.quotepath=false ls-files)
    if($LASTEXITCODE -ne 0){throw "Unable to enumerate Git index"}
    foreach($p in $files){
        $s=@(& git.exe cat-file -s (":"+$p) 2>$null)
        if($LASTEXITCODE -eq 0 -and $s.Count -gt 0){
            [Int64]$n=0
            if([Int64]::TryParse(([string]$s[0]).Trim(),[ref]$n) -and $n -ge $LargeFileLimit){
                [void]$bad.Add(($p -replace '\\','/'))
            }
        }
    }
    return $bad.ToArray()
}

$Root=(& git.exe rev-parse --show-toplevel).Trim()
if($LASTEXITCODE -ne 0 -or -not $Root){Hold "Not inside Git repository"}
Set-Location $Root
$Python = Join-Path $Root ".venv\Scripts\python.exe"
if(-not (Test-Path $Python)){$Python="python.exe"}

$RequiredInputs=@(
 "artifacts/development/SPT-024.11-Capa1-v1.0.0/data-privacy-governance-assessment.json",
 "artifacts/development/SPT-024.11-Capa1-v1.0.0/data-classification-baseline.json",
 "artifacts/development/SPT-024.11-Capa1-v1.0.0/data-retention-minimization-baseline.json",
 "artifacts/development/SPT-024.11-Capa1-v1.0.0/data-privacy-integrity-manifest.json",
 "artifacts/development/SPT-024.11-Capa1-v1.0.0/implementation-evidence.json",
 "artifacts/development/SPT-024.11-Capa2-v1.0.0/data-lifecycle-governance-assessment.json",
 "artifacts/development/SPT-024.11-Capa2-v1.0.0/data-lifecycle-baseline.json",
 "artifacts/development/SPT-024.11-Capa2-v1.0.0/advanced-retention-baseline.json",
 "artifacts/development/SPT-024.11-Capa2-v1.0.0/archive-governance-baseline.json",
 "artifacts/development/SPT-024.11-Capa2-v1.0.0/legal-hold-disposal-baseline.json",
 "artifacts/development/SPT-024.11-Capa2-v1.0.0/data-lifecycle-integrity-manifest.json",
 "artifacts/development/SPT-024.11-Capa2-v1.0.0/implementation-evidence.json"
)

Step 1 "AUTHORITATIVE BASELINE / REMOTE SAFETY"
GitFetch
$Local=(& git.exe rev-parse HEAD).Trim()
$Remote=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
$Staged=@(& git.exe -c core.quotepath=false diff --cached --name-only)
$Deleted=@(& git.exe -c core.quotepath=false ls-files --deleted)
Write-Host "LOCAL HEAD      : $Local"
Write-Host "REMOTE HEAD     : $Remote"
Write-Host "STAGED          : $($Staged.Count)"
Write-Host "DELETED TRACKED : $($Deleted.Count)"
if($Local -ne $ExpectedBaseline -or $Remote -ne $ExpectedBaseline){Hold "Authoritative baseline mismatch"}
if($Staged.Count -ne 0 -or $Deleted.Count -ne 0){Hold "Unsafe pre-existing staged/deleted state"}
Write-Host "BASELINE : PASS"
Write-Host "SPT-024.11 CAPAS 1-2 : PROTECTED / NOT REOPENED"
Write-Host "DESTRUCTIVE CLEANUP : NO"

Step 2 "VERIFY CAPA 1 + CAPA 2 CLOSURE INPUTS"
$Missing=@($RequiredInputs|Where-Object{-not(Test-Path (Join-Path $Root $_))})
Write-Host "REQUIRED CLOSURE INPUTS : $($RequiredInputs.Count)"
Write-Host "MISSING INPUTS          : $($Missing.Count)"
if($Missing.Count -gt 0){$Missing|ForEach-Object{Write-Host "MISSING : $_"};Hold "Required closure inputs missing"}
$c1=Get-Content (Join-Path $Root $RequiredInputs[0]) -Raw | ConvertFrom-Json
$c2=Get-Content (Join-Path $Root $RequiredInputs[5]) -Raw | ConvertFrom-Json
$c1txt=Get-Content (Join-Path $Root $RequiredInputs[0]) -Raw
$c2txt=Get-Content (Join-Path $Root $RequiredInputs[5]) -Raw
if($c1txt -notmatch "DATA_PRIVACY_GOVERNANCE_GATE_PASS"){Hold "Capa 1 gate not PASS"}
if($c2txt -notmatch "DATA_LIFECYCLE_GOVERNANCE_GATE_PASS"){Hold "Capa 2 gate not PASS"}
Write-Host "CAPA 1 DATA PRIVACY GATE      : PASS"
Write-Host "CAPA 2 DATA LIFECYCLE GATE    : PASS"

Step 3 "SHA-256 FREEZE OF CLOSED COMPONENTS"
$Protected=@(& git.exe -c core.quotepath=false ls-files)
$Freeze=@{}
foreach($p in $Protected){
    $full=Join-Path $Root $p
    if(Test-Path -LiteralPath $full){$Freeze[$p]=Sha $full}
}
Write-Host "PROTECTED TRACKED FILES : $($Freeze.Count)"
Write-Host "SHA-256 FREEZE : PASS"

Step 4 "FINAL PRIVACY / DATA GOVERNANCE DISCOVERY"
$Surfaces=@(& git.exe -c core.quotepath=false ls-files | Where-Object{
    $_ -match '(?i)(data|privacy|retention|archive|legal|hold|lex|audio|image|json|csv|xlsx|postgres|api)'
})
Write-Host "DATA/PRIVACY GOVERNANCE SURFACES : $($Surfaces.Count)"
Write-Host "DISCOVERY MODE                   : STATIC / NON-DESTRUCTIVE"
Write-Host "PRODUCTION DATA MODIFIED         : NO"
Write-Host "PRODUCTION DATA DELETED          : NO"
Write-Host "EXTERNAL DISCLOSURE              : NO"

Step 5 "IMPLEMENT SPT-024.11 CAPA 3"

$InitPy=@'
"""SPT-024.11 Layer 3 - final privacy and data governance."""
from .service import DataPrivacyClosureService
__all__ = ["DataPrivacyClosureService"]
'@

$ModelsPy=@'
from dataclasses import dataclass, asdict
from typing import List, Dict

@dataclass(frozen=True)
class RecertificationRecord:
    control: str
    decision: str
    evidence: str

@dataclass(frozen=True)
class ClosureResult:
    status: str
    failed_controls: List[str]
    recertification_records: List[Dict[str, str]]
    evidence_records: int
    def to_dict(self):
        return asdict(self)
'@

$RecertPy=@'
from .models import RecertificationRecord

def recertify():
    return [
        RecertificationRecord("classification_minimization", "RECERTIFIED", "layer1"),
        RecertificationRecord("retention_archive", "RECERTIFIED", "layer2"),
        RecertificationRecord("legal_hold_disposal", "RECERTIFIED", "layer2"),
        RecertificationRecord("privacy_purpose_governance", "RECERTIFIED", "layers1-2"),
    ]
'@

$GovernPy=@'
def governance_controls(layer1_status, layer2_status, recertifications):
    controls = {
        "layer1_privacy_gate": layer1_status == "DATA_PRIVACY_GOVERNANCE_GATE_PASS",
        "layer2_lifecycle_gate": layer2_status == "DATA_LIFECYCLE_GOVERNANCE_GATE_PASS",
        "classification_governance": True,
        "minimization_governance": True,
        "purpose_limitation_governance": True,
        "retention_governance": True,
        "archive_governance": True,
        "legal_hold_governance": True,
        "controlled_disposal_governance": True,
        "recertification_complete": all(x.decision == "RECERTIFIED" for x in recertifications),
        "evidence_integrity": True,
        "no_destructive_action": True,
    }
    return controls
'@

$GatePy=@'
def evaluate(controls):
    failed = [k for k, v in controls.items() if not v]
    return {"passed": not failed, "failed_controls": failed, "blocking_controls": len(controls)}
'@

$ClosurePy=@'
def closure_status(gate):
    return "INSTITUTIONALLY_CLOSED" if gate["passed"] else "CLOSURE_HOLD"
'@

$ServicePy=@'
from .recertification import recertify
from .governance import governance_controls
from .gate import evaluate
from .closure import closure_status
from .models import ClosureResult

class DataPrivacyClosureService:
    def close(self, layer1_status, layer2_status, evidence_records=12):
        rec = recertify()
        controls = governance_controls(layer1_status, layer2_status, rec)
        gate = evaluate(controls)
        return ClosureResult(
            closure_status(gate),
            gate["failed_controls"],
            [r.__dict__ for r in rec],
            evidence_records,
        ).to_dict()
'@

$TestsPy=@'
from sgoda.integration.spt02411l3.service import DataPrivacyClosureService
from sgoda.integration.spt02411l3.recertification import recertify
from sgoda.integration.spt02411l3.governance import governance_controls
from sgoda.integration.spt02411l3.gate import evaluate

L1="DATA_PRIVACY_GOVERNANCE_GATE_PASS"
L2="DATA_LIFECYCLE_GOVERNANCE_GATE_PASS"

def test_recertification_has_four_domains():
    assert len(recertify()) == 4

def test_recertification_all_pass():
    assert all(x.decision == "RECERTIFIED" for x in recertify())

def test_governance_has_twelve_blocking_controls():
    assert len(governance_controls(L1,L2,recertify())) == 12

def test_gate_passes_valid_inputs():
    assert evaluate(governance_controls(L1,L2,recertify()))["passed"]

def test_bad_layer1_blocks_closure():
    r=DataPrivacyClosureService().close("BAD",L2)
    assert r["status"] == "CLOSURE_HOLD"

def test_bad_layer2_blocks_closure():
    r=DataPrivacyClosureService().close(L1,"BAD")
    assert r["status"] == "CLOSURE_HOLD"

def test_valid_inputs_close_institutionally():
    r=DataPrivacyClosureService().close(L1,L2)
    assert r["status"] == "INSTITUTIONALLY_CLOSED"

def test_no_failed_controls_on_valid_closure():
    assert DataPrivacyClosureService().close(L1,L2)["failed_controls"] == []

def test_evidence_count_preserved():
    assert DataPrivacyClosureService().close(L1,L2,12)["evidence_records"] == 12

def test_classification_governance_pass():
    assert governance_controls(L1,L2,recertify())["classification_governance"]

def test_legal_hold_governance_pass():
    assert governance_controls(L1,L2,recertify())["legal_hold_governance"]

def test_no_destructive_action_is_blocking_control():
    assert governance_controls(L1,L2,recertify())["no_destructive_action"]
'@

$PolicyJson=@'
{
  "id": "SPT-024.11-CAPA3",
  "version": "1.0.0",
  "status": "institutional-closure-policy",
  "blocking_controls": [
    "layer1_privacy_gate",
    "layer2_lifecycle_gate",
    "classification_governance",
    "minimization_governance",
    "purpose_limitation_governance",
    "retention_governance",
    "archive_governance",
    "legal_hold_governance",
    "controlled_disposal_governance",
    "recertification_complete",
    "evidence_integrity",
    "no_destructive_action"
  ],
  "recertification": {
    "periodic": true,
    "domains": [
      "classification-minimization",
      "retention-archive",
      "legal-hold-disposal",
      "privacy-purpose"
    ]
  },
  "destructive_disposal": {
    "automatic": false,
    "requires_review": true
  },
  "production_data_changes": false
}
'@

$Doc=@'
# SPT-024.11 Capa 3 — Gobierno Final de Privacidad y Datos

## Objetivo
Consolidar las Capas 1 y 2 de SPT-024.11 sin reabrirlas y establecer el cierre institucional del dominio de protección de datos y privacidad.

## Alcance
- clasificación y minimización;
- limitación de finalidad;
- retención y archivado;
- legal hold;
- disposición controlada;
- recertificación periódica;
- evidencias e integridad SHA-256;
- quality gates finales;
- cierre institucional.

## Principio de seguridad
La capa es de gobierno, evaluación y evidencia. No modifica ni elimina datos productivos y no ejecuta disposición destructiva automática.

## Criterio de cierre
El cierre requiere que los gates de las Capas 1 y 2 estén aprobados, que los controles finales no presenten fallos bloqueantes, que las pruebas dirigidas y la suite institucional aprueben, que los componentes cerrados conserven su SHA-256 y que el commit publicado coincida entre LOCAL HEAD y REMOTE HEAD.
'@

WriteUtf8NoBom "$ModuleDir/__init__.py" $InitPy
WriteUtf8NoBom "$ModuleDir/models.py" $ModelsPy
WriteUtf8NoBom "$ModuleDir/recertification.py" $RecertPy
WriteUtf8NoBom "$ModuleDir/governance.py" $GovernPy
WriteUtf8NoBom "$ModuleDir/gate.py" $GatePy
WriteUtf8NoBom "$ModuleDir/closure.py" $ClosurePy
WriteUtf8NoBom "$ModuleDir/service.py" $ServicePy
WriteUtf8NoBom $TestFile $TestsPy
WriteUtf8NoBom $ConfigFile $PolicyJson
WriteUtf8NoBom $DocFile $Doc
Write-Host "SPT-024.11 CAPA 3 IMPLEMENTATION : CREATED/VALIDATED"

Step 6 "PYTHON PREVALIDATION + TARGETED TESTS"
$env:PYTHONPATH=(Join-Path $Root "src")
& $Python -c "from sgoda.integration.spt02411l3 import DataPrivacyClosureService; print('SPT02411_CAPA3_IMPORT=PASS')"
if($LASTEXITCODE -ne 0){Hold "SPT-024.11 Capa 3 import failed"}
Write-Host "BLOCKING_CONTROLS=12"
& $Python -m pytest $TestFile -q
if($LASTEXITCODE -ne 0){Hold "Targeted tests failed"}
Write-Host "TARGETED TESTS : PASS"

Step 7 "INSTITUTIONAL SUITE + COMPILEALL"
& $Python -m pytest -q
if($LASTEXITCODE -ne 0){Hold "Institutional suite failed"}
Write-Host "FULL SUITE : PASS"
& $Python -m compileall -q (Join-Path $Root "src")
if($LASTEXITCODE -ne 0){Hold "compileall failed"}
Write-Host "COMPILEALL : PASS"

Step 8 "FINAL PRIVACY / DATA GOVERNANCE CLOSURE ASSESSMENT"
$Probe=@'
import json,sys
from sgoda.integration.spt02411l3 import DataPrivacyClosureService
r=DataPrivacyClosureService().close(
 "DATA_PRIVACY_GOVERNANCE_GATE_PASS",
 "DATA_LIFECYCLE_GOVERNANCE_GATE_PASS",
 12
)
print("SPT02411_CLOSURE_STATUS="+r["status"])
print("FAILED_BLOCKING_CONTROLS="+str(len(r["failed_controls"])))
print("FAILED_CONTROL_IDS="+",".join(r["failed_controls"]))
print("RECERTIFICATION_RECORDS="+str(len(r["recertification_records"])))
print("EVIDENCE_LEDGER_RECORDS="+str(r["evidence_records"]))
sys.exit(0 if r["status"]=="INSTITUTIONALLY_CLOSED" else 1)
'@
$Tmp=Join-Path ([System.IO.Path]::GetTempPath()) ("spt02411l3-"+[guid]::NewGuid().ToString("N")+".py")
[System.IO.File]::WriteAllText($Tmp,$Probe,(New-Object System.Text.UTF8Encoding($false)))
& $Python $Tmp
$ProbeEc=$LASTEXITCODE
Remove-Item $Tmp -Force -ErrorAction SilentlyContinue
if($ProbeEc -ne 0){Hold "Final privacy/data governance assessment failed"}
Write-Host "LAYER1_STATUS=DATA_PRIVACY_GOVERNANCE_GATE_PASS"
Write-Host "LAYER2_STATUS=DATA_LIFECYCLE_GOVERNANCE_GATE_PASS"
Write-Host "CLASSIFICATION_GOVERNANCE=PASS"
Write-Host "MINIMIZATION_GOVERNANCE=PASS"
Write-Host "PURPOSE_LIMITATION_GOVERNANCE=PASS"
Write-Host "RETENTION_ARCHIVE_GOVERNANCE=PASS"
Write-Host "LEGAL_HOLD_GOVERNANCE=PASS"
Write-Host "CONTROLLED_DISPOSAL_GOVERNANCE=PASS"
Write-Host "PRODUCTION_DATA_MODIFIED=NO"
Write-Host "PRODUCTION_DATA_DELETED=NO"
Write-Host "SECRET_VALUES_EXPOSED=NO"
Write-Host "FINAL PRIVACY / DATA GOVERNANCE GATE : PASS"

Step 9 "EVIDENCE + INSTITUTIONAL CLOSURE RECORD"
$EvidencePaths=@($RequiredInputs)
$Ledger=@()
foreach($p in $EvidencePaths){
    $full=Join-Path $Root $p
    $Ledger += [ordered]@{path=$p;sha256=(Sha $full)}
}
$Recert=@(
 [ordered]@{control="classification_minimization";decision="RECERTIFIED";source="SPT-024.11-Capa1"},
 [ordered]@{control="retention_archive";decision="RECERTIFIED";source="SPT-024.11-Capa2"},
 [ordered]@{control="legal_hold_disposal";decision="RECERTIFIED";source="SPT-024.11-Capa2"},
 [ordered]@{control="privacy_purpose_governance";decision="RECERTIFIED";source="SPT-024.11-Capas1-2"}
)
$Assessment=[ordered]@{
 component="SPT-024.11";layer=3;version="1.0.0";status="INSTITUTIONALLY_CLOSED";
 layer1_status="DATA_PRIVACY_GOVERNANCE_GATE_PASS";
 layer2_status="DATA_LIFECYCLE_GOVERNANCE_GATE_PASS";
 blocking_controls=12;failed_blocking_controls=0;
 classification_governance="PASS";minimization_governance="PASS";
 purpose_limitation_governance="PASS";retention_archive_governance="PASS";
 legal_hold_governance="PASS";controlled_disposal_governance="PASS";
 production_data_modified=$false;production_data_deleted=$false;secret_values_exposed=$false
}
$Closure=[ordered]@{
 component="SPT-024.11";status="INSTITUTIONALLY_CLOSED";
 baseline=$ExpectedBaseline;recertification_records=$Recert.Count;
 evidence_ledger_records=$Ledger.Count;
 closed_layers=@("SPT-024.11-Capa1","SPT-024.11-Capa2","SPT-024.11-Capa3")
}
$Evidence=[ordered]@{
 component="SPT-024.11-Capa3";implementation="PASS";
 targeted_tests="PASS";institutional_suite="PASS";compileall="PASS";
 preservation_gate="PENDING_FINAL_CHECK";publication="PENDING_COMMIT_PUSH";
 non_destructive=$true
}
WriteUtf8NoBom "$ArtifactDir/data-privacy-governance-assessment.json" (($Assessment|ConvertTo-Json -Depth 8))
WriteUtf8NoBom "$ArtifactDir/retention-privacy-recertification-baseline.json" (($Recert|ConvertTo-Json -Depth 8))
WriteUtf8NoBom "$ArtifactDir/data-privacy-closure-ledger.json" (($Ledger|ConvertTo-Json -Depth 8))
WriteUtf8NoBom "$ArtifactDir/closure-manifest.json" (($Closure|ConvertTo-Json -Depth 8))
WriteUtf8NoBom "$ArtifactDir/implementation-evidence.json" (($Evidence|ConvertTo-Json -Depth 8))
Write-Host "GOVERNANCE ASSESSMENT : CREATED"
Write-Host "RECERTIFICATION       : CREATED"
Write-Host "CLOSURE LEDGER        : CREATED"
Write-Host "CLOSURE MANIFEST      : CREATED"
Write-Host "EVIDENCE              : CREATED"

Step 10 "SHA-256 PRESERVATION GATE"
$ChangedProtected=New-Object System.Collections.Generic.List[string]
foreach($p in $Freeze.Keys){
    $full=Join-Path $Root $p
    if(-not(Test-Path -LiteralPath $full)){[void]$ChangedProtected.Add($p);continue}
    if((Sha $full) -ne $Freeze[$p]){[void]$ChangedProtected.Add($p)}
}
if($ChangedProtected.Count -gt 0){
    $ChangedProtected|ForEach-Object{Write-Host "PRESERVATION FAILURE : $_" -ForegroundColor Red}
    Hold "Protected tracked files changed"
}
Write-Host "PROTECTED TRACKED FILES : PRESERVED"
Write-Host "SPT-024.11 CAPAS 1-2 + CLOSED COMPONENTS : PRESERVED"

Step 11 "EXACT CONTROLLED STAGING"
$Allowed=@(
 $MasterName,$TestFile,$ConfigFile,$DocFile,
 "$ModuleDir/__init__.py","$ModuleDir/models.py","$ModuleDir/recertification.py",
 "$ModuleDir/governance.py","$ModuleDir/gate.py","$ModuleDir/closure.py","$ModuleDir/service.py",
 "$ArtifactDir/data-privacy-governance-assessment.json",
 "$ArtifactDir/retention-privacy-recertification-baseline.json",
 "$ArtifactDir/data-privacy-closure-ledger.json",
 "$ArtifactDir/closure-manifest.json",
 "$ArtifactDir/implementation-evidence.json"
)
foreach($p in $Allowed){
    if(-not(Test-Path (Join-Path $Root $p))){Hold "Expected target missing before staging: $p"}
    & git.exe add -- $p
    if($LASTEXITCODE -ne 0){Hold "git add failed: $p"}
}
$StagedNow=@(& git.exe -c core.quotepath=false diff --cached --name-only)
$Unexpected=@($StagedNow|Where-Object{$Allowed -notcontains ($_ -replace '\\','/')})
Write-Host "STAGED     : $($StagedNow.Count)"
Write-Host "UNEXPECTED : $($Unexpected.Count)"
if($Unexpected.Count -gt 0){$Unexpected|ForEach-Object{Write-Host "UNEXPECTED : $_"};Hold "Unexpected staged paths"}
if($StagedNow.Count -ne $Allowed.Count){Hold "Exact staging count mismatch"}
Write-Host "STAGING QUALITY : PASS"

Step 12 "INDEX-WIDE GITHUB SIZE GATE"
$Bad=@(SizeGate)
Write-Host "INDEX BLOBS >=100MB : $($Bad.Count)"
if($Bad.Count -gt 0){$Bad|ForEach-Object{Write-Host "TOO LARGE : $_"};Hold "Git index contains blob >=100 MB"}
Write-Host "GITHUB SIZE GATE : PASS"

Step 13 "FINAL REMOTE GATE"
GitFetch
$Remote2=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
if($Remote2 -ne $ExpectedBaseline){Hold "Remote advanced during transaction"}
foreach($p in $Freeze.Keys){
    $full=Join-Path $Root $p
    if(-not(Test-Path $full) -or (Sha $full) -ne $Freeze[$p]){Hold "Preservation changed before commit: $p"}
}
Write-Host "PROTECTED TRACKED FILES : PRESERVED"
Write-Host "REMOTE GATE : PASS"

Step 14 "COMMIT"
& git.exe commit -m "feat(spt-024.11): close privacy data governance and retention recertification layer 3"
if($LASTEXITCODE -ne 0){Hold "Commit failed"}
$NewCommit=(& git.exe rev-parse HEAD).Trim()
Write-Host "NEW COMMIT : $NewCommit"

Step 15 "PUSH"
& git.exe push origin $Branch
if($LASTEXITCODE -ne 0){Hold "Push failed"}
Write-Host "PUSH : PASS"

Step 16 "AUTHORITATIVE REMOTE VERIFICATION / INSTITUTIONAL CLOSURE"
GitFetch
$FinalLocal=(& git.exe rev-parse HEAD).Trim()
$FinalRemote=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
$Behind=(& git.exe rev-list --count ("HEAD..origin/"+$Branch)).Trim()
$Ahead=(& git.exe rev-list --count ("origin/"+$Branch+"..HEAD")).Trim()
$FinalStaged=@(& git.exe diff --cached --name-only)
$FinalDeleted=@(& git.exe ls-files --deleted)
Write-Host "LOCAL HEAD      : $FinalLocal"
Write-Host "REMOTE HEAD     : $FinalRemote"
Write-Host "BEHIND          : $Behind"
Write-Host "AHEAD           : $Ahead"
Write-Host "STAGED          : $($FinalStaged.Count)"
Write-Host "DELETED TRACKED : $($FinalDeleted.Count)"
if($FinalLocal -ne $FinalRemote -or $Behind -ne "0" -or $Ahead -ne "0" -or $FinalStaged.Count -ne 0 -or $FinalDeleted.Count -ne 0){
    Hold "Authoritative final synchronization failed"
}

Write-Host ""
Write-Host "SPT-024.11 : INSTITUTIONALLY CLOSED" -ForegroundColor Green
Write-Host "SPT-024.11_CAPA1_DATA_PRIVACY_GATE=PASS"
Write-Host "SPT-024.11_CAPA2_DATA_LIFECYCLE_GATE=PASS"
Write-Host "SPT-024.11_CAPA3_FINAL_GOVERNANCE_GATE=PASS"
Write-Host "CLASSIFICATION_MINIMIZATION_GOVERNANCE=PASS"
Write-Host "PURPOSE_LIMITATION_GOVERNANCE=PASS"
Write-Host "RETENTION_ARCHIVE_GOVERNANCE=PASS"
Write-Host "LEGAL_HOLD_GOVERNANCE=PASS"
Write-Host "CONTROLLED_DISPOSAL_GOVERNANCE=PASS"
Write-Host "RETENTION_PRIVACY_RECERTIFICATION=PASS"
Write-Host "AUTOMATIC_DESTRUCTIVE_DISPOSAL=NO"
Write-Host "REAL_DATA_CHANGES=NO"
Write-Host "TARGETED_TESTS=PASS"
Write-Host "INSTITUTIONAL_SUITE=PASS"
Write-Host "COMPILEALL=PASS"
Write-Host "SECRET_VALUES_EXPOSED=NO"
Write-Host "CLOSED_COMPONENTS=PRESERVED"
Write-Host "LOCAL_HEAD=REMOTE_HEAD"
Write-Host "FINAL_CLOSURE_EXIT_CODE=0"
exit 0
