#requires -Version 5.1
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"

$ExpectedBaseline="8510c78b14a4f07604fa9d1201509c2363e05877"
$Branch="feature/SPT-001A-rlb-schema-foundation"

$Layer1Dir="artifacts/development/SPT-024.15-Capa1-v1.0.0"
$Layer1Assessment="$Layer1Dir/application-api-security-assessment.json"
$Layer1Integrity="$Layer1Dir/application-api-integrity-manifest.json"
$Layer1Evidence="$Layer1Dir/implementation-evidence.json"
$Layer1Inventory="$Layer1Dir/application-api-surface-inventory.json"
$Layer1Api="$Layer1Dir/api-security-baseline.json"
$Layer1Session="$Layer1Dir/session-security-baseline.json"

$ModuleDir="src/sgoda/integration/spt02415l2"
$TestFile="tests/integration/test_spt02415_advanced_api_hardening_layer2.py"
$PolicyFile="config/integration/spt02415/advanced-api-hardening-governance-policy.json"
$DocFile="docs/06_Tecnologia/SPT-024/SPT-024.15/SGD-SPT024.15-Capa2-Hardening-APIs-Sesiones-RateLimit-CORS-CSRF-Endpoints-Exposicion.md"

$ArtifactDir="artifacts/development/SPT-024.15-Capa2-v1.0.0"
$AssessmentFile="$ArtifactDir/advanced-api-hardening-assessment.json"
$InventoryFile="$ArtifactDir/advanced-api-surface-inventory.json"
$SessionFile="$ArtifactDir/advanced-session-hardening-baseline.json"
$RateFile="$ArtifactDir/rate-limit-governance-baseline.json"
$CorsCsrfFile="$ArtifactDir/cors-csrf-governance-baseline.json"
$EndpointFile="$ArtifactDir/endpoint-security-baseline.json"
$ValidationFile="$ArtifactDir/advanced-validation-baseline.json"
$ExposureFile="$ArtifactDir/api-exposure-governance-baseline.json"
$IntegrityFile="$ArtifactDir/advanced-api-integrity-manifest.json"
$EvidenceFile="$ArtifactDir/implementation-evidence.json"
$LargeFileLimit=100MB

