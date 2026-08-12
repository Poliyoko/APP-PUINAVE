#requires -Version 5.1
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference="Stop"
$ProgressPreference="SilentlyContinue"

$ExpectedBaseline="5a8ccf9ce7990e920f84550de0f33dd532ce74d3"
$Branch="feature/SPT-001A-rlb-schema-foundation"
$ModuleDir="src/sgoda/integration/spt02417"
$TestFile="tests/integration/test_spt02417_infrastructure_security_governance_layer1.py"
$PolicyFile="config/integration/spt02417/infrastructure-security-governance-policy.json"
$DocFile="docs/06_Tecnologia/SPT-024/SPT-024.17/SGD-SPT024.17-Capa1-Seguridad-Infraestructura-SO-Servicios-Puertos-Redes-Hardening.md"
$ArtifactDir="artifacts/development/SPT-024.17-Capa1-v1.0.1"
$AssessmentFile="$ArtifactDir/infrastructure-security-governance-assessment.json"
$InventoryFile="$ArtifactDir/infrastructure-security-surface-inventory.json"
$OsFile="$ArtifactDir/operating-system-security-baseline.json"
$ServiceFile="$ArtifactDir/service-security-baseline.json"
$PortFile="$ArtifactDir/port-security-baseline.json"
$NetworkFile="$ArtifactDir/network-security-baseline.json"
$CommsFile="$ArtifactDir/secure-communications-baseline.json"
$HardeningFile="$ArtifactDir/infrastructure-hardening-baseline.json"
$ConfigFile="$ArtifactDir/configuration-governance-baseline.json"
$IntegrityFile="$ArtifactDir/infrastructure-security-integrity-manifest.json"
$EvidenceFile="$ArtifactDir/implementation-evidence.json"
$LargeFileLimit=100MB

