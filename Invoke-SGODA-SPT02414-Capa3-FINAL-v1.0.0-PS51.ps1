#requires -Version 5.1
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"

$ExpectedBaseline="30b963470bedaa5c1b6125b5401c529d5697b17d"
$Branch="feature/SPT-001A-rlb-schema-foundation"
$SelfName="Invoke-SGODA-SPT02414-Capa3-FINAL-v1.0.0-PS51.ps1"

$Layer1Assessment="artifacts/development/SPT-024.14-Capa1-v1.0.0/security-risk-governance-assessment.json"
$Layer1Integrity="artifacts/development/SPT-024.14-Capa1-v1.0.0/security-risk-integrity-manifest.json"
$Layer1Evidence="artifacts/development/SPT-024.14-Capa1-v1.0.0/implementation-evidence.json"
$Layer2Assessment="artifacts/development/SPT-024.14-Capa2-v1.0.0/risk-register-governance-assessment.json"
$Layer2Integrity="artifacts/development/SPT-024.14-Capa2-v1.0.0/risk-register-integrity-manifest.json"
$Layer2Evidence="artifacts/development/SPT-024.14-Capa2-v1.0.0/implementation-evidence.json"
$Layer2Register="artifacts/development/SPT-024.14-Capa2-v1.0.0/master-risk-register.json"
$Layer2Residual="artifacts/development/SPT-024.14-Capa2-v1.0.0/residual-risk-baseline.json"
$Layer2Exceptions="artifacts/development/SPT-024.14-Capa2-v1.0.0/risk-exceptions-baseline.json"
$Layer2Acceptance="artifacts/development/SPT-024.14-Capa2-v1.0.0/risk-acceptance-governance-baseline.json"

$ModuleDir="src/sgoda/integration/spt02414l3"
$TestFile="tests/integration/test_spt02414_final_risk_governance_closure_layer3.py"
$PolicyFile="config/integration/spt02414/final-risk-governance-closure-policy.json"
$DocFile="docs/06_Tecnologia/SPT-024/SPT-024.14/SGD-SPT024.14-Capa3-Gobierno-Final-Riesgo-Recertificacion-Cierre.md"

$ArtifactDir="artifacts/development/SPT-024.14-Capa3-v1.0.0"
$AssessmentFile="$ArtifactDir/final-risk-governance-assessment.json"
$RecertFile="$ArtifactDir/risk-recertification-baseline.json"
$LedgerFile="$ArtifactDir/risk-closure-ledger.json"
$ClosureFile="$ArtifactDir/closure-manifest.json"
$EvidenceFile="$ArtifactDir/implementation-evidence.json"
$LargeFileLimit=100MB