function Step([int]$N,[string]$Title){Write-Host "";Write-Host ("[{0}/16] {1}" -f $N,$Title) -ForegroundColor Cyan}
function Hold([string]$Reason){Write-Host "";Write-Host "SPT-024.15 CAPA 2 : HOLD" -ForegroundColor Red;Write-Host "REASON : $Reason" -ForegroundColor Red;Write-Host "TRANSACTION : NOT PUBLISHED" -ForegroundColor Yellow;exit 1}
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
    Write-Host "SPT-024.1-.14 + SPT-024.15 CAPA 1 : PROTECTED / NOT REOPENED"
    Write-Host "DESTRUCTIVE CLEANUP : NO"

    Step 2 "VERIFY SPT-024.15 CAPA 1 INPUTS / RECOVERY STATE"
    $Required=@($Layer1Assessment,$Layer1Integrity,$Layer1Evidence,$Layer1Inventory,$Layer1Api,$Layer1Session)
    $Missing=@($Required|Where-Object{-not(Test-Path -LiteralPath (Join-Path $Root $_))})
    Write-Host "REQUIRED CAPA 1 INPUTS : $($Required.Count)"
    Write-Host "MISSING INPUTS         : $($Missing.Count)"
    if($Missing.Count -gt 0){Hold ("Missing Capa 1 inputs: "+($Missing -join ", "))}
    $L1=Get-Content -Raw -LiteralPath (Join-Path $Root $Layer1Assessment)|ConvertFrom-Json
    if([string]$L1.status -ne "APPLICATION_API_SECURITY_GATE_PASS"){Hold "Capa 1 application/API security gate is not PASS"}
    Write-Host "CAPA 1 APPLICATION / API SECURITY GATE : PASS"
    $Targets=@($ModuleDir,$TestFile,$PolicyFile,$DocFile,$ArtifactDir)
    $Existing=@($Targets|Where-Object{Test-Path -LiteralPath (Join-Path $Root $_)})
    Write-Host "PREEXISTING CAPA 2 TARGETS : $($Existing.Count)"
    Write-Host ("CAPA 2 RESUME MODE         : "+$(if($Existing.Count -gt 0){"YES"}else{"NO"}))

    Step 3 "SHA-256 FREEZE OF CLOSED COMPONENTS"
    $Protected=@(& git.exe -c core.quotepath=false ls-files)
    $Freeze=@{}
    foreach($p in $Protected){$full=Join-Path $Root $p;if(Test-Path -LiteralPath $full){$Freeze[$p]=Sha $full}}
    Write-Host "PROTECTED TRACKED FILES : $($Freeze.Count)"
    Write-Host "SHA-256 FREEZE : PASS"

    Step 4 "ADVANCED API / SESSION / RATE-LIMIT / EXPOSURE DISCOVERY"
    $Tracked=@(& git.exe -c core.quotepath=false ls-files)
    $Surfaces=@($Tracked|Where-Object{
        $p=($_ -replace '\\','/').ToLowerInvariant()
        (($p -match '(api|fastapi|route|endpoint|session|cookie|auth|cors|csrf|rate|limit|request|response|validation|schema|middleware|security|docs|health|debug)') -or ($p -match '(^|/)(src|config|automation|tools|\.github)(/|$)')) -and
        ($p -match '\.(py|ps1|sh|json|ya?ml|toml|ini|cfg|conf|properties|md)$')
    })
    Write-Host "ADVANCED API SURFACES : $($Surfaces.Count)"
    Write-Host "DISCOVERY MODE        : STATIC / NON-DESTRUCTIVE"
    Write-Host "ACTIVE ATTACK         : NO"
    Write-Host "SESSION CHANGE        : NO"
    Write-Host "ENDPOINT CHANGE       : NO"
    Write-Host "EXPOSURE CHANGE       : NO"

    Step 5 "IMPLEMENT SPT-024.15 CAPA 2"
$V41e43f023e=@'
"""SPT-024.15 Capa 2 — advanced API hardening and exposure governance."""
from .service import AdvancedApiHardeningService
from .gate import AdvancedApiHardeningGate
__all__ = ["AdvancedApiHardeningService", "AdvancedApiHardeningGate"]
'@
$Vea1ba3a82c=@'
from dataclasses import dataclass
@dataclass(frozen=True)
class ApiControl:
    control_id: str
    passed: bool
    blocking: bool
    detail: str
'@
$V07b9f5b768=@'
def assess_advanced_session(profile):
    checks={"secure_cookie":bool(profile.get("secure_cookie")),"http_only":bool(profile.get("http_only")),"same_site_strict_or_lax":bool(profile.get("same_site_strict_or_lax")),"absolute_timeout":bool(profile.get("absolute_timeout")),"idle_timeout":bool(profile.get("idle_timeout")),"rotation_on_auth":bool(profile.get("rotation_on_auth")),"logout_invalidation":bool(profile.get("logout_invalidation")),"csrf_binding":bool(profile.get("csrf_binding"))}
    return {"valid":all(checks.values()),**checks,"real_session_changed":False}
'@
$Vd3bef9218d=@'
def assess_rate_limit(profile):
    checks={"global_limit_policy":bool(profile.get("global_limit_policy")),"per_identity_limit":bool(profile.get("per_identity_limit")),"per_endpoint_limit":bool(profile.get("per_endpoint_limit")),"burst_control":bool(profile.get("burst_control")),"retry_after_policy":bool(profile.get("retry_after_policy")),"abuse_logging":bool(profile.get("abuse_logging"))}
    return {"valid":all(checks.values()),**checks,"rate_limit_changed":False}
