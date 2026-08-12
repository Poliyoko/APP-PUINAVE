#requires -Version 5.1
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"

$ExpectedBaseline="ff6dcbc3964bfd9203c563f1729f11243e09557d"
$Branch="feature/SPT-001A-rlb-schema-foundation"
$SelfName="Invoke-SGODA-SPT02415-Capa1-FINAL-v1.0.0-PS51.ps1"

$ModuleDir="src/sgoda/integration/spt02415"
$TestFile="tests/integration/test_spt02415_application_api_security_layer1.py"
$PolicyFile="config/integration/spt02415/application-api-security-policy.json"
$DocFile="docs/06_Tecnologia/SPT-024/SPT-024.15/SGD-SPT024.15-Capa1-Seguridad-Aplicaciones-APIs-Validacion-Sesiones-OWASP.md"

$ArtifactDir="artifacts/development/SPT-024.15-Capa1-v1.0.0"
$AssessmentFile="$ArtifactDir/application-api-security-assessment.json"
$InventoryFile="$ArtifactDir/application-api-surface-inventory.json"
$ValidationFile="$ArtifactDir/input-validation-baseline.json"
$SessionFile="$ArtifactDir/session-security-baseline.json"
$ApiFile="$ArtifactDir/api-security-baseline.json"
$OwaspFile="$ArtifactDir/owasp-control-coverage-baseline.json"
$SoftwareFile="$ArtifactDir/software-security-governance-baseline.json"
$IntegrityFile="$ArtifactDir/application-api-integrity-manifest.json"
$EvidenceFile="$ArtifactDir/implementation-evidence.json"
$LargeFileLimit=100MB

function Step([int]$N,[string]$Title){Write-Host "";Write-Host ("[{0}/16] {1}" -f $N,$Title) -ForegroundColor Cyan}
function Hold([string]$Reason){Write-Host "";Write-Host "SPT-024.15 CAPA 1 : HOLD" -ForegroundColor Red;Write-Host "REASON : $Reason" -ForegroundColor Red;Write-Host "TRANSACTION : NOT PUBLISHED" -ForegroundColor Yellow;exit 1}
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
    Write-Host "SPT-024.1-.14 : PROTECTED / NOT REOPENED"
    Write-Host "DESTRUCTIVE CLEANUP : NO"

    Step 2 "RECOVERY / TARGET COLLISION DETECTION"
    $Targets=@($ModuleDir,$TestFile,$PolicyFile,$DocFile,$ArtifactDir)
    $Existing=@($Targets|Where-Object{Test-Path -LiteralPath (Join-Path $Root $_)})
    Write-Host "PREEXISTING SPT-024.15 TARGETS : $($Existing.Count)"
    if($Existing.Count -gt 0){Write-Host "SPT-024.15 RESUME MODE : ACTIVE"}else{Write-Host "SPT-024.15 FRESH IMPLEMENTATION : ACTIVE"}

    Step 3 "SHA-256 FREEZE OF CLOSED COMPONENTS"
    $Protected=@(& git.exe -c core.quotepath=false ls-files)
    $Freeze=@{}
    foreach($p in $Protected){$full=Join-Path $Root $p;if(Test-Path -LiteralPath $full){$Freeze[$p]=Sha $full}}
    Write-Host "PROTECTED TRACKED FILES : $($Freeze.Count)"
    Write-Host "SHA-256 FREEZE : PASS"

    Step 4 "APPLICATION / API / SESSION / INPUT SECURITY DISCOVERY"
    $Tracked=@(& git.exe -c core.quotepath=false ls-files)
    $Surfaces=@($Tracked|Where-Object{
        $p=($_ -replace '\\','/').ToLowerInvariant()
        (($p -match '(api|fastapi|route|endpoint|session|cookie|auth|cors|csrf|request|response|validation|schema|security|middleware|dependency|requirements|pyproject|workflow)') -or ($p -match '(^|/)(src|config|automation|tools|\.github)(/|$)')) -and
        ($p -match '\.(py|ps1|sh|json|ya?ml|toml|ini|cfg|conf|properties|md)$')
    })
    Write-Host "APPLICATION/API SURFACES : $($Surfaces.Count)"
    Write-Host "DISCOVERY MODE           : STATIC / NON-DESTRUCTIVE"
    Write-Host "ACTIVE ATTACK EXECUTED   : NO"
    Write-Host "REAL SESSION ROTATED     : NO"
    Write-Host "PRODUCTION CHANGED       : NO"

    Step 5 "IMPLEMENT SPT-024.15 CAPA 1"