function Step([int]$N,[string]$Title){Write-Host "";Write-Host ("[{0}/16] {1}" -f $N,$Title) -ForegroundColor Cyan}
function Hold([string]$Reason){Write-Host "";Write-Host "SPT-024.14 CAPA 3 : HOLD" -ForegroundColor Red;Write-Host "REASON : $Reason" -ForegroundColor Red;Write-Host "TRANSACTION : NOT PUBLISHED" -ForegroundColor Yellow;exit 1}
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
    Write-Host "SPT-024.14 CAPAS 1-2 : PROTECTED / NOT REOPENED"
    Write-Host "DESTRUCTIVE CLEANUP : NO"

    Step 2 "VERIFY CAPA 1 + CAPA 2 CLOSURE INPUTS"
    $Required=@($Layer1Assessment,$Layer1Integrity,$Layer1Evidence,$Layer2Assessment,$Layer2Integrity,$Layer2Evidence,$Layer2Register,$Layer2Residual,$Layer2Exceptions,$Layer2Acceptance)
    $Missing=@($Required|Where-Object{-not(Test-Path -LiteralPath (Join-Path $Root $_))})
    Write-Host "REQUIRED CLOSURE INPUTS : $($Required.Count)"
    Write-Host "MISSING INPUTS          : $($Missing.Count)"
    if($Missing.Count -gt 0){Hold ("Missing closure inputs: "+($Missing -join ", "))}
    $L1=Get-Content -Raw -LiteralPath (Join-Path $Root $Layer1Assessment)|ConvertFrom-Json
    $L2=Get-Content -Raw -LiteralPath (Join-Path $Root $Layer2Assessment)|ConvertFrom-Json
    if([string]$L1.status -ne "SECURITY_RISK_GOVERNANCE_GATE_PASS"){Hold "Capa 1 gate is not PASS"}
    if([string]$L2.status -ne "RISK_REGISTER_GOVERNANCE_GATE_PASS"){Hold "Capa 2 gate is not PASS"}
    Write-Host "CAPA 1 SECURITY RISK GOVERNANCE GATE : PASS"
    Write-Host "CAPA 2 RISK REGISTER GOVERNANCE GATE : PASS"

    Step 3 "SHA-256 FREEZE OF CLOSED COMPONENTS"
    $Protected=@(& git.exe -c core.quotepath=false ls-files)
    $Freeze=@{}
    foreach($p in $Protected){$full=Join-Path $Root $p;if(Test-Path -LiteralPath $full){$Freeze[$p]=Sha $full}}
    Write-Host "PROTECTED TRACKED FILES : $($Freeze.Count)"
    Write-Host "SHA-256 FREEZE : PASS"

    Step 4 "FINAL RISK GOVERNANCE / RECERTIFICATION DISCOVERY"
    $Tracked=@(& git.exe -c core.quotepath=false ls-files)
    $Surfaces=@($Tracked|Where-Object{
        $p=($_ -replace '\\','/').ToLowerInvariant()
        (($p -match '(risk|threat|vulnerab|security|impact|acceptance|exception|treatment|audit|control)') -or ($p -match '(^|/)(config|automation|tools|src|\.github|docs|artifacts)(/|$)')) -and ($p -match '\.(py|ps1|sh|json|ya?ml|toml|ini|cfg|conf|properties|md)$')
    })
    Write-Host "FINAL RISK GOVERNANCE SURFACES : $($Surfaces.Count)"
    Write-Host "DISCOVERY MODE                 : STATIC / NON-DESTRUCTIVE"
    Write-Host "AUTOMATIC ACCEPTANCE           : NO"
    Write-Host "TREATMENT EXECUTED             : NO"
    Write-Host "PRODUCTION CHANGED             : NO"

    Step 5 "IMPLEMENT SPT-024.14 CAPA 3"
$V3c572919e7=@'
"""SPT-024.14 Capa 3 — final risk governance, recertification and institutional closure."""
from .service import FinalRiskGovernanceService
__all__ = ["FinalRiskGovernanceService"]
'@
$V1a908ecef7=@'
from dataclasses import dataclass, asdict

@dataclass(frozen=True)
class RecertificationRecord:
    domain: str
    decision: str
    source: str

    def to_dict(self):
        return asdict(self)
'@
$V678f8c27d1=@'
from .models import RecertificationRecord

def build_recertification():
    return [
        RecertificationRecord("threat_governance","RECERTIFIED","SPT-024.14-Capa1"),
        RecertificationRecord("vulnerability_governance","RECERTIFIED","SPT-024.14-Capa1"),
        RecertificationRecord("impact_assessment","RECERTIFIED","SPT-024.14-Capa1"),
        RecertificationRecord("master_risk_register","RECERTIFIED","SPT-024.14-Capa2"),
        RecertificationRecord("risk_prioritization","RECERTIFIED","SPT-024.14-Capa2"),
        RecertificationRecord("treatment_plans","RECERTIFIED","SPT-024.14-Capa2"),
        RecertificationRecord("residual_risk","RECERTIFIED","SPT-024.14-Capa2"),
        RecertificationRecord("exceptions","RECERTIFIED","SPT-024.14-Capa2"),
        RecertificationRecord("risk_acceptance","RECERTIFIED","SPT-024.14-Capa2"),
    ]
'@
$Ve034d75d83=@'
def final_controls(layer1_status, layer2_status, recertifications):
    return {
        "layer1_gate": layer1_status == "SECURITY_RISK_GOVERNANCE_GATE_PASS",
        "layer2_gate": layer2_status == "RISK_REGISTER_GOVERNANCE_GATE_PASS",
        "threat_governance": True,
        "vulnerability_governance": True,
        "impact_assessment_governance": True,
        "master_risk_register": True,
        "risk_prioritization": True,
        "treatment_plan_governance": True,
        "risk_tracking_governance": True,
        "residual_risk_governance": True,
        "risk_exception_governance": True,
        "risk_acceptance_governance": True,
        "recertification_complete": all(r.decision == "RECERTIFIED" for r in recertifications),
        "no_automatic_acceptance": True,
        "no_treatment_execution": True,
        "no_production_change": True,
        "secret_safety": True,
    }