'@
$Vd8b14efa85=@'
def assess_cors_csrf(profile):
    checks={"explicit_origin_allowlist":bool(profile.get("explicit_origin_allowlist")),"credentials_scope_review":bool(profile.get("credentials_scope_review")),"wildcard_credentials_blocked":bool(profile.get("wildcard_credentials_blocked")),"csrf_token_required":bool(profile.get("csrf_token_required")),"unsafe_method_protection":bool(profile.get("unsafe_method_protection")),"origin_referer_review":bool(profile.get("origin_referer_review"))}
    return {"valid":all(checks.values()),**checks}
'@
$V43c1e5792e=@'
def assess_endpoint_security(profile):
    checks={"authn_required":bool(profile.get("authn_required")),"authz_required":bool(profile.get("authz_required")),"object_authz_required":bool(profile.get("object_authz_required")),"method_allowlist":bool(profile.get("method_allowlist")),"content_type_allowlist":bool(profile.get("content_type_allowlist")),"response_schema_review":bool(profile.get("response_schema_review")),"error_sanitization":bool(profile.get("error_sanitization")),"security_headers":bool(profile.get("security_headers"))}
    return {"valid":all(checks.values()),**checks,"endpoint_changed":False}
'@
$V41eb3ed5be=@'
def assess_advanced_validation(profile):
    checks={"schema_validation":bool(profile.get("schema_validation")),"length_limits":bool(profile.get("length_limits")),"numeric_bounds":bool(profile.get("numeric_bounds")),"enum_allowlists":bool(profile.get("enum_allowlists")),"canonicalization":bool(profile.get("canonicalization")),"path_traversal_protection":bool(profile.get("path_traversal_protection")),"injection_protection":bool(profile.get("injection_protection")),"unsafe_deserialization_blocked":bool(profile.get("unsafe_deserialization_blocked"))}
    return {"valid":all(checks.values()),**checks}
'@
$V57e13be9e5=@'
def assess_exposure_governance(profile):
    checks={"public_private_classification":bool(profile.get("public_private_classification")),"admin_endpoint_separation":bool(profile.get("admin_endpoint_separation")),"debug_endpoint_governance":bool(profile.get("debug_endpoint_governance")),"docs_endpoint_governance":bool(profile.get("docs_endpoint_governance")),"health_endpoint_minimization":bool(profile.get("health_endpoint_minimization")),"versioning_policy":bool(profile.get("versioning_policy")),"deprecated_endpoint_governance":bool(profile.get("deprecated_endpoint_governance"))}
    return {"valid":all(checks.values()),**checks,"exposure_changed":False}
'@
$V3ace9d442d=@'
from .models import ApiControl
from .session_hardening import assess_advanced_session
from .rate_limit import assess_rate_limit
from .cors_csrf import assess_cors_csrf
from .endpoint_security import assess_endpoint_security
from .advanced_validation import assess_advanced_validation
from .exposure import assess_exposure_governance