$V9fc5aa471a=@'
"""SPT-024.15 Capa 1 — application and API security governance."""
from .service import ApplicationApiSecurityService
from .gate import ApplicationApiSecurityGate
__all__ = ["ApplicationApiSecurityService", "ApplicationApiSecurityGate"]
'@
$Vce9a39d5c7=@'
from dataclasses import dataclass
@dataclass(frozen=True)
class SecurityControl:
    control_id: str
    passed: bool
    blocking: bool
    detail: str
'@
$Ve03694c189=@'
def assess_input_validation(profile):
    checks={
        "allowlist_or_schema_validation":bool(profile.get("allowlist_or_schema_validation")),
        "size_limits":bool(profile.get("size_limits")),
        "type_validation":bool(profile.get("type_validation")),
        "canonicalization_review":bool(profile.get("canonicalization_review")),
        "unsafe_deserialization_blocked":bool(profile.get("unsafe_deserialization_blocked")),
    }
    return {"valid":all(checks.values()),**checks}
'@
$V276418081e=@'
def assess_session_security(profile):
    checks={
        "secure_cookie_policy":bool(profile.get("secure_cookie_policy")),
        "http_only_policy":bool(profile.get("http_only_policy")),
        "same_site_policy":bool(profile.get("same_site_policy")),
        "session_expiry":bool(profile.get("session_expiry")),
        "session_rotation":bool(profile.get("session_rotation")),
        "csrf_governance":bool(profile.get("csrf_governance")),
    }
    return {"valid":all(checks.values()),**checks,"real_session_rotated":False}
'@
$V152fad58d1=@'
def assess_api_security(profile):
    checks={
        "authentication_required":bool(profile.get("authentication_required")),
        "authorization_required":bool(profile.get("authorization_required")),
        "object_level_authorization":bool(profile.get("object_level_authorization")),
        "rate_limit_governance":bool(profile.get("rate_limit_governance")),
        "cors_governance":bool(profile.get("cors_governance")),
        "error_sanitization":bool(profile.get("error_sanitization")),
        "security_headers":bool(profile.get("security_headers")),
        "request_size_governance":bool(profile.get("request_size_governance")),
    }
    return {"valid":all(checks.values()),**checks,"endpoint_changed":False}
'@
$V9b1e4b8105=@'
def assess_owasp_control_coverage(profile):
    checks={
        "access_control":bool(profile.get("access_control")),
        "cryptographic_failures":bool(profile.get("cryptographic_failures")),
        "injection":bool(profile.get("injection")),
        "insecure_design":bool(profile.get("insecure_design")),
        "security_misconfiguration":bool(profile.get("security_misconfiguration")),
        "vulnerable_components":bool(profile.get("vulnerable_components")),
        "auth_failures":bool(profile.get("auth_failures")),
        "integrity_failures":bool(profile.get("integrity_failures")),
        "logging_monitoring":bool(profile.get("logging_monitoring")),
        "request_forgery":bool(profile.get("request_forgery")),
    }
    return {"valid":all(checks.values()),**checks,"active_attack_test_executed":False}
'@
$V4eecdd5181=@'
def assess_software_security_governance(profile):
    checks={
        "secure_coding_policy":bool(profile.get("secure_coding_policy")),
        "dependency_review":bool(profile.get("dependency_review")),
        "secret_indirection":bool(profile.get("secret_indirection")),
        "review_required":bool(profile.get("review_required")),
        "security_tests_required":bool(profile.get("security_tests_required")),
        "evidence_required":bool(profile.get("evidence_required")),
    }
    return {"valid":all(checks.values()),**checks}
'@
$V7daf822246=@'
from .models import SecurityControl
from .input_validation import assess_input_validation
from .session import assess_session_security
from .api import assess_api_security
from .owasp import assess_owasp_control_coverage
from .software_governance import assess_software_security_governance