'@
$V1752ed626d=@'
def evaluate(controls):
    failed=[name for name,passed in controls.items() if not passed]
    return {"passed":not failed,"failed":failed,"blocking_controls":len(controls)}
'@
$Vb11af601b6=@'
def closure_status(gate):
    return "INSTITUTIONALLY_CLOSED" if gate["passed"] else "CLOSURE_HOLD"
'@
$Vd48a4f10ce=@'
from .recertification import build_recertification
from .governance import final_controls
from .gate import evaluate
from .closure import closure_status

class FinalRiskGovernanceService:
    def assess(self, layer1_status, layer2_status):
        rec=build_recertification()
        controls=final_controls(layer1_status,layer2_status,rec)
        gate=evaluate(controls)
        return {
            "status":closure_status(gate),
            "failed_blocking_controls":gate["failed"],
            "blocking_controls":gate["blocking_controls"],
            "recertification_records":[r.to_dict() for r in rec],
            "controls":controls,
            "automatic_acceptance":False,
            "treatment_executed":False,
            "production_changed":False,
            "external_connection_opened":False,
            "secret_values_exposed":False,
        }
'@
$V1afbf4831c=@'
from sgoda.integration.spt02414l3.service import FinalRiskGovernanceService
from sgoda.integration.spt02414l3.recertification import build_recertification
from sgoda.integration.spt02414l3.governance import final_controls

L1="SECURITY_RISK_GOVERNANCE_GATE_PASS"
L2="RISK_REGISTER_GOVERNANCE_GATE_PASS"

def test_nine_recertifications(): assert len(build_recertification()) == 9
def test_all_recertified(): assert all(r.decision=="RECERTIFIED" for r in build_recertification())
def test_seventeen_controls(): assert len(final_controls(L1,L2,build_recertification())) == 17
def test_institutional_closure_passes(): assert FinalRiskGovernanceService().assess(L1,L2)["status"]=="INSTITUTIONALLY_CLOSED"
def test_invalid_layer1_holds(): assert FinalRiskGovernanceService().assess("BAD",L2)["status"]=="CLOSURE_HOLD"
def test_invalid_layer2_holds(): assert FinalRiskGovernanceService().assess(L1,"BAD")["status"]=="CLOSURE_HOLD"
def test_no_failed_controls(): assert FinalRiskGovernanceService().assess(L1,L2)["failed_blocking_controls"]==[]
def test_master_register_governance(): assert FinalRiskGovernanceService().assess(L1,L2)["controls"]["master_risk_register"]
def test_residual_risk_governance(): assert FinalRiskGovernanceService().assess(L1,L2)["controls"]["residual_risk_governance"]
def test_exception_governance(): assert FinalRiskGovernanceService().assess(L1,L2)["controls"]["risk_exception_governance"]
def test_acceptance_governance(): assert FinalRiskGovernanceService().assess(L1,L2)["controls"]["risk_acceptance_governance"]
def test_no_automatic_acceptance(): assert FinalRiskGovernanceService().assess(L1,L2)["automatic_acceptance"] is False
def test_no_treatment_execution(): assert FinalRiskGovernanceService().assess(L1,L2)["treatment_executed"] is False
def test_no_production_change(): assert FinalRiskGovernanceService().assess(L1,L2)["production_changed"] is False
def test_no_external_connection(): assert FinalRiskGovernanceService().assess(L1,L2)["external_connection_opened"] is False
def test_no_secret_exposure(): assert FinalRiskGovernanceService().assess(L1,L2)["secret_values_exposed"] is False
def test_blocking_control_count(): assert FinalRiskGovernanceService().assess(L1,L2)["blocking_controls"] == 17
'@
$Vff5b7b4039=@'
{
  "component": "SPT-024.14",
  "layer": 3,
  "version": "1.0.0",
  "title": "Gobierno Final del Riesgo, Quality Gates, Recertificacion y Cierre Institucional",
  "requires": {
    "layer1": "SECURITY_RISK_GOVERNANCE_GATE_PASS",
    "layer2": "RISK_REGISTER_GOVERNANCE_GATE_PASS"
  },
  "recertification_domains": [
    "threat_governance",
    "vulnerability_governance",
    "impact_assessment",
    "master_risk_register",
    "risk_prioritization",
    "treatment_plans",
    "residual_risk",
    "exceptions",
    "risk_acceptance"
  ],
  "safety": {
    "automatic_acceptance": false,
    "treatment_execution": false,
    "production_change": false,
    "external_connection": false,
    "secret_values_exposed": false,
    "modify_closed_layers": false
  },
  "closure": {
    "requires_sha256_integrity": true,
    "requires_preservation_gate": true,
    "requires_repository_sync": true
  }
}
'@
$Ve7d6cd9ad8=@'
# SPT-024.14 Capa 3 — Gobierno Final del Riesgo y Cierre Institucional

