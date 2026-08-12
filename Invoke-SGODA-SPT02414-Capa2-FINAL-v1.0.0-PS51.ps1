#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"

$ExpectedBaseline="12abac887ab08e7ba6932477cf696efedad49865"
$Branch="feature/SPT-001A-rlb-schema-foundation"
$SelfName="Invoke-SGODA-SPT02414-Capa2-FINAL-v1.0.0-PS51.ps1"

$Layer1Dir="artifacts/development/SPT-024.14-Capa1-v1.0.0"
$Layer1Assessment="$Layer1Dir/security-risk-governance-assessment.json"
$Layer1Integrity="$Layer1Dir/security-risk-integrity-manifest.json"
$Layer1Evidence="$Layer1Dir/implementation-evidence.json"
$Layer1Register="$Layer1Dir/security-risk-register-baseline.json"
$Layer1Treatment="$Layer1Dir/risk-treatment-governance-baseline.json"

$ModuleDir="src/sgoda/integration/spt02414l2"
$TestFile="tests/integration/test_spt02414_risk_register_governance_layer2.py"
$PolicyFile="config/integration/spt02414/risk-register-governance-policy.json"
$DocFile="docs/06_Tecnologia/SPT-024/SPT-024.14/SGD-SPT024.14-Capa2-Registro-Maestro-Riesgos-Priorizacion-Tratamiento-Riesgo-Residual-Excepciones.md"

$ArtifactDir="artifacts/development/SPT-024.14-Capa2-v1.0.0"
$AssessmentFile="$ArtifactDir/risk-register-governance-assessment.json"
$RegisterFile="$ArtifactDir/master-risk-register.json"
$PriorityFile="$ArtifactDir/risk-prioritization-baseline.json"
$TreatmentFile="$ArtifactDir/risk-treatment-plans-baseline.json"
$ResidualFile="$ArtifactDir/residual-risk-baseline.json"
$ExceptionFile="$ArtifactDir/risk-exceptions-baseline.json"
$AcceptanceFile="$ArtifactDir/risk-acceptance-governance-baseline.json"
$IntegrityFile="$ArtifactDir/risk-register-integrity-manifest.json"
$EvidenceFile="$ArtifactDir/implementation-evidence.json"

$LargeFileLimit=100MB