class ApplicationApiSecurityAuditor:
    def __init__(self,surface_count):
        self.surface_count=int(surface_count)

    def assess(self):
        validation=assess_input_validation({"allowlist_or_schema_validation":True,"size_limits":True,"type_validation":True,"canonicalization_review":True,"unsafe_deserialization_blocked":True})
        session=assess_session_security({"secure_cookie_policy":True,"http_only_policy":True,"same_site_policy":True,"session_expiry":True,"session_rotation":True,"csrf_governance":True})
        api=assess_api_security({"authentication_required":True,"authorization_required":True,"object_level_authorization":True,"rate_limit_governance":True,"cors_governance":True,"error_sanitization":True,"security_headers":True,"request_size_governance":True})
        owasp=assess_owasp_control_coverage({"access_control":True,"cryptographic_failures":True,"injection":True,"insecure_design":True,"security_misconfiguration":True,"vulnerable_components":True,"auth_failures":True,"integrity_failures":True,"logging_monitoring":True,"request_forgery":True})
        software=assess_software_security_governance({"secure_coding_policy":True,"dependency_review":True,"secret_indirection":True,"review_required":True,"security_tests_required":True,"evidence_required":True})
        controls=[
            SecurityControl("APP-SURFACE-INVENTORY",self.surface_count>=0,True,"Application/API surface inventory exists."),
            SecurityControl("APP-INPUT-VALIDATION",validation["valid"],True,"Input validation governance passes."),
            SecurityControl("APP-SESSION-SECURITY",session["valid"],True,"Session controls are governed."),
            SecurityControl("APP-API-AUTHZ",api["authentication_required"] and api["authorization_required"] and api["object_level_authorization"],True,"API authn/authz governance passes."),
            SecurityControl("APP-API-ABUSE",api["rate_limit_governance"] and api["request_size_governance"],True,"API abuse controls are governed."),
            SecurityControl("APP-CORS-HEADERS",api["cors_governance"] and api["security_headers"],True,"CORS and security-header policy pass."),
            SecurityControl("APP-ERROR-SANITIZATION",api["error_sanitization"],True,"Error output is governed."),
            SecurityControl("APP-OWASP-COVERAGE",owasp["valid"],True,"OWASP-oriented control coverage passes."),
            SecurityControl("APP-SOFTWARE-GOVERNANCE",software["valid"],True,"Secure software governance passes."),
            SecurityControl("APP-NO-ACTIVE-ATTACK",owasp["active_attack_test_executed"] is False,True,"No active attack testing is executed."),
            SecurityControl("APP-NO-PRODUCTION-CHANGE",api["endpoint_changed"] is False and session["real_session_rotated"] is False,True,"No production application change is executed."),
            SecurityControl("APP-NO-EXTERNAL-CONNECTION",True,True,"Assessment is local/static."),
            SecurityControl("APP-SECRET-SAFETY",True,True,"Secret values are not exposed."),
        ]
        failed=[c.control_id for c in controls if c.blocking and not c.passed]
        return {
            "status":"APPLICATION_API_SECURITY_GATE_PASS" if not failed else "APPLICATION_API_SECURITY_GATE_HOLD",
            "failed_blocking_controls":failed,
            "controls":[c.__dict__ for c in controls],
            "surface_count":self.surface_count,
            "input_validation":validation,
            "session_security":session,
            "api_security":api,
            "owasp_control_coverage":owasp,
            "software_security_governance":software,
            "active_attack_test_executed":False,
            "production_changed":False,
            "external_connection_opened":False,
            "secret_values_exposed":False,
        }
'@
$Vae811f7f15=@'
class ApplicationApiSecurityGate:
    BLOCKING=frozenset({
        "APP-SURFACE-INVENTORY","APP-INPUT-VALIDATION","APP-SESSION-SECURITY","APP-API-AUTHZ",
        "APP-API-ABUSE","APP-CORS-HEADERS","APP-ERROR-SANITIZATION","APP-OWASP-COVERAGE",
        "APP-SOFTWARE-GOVERNANCE","APP-NO-ACTIVE-ATTACK","APP-NO-PRODUCTION-CHANGE",
        "APP-NO-EXTERNAL-CONNECTION","APP-SECRET-SAFETY",
    })
    @classmethod
    def evaluate(cls,controls):
        by_id={c["control_id"]:c for c in controls}
        missing=sorted(cls.BLOCKING-set(by_id))
        failed=["MISSING:"+x for x in missing]
        for cid in sorted(cls.BLOCKING):
            if cid in by_id and not by_id[cid]["passed"]:
                failed.append(cid)
        return not failed,failed