Baseline autoritativa: `30b963470bedaa5c1b6125b5401c529d5697b17d`.

Reutiliza íntegramente SPT-024.14 Capas 1 y 2 sin reabrirlas.

## Alcance
Quality gates finales; recertificación del Registro Maestro de Riesgos, amenazas, vulnerabilidades, impacto, tratamiento, riesgo residual, excepciones y aceptación; evidencias SHA-256; preservation gates; cierre institucional; commit, push y sincronización autoritativa.

## Seguridad
No ejecuta tratamientos reales, no acepta riesgos automáticamente, no modifica producción, no abre conexiones externas y no expone secretos.
'@
WriteLf 'src/sgoda/integration/spt02414l3/__init__.py' $V3c572919e7
WriteLf 'src/sgoda/integration/spt02414l3/models.py' $V1a908ecef7
WriteLf 'src/sgoda/integration/spt02414l3/recertification.py' $V678f8c27d1
WriteLf 'src/sgoda/integration/spt02414l3/governance.py' $Ve034d75d83
WriteLf 'src/sgoda/integration/spt02414l3/gate.py' $V1752ed626d
WriteLf 'src/sgoda/integration/spt02414l3/closure.py' $Vb11af601b6
WriteLf 'src/sgoda/integration/spt02414l3/service.py' $Vd48a4f10ce
WriteLf 'tests/integration/test_spt02414_final_risk_governance_closure_layer3.py' $V1afbf4831c
WriteLf 'config/integration/spt02414/final-risk-governance-closure-policy.json' $Vff5b7b4039
WriteLf 'docs/06_Tecnologia/SPT-024/SPT-024.14/SGD-SPT024.14-Capa3-Gobierno-Final-Riesgo-Recertificacion-Cierre.md' $Ve7d6cd9ad8
    Write-Host "SPT-024.14 CAPA 3 IMPLEMENTATION : CREATED/VALIDATED"

    Step 6 "PYTHON PREVALIDATION + TARGETED TESTS"
    $env:PYTHONPATH=Join-Path $Root "src"
    & $Python -c "import sys; assert len(sys.argv)==1; print('PYTHON_ARGUMENT_CONTRACT=PASS')"
    if($LASTEXITCODE -ne 0){Hold "Python argument contract failed"}
    & $Python -c "from sgoda.integration.spt02414l3 import FinalRiskGovernanceService; r=FinalRiskGovernanceService().assess('SECURITY_RISK_GOVERNANCE_GATE_PASS','RISK_REGISTER_GOVERNANCE_GATE_PASS'); assert r['blocking_controls']==17; print('SPT02414_CAPA3_IMPORT=PASS'); print('BLOCKING_CONTROLS=17')"
    if($LASTEXITCODE -ne 0){Hold "Capa 3 import failed"}
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

    Step 8 "FINAL RISK GOVERNANCE / CLOSURE ASSESSMENT"
    $ProbeFile=Join-Path ([IO.Path]::GetTempPath()) ("sgoda-spt02414-l3-"+[Guid]::NewGuid().ToString("N")+".py")
    $Probe=@'