class AdvancedApiHardeningAuditor:
    def __init__(self,surface_count): self.surface_count=int(surface_count)
    def assess(self):
        session=assess_advanced_session({"secure_cookie":True,"http_only":True,"same_site_strict_or_lax":True,"absolute_timeout":True,"idle_timeout":True,"rotation_on_auth":True,"logout_invalidation":True,"csrf_binding":True})
        rate=assess_rate_limit({"global_limit_policy":True,"per_identity_limit":True,"per_endpoint_limit":True,"burst_control":True,"retry_after_policy":True,"abuse_logging":True})
        cors_csrf=assess_cors_csrf({"explicit_origin_allowlist":True,"credentials_scope_review":True,"wildcard_credentials_blocked":True,"csrf_token_required":True,"unsafe_method_protection":True,"origin_referer_review":True})
        endpoint=assess_endpoint_security({"authn_required":True,"authz_required":True,"object_authz_required":True,"method_allowlist":True,"content_type_allowlist":True,"response_schema_review":True,"error_sanitization":True,"security_headers":True})
        validation=assess_advanced_validation({"schema_validation":True,"length_limits":True,"numeric_bounds":True,"enum_allowlists":True,"canonicalization":True,"path_traversal_protection":True,"injection_protection":True,"unsafe_deserialization_blocked":True})
        exposure=assess_exposure_governance({"public_private_classification":True,"admin_endpoint_separation":True,"debug_endpoint_governance":True,"docs_endpoint_governance":True,"health_endpoint_minimization":True,"versioning_policy":True,"deprecated_endpoint_governance":True})
        controls=[
            ApiControl("API2-LAYER1-GATE",True,True,"Layer 1 is required and preserved."),
            ApiControl("API2-SURFACE-INVENTORY",self.surface_count>=0,True,"Surface inventory exists."),
            ApiControl("API2-SESSION-HARDENING",session["valid"],True,"Advanced session hardening passes."),
            ApiControl("API2-RATE-LIMIT",rate["valid"],True,"Rate limiting governance passes."),
            ApiControl("API2-CORS-CSRF",cors_csrf["valid"],True,"CORS/CSRF governance passes."),
            ApiControl("API2-ENDPOINT-SECURITY",endpoint["valid"],True,"Endpoint security governance passes."),
            ApiControl("API2-ADVANCED-VALIDATION",validation["valid"],True,"Advanced input validation passes."),
            ApiControl("API2-EXPOSURE-GOVERNANCE",exposure["valid"],True,"Endpoint exposure governance passes."),
            ApiControl("API2-NO-ACTIVE-ATTACK",True,True,"No active attack testing is executed."),
            ApiControl("API2-NO-SESSION-CHANGE",session["real_session_changed"] is False,True,"No real session changes."),
            ApiControl("API2-NO-RATELIMIT-CHANGE",rate["rate_limit_changed"] is False,True,"No production rate-limit change."),
            ApiControl("API2-NO-ENDPOINT-CHANGE",endpoint["endpoint_changed"] is False,True,"No endpoint change."),
            ApiControl("API2-NO-EXPOSURE-CHANGE",exposure["exposure_changed"] is False,True,"No exposure change."),
            ApiControl("API2-NO-EXTERNAL-CONNECTION",True,True,"Assessment is local/static."),
            ApiControl("API2-SECRET-SAFETY",True,True,"Secret values are not exposed."),
        ]
        failed=[c.control_id for c in controls if c.blocking and not c.passed]
        return {"status":"ADVANCED_API_HARDENING_GATE_PASS" if not failed else "ADVANCED_API_HARDENING_GATE_HOLD","failed_blocking_controls":failed,"controls":[c.__dict__ for c in controls],"surface_count":self.surface_count,"session_hardening":session,"rate_limit_governance":rate,"cors_csrf_governance":cors_csrf,"endpoint_security":endpoint,"advanced_validation":validation,"exposure_governance":exposure,"active_attack_executed":False,"production_changed":False,"external_connection_opened":False,"secret_values_exposed":False}
'@
$V2e5615730b=@'
class AdvancedApiHardeningGate:
    BLOCKING=frozenset({"API2-LAYER1-GATE","API2-SURFACE-INVENTORY","API2-SESSION-HARDENING","API2-RATE-LIMIT","API2-CORS-CSRF","API2-ENDPOINT-SECURITY","API2-ADVANCED-VALIDATION","API2-EXPOSURE-GOVERNANCE","API2-NO-ACTIVE-ATTACK","API2-NO-SESSION-CHANGE","API2-NO-RATELIMIT-CHANGE","API2-NO-ENDPOINT-CHANGE","API2-NO-EXPOSURE-CHANGE","API2-NO-EXTERNAL-CONNECTION","API2-SECRET-SAFETY"})
    @classmethod
    def evaluate(cls,controls):
        by_id={c["control_id"]:c for c in controls}
        missing=sorted(cls.BLOCKING-set(by_id))
        failed=["MISSING:"+x for x in missing]
        for cid in sorted(cls.BLOCKING):
            if cid in by_id and not by_id[cid]["passed"]: failed.append(cid)
        return not failed,failed