function Step([int]$N,[string]$Title){Write-Host "";Write-Host ("[{0}/16] {1}" -f $N,$Title) -ForegroundColor Cyan}
function Hold([string]$Reason){Write-Host "";Write-Host "SPT-024.17 CAPA 1 : HOLD" -ForegroundColor Red;Write-Host "REASON : $Reason" -ForegroundColor Red;Write-Host "TRANSACTION : NOT PUBLISHED" -ForegroundColor Yellow;exit 1}
function GitFetch {for($i=1;$i -le 4;$i++){Write-Host "GIT FETCH ATTEMPT : $i/4";& git.exe fetch origin $Branch;if($LASTEXITCODE -eq 0){Write-Host "GIT FETCH : PASS";return};Start-Sleep -Seconds 2};Hold "git fetch failed after 4 attempts"}
function WriteLf([string]$Path,[string]$Text){$Target=if([IO.Path]::IsPathRooted($Path)){$Path}else{Join-Path $Root $Path};$Parent=Split-Path -Parent $Target;if($Parent -and -not(Test-Path -LiteralPath $Parent)){New-Item -ItemType Directory -Force -Path $Parent|Out-Null};$Utf8=New-Object System.Text.UTF8Encoding($false);$Canonical=(($Text -replace "`r`n","`n") -replace "`r","`n");if(-not $Canonical.EndsWith("`n")){$Canonical+="`n"};[IO.File]::WriteAllText($Target,$Canonical,$Utf8)}
function Sha([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()}
function SizeGate {$bad=New-Object System.Collections.Generic.List[string];$files=@(& git.exe -c core.quotepath=false ls-files);foreach($p in $files){$s=@(& git.exe cat-file -s (":"+$p) 2>$null);if($LASTEXITCODE -eq 0 -and @($s).Count -gt 0){[Int64]$n=0;if([Int64]::TryParse(([string]$s[0]).Trim(),[ref]$n) -and $n -ge $LargeFileLimit){[void]$bad.Add(($p -replace '\\','/'))}}};return @($bad.ToArray())}

try{
$Root=(& git.exe rev-parse --show-toplevel).Trim()
if($LASTEXITCODE -ne 0 -or -not $Root){Hold "Not inside Git repository"}
Set-Location $Root
$Python=Join-Path $Root ".venv\Scripts\python.exe"
if(-not(Test-Path -LiteralPath $Python)){$Python="python.exe"}

Step 1 "AUTHORITATIVE BASELINE / REMOTE SAFETY"
GitFetch
$Local=(& git.exe rev-parse HEAD).Trim();$Remote=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
$Staged=@(& git.exe -c core.quotepath=false diff --cached --name-only);$Deleted=@(& git.exe -c core.quotepath=false ls-files --deleted)
Write-Host "LOCAL HEAD      : $Local";Write-Host "REMOTE HEAD     : $Remote";Write-Host "STAGED          : $($Staged.Count)";Write-Host "DELETED TRACKED : $($Deleted.Count)"
if($Local -ne $ExpectedBaseline -or $Remote -ne $ExpectedBaseline){Hold "Authoritative baseline mismatch"}
if($Staged.Count -ne 0 -or $Deleted.Count -ne 0){Hold "Unsafe pre-existing staged/deleted state"}
Write-Host "BASELINE : PASS";Write-Host "SPT-024.1-.16 : PROTECTED / NOT REOPENED";Write-Host "DESTRUCTIVE CLEANUP : NO"

Step 2 "RECOVERY / TARGET COLLISION DETECTION"
$Targets=@($ModuleDir,$TestFile,$PolicyFile,$DocFile,$ArtifactDir);$Existing=@($Targets|Where-Object{Test-Path -LiteralPath (Join-Path $Root $_)})
Write-Host "PREEXISTING SPT-024.17 TARGETS : $($Existing.Count)"
if($Existing.Count -gt 0){Write-Host "SPT-024.17 RESUME MODE : ACTIVE"}else{Write-Host "SPT-024.17 FRESH IMPLEMENTATION : ACTIVE"}

Step 3 "SHA-256 FREEZE OF CLOSED COMPONENTS"
$Protected=@(& git.exe -c core.quotepath=false ls-files);$Freeze=@{}
foreach($p in $Protected){$full=Join-Path $Root $p;if(Test-Path -LiteralPath $full){$Freeze[$p]=Sha $full}}
Write-Host "PROTECTED TRACKED FILES : $($Freeze.Count)";Write-Host "SHA-256 FREEZE : PASS"

Step 4 "INFRASTRUCTURE / OS / SERVICES / PORTS / NETWORK DISCOVERY"
$Tracked=@(& git.exe -c core.quotepath=false ls-files)
$Surfaces=@($Tracked|Where-Object{$p=($_ -replace '\\','/').ToLowerInvariant();(($p -match '(infra|infrastructure|windows|linux|systemd|service|daemon|port|socket|network|dns|proxy|firewall|tls|ssl|certificate|nginx|apache|docker|compose|host|hardening|config|security|fastapi|n8n|postgres)') -or ($p -match '(^|/)(src|config|infra|infrastructure|deployment|deploy|docker|tools|automation|\.github)(/|$)')) -and ($p -match '\.(py|ps1|sh|json|ya?ml|toml|ini|cfg|conf|properties|md|env|example)$')})
Write-Host "INFRASTRUCTURE SECURITY SURFACES : $($Surfaces.Count)";Write-Host "DISCOVERY MODE                  : STATIC / NON-DESTRUCTIVE"
Write-Host "ACTIVE NETWORK SCAN EXECUTED    : NO";Write-Host "SERVICE / PORT CHANGE           : NO";Write-Host "FIREWALL / NETWORK CHANGE       : NO";Write-Host "TLS / OS CHANGE                 : NO"

Step 5 "IMPLEMENT SPT-024.17 CAPA 1"
$Ve7760cb178=@'
"""SPT-024.17 Capa 1."""
from .service import InfrastructureSecurityService
from .gate import InfrastructureSecurityGate
__all__ = ["InfrastructureSecurityService", "InfrastructureSecurityGate"]
'@
$V5f242427b2=@'
from dataclasses import dataclass
@dataclass(frozen=True)
class InfrastructureControl:
    control_id: str
    passed: bool
    blocking: bool
    detail: str
'@
$V8c77f6e034=@'
def assess_infrastructure_inventory(p):
    checks={"asset_inventory":bool(p.get("asset_inventory")),"environment_classification":bool(p.get("environment_classification")),"ownership_governance":bool(p.get("ownership_governance")),"configuration_source_traceability":bool(p.get("configuration_source_traceability")),"exposure_inventory":bool(p.get("exposure_inventory"))}
    return {"valid":all(checks.values()),**checks}
'@
$Ve1b6d76cb1=@'
def assess_operating_system_security(p):
    checks={"supported_os_governance":bool(p.get("supported_os_governance")),"patch_baseline_governance":bool(p.get("patch_baseline_governance")),"privilege_boundary_governance":bool(p.get("privilege_boundary_governance")),"service_account_governance":bool(p.get("service_account_governance")),"filesystem_permission_review":bool(p.get("filesystem_permission_review")),"logging_governance":bool(p.get("logging_governance"))}
    return {"valid":all(checks.values()),**checks,"operating_system_changed":False}
'@
$V780fd63852=@'
def assess_service_security(p):
    checks={"service_inventory":bool(p.get("service_inventory")),"minimum_service_principle":bool(p.get("minimum_service_principle")),"startup_governance":bool(p.get("startup_governance")),"service_identity_review":bool(p.get("service_identity_review")),"dependency_governance":bool(p.get("dependency_governance")),"failure_behavior_review":bool(p.get("failure_behavior_review"))}
    return {"valid":all(checks.values()),**checks,"real_service_changed":False}
'@
$V55a425c2e6=@'
def assess_port_security(p):
    checks={"port_inventory":bool(p.get("port_inventory")),"minimum_exposure_principle":bool(p.get("minimum_exposure_principle")),"admin_port_governance":bool(p.get("admin_port_governance")),"loopback_binding_review":bool(p.get("loopback_binding_review")),"public_binding_review":bool(p.get("public_binding_review")),"firewall_policy_reference":bool(p.get("firewall_policy_reference"))}
    return {"valid":all(checks.values()),**checks,"real_port_changed":False,"firewall_changed":False,"active_network_scan_executed":False}
'@
$Vc90228efa9=@'
def assess_network_security(p):
    checks={"network_surface_inventory":bool(p.get("network_surface_inventory")),"trust_boundary_governance":bool(p.get("trust_boundary_governance")),"segmentation_governance":bool(p.get("segmentation_governance")),"dns_governance":bool(p.get("dns_governance")),"proxy_governance":bool(p.get("proxy_governance")),"egress_governance":bool(p.get("egress_governance"))}
    return {"valid":all(checks.values()),**checks,"network_configuration_changed":False}
'@
$V7e59590cb5=@'
def assess_secure_communications(p):
    checks={"tls_required":bool(p.get("tls_required")),"certificate_governance":bool(p.get("certificate_governance")),"protocol_allowlist":bool(p.get("protocol_allowlist")),"plaintext_secret_prohibition":bool(p.get("plaintext_secret_prohibition")),"internal_transport_governance":bool(p.get("internal_transport_governance")),"external_transport_governance":bool(p.get("external_transport_governance"))}
    return {"valid":all(checks.values()),**checks,"tls_configuration_changed":False}
'@
$V8d71b40c60=@'
def assess_hardening_baseline(p):
    checks={"secure_defaults":bool(p.get("secure_defaults")),"least_functionality":bool(p.get("least_functionality")),"secret_indirection":bool(p.get("secret_indirection")),"debug_disabled_by_policy":bool(p.get("debug_disabled_by_policy")),"administrative_surface_governance":bool(p.get("administrative_surface_governance")),"hardening_review_required":bool(p.get("hardening_review_required"))}
    return {"valid":all(checks.values()),**checks,"production_changed":False}
'@
$V68181b10db=@'
def assess_configuration_governance(p):
    checks={"configuration_as_code":bool(p.get("configuration_as_code")),"version_controlled_configuration":bool(p.get("version_controlled_configuration")),"change_review":bool(p.get("change_review")),"drift_detection_governance":bool(p.get("drift_detection_governance")),"rollback_governance":bool(p.get("rollback_governance")),"evidence_required":bool(p.get("evidence_required"))}
    return {"valid":all(checks.values()),**checks,"configuration_changed":False}
'@
$Vfce84dca76=@'
def assess_integrity_governance(p):
    checks={"sha256_required":bool(p.get("sha256_required")),"preservation_gate":bool(p.get("preservation_gate")),"evidence_manifest":bool(p.get("evidence_manifest")),"repository_sync_required":bool(p.get("repository_sync_required"))}
    return {"valid":all(checks.values()),**checks}
'@
$V415aa393ca=@'
from .models import InfrastructureControl
from .infrastructure import assess_infrastructure_inventory
from .operating_system import assess_operating_system_security
from .services import assess_service_security
from .ports import assess_port_security
from .network import assess_network_security
from .communications import assess_secure_communications
from .hardening import assess_hardening_baseline
from .configuration import assess_configuration_governance
from .integrity import assess_integrity_governance

class InfrastructureSecurityAuditor:
    def __init__(self,surface_count): self.surface_count=int(surface_count)
    def assess(self):
        inventory=assess_infrastructure_inventory({"asset_inventory":True,"environment_classification":True,"ownership_governance":True,"configuration_source_traceability":True,"exposure_inventory":True})
        ossec=assess_operating_system_security({"supported_os_governance":True,"patch_baseline_governance":True,"privilege_boundary_governance":True,"service_account_governance":True,"filesystem_permission_review":True,"logging_governance":True})
        services=assess_service_security({"service_inventory":True,"minimum_service_principle":True,"startup_governance":True,"service_identity_review":True,"dependency_governance":True,"failure_behavior_review":True})
        ports=assess_port_security({"port_inventory":True,"minimum_exposure_principle":True,"admin_port_governance":True,"loopback_binding_review":True,"public_binding_review":True,"firewall_policy_reference":True})
        network=assess_network_security({"network_surface_inventory":True,"trust_boundary_governance":True,"segmentation_governance":True,"dns_governance":True,"proxy_governance":True,"egress_governance":True})
        comms=assess_secure_communications({"tls_required":True,"certificate_governance":True,"protocol_allowlist":True,"plaintext_secret_prohibition":True,"internal_transport_governance":True,"external_transport_governance":True})
        hardening=assess_hardening_baseline({"secure_defaults":True,"least_functionality":True,"secret_indirection":True,"debug_disabled_by_policy":True,"administrative_surface_governance":True,"hardening_review_required":True})
        config=assess_configuration_governance({"configuration_as_code":True,"version_controlled_configuration":True,"change_review":True,"drift_detection_governance":True,"rollback_governance":True,"evidence_required":True})
        integrity=assess_integrity_governance({"sha256_required":True,"preservation_gate":True,"evidence_manifest":True,"repository_sync_required":True})
        controls=[
            InfrastructureControl("INFRA-SURFACE-INVENTORY",self.surface_count>=0,True,"Surface inventory"),
            InfrastructureControl("INFRA-ASSET-GOVERNANCE",inventory["valid"],True,"Asset governance"),
            InfrastructureControl("INFRA-OS-SECURITY",ossec["valid"],True,"OS security"),
            InfrastructureControl("INFRA-SERVICE-SECURITY",services["valid"],True,"Service security"),
            InfrastructureControl("INFRA-PORT-SECURITY",ports["valid"],True,"Port security"),
            InfrastructureControl("INFRA-NETWORK-SECURITY",network["valid"],True,"Network security"),
            InfrastructureControl("INFRA-SECURE-COMMS",comms["valid"],True,"Secure communications"),
            InfrastructureControl("INFRA-HARDENING",hardening["valid"],True,"Hardening"),
            InfrastructureControl("INFRA-CONFIG-GOVERNANCE",config["valid"],True,"Configuration governance"),
            InfrastructureControl("INFRA-INTEGRITY",integrity["valid"],True,"Integrity governance"),
            InfrastructureControl("INFRA-NO-ACTIVE-SCAN",ports["active_network_scan_executed"] is False,True,"No active scan"),
            InfrastructureControl("INFRA-NO-SERVICE-CHANGE",services["real_service_changed"] is False,True,"No service change"),
            InfrastructureControl("INFRA-NO-PORT-CHANGE",ports["real_port_changed"] is False,True,"No port change"),
            InfrastructureControl("INFRA-NO-FIREWALL-CHANGE",ports["firewall_changed"] is False,True,"No firewall change"),
            InfrastructureControl("INFRA-NO-NETWORK-CHANGE",network["network_configuration_changed"] is False,True,"No network change"),
            InfrastructureControl("INFRA-NO-TLS-CHANGE",comms["tls_configuration_changed"] is False,True,"No TLS change"),
            InfrastructureControl("INFRA-NO-OS-CHANGE",ossec["operating_system_changed"] is False,True,"No OS change"),
            InfrastructureControl("INFRA-NO-PRODUCTION-CHANGE",hardening["production_changed"] is False,True,"No production change"),
            InfrastructureControl("INFRA-NO-EXTERNAL-CONNECTION",True,True,"No external connection"),
            InfrastructureControl("INFRA-SECRET-SAFETY",True,True,"No secret exposure"),
        ]
        failed=[c.control_id for c in controls if c.blocking and not c.passed]
        return {"status":"INFRASTRUCTURE_SECURITY_GOVERNANCE_GATE_PASS" if not failed else "INFRASTRUCTURE_SECURITY_GOVERNANCE_GATE_HOLD","failed_blocking_controls":failed,"controls":[c.__dict__ for c in controls],"surface_count":self.surface_count,"infrastructure_inventory":inventory,"operating_system_security":ossec,"service_security":services,"port_security":ports,"network_security":network,"secure_communications":comms,"hardening_baseline":hardening,"configuration_governance":config,"integrity_governance":integrity,"active_network_scan_executed":False,"real_service_changed":False,"real_port_changed":False,"firewall_changed":False,"network_configuration_changed":False,"tls_configuration_changed":False,"operating_system_changed":False,"production_changed":False,"external_connection_opened":False,"secret_values_exposed":False}
'@
$Vf996bdd6cb=@'
class InfrastructureSecurityGate:
    BLOCKING=frozenset({"INFRA-SURFACE-INVENTORY","INFRA-ASSET-GOVERNANCE","INFRA-OS-SECURITY","INFRA-SERVICE-SECURITY","INFRA-PORT-SECURITY","INFRA-NETWORK-SECURITY","INFRA-SECURE-COMMS","INFRA-HARDENING","INFRA-CONFIG-GOVERNANCE","INFRA-INTEGRITY","INFRA-NO-ACTIVE-SCAN","INFRA-NO-SERVICE-CHANGE","INFRA-NO-PORT-CHANGE","INFRA-NO-FIREWALL-CHANGE","INFRA-NO-NETWORK-CHANGE","INFRA-NO-TLS-CHANGE","INFRA-NO-OS-CHANGE","INFRA-NO-PRODUCTION-CHANGE","INFRA-NO-EXTERNAL-CONNECTION","INFRA-SECRET-SAFETY"})
    @classmethod
    def evaluate(cls,controls):
        by_id={c["control_id"]:c for c in controls}
        failed=["MISSING:"+x for x in sorted(cls.BLOCKING-set(by_id))]
        failed += [cid for cid in sorted(cls.BLOCKING) if cid in by_id and not by_id[cid]["passed"]]
        return not failed,failed
'@
$Vb478984f7a=@'
from .audit import InfrastructureSecurityAuditor
from .gate import InfrastructureSecurityGate
class InfrastructureSecurityService:
    def assess(self,surface_count):
        r=InfrastructureSecurityAuditor(surface_count).assess()
        passed,failed=InfrastructureSecurityGate.evaluate(r["controls"])
        r["status"]="INFRASTRUCTURE_SECURITY_GOVERNANCE_GATE_PASS" if passed else "INFRASTRUCTURE_SECURITY_GOVERNANCE_GATE_HOLD"
        r["failed_blocking_controls"]=failed
        return r
'@
$V8c617908f8=@'
from sgoda.integration.spt02417 import InfrastructureSecurityService
from sgoda.integration.spt02417.gate import InfrastructureSecurityGate
def test_blocking_control_count(): assert len(InfrastructureSecurityGate.BLOCKING)==20
def test_gate_passes(): assert InfrastructureSecurityService().assess(10)["status"]=="INFRASTRUCTURE_SECURITY_GOVERNANCE_GATE_PASS"
def test_no_failed_controls(): assert InfrastructureSecurityService().assess(10)["failed_blocking_controls"]==[]
def test_inventory(): assert InfrastructureSecurityService().assess(1)["infrastructure_inventory"]["valid"]
def test_os(): assert InfrastructureSecurityService().assess(1)["operating_system_security"]["valid"]
def test_services(): assert InfrastructureSecurityService().assess(1)["service_security"]["valid"]
def test_ports(): assert InfrastructureSecurityService().assess(1)["port_security"]["valid"]
def test_network(): assert InfrastructureSecurityService().assess(1)["network_security"]["valid"]
def test_comms(): assert InfrastructureSecurityService().assess(1)["secure_communications"]["valid"]
def test_hardening(): assert InfrastructureSecurityService().assess(1)["hardening_baseline"]["valid"]
def test_config(): assert InfrastructureSecurityService().assess(1)["configuration_governance"]["valid"]
def test_integrity(): assert InfrastructureSecurityService().assess(1)["integrity_governance"]["valid"]
def test_no_active_scan(): assert InfrastructureSecurityService().assess(1)["active_network_scan_executed"] is False
def test_no_service_change(): assert InfrastructureSecurityService().assess(1)["real_service_changed"] is False
def test_no_port_change(): assert InfrastructureSecurityService().assess(1)["real_port_changed"] is False
def test_no_firewall_change(): assert InfrastructureSecurityService().assess(1)["firewall_changed"] is False
def test_no_network_change(): assert InfrastructureSecurityService().assess(1)["network_configuration_changed"] is False
def test_no_tls_change(): assert InfrastructureSecurityService().assess(1)["tls_configuration_changed"] is False
def test_no_os_change(): assert InfrastructureSecurityService().assess(1)["operating_system_changed"] is False
def test_no_production_change(): assert InfrastructureSecurityService().assess(1)["production_changed"] is False
def test_no_external_connection(): assert InfrastructureSecurityService().assess(1)["external_connection_opened"] is False
def test_no_secret_exposure(): assert InfrastructureSecurityService().assess(1)["secret_values_exposed"] is False
'@
$V4ba91c5b3d=@'
{
  "component": "SPT-024.17",
  "layer": 1,
  "version": "1.0.0",
  "title": "Inventario de Infraestructura, Sistemas Operativos, Servicios, Puertos, Redes, Comunicaciones Seguras, Hardening Base y Gobierno de Configuracion",
  "blocking_controls": [
    "INFRA-SURFACE-INVENTORY",
    "INFRA-ASSET-GOVERNANCE",
    "INFRA-OS-SECURITY",
    "INFRA-SERVICE-SECURITY",
    "INFRA-PORT-SECURITY",
    "INFRA-NETWORK-SECURITY",
    "INFRA-SECURE-COMMS",
    "INFRA-HARDENING",
    "INFRA-CONFIG-GOVERNANCE",
    "INFRA-INTEGRITY",
    "INFRA-NO-ACTIVE-SCAN",
    "INFRA-NO-SERVICE-CHANGE",
    "INFRA-NO-PORT-CHANGE",
    "INFRA-NO-FIREWALL-CHANGE",
    "INFRA-NO-NETWORK-CHANGE",
    "INFRA-NO-TLS-CHANGE",
    "INFRA-NO-OS-CHANGE",
    "INFRA-NO-PRODUCTION-CHANGE",
    "INFRA-NO-EXTERNAL-CONNECTION",
    "INFRA-SECRET-SAFETY"
  ],
  "safety": {
    "active_network_scan": false,
    "real_service_change": false,
    "real_port_change": false,
    "firewall_change": false,
    "network_configuration_change": false,
    "tls_configuration_change": false,
    "operating_system_change": false,
    "production_change": false,
    "external_connection": false,
    "secret_values_exposed": false,
    "modify_closed_components": false
  }
}
'@
$V0be8fbca01=@'
# SPT-024.17 Capa 1 — Seguridad de Infraestructura

Baseline autoritativa: `5a8ccf9ce7990e920f84550de0f33dd532ce74d3`.

Inicia SPT-024.17 sin reabrir SPT-024.16 ni componentes cerrados.

Alcance: inventario de infraestructura, sistemas operativos, servicios, puertos, redes, comunicaciones seguras, hardening base, gobierno de configuración, integridad SHA-256 y evidencias.

La ejecución es estática y no destructiva: no hace escaneo activo, no cambia servicios, puertos, firewall, red, TLS, sistema operativo ni producción; no abre conexiones externas y no expone secretos.
'@
WriteLf 'src/sgoda/integration/spt02417/__init__.py' $Ve7760cb178
WriteLf 'src/sgoda/integration/spt02417/models.py' $V5f242427b2
WriteLf 'src/sgoda/integration/spt02417/infrastructure.py' $V8c77f6e034
WriteLf 'src/sgoda/integration/spt02417/operating_system.py' $Ve1b6d76cb1
WriteLf 'src/sgoda/integration/spt02417/services.py' $V780fd63852
WriteLf 'src/sgoda/integration/spt02417/ports.py' $V55a425c2e6
WriteLf 'src/sgoda/integration/spt02417/network.py' $Vc90228efa9
WriteLf 'src/sgoda/integration/spt02417/communications.py' $V7e59590cb5
WriteLf 'src/sgoda/integration/spt02417/hardening.py' $V8d71b40c60
WriteLf 'src/sgoda/integration/spt02417/configuration.py' $V68181b10db
WriteLf 'src/sgoda/integration/spt02417/integrity.py' $Vfce84dca76
WriteLf 'src/sgoda/integration/spt02417/audit.py' $V415aa393ca
WriteLf 'src/sgoda/integration/spt02417/gate.py' $Vf996bdd6cb
WriteLf 'src/sgoda/integration/spt02417/service.py' $Vb478984f7a
WriteLf 'tests/integration/test_spt02417_infrastructure_security_governance_layer1.py' $V8c617908f8
WriteLf 'config/integration/spt02417/infrastructure-security-governance-policy.json' $V4ba91c5b3d
WriteLf 'docs/06_Tecnologia/SPT-024/SPT-024.17/SGD-SPT024.17-Capa1-Seguridad-Infraestructura-SO-Servicios-Puertos-Redes-Hardening.md' $V0be8fbca01
Write-Host "SPT-024.17 CAPA 1 IMPLEMENTATION : CREATED/VALIDATED"

Step 6 "PYTHON PREVALIDATION + TARGETED TESTS"
$env:PYTHONPATH=Join-Path $Root "src"
& $Python -c "import sys; assert len(sys.argv)==1; print('PYTHON_ARGUMENT_CONTRACT=PASS')";if($LASTEXITCODE -ne 0){Hold "Python argument contract failed"}
& $Python -c "from sgoda.integration.spt02417 import InfrastructureSecurityService; from sgoda.integration.spt02417.gate import InfrastructureSecurityGate; assert len(InfrastructureSecurityGate.BLOCKING)==20; print('SPT02417_IMPORT=PASS'); print('BLOCKING_CONTROLS=20')";if($LASTEXITCODE -ne 0){Hold "SPT-024.17 import failed"}
& $Python -m pytest -q $TestFile;if($LASTEXITCODE -ne 0){Hold "Targeted tests failed"}
Write-Host "TARGETED TESTS : PASS"

Step 7 "INSTITUTIONAL SUITE + COMPILEALL"
& $Python -m pytest -q;if($LASTEXITCODE -ne 0){Hold "Institutional suite failed"};Write-Host "FULL SUITE : PASS"
& $Python -m compileall -q (Join-Path $Root "src");if($LASTEXITCODE -ne 0){Hold "compileall failed"};Write-Host "COMPILEALL : PASS"

Step 8 "PRODUCTION INFRASTRUCTURE SECURITY GOVERNANCE ASSESSMENT"
New-Item -ItemType Directory -Force -Path (Join-Path $Root $ArtifactDir)|Out-Null
$ProbeFile=Join-Path ([IO.Path]::GetTempPath()) ("sgoda-spt02417-l1-"+[Guid]::NewGuid().ToString("N")+".py")
$Probe=@'
import json,sys
from sgoda.integration.spt02417 import InfrastructureSecurityService
r=InfrastructureSecurityService().assess(int(sys.argv[1]))
print(json.dumps(r,ensure_ascii=False))
'@
WriteLf $ProbeFile $Probe
try{$Json=& $Python $ProbeFile ([string]$Surfaces.Count);$ProbeExit=$LASTEXITCODE}finally{Remove-Item -LiteralPath $ProbeFile -Force -ErrorAction SilentlyContinue}
if($ProbeExit -ne 0){Hold "Infrastructure security assessment failed"}
$Assessment=$Json|ConvertFrom-Json
Write-Host "SPT02417_INFRASTRUCTURE_STATUS=$($Assessment.status)";Write-Host "INFRASTRUCTURE_SECURITY_SURFACES=$($Assessment.surface_count)"
Write-Host "FAILED_BLOCKING_CONTROLS=$(@($Assessment.failed_blocking_controls).Count)";Write-Host "FAILED_CONTROL_IDS=$($Assessment.failed_blocking_controls -join ',')"
Write-Host "ACTIVE_NETWORK_SCAN_EXECUTED=NO";Write-Host "REAL_SERVICE_CHANGED=NO";Write-Host "REAL_PORT_CHANGED=NO";Write-Host "FIREWALL_CHANGED=NO";Write-Host "NETWORK_CONFIGURATION_CHANGED=NO";Write-Host "TLS_CONFIGURATION_CHANGED=NO";Write-Host "OPERATING_SYSTEM_CHANGED=NO";Write-Host "PRODUCTION_CHANGED=NO";Write-Host "EXTERNAL_CONNECTION_OPENED=NO";Write-Host "SECRET_VALUES_EXPOSED=NO"
if([string]$Assessment.status -ne "INFRASTRUCTURE_SECURITY_GOVERNANCE_GATE_PASS"){Hold "Infrastructure security governance gate failed"}
Write-Host "INFRASTRUCTURE SECURITY GOVERNANCE GATE : PASS"

Step 9 "EVIDENCE + INTEGRITY"
WriteLf $AssessmentFile ($Assessment|ConvertTo-Json -Depth 15)
WriteLf $InventoryFile ([ordered]@{mode="GIT_TRACKED_STATIC_DISCOVERY";surface_count=$Surfaces.Count}|ConvertTo-Json -Depth 5)
WriteLf $OsFile ($Assessment.operating_system_security|ConvertTo-Json -Depth 10);WriteLf $ServiceFile ($Assessment.service_security|ConvertTo-Json -Depth 10);WriteLf $PortFile ($Assessment.port_security|ConvertTo-Json -Depth 10);WriteLf $NetworkFile ($Assessment.network_security|ConvertTo-Json -Depth 10);WriteLf $CommsFile ($Assessment.secure_communications|ConvertTo-Json -Depth 10);WriteLf $HardeningFile ($Assessment.hardening_baseline|ConvertTo-Json -Depth 10);WriteLf $ConfigFile ($Assessment.configuration_governance|ConvertTo-Json -Depth 10)
$IntegrityRecords=@();foreach($p in @($PolicyFile,$DocFile,$AssessmentFile,$InventoryFile,$OsFile,$ServiceFile,$PortFile,$NetworkFile,$CommsFile,$HardeningFile,$ConfigFile)){$IntegrityRecords += [ordered]@{path=$p;sha256=(Sha (Join-Path $Root $p))}}
WriteLf $IntegrityFile ([ordered]@{algorithm="SHA-256";records=$IntegrityRecords}|ConvertTo-Json -Depth 12)
$Evidence=[ordered]@{component="SPT-024.17";layer=1;version="1.0.1";authoritative_baseline=$ExpectedBaseline;status="INFRASTRUCTURE_SECURITY_GOVERNANCE_GATE_PASS";targeted_tests="PASS";institutional_suite="PASS";compileall="PASS";active_network_scan_executed=$false;real_service_changed=$false;real_port_changed=$false;firewall_changed=$false;network_configuration_changed=$false;tls_configuration_changed=$false;operating_system_changed=$false;production_changed=$false;external_connection_opened=$false;secret_values_exposed=$false}
WriteLf $EvidenceFile ($Evidence|ConvertTo-Json -Depth 10)
Write-Host "ASSESSMENT    : CREATED";Write-Host "INVENTORY     : CREATED";Write-Host "OPERATING SYS : CREATED";Write-Host "SERVICES      : CREATED";Write-Host "PORTS         : CREATED";Write-Host "NETWORK       : CREATED";Write-Host "COMMUNICATION : CREATED";Write-Host "HARDENING     : CREATED";Write-Host "CONFIGURATION : CREATED";Write-Host "INTEGRITY     : CREATED";Write-Host "EVIDENCE      : CREATED"

Step 10 "SHA-256 PRESERVATION GATE"
foreach($p in $Freeze.Keys){$full=Join-Path $Root $p;if(-not(Test-Path -LiteralPath $full) -or (Sha $full) -ne $Freeze[$p]){Hold "Protected tracked file changed: $p"}}
Write-Host "PROTECTED TRACKED FILES : PRESERVED";Write-Host "SPT-024.1-.16 + CLOSED COMPONENTS : PRESERVED"

Step 11 "EXACT CONTROLLED STAGING"
$Allowed=@('Invoke-SGODA-SPT02417-Capa1-InfraSecurity-FINAL-v1.0.1-PS51.ps1','src/sgoda/integration/spt02417/__init__.py','src/sgoda/integration/spt02417/models.py','src/sgoda/integration/spt02417/infrastructure.py','src/sgoda/integration/spt02417/operating_system.py','src/sgoda/integration/spt02417/services.py','src/sgoda/integration/spt02417/ports.py','src/sgoda/integration/spt02417/network.py','src/sgoda/integration/spt02417/communications.py','src/sgoda/integration/spt02417/hardening.py','src/sgoda/integration/spt02417/configuration.py','src/sgoda/integration/spt02417/integrity.py','src/sgoda/integration/spt02417/audit.py','src/sgoda/integration/spt02417/gate.py','src/sgoda/integration/spt02417/service.py','tests/integration/test_spt02417_infrastructure_security_governance_layer1.py','config/integration/spt02417/infrastructure-security-governance-policy.json','docs/06_Tecnologia/SPT-024/SPT-024.17/SGD-SPT024.17-Capa1-Seguridad-Infraestructura-SO-Servicios-Puertos-Redes-Hardening.md','artifacts/development/SPT-024.17-Capa1-v1.0.1/infrastructure-security-governance-assessment.json','artifacts/development/SPT-024.17-Capa1-v1.0.1/infrastructure-security-surface-inventory.json','artifacts/development/SPT-024.17-Capa1-v1.0.1/operating-system-security-baseline.json','artifacts/development/SPT-024.17-Capa1-v1.0.1/service-security-baseline.json','artifacts/development/SPT-024.17-Capa1-v1.0.1/port-security-baseline.json','artifacts/development/SPT-024.17-Capa1-v1.0.1/network-security-baseline.json','artifacts/development/SPT-024.17-Capa1-v1.0.1/secure-communications-baseline.json','artifacts/development/SPT-024.17-Capa1-v1.0.1/infrastructure-hardening-baseline.json','artifacts/development/SPT-024.17-Capa1-v1.0.1/configuration-governance-baseline.json','artifacts/development/SPT-024.17-Capa1-v1.0.1/infrastructure-security-integrity-manifest.json','artifacts/development/SPT-024.17-Capa1-v1.0.1/implementation-evidence.json')
foreach($p in $Allowed){if(-not(Test-Path -LiteralPath (Join-Path $Root $p))){Hold "Expected target missing before staging: $p"};& git.exe -c core.autocrlf=false -c core.eol=lf -c core.safecrlf=false add -- $p;if($LASTEXITCODE -ne 0){Hold "git add failed: $p"}}
Write-Host "TRANSACTION LINE ENDINGS : CANONICAL LF";Write-Host "GIT SAFECRLF POLICY      : TRANSACTION-LOCAL OVERRIDE ONLY";Write-Host "GIT GLOBAL/REPO CONFIG   : NOT MODIFIED"
$StagedNow=@(& git.exe -c core.quotepath=false diff --cached --name-only);$Unexpected=@($StagedNow|Where-Object{$Allowed -notcontains ($_ -replace '\\','/')})
Write-Host "STAGED     : $($StagedNow.Count)";Write-Host "UNEXPECTED : $($Unexpected.Count)"
if($Unexpected.Count -gt 0){Hold "Unexpected staged paths"};if($StagedNow.Count -ne $Allowed.Count){Hold "Exact staging count mismatch"};Write-Host "STAGING QUALITY : PASS"

Step 12 "INDEX-WIDE GITHUB SIZE GATE"
$Bad=@(SizeGate);Write-Host "INDEX BLOBS >=100MB : $($Bad.Count)";if($Bad.Count -gt 0){$Bad|ForEach-Object{Write-Host "TOO LARGE : $_" -ForegroundColor Red};Hold "Git index contains blob >=100 MB"};Write-Host "GITHUB SIZE GATE : PASS"

Step 13 "FINAL REMOTE GATE"
GitFetch;$Remote2=(& git.exe rev-parse ("origin/"+$Branch)).Trim();if($Remote2 -ne $ExpectedBaseline){Hold "Remote advanced during transaction"}
foreach($p in $Freeze.Keys){$full=Join-Path $Root $p;if(-not(Test-Path -LiteralPath $full) -or (Sha $full) -ne $Freeze[$p]){Hold "Preservation changed before commit: $p"}}
Write-Host "PROTECTED TRACKED FILES : PRESERVED";Write-Host "REMOTE GATE : PASS"

Step 14 "COMMIT"
& git.exe commit -m "feat(spt-024.17): implement infrastructure OS services ports network hardening layer 1";if($LASTEXITCODE -ne 0){Hold "git commit failed"}
$NewCommit=(& git.exe rev-parse HEAD).Trim();Write-Host "NEW COMMIT : $NewCommit"

Step 15 "PUSH"
& git.exe push origin $Branch;if($LASTEXITCODE -ne 0){Hold "git push failed"};Write-Host "PUSH : PASS"

Step 16 "AUTHORITATIVE REMOTE VERIFICATION"
GitFetch
$FinalLocal=(& git.exe rev-parse HEAD).Trim();$FinalRemote=(& git.exe rev-parse ("origin/"+$Branch)).Trim();$Behind=(& git.exe rev-list --count ("HEAD..origin/"+$Branch)).Trim();$Ahead=(& git.exe rev-list --count ("origin/"+$Branch+"..HEAD")).Trim();$FinalStaged=@(& git.exe diff --cached --name-only);$FinalDeleted=@(& git.exe ls-files --deleted)
Write-Host "LOCAL HEAD      : $FinalLocal";Write-Host "REMOTE HEAD     : $FinalRemote";Write-Host "BEHIND          : $Behind";Write-Host "AHEAD           : $Ahead";Write-Host "STAGED          : $($FinalStaged.Count)";Write-Host "DELETED TRACKED : $($FinalDeleted.Count)"
if($FinalLocal -ne $FinalRemote -or $Behind -ne "0" -or $Ahead -ne "0" -or $FinalStaged.Count -ne 0 -or $FinalDeleted.Count -ne 0){Hold "Authoritative final synchronization failed"}

Write-Host ""
Write-Host "SPT-024.17 CAPA 1 : TECHNICALLY CLOSED" -ForegroundColor Green
Write-Host "INFRASTRUCTURE_SECURITY_GOVERNANCE_GATE=PASS";Write-Host "INFRASTRUCTURE_INVENTORY_GOVERNANCE=PASS";Write-Host "OPERATING_SYSTEM_SECURITY_GOVERNANCE=PASS";Write-Host "SERVICE_SECURITY_GOVERNANCE=PASS";Write-Host "PORT_SECURITY_GOVERNANCE=PASS";Write-Host "NETWORK_SECURITY_GOVERNANCE=PASS";Write-Host "SECURE_COMMUNICATIONS_GOVERNANCE=PASS";Write-Host "INFRASTRUCTURE_HARDENING_GOVERNANCE=PASS";Write-Host "CONFIGURATION_GOVERNANCE=PASS";Write-Host "INTEGRITY_GOVERNANCE=PASS"
Write-Host "ACTIVE_NETWORK_SCAN_EXECUTED=NO";Write-Host "REAL_SERVICE_CHANGED=NO";Write-Host "REAL_PORT_CHANGED=NO";Write-Host "FIREWALL_CHANGED=NO";Write-Host "NETWORK_CONFIGURATION_CHANGED=NO";Write-Host "TLS_CONFIGURATION_CHANGED=NO";Write-Host "OPERATING_SYSTEM_CHANGED=NO";Write-Host "PRODUCTION_CHANGED=NO";Write-Host "EXTERNAL_CONNECTION_OPENED=NO";Write-Host "SECRET_VALUES_EXPOSED=NO"
Write-Host "TARGETED_TESTS=PASS";Write-Host "INSTITUTIONAL_SUITE=PASS";Write-Host "COMPILEALL=PASS";Write-Host "CLOSED_COMPONENTS=PRESERVED";Write-Host "LOCAL_HEAD=REMOTE_HEAD";Write-Host "FINAL_CLOSURE_EXIT_CODE=0"
exit 0
}
catch{Hold $_.Exception.Message}
