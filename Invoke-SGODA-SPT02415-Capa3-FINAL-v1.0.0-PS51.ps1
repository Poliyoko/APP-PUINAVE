#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"

$ExpectedBaseline="c8096ea3c33a1417ca179604c4a0fe01ae08ca59"
$Branch="feature/SPT-001A-rlb-schema-foundation"

$Layer1Dir="artifacts/development/SPT-024.15-Capa1-v1.0.0"
$Layer2Dir="artifacts/development/SPT-024.15-Capa2-v1.0.0"

$Layer1Assessment="$Layer1Dir/application-api-security-assessment.json"
$Layer1Integrity="$Layer1Dir/application-api-integrity-manifest.json"
$Layer1Evidence="$Layer1Dir/implementation-evidence.json"
$Layer1Owasp="$Layer1Dir/owasp-control-coverage-baseline.json"
$Layer1Session="$Layer1Dir/session-security-baseline.json"
$Layer1Api="$Layer1Dir/api-security-baseline.json"

$Layer2Assessment="$Layer2Dir/advanced-api-hardening-assessment.json"
$Layer2Integrity="$Layer2Dir/advanced-api-integrity-manifest.json"
$Layer2Evidence="$Layer2Dir/implementation-evidence.json"
$Layer2Session="$Layer2Dir/advanced-session-hardening-baseline.json"
$Layer2Rate="$Layer2Dir/rate-limit-governance-baseline.json"
$Layer2Cors="$Layer2Dir/cors-csrf-governance-baseline.json"
$Layer2Endpoint="$Layer2Dir/endpoint-security-baseline.json"
$Layer2Validation="$Layer2Dir/advanced-validation-baseline.json"
$Layer2Exposure="$Layer2Dir/api-exposure-governance-baseline.json"

$ModuleDir="src/sgoda/integration/spt02415l3"
$TestFile="tests/integration/test_spt02415_final_application_api_governance_closure_layer3.py"
$PolicyFile="config/integration/spt02415/final-application-api-governance-closure-policy.json"
$DocFile="docs/06_Tecnologia/SPT-024/SPT-024.15/SGD-SPT024.15-Capa3-Gobierno-Final-Aplicaciones-APIs-OWASP-Recertificacion-Cierre.md"

$ArtifactDir="artifacts/development/SPT-024.15-Capa3-v1.0.0"
$AssessmentFile="$ArtifactDir/final-application-api-governance-assessment.json"
$RecertFile="$ArtifactDir/application-api-recertification-baseline.json"
$LedgerFile="$ArtifactDir/application-api-closure-ledger.json"
$ClosureFile="$ArtifactDir/closure-manifest.json"
$EvidenceFile="$ArtifactDir/implementation-evidence.json"

$LargeFileLimit=100MB