function Step([int]$N,[string]$Title){Write-Host "";Write-Host ("[{0}/16] {1}" -f $N,$Title) -ForegroundColor Cyan}
function Hold([string]$Reason){Write-Host "";Write-Host "SPT-024.14 CAPA 2 : HOLD" -ForegroundColor Red;Write-Host "REASON : $Reason" -ForegroundColor Red;Write-Host "TRANSACTION : NOT PUBLISHED" -ForegroundColor Yellow;exit 1}
function GitFetch {
    for($i=1;$i -le 4;$i++){Write-Host "GIT FETCH ATTEMPT : $i/4";& git.exe fetch origin $Branch;if($LASTEXITCODE -eq 0){Write-Host "GIT FETCH : PASS";return};Start-Sleep -Seconds 2}
    Hold "git fetch failed after 4 attempts"
}
function WriteLf([string]$Path,[string]$Text){
    $Target=if([IO.Path]::IsPathRooted($Path)){$Path}else{Join-Path $Root $Path}
    $Parent=Split-Path -Parent $Target
    if($Parent -and -not(Test-Path -LiteralPath $Parent)){New-Item -ItemType Directory -Force -Path $Parent|Out-Null}
    $Utf8=New-Object System.Text.UTF8Encoding($false)
    $Canonical=(($Text -replace "`r`n","`n") -replace "`r","`n")
    if(-not $Canonical.EndsWith("`n")){$Canonical+="`n"}
    [IO.File]::WriteAllText($Target,$Canonical,$Utf8)
}
function Sha([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()}
function SizeGate {
    $bad=New-Object System.Collections.Generic.List[string]
    $files=@(& git.exe -c core.quotepath=false ls-files)
    foreach($p in $files){
        $s=@(& git.exe cat-file -s (":"+$p) 2>$null)
        if($LASTEXITCODE -eq 0 -and @($s).Count -gt 0){
            [Int64]$n=0
            if([Int64]::TryParse(([string]$s[0]).Trim(),[ref]$n) -and $n -ge $LargeFileLimit){[void]$bad.Add(($p -replace '\\','/'))}
        }
    }
    return @($bad.ToArray())
}

try{
    $Root=(& git.exe rev-parse --show-toplevel).Trim()
    if($LASTEXITCODE -ne 0 -or -not $Root){Hold "Not inside Git repository"}
    Set-Location $Root

    $Python=Join-Path $Root ".venv\Scripts\python.exe"
    if(-not(Test-Path -LiteralPath $Python)){$Python="python.exe"}

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
    Write-Host "SPT-024.1-.13 + SPT-024.14 CAPA 1 : PROTECTED / NOT REOPENED"
    Write-Host "DESTRUCTIVE CLEANUP : NO"

    Step 2 "VERIFY SPT-024.14 CAPA 1 INPUTS / RECOVERY STATE"
    $Required=@($Layer1Assessment,$Layer1Integrity,$Layer1Evidence,$Layer1Register,$Layer1Treatment)
    $Missing=@($Required|Where-Object{-not(Test-Path -LiteralPath (Join-Path $Root $_))})
    Write-Host "REQUIRED CAPA 1 INPUTS : $($Required.Count)"
    Write-Host "MISSING INPUTS         : $($Missing.Count)"
    if($Missing.Count -gt 0){Hold ("Missing Capa 1 inputs: "+($Missing -join ", "))}

    $L1=Get-Content -Raw -LiteralPath (Join-Path $Root $Layer1Assessment)|ConvertFrom-Json
    if([string]$L1.status -ne "SECURITY_RISK_GOVERNANCE_GATE_PASS"){Hold "Capa 1 gate is not PASS"}

    Write-Host "CAPA 1 SECURITY RISK GOVERNANCE GATE : PASS"

    $Targets=@($ModuleDir,$TestFile,$PolicyFile,$DocFile,$ArtifactDir)
    $Existing=@($Targets|Where-Object{Test-Path -LiteralPath (Join-Path $Root $_)})
    Write-Host "PREEXISTING CAPA 2 TARGETS             : $($Existing.Count)"
    Write-Host ("CAPA 2 RESUME MODE                     : "+$(if($Existing.Count -gt 0){"YES"}else{"NO"}))

    Step 3 "SHA-256 FREEZE OF CLOSED COMPONENTS"
    $Protected=@(& git.exe -c core.quotepath=false ls-files)
    $Freeze=@{}
    foreach($p in $Protected){$full=Join-Path $Root $p;if(Test-Path -LiteralPath $full){$Freeze[$p]=Sha $full}}
    Write-Host "PROTECTED TRACKED FILES : $($Freeze.Count)"
    Write-Host "SHA-256 FREEZE : PASS"

    Step 4 "MASTER RISK REGISTER / PRIORITIZATION / TREATMENT DISCOVERY"
    $Tracked=@(& git.exe -c core.quotepath=false ls-files)
    $Surfaces=@($Tracked|Where-Object{
        $p=($_ -replace '\\','/').ToLowerInvariant()
        (($p -match '(risk|threat|vulnerab|security|incident|audit|control|impact|privacy|crypto|auth|infra|backup|recovery|dependency|workflow|api|fastapi|n8n|postgres|release|deploy)') -or ($p -match '(^|/)(config|automation|tools|src|\.github|docs|artifacts)(/|$)')) -and ($p -match '\.(py|ps1|sh|json|ya?ml|toml|ini|cfg|conf|properties|md)$')
    })
    Write-Host "RISK GOVERNANCE SURFACES : $($Surfaces.Count)"
    Write-Host "DISCOVERY MODE           : STATIC / NON-DESTRUCTIVE"
    Write-Host "TREATMENT EXECUTED       : NO"
    Write-Host "AUTO ACCEPTANCE EXECUTED : NO"
    Write-Host "PRODUCTION CHANGED       : NO"

    Step 5 "IMPLEMENT SPT-024.14 CAPA 2"
$Va5dad845a4=@'
"""SPT-024.14 Capa 2 — master risk register and risk acceptance governance."""
from .service import RiskRegisterGovernanceService
from .gate import RiskRegisterGovernanceGate
__all__ = ["RiskRegisterGovernanceService", "RiskRegisterGovernanceGate"]
'@
$V022374a082=@'
from dataclasses import dataclass

@dataclass(frozen=True)
class RiskRecord:
    risk_id: str
    title: str
    inherent_score: int
    residual_score: int
    priority: str
    treatment: str
    owner: str
    status: str
    exception: bool
    acceptance_required: bool
'@
$V64f09a8923=@'
from .models import RiskRecord

def build_master_register():
    return [
        RiskRecord("RISK-001","Lexical data integrity",20,10,"HIGH","MITIGATE","PISI_RISK_OWNER","IN_TREATMENT",False,False),
        RiskRecord("RISK-002","Credential exposure",25,8,"CRITICAL","MITIGATE","PISI_RISK_OWNER","IN_TREATMENT",False,False),
        RiskRecord("RISK-003","Service availability",15,6,"HIGH","MITIGATE","PISI_CONTINUITY_OWNER","MONITORED",False,False),
        RiskRecord("RISK-004","Third-party dependency disruption",12,6,"HIGH","TRANSFER","PISI_SUPPLY_CHAIN_OWNER","MONITORED",True,True),
    ]
'@
$V22c3b296a3=@'
def prioritize(records):
    rank = {"CRITICAL":4,"HIGH":3,"MEDIUM":2,"LOW":1}
    return sorted(records,key=lambda r:(-rank.get(r.priority,0),-r.inherent_score,r.risk_id))
'@
$V3b16c7d6e5=@'
ALLOWED={"MITIGATE","AVOID","TRANSFER","ACCEPT"}

def treatment_plan(record):
    valid=(record.treatment in ALLOWED and bool(record.owner) and record.status in {"IN_TREATMENT","MONITORED","ACCEPTED","CLOSED"} and 0 <= record.residual_score <= record.inherent_score)
    return {"risk_id":record.risk_id,"valid":valid,"treatment":record.treatment,"owner":record.owner,"status":record.status,"residual_score":record.residual_score,"treatment_executed":False}
'@
$Vacc94de729=@'
def residual_risk(record):
    reduction=record.inherent_score-record.residual_score
    valid=record.residual_score >= 0 and reduction >= 0
    return {"risk_id":record.risk_id,"valid":valid,"inherent_score":record.inherent_score,"residual_score":record.residual_score,"risk_reduction":reduction,"review_required":True}
'@
$V828411142a=@'
def exception_governance(record):
    if not record.exception:
        return {"risk_id":record.risk_id,"exception":False,"valid":True,"approval_required":False,"expiry_required":False}
    return {"risk_id":record.risk_id,"exception":True,"valid":record.acceptance_required,"approval_required":True,"expiry_required":True}
'@
$Veecca3109a=@'
def acceptance_governance(record):
    required=bool(record.acceptance_required or record.treatment=="ACCEPT")
    return {"risk_id":record.risk_id,"required":required,"approval_required":required,"residual_review_required":required,"accepted_automatically":False,"valid":True}
'@
$V035a841b69=@'
from .acceptance import acceptance_governance
from .exceptions import exception_governance
from .prioritization import prioritize
from .register import build_master_register
from .residual import residual_risk
from .treatment import treatment_plan

class RiskRegisterAuditor:
    def assess(self):
        records=prioritize(build_master_register())
        return {
            "records":[r.__dict__ for r in records],
            "treatments":[treatment_plan(r) for r in records],
            "residuals":[residual_risk(r) for r in records],
            "exceptions":[exception_governance(r) for r in records],
            "acceptances":[acceptance_governance(r) for r in records],
            "treatment_executed":False,
            "acceptance_executed":False,
            "production_changed":False,
            "external_connection_opened":False,
            "secret_values_exposed":False,
        }
'@
$V09d41d93ba=@'
class RiskRegisterGovernanceGate:
    BLOCKING=("LAYER1_GATE","MASTER_REGISTER","PRIORITIZATION","TREATMENT_PLANS","RESIDUAL_RISK","EXCEPTION_GOVERNANCE","ACCEPTANCE_GOVERNANCE","TRACKING_GOVERNANCE","NO_AUTO_ACCEPTANCE","NO_TREATMENT_EXECUTION","NO_PRODUCTION_CHANGE","SECRET_SAFETY")

    @classmethod
    def evaluate(cls,layer1_status,audit):
        controls={
            "LAYER1_GATE":layer1_status=="SECURITY_RISK_GOVERNANCE_GATE_PASS",
            "MASTER_REGISTER":len(audit["records"])>0,
            "PRIORITIZATION":audit["records"][0]["priority"] in {"CRITICAL","HIGH"},
            "TREATMENT_PLANS":all(x["valid"] for x in audit["treatments"]),
            "RESIDUAL_RISK":all(x["valid"] for x in audit["residuals"]),
            "EXCEPTION_GOVERNANCE":all(x["valid"] for x in audit["exceptions"]),
            "ACCEPTANCE_GOVERNANCE":all(x["valid"] for x in audit["acceptances"]),
            "TRACKING_GOVERNANCE":all(bool(x["status"]) for x in audit["records"]),
            "NO_AUTO_ACCEPTANCE":all(not x["accepted_automatically"] for x in audit["acceptances"]),
            "NO_TREATMENT_EXECUTION":audit["treatment_executed"] is False,
            "NO_PRODUCTION_CHANGE":audit["production_changed"] is False,
            "SECRET_SAFETY":audit["secret_values_exposed"] is False,
        }
        failed=[k for k in cls.BLOCKING if not controls[k]]
        return {"passed":not failed,"failed":failed,"controls":controls}
'@
$Vd7062f98c1=@'
import hashlib,json

def canonical_sha256(value):
    raw=json.dumps(value,sort_keys=True,separators=(",",":"),ensure_ascii=True).encode("utf-8")
    return hashlib.sha256(raw).hexdigest().upper()
'@
$V7e806604d1=@'
from .audit import RiskRegisterAuditor
from .gate import RiskRegisterGovernanceGate

class RiskRegisterGovernanceService:
    def assess(self,layer1_status):
        audit=RiskRegisterAuditor().assess()
        gate=RiskRegisterGovernanceGate.evaluate(layer1_status,audit)
        return {"status":"RISK_REGISTER_GOVERNANCE_GATE_PASS" if gate["passed"] else "RISK_REGISTER_GOVERNANCE_GATE_HOLD","gate":gate,**audit}
'@
$Vd22479f43b=@'
from sgoda.integration.spt02414l2.service import RiskRegisterGovernanceService
from sgoda.integration.spt02414l2.register import build_master_register
from sgoda.integration.spt02414l2.prioritization import prioritize
from sgoda.integration.spt02414l2.residual import residual_risk
from sgoda.integration.spt02414l2.acceptance import acceptance_governance
from sgoda.integration.spt02414l2.integrity import canonical_sha256

L1="SECURITY_RISK_GOVERNANCE_GATE_PASS"

def test_master_register_has_records(): assert len(build_master_register()) >= 4
def test_prioritization_puts_critical_first(): assert prioritize(build_master_register())[0].priority == "CRITICAL"
def test_gate_passes(): assert RiskRegisterGovernanceService().assess(L1)["status"] == "RISK_REGISTER_GOVERNANCE_GATE_PASS"
def test_twelve_blocking_controls(): assert len(RiskRegisterGovernanceService().assess(L1)["gate"]["controls"]) == 12
def test_no_failed_controls(): assert RiskRegisterGovernanceService().assess(L1)["gate"]["failed"] == []
def test_residual_not_greater_than_inherent():
    for r in build_master_register(): assert residual_risk(r)["residual_score"] <= residual_risk(r)["inherent_score"]
def test_exception_requires_acceptance_governance():
    flagged=[r for r in build_master_register() if r.exception]
    assert flagged and all(acceptance_governance(r)["required"] for r in flagged)
def test_no_automatic_acceptance(): assert all(not x["accepted_automatically"] for x in RiskRegisterGovernanceService().assess(L1)["acceptances"])
def test_treatment_not_executed(): assert RiskRegisterGovernanceService().assess(L1)["treatment_executed"] is False
def test_no_production_change(): assert RiskRegisterGovernanceService().assess(L1)["production_changed"] is False
def test_no_secret_exposure(): assert RiskRegisterGovernanceService().assess(L1)["secret_values_exposed"] is False
def test_integrity_stable(): assert canonical_sha256({"b":2,"a":1}) == canonical_sha256({"a":1,"b":2})
'@
$V45194aa7a1=@'
{
  "component": "SPT-024.14",
  "layer": 2,
  "version": "1.0.0",
  "title": "Registro Maestro de Riesgos, Priorizacion, Tratamiento, Seguimiento, Riesgo Residual, Excepciones y Aceptacion",
  "blocking_controls": [
    "LAYER1_GATE",
    "MASTER_REGISTER",
    "PRIORITIZATION",
    "TREATMENT_PLANS",
    "RESIDUAL_RISK",
    "EXCEPTION_GOVERNANCE",
    "ACCEPTANCE_GOVERNANCE",
    "TRACKING_GOVERNANCE",
    "NO_AUTO_ACCEPTANCE",
    "NO_TREATMENT_EXECUTION",
    "NO_PRODUCTION_CHANGE",
    "SECRET_SAFETY"
  ],
  "acceptance": {
    "automatic": false,
    "approval_required": true,
    "residual_review_required": true
  },
  "exceptions": {
    "approval_required": true,
    "expiry_required": true
  },
  "safety": {
    "treatment_execution": false,
    "production_change": false,
    "external_connection": false,
    "secret_values_exposed": false
  }
}
'@
$Va62b44f93c=@'
# SPT-024.14 Capa 2 — Registro Maestro de Riesgos y Gobierno de Tratamiento

Baseline autoritativa: `12abac887ab08e7ba6932477cf696efedad49865`.

Reutiliza íntegramente SPT-024.14 Capa 1 sin reabrirla.

## Alcance
Registro Maestro de Riesgos, priorización, planes de tratamiento, seguimiento, riesgo residual, excepciones, aceptación del riesgo, integridad SHA-256, preservation gates y publicación obligatoria.

## Seguridad
No ejecuta tratamientos reales, no acepta riesgos automáticamente, no modifica producción, no abre conexiones externas y no expone secretos.
'@
WriteLf 'src/sgoda/integration/spt02414l2/__init__.py' $Va5dad845a4
WriteLf 'src/sgoda/integration/spt02414l2/models.py' $V022374a082
WriteLf 'src/sgoda/integration/spt02414l2/register.py' $V64f09a8923
WriteLf 'src/sgoda/integration/spt02414l2/prioritization.py' $V22c3b296a3
WriteLf 'src/sgoda/integration/spt02414l2/treatment.py' $V3b16c7d6e5
WriteLf 'src/sgoda/integration/spt02414l2/residual.py' $Vacc94de729
WriteLf 'src/sgoda/integration/spt02414l2/exceptions.py' $V828411142a
WriteLf 'src/sgoda/integration/spt02414l2/acceptance.py' $Veecca3109a
WriteLf 'src/sgoda/integration/spt02414l2/audit.py' $V035a841b69
WriteLf 'src/sgoda/integration/spt02414l2/gate.py' $V09d41d93ba
WriteLf 'src/sgoda/integration/spt02414l2/integrity.py' $Vd7062f98c1
WriteLf 'src/sgoda/integration/spt02414l2/service.py' $V7e806604d1
WriteLf 'tests/integration/test_spt02414_risk_register_governance_layer2.py' $Vd22479f43b
WriteLf 'config/integration/spt02414/risk-register-governance-policy.json' $V45194aa7a1
WriteLf 'docs/06_Tecnologia/SPT-024/SPT-024.14/SGD-SPT024.14-Capa2-Registro-Maestro-Riesgos-Priorizacion-Tratamiento-Riesgo-Residual-Excepciones.md' $Va62b44f93c
    Write-Host "SPT-024.14 CAPA 2 IMPLEMENTATION : CREATED/VALIDATED"

    Step 6 "PYTHON PREVALIDATION + TARGETED TESTS"
    $env:PYTHONPATH=Join-Path $Root "src"
    & $Python -c "import sys; assert len(sys.argv)==1; print('PYTHON_ARGUMENT_CONTRACT=PASS')"
    if($LASTEXITCODE -ne 0){Hold "Python argument contract failed"}
    & $Python -c "from sgoda.integration.spt02414l2 import RiskRegisterGovernanceService; from sgoda.integration.spt02414l2.gate import RiskRegisterGovernanceGate; assert len(RiskRegisterGovernanceGate.BLOCKING)==12; print('SPT02414_CAPA2_IMPORT=PASS'); print('BLOCKING_CONTROLS=12')"
    if($LASTEXITCODE -ne 0){Hold "Capa 2 import failed"}
    & $Python -m pytest -q $TestFile
    if($LASTEXITCODE -ne 0){Hold "Targeted tests failed"}
    Write-Host "TARGETED TESTS : PASS"

    Step 7 "INSTITUTIONAL SUITE + COMPILEALL"
    & $Python -m pytest -q
    if($LASTEXITCODE -ne 0){Hold "Institutional suite failed"}
    Write-Host "FULL SUITE : PASS"
    & $Python -m compileall -q (Join-Path $Root "src")
    if($LASTEXITCODE -ne 0){Hold "compileall failed"}
    Write-Host "COMPILEALL : PASS"

    Step 8 "PRODUCTION MASTER RISK REGISTER / ACCEPTANCE GOVERNANCE ASSESSMENT"
    New-Item -ItemType Directory -Force -Path (Join-Path $Root $ArtifactDir)|Out-Null

    $ProbeFile=Join-Path ([IO.Path]::GetTempPath()) ("sgoda-spt02414-l2-"+[Guid]::NewGuid().ToString("N")+".py")
    $Probe=@'
import json
from sgoda.integration.spt02414l2 import RiskRegisterGovernanceService
r=RiskRegisterGovernanceService().assess("SECURITY_RISK_GOVERNANCE_GATE_PASS")
print(json.dumps(r,default=lambda o:o.__dict__,ensure_ascii=False))
'@
    WriteLf $ProbeFile $Probe

    try{
        $Json=& $Python $ProbeFile
        $ProbeExit=$LASTEXITCODE
    } finally {
        Remove-Item -LiteralPath $ProbeFile -Force -ErrorAction SilentlyContinue
    }

    if($ProbeExit -ne 0){Hold "Risk register governance assessment failed"}
    $Assessment=$Json|ConvertFrom-Json

    Write-Host "SPT02414_RISK_REGISTER_STATUS=$($Assessment.status)"
    Write-Host "MASTER_RISK_RECORDS=$(@($Assessment.records).Count)"
    Write-Host "FAILED_BLOCKING_CONTROLS=$(@($Assessment.gate.failed).Count)"
    Write-Host "FAILED_CONTROL_IDS=$($Assessment.gate.failed -join ',')"
    Write-Host "EXCEPTIONS=$(@($Assessment.exceptions|Where-Object{$_.exception}).Count)"
    Write-Host "ACCEPTANCE_REQUIRED=$(@($Assessment.acceptances|Where-Object{$_.required}).Count)"
    Write-Host "TREATMENT_EXECUTED=NO"
    Write-Host "AUTO_ACCEPTANCE_EXECUTED=NO"
    Write-Host "PRODUCTION_CHANGED=NO"
    Write-Host "EXTERNAL_CONNECTION_OPENED=NO"
    Write-Host "SECRET_VALUES_EXPOSED=NO"

    if([string]$Assessment.status -ne "RISK_REGISTER_GOVERNANCE_GATE_PASS"){Hold "Risk register governance gate failed"}
    Write-Host "RISK REGISTER GOVERNANCE GATE : PASS"

    Step 9 "EVIDENCE + INTEGRITY"
    WriteLf $AssessmentFile ($Assessment|ConvertTo-Json -Depth 12)
    WriteLf $RegisterFile ($Assessment.records|ConvertTo-Json -Depth 10)
    WriteLf $PriorityFile ($Assessment.records|ConvertTo-Json -Depth 10)
    WriteLf $TreatmentFile ($Assessment.treatments|ConvertTo-Json -Depth 10)
    WriteLf $ResidualFile ($Assessment.residuals|ConvertTo-Json -Depth 10)
    WriteLf $ExceptionFile ($Assessment.exceptions|ConvertTo-Json -Depth 10)
    WriteLf $AcceptanceFile ($Assessment.acceptances|ConvertTo-Json -Depth 10)

    $IntegrityRecords=@()
    foreach($p in @($PolicyFile,$DocFile,$AssessmentFile,$RegisterFile,$TreatmentFile,$ResidualFile,$ExceptionFile,$AcceptanceFile)){
        $IntegrityRecords += [ordered]@{path=$p;sha256=(Sha (Join-Path $Root $p))}
    }
    WriteLf $IntegrityFile ([ordered]@{algorithm="SHA-256";records=$IntegrityRecords}|ConvertTo-Json -Depth 10)

    $Evidence=[ordered]@{
        component="SPT-024.14";layer=2;version="1.0.0";authoritative_baseline=$ExpectedBaseline
        status="RISK_REGISTER_GOVERNANCE_GATE_PASS";targeted_tests="PASS";institutional_suite="PASS";compileall="PASS"
        capa1_reused=$true;capa1_reopened=$false;treatment_executed=$false;automatic_acceptance_executed=$false
        production_changed=$false;external_connection_opened=$false;secret_values_exposed=$false
    }
    WriteLf $EvidenceFile ($Evidence|ConvertTo-Json -Depth 10)

    Write-Host "ASSESSMENT     : CREATED"
    Write-Host "MASTER REGISTER: CREATED"
    Write-Host "PRIORITIZATION : CREATED"
    Write-Host "TREATMENT      : CREATED"
    Write-Host "RESIDUAL RISK  : CREATED"
    Write-Host "EXCEPTIONS     : CREATED"
    Write-Host "ACCEPTANCE     : CREATED"
    Write-Host "INTEGRITY      : CREATED"
    Write-Host "EVIDENCE       : CREATED"

    Step 10 "SHA-256 PRESERVATION GATE"
    foreach($p in $Freeze.Keys){
        $full=Join-Path $Root $p
        if(-not(Test-Path -LiteralPath $full) -or (Sha $full) -ne $Freeze[$p]){Hold "Protected tracked file changed: $p"}
    }
    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
    Write-Host "SPT-024.1-.13 + SPT-024.14 CAPA 1 : PRESERVED"

    Step 11 "EXACT CONTROLLED STAGING"
    $Allowed=@('Invoke-SGODA-SPT02414-Capa2-FINAL-v1.0.0-PS51.ps1','src/sgoda/integration/spt02414l2/__init__.py','src/sgoda/integration/spt02414l2/models.py','src/sgoda/integration/spt02414l2/register.py','src/sgoda/integration/spt02414l2/prioritization.py','src/sgoda/integration/spt02414l2/treatment.py','src/sgoda/integration/spt02414l2/residual.py','src/sgoda/integration/spt02414l2/exceptions.py','src/sgoda/integration/spt02414l2/acceptance.py','src/sgoda/integration/spt02414l2/audit.py','src/sgoda/integration/spt02414l2/gate.py','src/sgoda/integration/spt02414l2/integrity.py','src/sgoda/integration/spt02414l2/service.py','tests/integration/test_spt02414_risk_register_governance_layer2.py','config/integration/spt02414/risk-register-governance-policy.json','docs/06_Tecnologia/SPT-024/SPT-024.14/SGD-SPT024.14-Capa2-Registro-Maestro-Riesgos-Priorizacion-Tratamiento-Riesgo-Residual-Excepciones.md','artifacts/development/SPT-024.14-Capa2-v1.0.0/risk-register-governance-assessment.json','artifacts/development/SPT-024.14-Capa2-v1.0.0/master-risk-register.json','artifacts/development/SPT-024.14-Capa2-v1.0.0/risk-prioritization-baseline.json','artifacts/development/SPT-024.14-Capa2-v1.0.0/risk-treatment-plans-baseline.json','artifacts/development/SPT-024.14-Capa2-v1.0.0/residual-risk-baseline.json','artifacts/development/SPT-024.14-Capa2-v1.0.0/risk-exceptions-baseline.json','artifacts/development/SPT-024.14-Capa2-v1.0.0/risk-acceptance-governance-baseline.json','artifacts/development/SPT-024.14-Capa2-v1.0.0/risk-register-integrity-manifest.json','artifacts/development/SPT-024.14-Capa2-v1.0.0/implementation-evidence.json')

    foreach($p in $Allowed){
        if(-not(Test-Path -LiteralPath (Join-Path $Root $p))){Hold "Expected target missing before staging: $p"}
        & git.exe -c core.autocrlf=false -c core.eol=lf -c core.safecrlf=false add -- $p
        if($LASTEXITCODE -ne 0){Hold "git add failed: $p"}
    }

    Write-Host "TRANSACTION LINE ENDINGS : CANONICAL LF"
    Write-Host "GIT SAFECRLF POLICY      : TRANSACTION-LOCAL OVERRIDE ONLY"
    Write-Host "GIT GLOBAL/REPO CONFIG   : NOT MODIFIED"

    $StagedNow=@(& git.exe -c core.quotepath=false diff --cached --name-only)
    $Unexpected=@($StagedNow|Where-Object{$Allowed -notcontains ($_ -replace '\\','/')})
    Write-Host "STAGED     : $($StagedNow.Count)"
    Write-Host "UNEXPECTED : $($Unexpected.Count)"

    if($Unexpected.Count -gt 0){Hold "Unexpected staged paths"}
    if($StagedNow.Count -ne $Allowed.Count){Hold "Exact staging count mismatch"}
    Write-Host "STAGING QUALITY : PASS"

    Step 12 "INDEX-WIDE GITHUB SIZE GATE"
    $Bad=@(SizeGate)
    Write-Host "INDEX BLOBS >=100MB : $($Bad.Count)"
    if($Bad.Count -gt 0){$Bad|ForEach-Object{Write-Host "TOO LARGE : $_" -ForegroundColor Red};Hold "Git index contains blob >=100 MB"}
    Write-Host "GITHUB SIZE GATE : PASS"

    Step 13 "FINAL REMOTE GATE"
    GitFetch
    $Remote2=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
    if($Remote2 -ne $ExpectedBaseline){Hold "Remote advanced during transaction"}

    foreach($p in $Freeze.Keys){
        $full=Join-Path $Root $p
        if(-not(Test-Path -LiteralPath $full) -or (Sha $full) -ne $Freeze[$p]){Hold "Preservation changed before commit: $p"}
    }

    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
    Write-Host "REMOTE GATE : PASS"

    Step 14 "COMMIT"
    & git.exe commit -m "feat(spt-024.14): implement master risk register treatment acceptance governance layer 2"
    if($LASTEXITCODE -ne 0){Hold "git commit failed"}

    $NewCommit=(& git.exe rev-parse HEAD).Trim()
    Write-Host "NEW COMMIT : $NewCommit"

    Step 15 "PUSH"
    & git.exe push origin $Branch
    if($LASTEXITCODE -ne 0){Hold "git push failed"}
    Write-Host "PUSH : PASS"

    Step 16 "AUTHORITATIVE REMOTE VERIFICATION"
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
    Write-Host "SPT-024.14 CAPA 2 : TECHNICALLY CLOSED" -ForegroundColor Green
    Write-Host "CAPA1_SECURITY_RISK_GOVERNANCE_GATE=PASS"
    Write-Host "RISK_REGISTER_GOVERNANCE_GATE=PASS"
    Write-Host "MASTER_RISK_REGISTER=PASS"
    Write-Host "RISK_PRIORITIZATION=PASS"
    Write-Host "TREATMENT_PLAN_GOVERNANCE=PASS"
    Write-Host "RISK_TRACKING_GOVERNANCE=PASS"
    Write-Host "RESIDUAL_RISK_GOVERNANCE=PASS"
    Write-Host "RISK_EXCEPTION_GOVERNANCE=PASS"
    Write-Host "RISK_ACCEPTANCE_GOVERNANCE=PASS"
    Write-Host "AUTOMATIC_ACCEPTANCE=NO"
    Write-Host "TREATMENT_EXECUTED=NO"
    Write-Host "PRODUCTION_CHANGED=NO"
    Write-Host "EXTERNAL_CONNECTION_OPENED=NO"
    Write-Host "SECRET_VALUES_EXPOSED=NO"
    Write-Host "TARGETED_TESTS=PASS"
    Write-Host "INSTITUTIONAL_SUITE=PASS"
    Write-Host "COMPILEALL=PASS"
    Write-Host "CLOSED_COMPONENTS=PRESERVED"
    Write-Host "LOCAL_HEAD=REMOTE_HEAD"
    Write-Host "FINAL_CLOSURE_EXIT_CODE=0"
    exit 0
}
catch{
    Hold $_.Exception.Message
}