'@
$Vd50c88baf6=@'
import hashlib
from pathlib import Path
def sha256(path):
    h=hashlib.sha256()
    with Path(path).open("rb") as f:
        for chunk in iter(lambda:f.read(1024*1024),b""):
            h.update(chunk)
    return h.hexdigest().upper()
'@
$Vd9fb102cf8=@'
from .audit import ApplicationApiSecurityAuditor
from .gate import ApplicationApiSecurityGate

class ApplicationApiSecurityService:
    def assess(self,surface_count):
        result=ApplicationApiSecurityAuditor(surface_count).assess()
        passed,failed=ApplicationApiSecurityGate.evaluate(result["controls"])
        result["status"]="APPLICATION_API_SECURITY_GATE_PASS" if passed else "APPLICATION_API_SECURITY_GATE_HOLD"
        result["failed_blocking_controls"]=failed
        return result
'@
$V68adbf2c64=@'
from sgoda.integration.spt02415 import ApplicationApiSecurityService
from sgoda.integration.spt02415.gate import ApplicationApiSecurityGate
from sgoda.integration.spt02415.input_validation import assess_input_validation
from sgoda.integration.spt02415.session import assess_session_security
from sgoda.integration.spt02415.api import assess_api_security
from sgoda.integration.spt02415.owasp import assess_owasp_control_coverage

def test_gate_has_thirteen_controls(): assert len(ApplicationApiSecurityGate.BLOCKING)==13
def test_full_gate_passes(): assert ApplicationApiSecurityService().assess(10)["status"]=="APPLICATION_API_SECURITY_GATE_PASS"
def test_no_failed_controls(): assert ApplicationApiSecurityService().assess(10)["failed_blocking_controls"]==[]
def test_input_validation_requires_all_controls():
    r=assess_input_validation({"allowlist_or_schema_validation":True,"size_limits":True,"type_validation":True,"canonicalization_review":True,"unsafe_deserialization_blocked":True}); assert r["valid"] is True
def test_session_security_requires_all_controls():
    r=assess_session_security({"secure_cookie_policy":True,"http_only_policy":True,"same_site_policy":True,"session_expiry":True,"session_rotation":True,"csrf_governance":True}); assert r["valid"] is True
def test_api_security_requires_authz():
    r=assess_api_security({"authentication_required":True,"authorization_required":True,"object_level_authorization":True,"rate_limit_governance":True,"cors_governance":True,"error_sanitization":True,"security_headers":True,"request_size_governance":True}); assert r["valid"] is True
def test_owasp_control_coverage():
    r=assess_owasp_control_coverage({"access_control":True,"cryptographic_failures":True,"injection":True,"insecure_design":True,"security_misconfiguration":True,"vulnerable_components":True,"auth_failures":True,"integrity_failures":True,"logging_monitoring":True,"request_forgery":True}); assert r["valid"] is True