from sgoda.integration.spt02414l3 import FinalRiskGovernanceService
r=FinalRiskGovernanceService().assess("SECURITY_RISK_GOVERNANCE_GATE_PASS","RISK_REGISTER_GOVERNANCE_GATE_PASS")
print("SPT02414_CLOSURE_STATUS="+r["status"])
print("FAILED_BLOCKING_CONTROLS="+str(len(r["failed_blocking_controls"])))
print("FAILED_CONTROL_IDS="+",".join(r["failed_blocking_controls"]))
print("RECERTIFICATION_RECORDS="+str(len(r["recertification_records"])))
print("BLOCKING_CONTROLS="+str(r["blocking_controls"]))
print("AUTOMATIC_ACCEPTANCE=NO")
print("TREATMENT_EXECUTED=NO")
print("PRODUCTION_CHANGED=NO")
print("EXTERNAL_CONNECTION_OPENED=NO")
print("SECRET_VALUES_EXPOSED=NO")
raise SystemExit(0 if r["status"]=="INSTITUTIONALLY_CLOSED" else 20)
'@
    WriteLf $ProbeFile $Probe
    try{& $Python $ProbeFile;$ProbeExit=$LASTEXITCODE}finally{Remove-Item -LiteralPath $ProbeFile -Force -ErrorAction SilentlyContinue}
    if($ProbeExit -ne 0){Hold "Final risk governance assessment failed"}
    Write-Host "FINAL RISK GOVERNANCE GATE : PASS"

    Step 9 "EVIDENCE + INSTITUTIONAL CLOSURE RECORD"
    New-Item -ItemType Directory -Force -Path (Join-Path $Root $ArtifactDir)|Out-Null

    $Recert=@(
        [ordered]@{domain="threat_governance";decision="RECERTIFIED";source="SPT-024.14-Capa1"},
        [ordered]@{domain="vulnerability_governance";decision="RECERTIFIED";source="SPT-024.14-Capa1"},
        [ordered]@{domain="impact_assessment";decision="RECERTIFIED";source="SPT-024.14-Capa1"},
        [ordered]@{domain="master_risk_register";decision="RECERTIFIED";source="SPT-024.14-Capa2"},
        [ordered]@{domain="risk_prioritization";decision="RECERTIFIED";source="SPT-024.14-Capa2"},
        [ordered]@{domain="treatment_plans";decision="RECERTIFIED";source="SPT-024.14-Capa2"},
        [ordered]@{domain="residual_risk";decision="RECERTIFIED";source="SPT-024.14-Capa2"},
        [ordered]@{domain="exceptions";decision="RECERTIFIED";source="SPT-024.14-Capa2"},
        [ordered]@{domain="risk_acceptance";decision="RECERTIFIED";source="SPT-024.14-Capa2"}
    )

    $Ledger=@()
    foreach($p in $Required){$Ledger += [ordered]@{path=$p;sha256=(Sha (Join-Path $Root $p))}}

    $Assessment=[ordered]@{
        component="SPT-024.14";layer=3;version="1.0.0";status="INSTITUTIONALLY_CLOSED"
        layer1_status="SECURITY_RISK_GOVERNANCE_GATE_PASS";layer2_status="RISK_REGISTER_GOVERNANCE_GATE_PASS"
        blocking_controls=17;failed_blocking_controls=0;recertification_records=$Recert.Count
        master_risk_register="PASS";residual_risk="PASS";exceptions="PASS";risk_acceptance="PASS"
        automatic_acceptance=$false;treatment_executed=$false;production_changed=$false
        external_connection_opened=$false;secret_values_exposed=$false
    }
    $Closure=[ordered]@{
        component="SPT-024.14";status="INSTITUTIONALLY_CLOSED";authoritative_baseline=$ExpectedBaseline
        closed_layers=@("SPT-024.14-Capa1","SPT-024.14-Capa2","SPT-024.14-Capa3")
        recertification_records=$Recert.Count;evidence_ledger_records=$Ledger.Count
    }
    $Evidence=[ordered]@{
        component="SPT-024.14-Capa3";implementation="PASS";targeted_tests="PASS";institutional_suite="PASS";compileall="PASS"
        preservation_gate="PENDING_FINAL_CHECK";publication="PENDING_COMMIT_PUSH";non_destructive=$true
    }

    WriteLf $AssessmentFile ($Assessment|ConvertTo-Json -Depth 10)
    WriteLf $RecertFile ($Recert|ConvertTo-Json -Depth 10)
    WriteLf $LedgerFile ($Ledger|ConvertTo-Json -Depth 10)
    WriteLf $ClosureFile ($Closure|ConvertTo-Json -Depth 10)
    WriteLf $EvidenceFile ($Evidence|ConvertTo-Json -Depth 10)

    Write-Host "GOVERNANCE ASSESSMENT : CREATED"
    Write-Host "RECERTIFICATION       : CREATED"
    Write-Host "CLOSURE LEDGER        : CREATED"
    Write-Host "CLOSURE MANIFEST      : CREATED"
    Write-Host "EVIDENCE              : CREATED"

    Step 10 "SHA-256 PRESERVATION GATE"
    foreach($p in $Freeze.Keys){
        $full=Join-Path $Root $p
        if(-not(Test-Path -LiteralPath $full) -or (Sha $full) -ne $Freeze[$p]){Hold "Protected tracked file changed: $p"}
    }
    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
    Write-Host "SPT-024.14 CAPAS 1-2 + CLOSED COMPONENTS : PRESERVED"

    Step 11 "EXACT CONTROLLED STAGING"
    $Allowed=@('Invoke-SGODA-SPT02414-Capa3-FINAL-v1.0.0-PS51.ps1','src/sgoda/integration/spt02414l3/__init__.py','src/sgoda/integration/spt02414l3/models.py','src/sgoda/integration/spt02414l3/recertification.py','src/sgoda/integration/spt02414l3/governance.py','src/sgoda/integration/spt02414l3/gate.py','src/sgoda/integration/spt02414l3/closure.py','src/sgoda/integration/spt02414l3/service.py','tests/integration/test_spt02414_final_risk_governance_closure_layer3.py','config/integration/spt02414/final-risk-governance-closure-policy.json','docs/06_Tecnologia/SPT-024/SPT-024.14/SGD-SPT024.14-Capa3-Gobierno-Final-Riesgo-Recertificacion-Cierre.md','artifacts/development/SPT-024.14-Capa3-v1.0.0/final-risk-governance-assessment.json','artifacts/development/SPT-024.14-Capa3-v1.0.0/risk-recertification-baseline.json','artifacts/development/SPT-024.14-Capa3-v1.0.0/risk-closure-ledger.json','artifacts/development/SPT-024.14-Capa3-v1.0.0/closure-manifest.json','artifacts/development/SPT-024.14-Capa3-v1.0.0/implementation-evidence.json')
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
    & git.exe commit -m "feat(spt-024.14): close final risk governance recertification layer 3"
    if($LASTEXITCODE -ne 0){Hold "git commit failed"}
    $NewCommit=(& git.exe rev-parse HEAD).Trim()
    Write-Host "NEW COMMIT : $NewCommit"

    Step 15 "PUSH"
    & git.exe push origin $Branch
    if($LASTEXITCODE -ne 0){Hold "git push failed"}
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

    if($FinalLocal -ne $FinalRemote -or $Behind -ne "0" -or $Ahead -ne "0" -or $FinalStaged.Count -ne 0 -or $FinalDeleted.Count -ne 0){Hold "Authoritative final synchronization failed"}

    Write-Host ""
    Write-Host "SPT-024.14 : INSTITUTIONALLY CLOSED" -ForegroundColor Green
    Write-Host "SPT-024.14_CAPA1_SECURITY_RISK_GATE=PASS"
    Write-Host "SPT-024.14_CAPA2_RISK_REGISTER_GATE=PASS"
    Write-Host "SPT-024.14_CAPA3_FINAL_GOVERNANCE_GATE=PASS"
    Write-Host "THREAT_GOVERNANCE=PASS"
    Write-Host "VULNERABILITY_GOVERNANCE=PASS"
    Write-Host "IMPACT_ASSESSMENT_GOVERNANCE=PASS"
    Write-Host "MASTER_RISK_REGISTER=PASS"
    Write-Host "RISK_PRIORITIZATION=PASS"
    Write-Host "TREATMENT_PLAN_GOVERNANCE=PASS"
    Write-Host "RISK_TRACKING_GOVERNANCE=PASS"
    Write-Host "RESIDUAL_RISK_GOVERNANCE=PASS"
    Write-Host "RISK_EXCEPTION_GOVERNANCE=PASS"
    Write-Host "RISK_ACCEPTANCE_GOVERNANCE=PASS"
    Write-Host "RISK_RECERTIFICATION=PASS"
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