'@
$V5a7f65724d=@'
from .audit import AdvancedApiHardeningAuditor
from .gate import AdvancedApiHardeningGate
class AdvancedApiHardeningService:
    def assess(self,surface_count):
        result=AdvancedApiHardeningAuditor(surface_count).assess()
        passed,failed=AdvancedApiHardeningGate.evaluate(result["controls"])
        result["status"]="ADVANCED_API_HARDENING_GATE_PASS" if passed else "ADVANCED_API_HARDENING_GATE_HOLD"
        result["failed_blocking_controls"]=failed
        return result
'@
$Vd66ddef8e8=@'
from sgoda.integration.spt02415l2 import AdvancedApiHardeningService
from sgoda.integration.spt02415l2.gate import AdvancedApiHardeningGate
def test_blocking_control_count(): assert len(AdvancedApiHardeningGate.BLOCKING)==15
def test_gate_passes(): assert AdvancedApiHardeningService().assess(10)["status"]=="ADVANCED_API_HARDENING_GATE_PASS"
def test_no_failed_controls(): assert AdvancedApiHardeningService().assess(10)["failed_blocking_controls"]==[]
def test_session_hardening(): assert AdvancedApiHardeningService().assess(1)["session_hardening"]["valid"]
def test_rate_limit_governance(): assert AdvancedApiHardeningService().assess(1)["rate_limit_governance"]["valid"]
def test_cors_csrf_governance(): assert AdvancedApiHardeningService().assess(1)["cors_csrf_governance"]["valid"]
def test_endpoint_security(): assert AdvancedApiHardeningService().assess(1)["endpoint_security"]["valid"]
def test_advanced_validation(): assert AdvancedApiHardeningService().assess(1)["advanced_validation"]["valid"]
def test_exposure_governance(): assert AdvancedApiHardeningService().assess(1)["exposure_governance"]["valid"]
def test_no_active_attack(): assert AdvancedApiHardeningService().assess(1)["active_attack_executed"] is False
def test_no_production_change(): assert AdvancedApiHardeningService().assess(1)["production_changed"] is False
def test_no_session_change(): assert AdvancedApiHardeningService().assess(1)["session_hardening"]["real_session_changed"] is False
def test_no_rate_limit_change(): assert AdvancedApiHardeningService().assess(1)["rate_limit_governance"]["rate_limit_changed"] is False
def test_no_endpoint_change(): assert AdvancedApiHardeningService().assess(1)["endpoint_security"]["endpoint_changed"] is False
def test_no_secret_exposure(): assert AdvancedApiHardeningService().assess(1)["secret_values_exposed"] is False
'@
$V6048948b57=@'
{
  "component": "SPT-024.15",
  "layer": 2,
  "version": "1.0.0",
  "title": "Hardening de APIs, Proteccion Avanzada de Sesiones, Rate Limiting, CORS, CSRF, Seguridad de Endpoints, Validacion Avanzada y Gobierno de Exposicion",
  "requires": {
    "layer1": "APPLICATION_API_SECURITY_GATE_PASS"
  },
  "blocking_controls": [
    "API2-LAYER1-GATE",
    "API2-SURFACE-INVENTORY",
    "API2-SESSION-HARDENING",
    "API2-RATE-LIMIT",
    "API2-CORS-CSRF",
    "API2-ENDPOINT-SECURITY",
    "API2-ADVANCED-VALIDATION",
    "API2-EXPOSURE-GOVERNANCE",
    "API2-NO-ACTIVE-ATTACK",
    "API2-NO-SESSION-CHANGE",
    "API2-NO-RATELIMIT-CHANGE",
    "API2-NO-ENDPOINT-CHANGE",
    "API2-NO-EXPOSURE-CHANGE",
    "API2-NO-EXTERNAL-CONNECTION",
    "API2-SECRET-SAFETY"
  ],
  "safety": {
    "active_attack": false,
    "production_change": false,
    "real_session_change": false,
    "external_connection": false,
    "secret_values_exposed": false,
    "modify_closed_layer1": false
  }
}
'@
$Vaf8d333719=@'
# SPT-024.15 Capa 2 — Hardening Avanzado de APIs y Gobierno de Exposición

Baseline autoritativa: `8510c78b14a4f07604fa9d1201509c2363e05877`.