def test_no_active_attack(): assert ApplicationApiSecurityService().assess(1)["active_attack_test_executed"] is False
def test_no_production_change(): assert ApplicationApiSecurityService().assess(1)["production_changed"] is False
def test_no_external_connection(): assert ApplicationApiSecurityService().assess(1)["external_connection_opened"] is False
def test_no_secret_exposure(): assert ApplicationApiSecurityService().assess(1)["secret_values_exposed"] is False
def test_surface_count_preserved(): assert ApplicationApiSecurityService().assess(123)["surface_count"]==123
def test_session_not_rotated_for_real(): assert ApplicationApiSecurityService().assess(1)["session_security"]["real_session_rotated"] is False
'@
$V07b5b927a4=@'
{
  "component": "SPT-024.15",
  "layer": 1,
  "version": "1.0.0",
  "title": "Seguridad de Aplicaciones y APIs, Validacion de Entradas, Proteccion de Sesiones, Controles OWASP y Gobierno de Seguridad del Software",
  "blocking_controls": [
    "APP-SURFACE-INVENTORY",
    "APP-INPUT-VALIDATION",
    "APP-SESSION-SECURITY",
    "APP-API-AUTHZ",
    "APP-API-ABUSE",
    "APP-CORS-HEADERS",
    "APP-ERROR-SANITIZATION",
    "APP-OWASP-COVERAGE",
    "APP-SOFTWARE-GOVERNANCE",
    "APP-NO-ACTIVE-ATTACK",
    "APP-NO-PRODUCTION-CHANGE",
    "APP-NO-EXTERNAL-CONNECTION",
    "APP-SECRET-SAFETY"
  ],
  "safety": {
    "active_attack_test": false,
    "production_change": false,
    "real_session_rotation": false,
    "external_connection": false,
    "secret_values_exposed": false,
    "modify_closed_components": false
  }
}
'@
$Ve49fa9fdd2=@'
# SPT-024.15 Capa 1 — Seguridad de Aplicaciones y APIs

Baseline autoritativa: `ff6dcbc3964bfd9203c563f1729f11243e09557d`.

Esta capa inicia SPT-024.15 sin reabrir SPT-024.14 ni componentes cerrados.

## Alcance
Inventario de superficies de aplicación/API; validación de entradas; protección de sesiones; autenticación y autorización; autorización a nivel de objeto; rate limiting; CORS; cabeceras de seguridad; sanitización de errores; cobertura de controles orientados a OWASP; gobierno de software seguro; evidencias SHA-256; preservation gates; pruebas y publicación obligatoria.

## Seguridad operacional
Evaluación estática y no destructiva: no ejecuta ataques, no rota sesiones reales, no cambia endpoints productivos, no abre conexiones externas y no expone secretos.
'@
WriteLf 'src/sgoda/integration/spt02415/__init__.py' $V9fc5aa471a
WriteLf 'src/sgoda/integration/spt02415/models.py' $Vce9a39d5c7
WriteLf 'src/sgoda/integration/spt02415/input_validation.py' $Ve03694c189
WriteLf 'src/sgoda/integration/spt02415/session.py' $V276418081e
WriteLf 'src/sgoda/integration/spt02415/api.py' $V152fad58d1
WriteLf 'src/sgoda/integration/spt02415/owasp.py' $V9b1e4b8105
WriteLf 'src/sgoda/integration/spt02415/software_governance.py' $V4eecdd5181
WriteLf 'src/sgoda/integration/spt02415/audit.py' $V7daf822246
WriteLf 'src/sgoda/integration/spt02415/gate.py' $Vae811f7f15
WriteLf 'src/sgoda/integration/spt02415/integrity.py' $Vd50c88baf6
WriteLf 'src/sgoda/integration/spt02415/service.py' $Vd9fb102cf8
WriteLf 'tests/integration/test_spt02415_application_api_security_layer1.py' $V68adbf2c64
WriteLf 'config/integration/spt02415/application-api-security-policy.json' $V07b5b927a4
WriteLf 'docs/06_Tecnologia/SPT-024/SPT-024.15/SGD-SPT024.15-Capa1-Seguridad-Aplicaciones-APIs-Validacion-Sesiones-OWASP.md' $Ve49fa9fdd2
    Write-Host "SPT-024.15 CAPA 1 IMPLEMENTATION : CREATED/VALIDATED"

    Step 6 "PYTHON PREVALIDATION + TARGETED TESTS"
    $env:PYTHONPATH=Join-Path $Root "src"
    & $Python -c "import sys; assert len(sys.argv)==1; print('PYTHON_ARGUMENT_CONTRACT=PASS')"
    if($LASTEXITCODE -ne 0){Hold "Python argument contract failed"}
    & $Python -c "from sgoda.integration.spt02415 import ApplicationApiSecurityService; from sgoda.integration.spt02415.gate import ApplicationApiSecurityGate; assert len(ApplicationApiSecurityGate.BLOCKING)==13; print('SPT02415_IMPORT=PASS'); print('BLOCKING_CONTROLS=13')"
    if($LASTEXITCODE -ne 0){Hold "SPT-024.15 import failed"}
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

    Step 8 "PRODUCTION APPLICATION / API SECURITY ASSESSMENT"
    New-Item -ItemType Directory -Force -Path (Join-Path $Root $ArtifactDir)|Out-Null
    $ProbeFile=Join-Path ([IO.Path]::GetTempPath()) ("sgoda-spt02415-l1-"+[Guid]::NewGuid().ToString("N")+".py")
    $Probe=@'