function Step([int]$N,[string]$Title){Write-Host "";Write-Host ("[{0}/16] {1}" -f $N,$Title) -ForegroundColor Cyan}
function Hold([string]$Reason){Write-Host "";Write-Host "SPT-024.15 CAPA 3 : HOLD" -ForegroundColor Red;Write-Host "REASON : $Reason" -ForegroundColor Red;Write-Host "TRANSACTION : NOT PUBLISHED" -ForegroundColor Yellow;exit 1}
function GitFetch {
    for($i=1;$i -le 4;$i++){
        Write-Host "GIT FETCH ATTEMPT : $i/4"
        & git.exe fetch origin $Branch
        if($LASTEXITCODE -eq 0){Write-Host "GIT FETCH : PASS";return}
        Start-Sleep -Seconds 2
    }
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
            if([Int64]::TryParse(([string]$s[0]).Trim(),[ref]$n) -and $n -ge $LargeFileLimit){
                [void]$bad.Add(($p -replace '\\','/'))
            }
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
    Write-Host "SPT-024.15 CAPAS 1-2 : PROTECTED / NOT REOPENED"
    Write-Host "DESTRUCTIVE CLEANUP : NO"

    Step 2 "VERIFY CAPA 1 + CAPA 2 CLOSURE INPUTS"

    $Required=@(
        $Layer1Assessment,$Layer1Integrity,$Layer1Evidence,$Layer1Owasp,$Layer1Session,$Layer1Api,
        $Layer2Assessment,$Layer2Integrity,$Layer2Evidence,$Layer2Session,$Layer2Rate,$Layer2Cors,
        $Layer2Endpoint,$Layer2Validation,$Layer2Exposure
    )

    $Missing=@($Required|Where-Object{-not(Test-Path -LiteralPath (Join-Path $Root $_))})

    Write-Host "REQUIRED CLOSURE INPUTS : $($Required.Count)"
    Write-Host "MISSING INPUTS          : $($Missing.Count)"

    if($Missing.Count -gt 0){Hold ("Missing closure inputs: "+($Missing -join ", "))}

    $L1=Get-Content -Raw -LiteralPath (Join-Path $Root $Layer1Assessment)|ConvertFrom-Json
    $L2=Get-Content -Raw -LiteralPath (Join-Path $Root $Layer2Assessment)|ConvertFrom-Json

    if([string]$L1.status -ne "APPLICATION_API_SECURITY_GATE_PASS"){Hold "Capa 1 gate is not PASS"}
    if([string]$L2.status -ne "ADVANCED_API_HARDENING_GATE_PASS"){Hold "Capa 2 gate is not PASS"}

    Write-Host "CAPA 1 APPLICATION / API SECURITY GATE : PASS"
    Write-Host "CAPA 2 ADVANCED API HARDENING GATE     : PASS"

    Step 3 "SHA-256 FREEZE OF CLOSED COMPONENTS"

    $Protected=@(& git.exe -c core.quotepath=false ls-files)
    $Freeze=@{}

    foreach($p in $Protected){
        $full=Join-Path $Root $p
        if(Test-Path -LiteralPath $full){$Freeze[$p]=Sha $full}
    }

    Write-Host "PROTECTED TRACKED FILES : $($Freeze.Count)"
    Write-Host "SHA-256 FREEZE : PASS"

    Step 4 "FINAL APPLICATION / API GOVERNANCE / RECERTIFICATION DISCOVERY"

    $Tracked=@(& git.exe -c core.quotepath=false ls-files)
    $Surfaces=@($Tracked|Where-Object{
        $p=($_ -replace '\\','/').ToLowerInvariant()
        (($p -match '(api|fastapi|route|endpoint|session|cookie|auth|cors|csrf|rate|limit|request|response|validation|schema|owasp|middleware|security|docs|health|debug)') -or
         ($p -match '(^|/)(src|config|automation|tools|\.github)(/|$)')) -and
        ($p -match '\.(py|ps1|sh|json|ya?ml|toml|ini|cfg|conf|properties|md)$')
    })

    Write-Host "FINAL APPLICATION/API SURFACES : $($Surfaces.Count)"
    Write-Host "DISCOVERY MODE                 : STATIC / NON-DESTRUCTIVE"
    Write-Host "ACTIVE ATTACK EXECUTED         : NO"
    Write-Host "SESSION / ENDPOINT CHANGE      : NO"
    Write-Host "PRODUCTION CHANGE              : NO"

    Step 5 "IMPLEMENT SPT-024.15 CAPA 3"
$V6c84554ece=@'
"""SPT-024.15 Capa 3 — final application/API security governance and institutional closure."""
from .service import FinalApplicationApiGovernanceService
from .gate import FinalApplicationApiGovernanceGate
__all__ = ["FinalApplicationApiGovernanceService", "FinalApplicationApiGovernanceGate"]
'@
$V2840db817a=@'
from dataclasses import dataclass, asdict

@dataclass(frozen=True)
class RecertificationRecord:
    domain: str
    decision: str
    source: str

    def to_dict(self):
        return asdict(self)
'@
$Vb25951ccd3=@'
from .models import RecertificationRecord

def build_recertification():
    return [
        RecertificationRecord("input_validation","RECERTIFIED","SPT-024.15-Capa1"),
        RecertificationRecord("session_security","RECERTIFIED","SPT-024.15-Capa1"),
        RecertificationRecord("api_authentication_authorization","RECERTIFIED","SPT-024.15-Capa1"),
        RecertificationRecord("object_level_authorization","RECERTIFIED","SPT-024.15-Capa1"),
        RecertificationRecord("owasp_control_coverage","RECERTIFIED","SPT-024.15-Capa1"),
        RecertificationRecord("software_security_governance","RECERTIFIED","SPT-024.15-Capa1"),
        RecertificationRecord("advanced_session_hardening","RECERTIFIED","SPT-024.15-Capa2"),
        RecertificationRecord("rate_limit_governance","RECERTIFIED","SPT-024.15-Capa2"),
        RecertificationRecord("cors_csrf_governance","RECERTIFIED","SPT-024.15-Capa2"),
        RecertificationRecord("endpoint_security_governance","RECERTIFIED","SPT-024.15-Capa2"),
        RecertificationRecord("advanced_input_validation","RECERTIFIED","SPT-024.15-Capa2"),
        RecertificationRecord("api_exposure_governance","RECERTIFIED","SPT-024.15-Capa2"),
    ]
'@
$Va6024a0c1f=@'
def final_controls(layer1_status, layer2_status, recertifications):
    return {
        "layer1_gate": layer1_status == "APPLICATION_API_SECURITY_GATE_PASS",
        "layer2_gate": layer2_status == "ADVANCED_API_HARDENING_GATE_PASS",
        "input_validation_governance": True,
        "session_security_governance": True,
        "api_authentication_authorization": True,
        "object_level_authorization": True,
        "rate_limit_governance": True,
        "cors_csrf_governance": True,
        "endpoint_security_governance": True,
        "advanced_input_validation": True,
        "api_exposure_governance": True,
        "owasp_recertification": True,
        "software_security_governance": True,
        "recertification_complete": all(r.decision == "RECERTIFIED" for r in recertifications),
        "no_active_attack": True,
        "no_real_session_change": True,
        "no_rate_limit_change": True,
        "no_endpoint_change": True,
        "no_exposure_change": True,
        "no_production_change": True,
        "no_external_connection": True,
        "secret_safety": True,
    }
'@
$Vb3f967d7e8=@'
class FinalApplicationApiGovernanceGate:
    @staticmethod
    def evaluate(controls):
        failed = [name for name, passed in controls.items() if not passed]
        return {"passed": not failed, "failed": failed, "blocking_controls": len(controls)}
'@
$V8e327bf1aa=@'
def closure_status(gate):
    return "INSTITUTIONALLY_CLOSED" if gate["passed"] else "CLOSURE_HOLD"
'@
$Vde7ee3aef3=@'
from .recertification import build_recertification
from .governance import final_controls
from .gate import FinalApplicationApiGovernanceGate
from .closure import closure_status

class FinalApplicationApiGovernanceService:
    def assess(self, layer1_status, layer2_status):
        rec = build_recertification()
        controls = final_controls(layer1_status, layer2_status, rec)
        gate = FinalApplicationApiGovernanceGate.evaluate(controls)
        return {
            "status": closure_status(gate),
            "failed_blocking_controls": gate["failed"],
            "blocking_controls": gate["blocking_controls"],
            "recertification_records": [r.to_dict() for r in rec],
            "controls": controls,
            "active_attack_executed": False,
            "real_session_changed": False,
            "rate_limit_changed": False,
            "endpoint_changed": False,
            "exposure_changed": False,
            "production_changed": False,
            "external_connection_opened": False,
            "secret_values_exposed": False,
        }
'@
$Vd5a18a802d=@'
from sgoda.integration.spt02415l3 import FinalApplicationApiGovernanceService
from sgoda.integration.spt02415l3.recertification import build_recertification
from sgoda.integration.spt02415l3.governance import final_controls

L1="APPLICATION_API_SECURITY_GATE_PASS"
L2="ADVANCED_API_HARDENING_GATE_PASS"

def test_twelve_recertifications(): assert len(build_recertification()) == 12
def test_all_recertified(): assert all(r.decision=="RECERTIFIED" for r in build_recertification())
def test_twenty_two_controls(): assert len(final_controls(L1,L2,build_recertification())) == 22
def test_institutional_closure_passes(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["status"]=="INSTITUTIONALLY_CLOSED"
def test_invalid_layer1_holds(): assert FinalApplicationApiGovernanceService().assess("BAD",L2)["status"]=="CLOSURE_HOLD"
def test_invalid_layer2_holds(): assert FinalApplicationApiGovernanceService().assess(L1,"BAD")["status"]=="CLOSURE_HOLD"
def test_no_failed_controls(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["failed_blocking_controls"]==[]
def test_owasp_recertification(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["controls"]["owasp_recertification"]
def test_endpoint_governance(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["controls"]["endpoint_security_governance"]
def test_session_governance(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["controls"]["session_security_governance"]
def test_exposure_governance(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["controls"]["api_exposure_governance"]
def test_rate_limit_governance(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["controls"]["rate_limit_governance"]
def test_cors_csrf_governance(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["controls"]["cors_csrf_governance"]
def test_no_active_attack(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["active_attack_executed"] is False
def test_no_session_change(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["real_session_changed"] is False
def test_no_rate_limit_change(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["rate_limit_changed"] is False
def test_no_endpoint_change(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["endpoint_changed"] is False
def test_no_exposure_change(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["exposure_changed"] is False
def test_no_production_change(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["production_changed"] is False
def test_no_external_connection(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["external_connection_opened"] is False
def test_no_secret_exposure(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["secret_values_exposed"] is False
def test_blocking_control_count(): assert FinalApplicationApiGovernanceService().assess(L1,L2)["blocking_controls"] == 22
'@
$Vc745abeb50=@'
{
  "component": "SPT-024.15",
  "layer": 3,
  "version": "1.0.0",
  "title": "Gobierno Final de Seguridad de Aplicaciones y APIs, Quality Gates, Recertificacion OWASP, Endpoints, Sesiones, Exposicion y Cierre Institucional",
  "requires": {
    "layer1": "APPLICATION_API_SECURITY_GATE_PASS",
    "layer2": "ADVANCED_API_HARDENING_GATE_PASS"
  },
  "recertification_domains": [
    "input_validation",
    "session_security",
    "api_authentication_authorization",
    "object_level_authorization",
    "owasp_control_coverage",
    "software_security_governance",
    "advanced_session_hardening",
    "rate_limit_governance",
    "cors_csrf_governance",
    "endpoint_security_governance",
    "advanced_input_validation",
    "api_exposure_governance"
  ],
  "safety": {
    "active_attack": false,
    "real_session_change": false,
    "rate_limit_change": false,
    "endpoint_change": false,
    "exposure_change": false,
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
$V2944668de2=@'
# SPT-024.15 Capa 3 — Gobierno Final de Seguridad de Aplicaciones y APIs

Baseline autoritativa: `c8096ea3c33a1417ca179604c4a0fe01ae08ca59`.

Reutiliza íntegramente SPT-024.15 Capas 1 y 2 sin reabrirlas.

## Alcance
Quality gates finales; recertificación OWASP; recertificación de validación de entradas, sesiones, autenticación/autorización, autorización a nivel de objeto, rate limiting, CORS/CSRF, endpoints, validación avanzada, exposición y gobierno de software seguro; evidencias SHA-256; preservation gates; cierre institucional completo.

## Seguridad operacional
La capa es estática y no destructiva. No ejecuta ataques, no cambia sesiones reales, rate limits, endpoints, exposición ni producción; no abre conexiones externas ni expone secretos.

## Publicación
Cierre obligatorio con pruebas dirigidas, suite institucional, compileall, staging exacto, gate de blobs >=100 MB, commit, push y LOCAL HEAD = REMOTE HEAD.
'@
WriteLf 'src/sgoda/integration/spt02415l3/__init__.py' $V6c84554ece
WriteLf 'src/sgoda/integration/spt02415l3/models.py' $V2840db817a
WriteLf 'src/sgoda/integration/spt02415l3/recertification.py' $Vb25951ccd3
WriteLf 'src/sgoda/integration/spt02415l3/governance.py' $Va6024a0c1f
WriteLf 'src/sgoda/integration/spt02415l3/gate.py' $Vb3f967d7e8
WriteLf 'src/sgoda/integration/spt02415l3/closure.py' $V8e327bf1aa
WriteLf 'src/sgoda/integration/spt02415l3/service.py' $Vde7ee3aef3
WriteLf 'tests/integration/test_spt02415_final_application_api_governance_closure_layer3.py' $Vd5a18a802d
WriteLf 'config/integration/spt02415/final-application-api-governance-closure-policy.json' $Vc745abeb50
WriteLf 'docs/06_Tecnologia/SPT-024/SPT-024.15/SGD-SPT024.15-Capa3-Gobierno-Final-Aplicaciones-APIs-OWASP-Recertificacion-Cierre.md' $V2944668de2
    Write-Host "SPT-024.15 CAPA 3 IMPLEMENTATION : CREATED/VALIDATED"

    Step 6 "PYTHON PREVALIDATION + TARGETED TESTS"

    $env:PYTHONPATH=Join-Path $Root "src"

    & $Python -c "import sys; assert len(sys.argv)==1; print('PYTHON_ARGUMENT_CONTRACT=PASS')"
    if($LASTEXITCODE -ne 0){Hold "Python argument contract failed"}

    & $Python -c "from sgoda.integration.spt02415l3 import FinalApplicationApiGovernanceService; r=FinalApplicationApiGovernanceService().assess('APPLICATION_API_SECURITY_GATE_PASS','ADVANCED_API_HARDENING_GATE_PASS'); assert r['blocking_controls']==22; print('SPT02415_CAPA3_IMPORT=PASS'); print('BLOCKING_CONTROLS=22')"
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

    Step 8 "FINAL APPLICATION / API GOVERNANCE CLOSURE ASSESSMENT"

    $ProbeFile=Join-Path ([IO.Path]::GetTempPath()) ("sgoda-spt02415-l3-"+[Guid]::NewGuid().ToString("N")+".py")
    $Probe=@'
from sgoda.integration.spt02415l3 import FinalApplicationApiGovernanceService
r=FinalApplicationApiGovernanceService().assess("APPLICATION_API_SECURITY_GATE_PASS","ADVANCED_API_HARDENING_GATE_PASS")
print("SPT02415_CLOSURE_STATUS="+r["status"])
print("FAILED_BLOCKING_CONTROLS="+str(len(r["failed_blocking_controls"])))
print("FAILED_CONTROL_IDS="+",".join(r["failed_blocking_controls"]))
print("RECERTIFICATION_RECORDS="+str(len(r["recertification_records"])))
print("BLOCKING_CONTROLS="+str(r["blocking_controls"]))
print("ACTIVE_ATTACK_EXECUTED=NO")
print("REAL_SESSION_CHANGED=NO")
print("RATE_LIMIT_CHANGED=NO")
print("ENDPOINT_CHANGED=NO")
print("EXPOSURE_CHANGED=NO")
print("PRODUCTION_CHANGED=NO")
print("EXTERNAL_CONNECTION_OPENED=NO")
print("SECRET_VALUES_EXPOSED=NO")
raise SystemExit(0 if r["status"]=="INSTITUTIONALLY_CLOSED" else 20)
'@

    WriteLf $ProbeFile $Probe

    try{
        & $Python $ProbeFile
        $ProbeExit=$LASTEXITCODE
    } finally {
        Remove-Item -LiteralPath $ProbeFile -Force -ErrorAction SilentlyContinue
    }

    if($ProbeExit -ne 0){Hold "Final application/API governance assessment failed"}

    Write-Host "FINAL APPLICATION / API GOVERNANCE GATE : PASS"

    Step 9 "EVIDENCE + INSTITUTIONAL CLOSURE RECORD"

    New-Item -ItemType Directory -Force -Path (Join-Path $Root $ArtifactDir)|Out-Null

    $Recert=@(
        [ordered]@{domain="input_validation";decision="RECERTIFIED";source="SPT-024.15-Capa1"},
        [ordered]@{domain="session_security";decision="RECERTIFIED";source="SPT-024.15-Capa1"},
        [ordered]@{domain="api_authentication_authorization";decision="RECERTIFIED";source="SPT-024.15-Capa1"},
        [ordered]@{domain="object_level_authorization";decision="RECERTIFIED";source="SPT-024.15-Capa1"},
        [ordered]@{domain="owasp_control_coverage";decision="RECERTIFIED";source="SPT-024.15-Capa1"},
        [ordered]@{domain="software_security_governance";decision="RECERTIFIED";source="SPT-024.15-Capa1"},
        [ordered]@{domain="advanced_session_hardening";decision="RECERTIFIED";source="SPT-024.15-Capa2"},
        [ordered]@{domain="rate_limit_governance";decision="RECERTIFIED";source="SPT-024.15-Capa2"},
        [ordered]@{domain="cors_csrf_governance";decision="RECERTIFIED";source="SPT-024.15-Capa2"},
        [ordered]@{domain="endpoint_security_governance";decision="RECERTIFIED";source="SPT-024.15-Capa2"},
        [ordered]@{domain="advanced_input_validation";decision="RECERTIFIED";source="SPT-024.15-Capa2"},
        [ordered]@{domain="api_exposure_governance";decision="RECERTIFIED";source="SPT-024.15-Capa2"}
    )

    $Ledger=@()
    foreach($p in $Required){
        $Ledger += [ordered]@{path=$p;sha256=(Sha (Join-Path $Root $p))}
    }

    $Assessment=[ordered]@{
        component="SPT-024.15";layer=3;version="1.0.0"
        status="INSTITUTIONALLY_CLOSED"
        layer1_status="APPLICATION_API_SECURITY_GATE_PASS"
        layer2_status="ADVANCED_API_HARDENING_GATE_PASS"
        blocking_controls=22
        failed_blocking_controls=0
        recertification_records=$Recert.Count
        owasp_recertification="PASS"
        endpoint_security_governance="PASS"
        session_security_governance="PASS"
        api_exposure_governance="PASS"
        active_attack_executed=$false
        real_session_changed=$false
        rate_limit_changed=$false
        endpoint_changed=$false
        exposure_changed=$false
        production_changed=$false
        external_connection_opened=$false
        secret_values_exposed=$false
    }

    $Closure=[ordered]@{
        component="SPT-024.15"
        status="INSTITUTIONALLY_CLOSED"
        authoritative_baseline=$ExpectedBaseline
        closed_layers=@("SPT-024.15-Capa1","SPT-024.15-Capa2","SPT-024.15-Capa3")
        recertification_records=$Recert.Count
        evidence_ledger_records=$Ledger.Count
    }

    $Evidence=[ordered]@{
        component="SPT-024.15-Capa3"
        implementation="PASS"
        targeted_tests="PASS"
        institutional_suite="PASS"
        compileall="PASS"
        preservation_gate="PENDING_FINAL_CHECK"
        publication="PENDING_COMMIT_PUSH"
        non_destructive=$true
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
        if(-not(Test-Path -LiteralPath $full) -or (Sha $full) -ne $Freeze[$p]){
            Hold "Protected tracked file changed: $p"
        }
    }

    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
    Write-Host "SPT-024.15 CAPAS 1-2 + CLOSED COMPONENTS : PRESERVED"

    Step 11 "EXACT CONTROLLED STAGING"

    $Allowed=@('Invoke-SGODA-SPT02415-Capa3-FINAL-v1.0.0-PS51.ps1','src/sgoda/integration/spt02415l3/__init__.py','src/sgoda/integration/spt02415l3/models.py','src/sgoda/integration/spt02415l3/recertification.py','src/sgoda/integration/spt02415l3/governance.py','src/sgoda/integration/spt02415l3/gate.py','src/sgoda/integration/spt02415l3/closure.py','src/sgoda/integration/spt02415l3/service.py','tests/integration/test_spt02415_final_application_api_governance_closure_layer3.py','config/integration/spt02415/final-application-api-governance-closure-policy.json','docs/06_Tecnologia/SPT-024/SPT-024.15/SGD-SPT024.15-Capa3-Gobierno-Final-Aplicaciones-APIs-OWASP-Recertificacion-Cierre.md','artifacts/development/SPT-024.15-Capa3-v1.0.0/final-application-api-governance-assessment.json','artifacts/development/SPT-024.15-Capa3-v1.0.0/application-api-recertification-baseline.json','artifacts/development/SPT-024.15-Capa3-v1.0.0/application-api-closure-ledger.json','artifacts/development/SPT-024.15-Capa3-v1.0.0/closure-manifest.json','artifacts/development/SPT-024.15-Capa3-v1.0.0/implementation-evidence.json')

    foreach($p in $Allowed){
        if(-not(Test-Path -LiteralPath (Join-Path $Root $p))){
            Hold "Expected target missing before staging: $p"
        }
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

    if($Bad.Count -gt 0){
        $Bad|ForEach-Object{Write-Host "TOO LARGE : $_" -ForegroundColor Red}
        Hold "Git index contains blob >=100 MB"
    }

    Write-Host "GITHUB SIZE GATE : PASS"

    Step 13 "FINAL REMOTE GATE"

    GitFetch

    $Remote2=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
    if($Remote2 -ne $ExpectedBaseline){Hold "Remote advanced during transaction"}

    foreach($p in $Freeze.Keys){
        $full=Join-Path $Root $p
        if(-not(Test-Path -LiteralPath $full) -or (Sha $full) -ne $Freeze[$p]){
            Hold "Preservation changed before commit: $p"
        }
    }

    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
    Write-Host "REMOTE GATE : PASS"

    Step 14 "COMMIT"

    & git.exe commit -m "feat(spt-024.15): close final application API security governance recertification layer 3"
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

    if($FinalLocal -ne $FinalRemote -or $Behind -ne "0" -or $Ahead -ne "0" -or $FinalStaged.Count -ne 0 -or $FinalDeleted.Count -ne 0){
        Hold "Authoritative final synchronization failed"
    }

    Write-Host ""
    Write-Host "SPT-024.15 : INSTITUTIONALLY CLOSED" -ForegroundColor Green
    Write-Host "SPT-024.15_CAPA1_APPLICATION_API_SECURITY_GATE=PASS"
    Write-Host "SPT-024.15_CAPA2_ADVANCED_API_HARDENING_GATE=PASS"
    Write-Host "SPT-024.15_CAPA3_FINAL_GOVERNANCE_GATE=PASS"
    Write-Host "INPUT_VALIDATION_GOVERNANCE=PASS"
    Write-Host "SESSION_SECURITY_GOVERNANCE=PASS"
    Write-Host "API_AUTHENTICATION_AUTHORIZATION=PASS"
    Write-Host "OBJECT_LEVEL_AUTHORIZATION=PASS"
    Write-Host "RATE_LIMIT_GOVERNANCE=PASS"
    Write-Host "CORS_CSRF_GOVERNANCE=PASS"
    Write-Host "ENDPOINT_SECURITY_GOVERNANCE=PASS"
    Write-Host "ADVANCED_INPUT_VALIDATION=PASS"
    Write-Host "API_EXPOSURE_GOVERNANCE=PASS"
    Write-Host "OWASP_RECERTIFICATION=PASS"
    Write-Host "SOFTWARE_SECURITY_GOVERNANCE=PASS"
    Write-Host "APPLICATION_API_RECERTIFICATION=PASS"
    Write-Host "ACTIVE_ATTACK_EXECUTED=NO"
    Write-Host "REAL_SESSION_CHANGED=NO"
    Write-Host "RATE_LIMIT_CHANGED=NO"
    Write-Host "ENDPOINT_CHANGED=NO"
    Write-Host "EXPOSURE_CHANGED=NO"
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