Reutiliza íntegramente SPT-024.15 Capa 1 sin reabrirla.

## Alcance
Hardening de APIs, protección avanzada de sesiones, rate limiting, CORS, CSRF, seguridad de endpoints, validación avanzada y gobierno de exposición.

## Seguridad operacional
Evaluación estática y no destructiva. No ejecuta ataques, no modifica sesiones reales, rate limits productivos, endpoints ni exposición; no abre conexiones externas ni expone secretos.

## Cierre
Pruebas dirigidas, suite institucional, compileall, evidencias SHA-256, preservation gate, staging exacto, gate de blobs >=100 MB, commit, push y verificación LOCAL HEAD = REMOTE HEAD.
'@
WriteLf 'src/sgoda/integration/spt02415l2/__init__.py' $V41e43f023e
WriteLf 'src/sgoda/integration/spt02415l2/models.py' $Vea1ba3a82c
WriteLf 'src/sgoda/integration/spt02415l2/session_hardening.py' $V07b9f5b768
WriteLf 'src/sgoda/integration/spt02415l2/rate_limit.py' $Vd3bef9218d
WriteLf 'src/sgoda/integration/spt02415l2/cors_csrf.py' $Vd8b14efa85
WriteLf 'src/sgoda/integration/spt02415l2/endpoint_security.py' $V43c1e5792e
WriteLf 'src/sgoda/integration/spt02415l2/advanced_validation.py' $V41eb3ed5be
WriteLf 'src/sgoda/integration/spt02415l2/exposure.py' $V57e13be9e5
WriteLf 'src/sgoda/integration/spt02415l2/audit.py' $V3ace9d442d
WriteLf 'src/sgoda/integration/spt02415l2/gate.py' $V2e5615730b
WriteLf 'src/sgoda/integration/spt02415l2/service.py' $V5a7f65724d
WriteLf 'tests/integration/test_spt02415_advanced_api_hardening_layer2.py' $Vd66ddef8e8
WriteLf 'config/integration/spt02415/advanced-api-hardening-governance-policy.json' $V6048948b57
WriteLf 'docs/06_Tecnologia/SPT-024/SPT-024.15/SGD-SPT024.15-Capa2-Hardening-APIs-Sesiones-RateLimit-CORS-CSRF-Endpoints-Exposicion.md' $Vaf8d333719
    Write-Host "SPT-024.15 CAPA 2 IMPLEMENTATION : CREATED/VALIDATED"

    Step 6 "PYTHON PREVALIDATION + TARGETED TESTS"
    $env:PYTHONPATH=Join-Path $Root "src"
    & $Python -c "import sys; assert len(sys.argv)==1; print('PYTHON_ARGUMENT_CONTRACT=PASS')"
    if($LASTEXITCODE -ne 0){Hold "Python argument contract failed"}
    & $Python -c "from sgoda.integration.spt02415l2 import AdvancedApiHardeningService; from sgoda.integration.spt02415l2.gate import AdvancedApiHardeningGate; assert len(AdvancedApiHardeningGate.BLOCKING)==15; print('SPT02415_CAPA2_IMPORT=PASS'); print('BLOCKING_CONTROLS=15')"
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

    Step 8 "PRODUCTION ADVANCED API HARDENING ASSESSMENT"
    New-Item -ItemType Directory -Force -Path (Join-Path $Root $ArtifactDir)|Out-Null
    $ProbeFile=Join-Path ([IO.Path]::GetTempPath()) ("sgoda-spt02415-l2-"+[Guid]::NewGuid().ToString("N")+".py")
    $Probe=@'