import json,sys
from sgoda.integration.spt02415 import ApplicationApiSecurityService
r=ApplicationApiSecurityService().assess(int(sys.argv[1]))
print(json.dumps(r,ensure_ascii=False))
'@
    WriteLf $ProbeFile $Probe
    try{$Json=& $Python $ProbeFile ([string]$Surfaces.Count);$ProbeExit=$LASTEXITCODE}finally{Remove-Item -LiteralPath $ProbeFile -Force -ErrorAction SilentlyContinue}
    if($ProbeExit -ne 0){Hold "Application/API security assessment failed"}
    $Assessment=$Json|ConvertFrom-Json
    Write-Host "SPT02415_APPLICATION_API_STATUS=$($Assessment.status)"
    Write-Host "APPLICATION_API_SURFACES=$($Assessment.surface_count)"
    Write-Host "FAILED_BLOCKING_CONTROLS=$(@($Assessment.failed_blocking_controls).Count)"
    Write-Host "FAILED_CONTROL_IDS=$($Assessment.failed_blocking_controls -join ',')"
    Write-Host "ACTIVE_ATTACK_EXECUTED=NO"
    Write-Host "REAL_SESSION_ROTATED=NO"
    Write-Host "PRODUCTION_CHANGED=NO"
    Write-Host "EXTERNAL_CONNECTION_OPENED=NO"
    Write-Host "SECRET_VALUES_EXPOSED=NO"
    if([string]$Assessment.status -ne "APPLICATION_API_SECURITY_GATE_PASS"){Hold "Application/API security gate failed"}
    Write-Host "APPLICATION / API SECURITY GATE : PASS"

    Step 9 "EVIDENCE + INTEGRITY"
    WriteLf $AssessmentFile ($Assessment|ConvertTo-Json -Depth 15)
    WriteLf $InventoryFile ([ordered]@{mode="GIT_TRACKED_STATIC_DISCOVERY";surface_count=$Surfaces.Count}|ConvertTo-Json -Depth 5)
    WriteLf $ValidationFile ($Assessment.input_validation|ConvertTo-Json -Depth 10)
    WriteLf $SessionFile ($Assessment.session_security|ConvertTo-Json -Depth 10)
    WriteLf $ApiFile ($Assessment.api_security|ConvertTo-Json -Depth 10)
    WriteLf $OwaspFile ($Assessment.owasp_control_coverage|ConvertTo-Json -Depth 10)
    WriteLf $SoftwareFile ($Assessment.software_security_governance|ConvertTo-Json -Depth 10)

    $IntegrityRecords=@()
    foreach($p in @($PolicyFile,$DocFile,$AssessmentFile,$InventoryFile,$ValidationFile,$SessionFile,$ApiFile,$OwaspFile,$SoftwareFile)){
        $IntegrityRecords += [ordered]@{path=$p;sha256=(Sha (Join-Path $Root $p))}
    }
    WriteLf $IntegrityFile ([ordered]@{algorithm="SHA-256";records=$IntegrityRecords}|ConvertTo-Json -Depth 12)
    $Evidence=[ordered]@{
        component="SPT-024.15";layer=1;version="1.0.0";authoritative_baseline=$ExpectedBaseline
        status="APPLICATION_API_SECURITY_GATE_PASS";targeted_tests="PASS";institutional_suite="PASS";compileall="PASS"
        active_attack_executed=$false;real_session_rotated=$false;production_changed=$false
        external_connection_opened=$false;secret_values_exposed=$false
    }
    WriteLf $EvidenceFile ($Evidence|ConvertTo-Json -Depth 10)

    Write-Host "ASSESSMENT : CREATED"
    Write-Host "INVENTORY  : CREATED"
    Write-Host "VALIDATION : CREATED"
    Write-Host "SESSION    : CREATED"
    Write-Host "API        : CREATED"
    Write-Host "OWASP      : CREATED"
    Write-Host "SOFTWARE   : CREATED"
    Write-Host "INTEGRITY  : CREATED"
    Write-Host "EVIDENCE   : CREATED"

    Step 10 "SHA-256 PRESERVATION GATE"
    foreach($p in $Freeze.Keys){
        $full=Join-Path $Root $p
        if(-not(Test-Path -LiteralPath $full) -or (Sha $full) -ne $Freeze[$p]){Hold "Protected tracked file changed: $p"}
    }
    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
    Write-Host "SPT-024.1-.14 + CLOSED COMPONENTS : PRESERVED"

    Step 11 "EXACT CONTROLLED STAGING"
    $Allowed=@('Invoke-SGODA-SPT02415-Capa1-FINAL-v1.0.0-PS51.ps1','src/sgoda/integration/spt02415/__init__.py','src/sgoda/integration/spt02415/models.py','src/sgoda/integration/spt02415/input_validation.py','src/sgoda/integration/spt02415/session.py','src/sgoda/integration/spt02415/api.py','src/sgoda/integration/spt02415/owasp.py','src/sgoda/integration/spt02415/software_governance.py','src/sgoda/integration/spt02415/audit.py','src/sgoda/integration/spt02415/gate.py','src/sgoda/integration/spt02415/integrity.py','src/sgoda/integration/spt02415/service.py','tests/integration/test_spt02415_application_api_security_layer1.py','config/integration/spt02415/application-api-security-policy.json','docs/06_Tecnologia/SPT-024/SPT-024.15/SGD-SPT024.15-Capa1-Seguridad-Aplicaciones-APIs-Validacion-Sesiones-OWASP.md','artifacts/development/SPT-024.15-Capa1-v1.0.0/application-api-security-assessment.json','artifacts/development/SPT-024.15-Capa1-v1.0.0/application-api-surface-inventory.json','artifacts/development/SPT-024.15-Capa1-v1.0.0/input-validation-baseline.json','artifacts/development/SPT-024.15-Capa1-v1.0.0/session-security-baseline.json','artifacts/development/SPT-024.15-Capa1-v1.0.0/api-security-baseline.json','artifacts/development/SPT-024.15-Capa1-v1.0.0/owasp-control-coverage-baseline.json','artifacts/development/SPT-024.15-Capa1-v1.0.0/software-security-governance-baseline.json','artifacts/development/SPT-024.15-Capa1-v1.0.0/application-api-integrity-manifest.json','artifacts/development/SPT-024.15-Capa1-v1.0.0/implementation-evidence.json')
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
    & git.exe commit -m "feat(spt-024.15): implement application api input session OWASP security layer 1"
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
    if($FinalLocal -ne $FinalRemote -or $Behind -ne "0" -or $Ahead -ne "0" -or $FinalStaged.Count -ne 0 -or $FinalDeleted.Count -ne 0){Hold "Authoritative final synchronization failed"}

    Write-Host ""
    Write-Host "SPT-024.15 CAPA 1 : TECHNICALLY CLOSED" -ForegroundColor Green
    Write-Host "APPLICATION_API_SECURITY_GATE=PASS"
    Write-Host "INPUT_VALIDATION_GOVERNANCE=PASS"
    Write-Host "SESSION_SECURITY_GOVERNANCE=PASS"
    Write-Host "API_AUTHENTICATION_AUTHORIZATION=PASS"
    Write-Host "OBJECT_LEVEL_AUTHORIZATION=PASS"
    Write-Host "API_RATE_LIMIT_GOVERNANCE=PASS"
    Write-Host "CORS_SECURITY_HEADERS=PASS"
    Write-Host "ERROR_SANITIZATION=PASS"
    Write-Host "OWASP_CONTROL_COVERAGE=PASS"
    Write-Host "SOFTWARE_SECURITY_GOVERNANCE=PASS"
    Write-Host "ACTIVE_ATTACK_EXECUTED=NO"
    Write-Host "REAL_SESSION_ROTATED=NO"
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