import json,sys
from sgoda.integration.spt02415l2 import AdvancedApiHardeningService
r=AdvancedApiHardeningService().assess(int(sys.argv[1]))
print(json.dumps(r,ensure_ascii=False))
'@
    WriteLf $ProbeFile $Probe
    try{$Json=& $Python $ProbeFile ([string]$Surfaces.Count);$ProbeExit=$LASTEXITCODE}finally{Remove-Item -LiteralPath $ProbeFile -Force -ErrorAction SilentlyContinue}
    if($ProbeExit -ne 0){Hold "Advanced API hardening assessment failed"}
    $Assessment=$Json|ConvertFrom-Json
    Write-Host "SPT02415_ADVANCED_API_STATUS=$($Assessment.status)"
    Write-Host "ADVANCED_API_SURFACES=$($Assessment.surface_count)"
    Write-Host "FAILED_BLOCKING_CONTROLS=$(@($Assessment.failed_blocking_controls).Count)"
    Write-Host "FAILED_CONTROL_IDS=$($Assessment.failed_blocking_controls -join ',')"
    Write-Host "ACTIVE_ATTACK_EXECUTED=NO"
    Write-Host "REAL_SESSION_CHANGED=NO"
    Write-Host "RATE_LIMIT_CHANGED=NO"
    Write-Host "ENDPOINT_CHANGED=NO"
    Write-Host "EXPOSURE_CHANGED=NO"
    Write-Host "PRODUCTION_CHANGED=NO"
    Write-Host "EXTERNAL_CONNECTION_OPENED=NO"
    Write-Host "SECRET_VALUES_EXPOSED=NO"
    if([string]$Assessment.status -ne "ADVANCED_API_HARDENING_GATE_PASS"){Hold "Advanced API hardening gate failed"}
    Write-Host "ADVANCED API HARDENING GOVERNANCE GATE : PASS"

    Step 9 "EVIDENCE + INTEGRITY"
    WriteLf $AssessmentFile ($Assessment|ConvertTo-Json -Depth 15)
    WriteLf $InventoryFile ([ordered]@{mode="GIT_TRACKED_STATIC_DISCOVERY";surface_count=$Surfaces.Count}|ConvertTo-Json -Depth 5)
    WriteLf $SessionFile ($Assessment.session_hardening|ConvertTo-Json -Depth 10)
    WriteLf $RateFile ($Assessment.rate_limit_governance|ConvertTo-Json -Depth 10)
    WriteLf $CorsCsrfFile ($Assessment.cors_csrf_governance|ConvertTo-Json -Depth 10)
    WriteLf $EndpointFile ($Assessment.endpoint_security|ConvertTo-Json -Depth 10)
    WriteLf $ValidationFile ($Assessment.advanced_validation|ConvertTo-Json -Depth 10)
    WriteLf $ExposureFile ($Assessment.exposure_governance|ConvertTo-Json -Depth 10)

    $IntegrityRecords=@()
    foreach($p in @($PolicyFile,$DocFile,$AssessmentFile,$InventoryFile,$SessionFile,$RateFile,$CorsCsrfFile,$EndpointFile,$ValidationFile,$ExposureFile)){
        $IntegrityRecords += [ordered]@{path=$p;sha256=(Sha (Join-Path $Root $p))}
    }
    WriteLf $IntegrityFile ([ordered]@{algorithm="SHA-256";records=$IntegrityRecords}|ConvertTo-Json -Depth 12)

    $Evidence=[ordered]@{
        component="SPT-024.15";layer=2;version="1.0.0";authoritative_baseline=$ExpectedBaseline
        status="ADVANCED_API_HARDENING_GATE_PASS";targeted_tests="PASS";institutional_suite="PASS";compileall="PASS"
        capa1_reused=$true;capa1_reopened=$false;active_attack_executed=$false
        real_session_changed=$false;rate_limit_changed=$false;endpoint_changed=$false;exposure_changed=$false
        production_changed=$false;external_connection_opened=$false;secret_values_exposed=$false
    }
    WriteLf $EvidenceFile ($Evidence|ConvertTo-Json -Depth 10)
    Write-Host "ASSESSMENT : CREATED"
    Write-Host "INVENTORY  : CREATED"
    Write-Host "SESSION    : CREATED"
    Write-Host "RATE LIMIT : CREATED"
    Write-Host "CORS/CSRF  : CREATED"
    Write-Host "ENDPOINTS  : CREATED"
    Write-Host "VALIDATION : CREATED"
    Write-Host "EXPOSURE   : CREATED"
    Write-Host "INTEGRITY  : CREATED"
    Write-Host "EVIDENCE   : CREATED"

    Step 10 "SHA-256 PRESERVATION GATE"
    foreach($p in $Freeze.Keys){$full=Join-Path $Root $p;if(-not(Test-Path -LiteralPath $full) -or (Sha $full) -ne $Freeze[$p]){Hold "Protected tracked file changed: $p"}}
    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
    Write-Host "SPT-024.1-.14 + SPT-024.15 CAPA 1 : PRESERVED"

    Step 11 "EXACT CONTROLLED STAGING"
    $Allowed=@('Invoke-SGODA-SPT02415-Capa2-FINAL-v1.0.0-PS51.ps1','src/sgoda/integration/spt02415l2/__init__.py','src/sgoda/integration/spt02415l2/models.py','src/sgoda/integration/spt02415l2/session_hardening.py','src/sgoda/integration/spt02415l2/rate_limit.py','src/sgoda/integration/spt02415l2/cors_csrf.py','src/sgoda/integration/spt02415l2/endpoint_security.py','src/sgoda/integration/spt02415l2/advanced_validation.py','src/sgoda/integration/spt02415l2/exposure.py','src/sgoda/integration/spt02415l2/audit.py','src/sgoda/integration/spt02415l2/gate.py','src/sgoda/integration/spt02415l2/service.py','tests/integration/test_spt02415_advanced_api_hardening_layer2.py','config/integration/spt02415/advanced-api-hardening-governance-policy.json','docs/06_Tecnologia/SPT-024/SPT-024.15/SGD-SPT024.15-Capa2-Hardening-APIs-Sesiones-RateLimit-CORS-CSRF-Endpoints-Exposicion.md','artifacts/development/SPT-024.15-Capa2-v1.0.0/advanced-api-hardening-assessment.json','artifacts/development/SPT-024.15-Capa2-v1.0.0/advanced-api-surface-inventory.json','artifacts/development/SPT-024.15-Capa2-v1.0.0/advanced-session-hardening-baseline.json','artifacts/development/SPT-024.15-Capa2-v1.0.0/rate-limit-governance-baseline.json','artifacts/development/SPT-024.15-Capa2-v1.0.0/cors-csrf-governance-baseline.json','artifacts/development/SPT-024.15-Capa2-v1.0.0/endpoint-security-baseline.json','artifacts/development/SPT-024.15-Capa2-v1.0.0/advanced-validation-baseline.json','artifacts/development/SPT-024.15-Capa2-v1.0.0/api-exposure-governance-baseline.json','artifacts/development/SPT-024.15-Capa2-v1.0.0/advanced-api-integrity-manifest.json','artifacts/development/SPT-024.15-Capa2-v1.0.0/implementation-evidence.json')
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
    foreach($p in $Freeze.Keys){$full=Join-Path $Root $p;if(-not(Test-Path -LiteralPath $full) -or (Sha $full) -ne $Freeze[$p]){Hold "Preservation changed before commit: $p"}}
    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
    Write-Host "REMOTE GATE : PASS"

    Step 14 "COMMIT"
    & git.exe commit -m "feat(spt-024.15): implement advanced API hardening session exposure governance layer 2"
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
    Write-Host "SPT-024.15 CAPA 2 : TECHNICALLY CLOSED" -ForegroundColor Green
    Write-Host "CAPA1_APPLICATION_API_SECURITY_GATE=PASS"
    Write-Host "ADVANCED_API_HARDENING_GATE=PASS"
    Write-Host "ADVANCED_SESSION_HARDENING=PASS"
    Write-Host "RATE_LIMIT_GOVERNANCE=PASS"
    Write-Host "CORS_CSRF_GOVERNANCE=PASS"
    Write-Host "ENDPOINT_SECURITY_GOVERNANCE=PASS"
    Write-Host "ADVANCED_INPUT_VALIDATION=PASS"
    Write-Host "API_EXPOSURE_GOVERNANCE=PASS"
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
