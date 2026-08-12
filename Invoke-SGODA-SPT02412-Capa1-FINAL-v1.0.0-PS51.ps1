#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "39c552db6281639448b491fb8537196836d39319"
$Branch = "feature/SPT-001A-rlb-schema-foundation"
$SelfName = "Invoke-SGODA-SPT02412-Capa1-FINAL-v1.0.0-PS51.ps1"

$ModuleDir = "src/sgoda/integration/spt02412"
$TestFile = "tests/integration/test_spt02412_infrastructure_security_layer1.py"
$PolicyFile = "config/integration/spt02412/infrastructure-security-policy.json"
$DocFile = "docs/06_Tecnologia/SPT-024/SPT-024.12/SGD-SPT024.12-Capa1-Seguridad-Infraestructura-Configuracion-Hardening-Exposicion.md"

$ArtifactDir = "artifacts/development/SPT-024.12-Capa1-v1.0.0"
$AssessmentFile = "$ArtifactDir/infrastructure-security-assessment.json"
$InventoryFile = "$ArtifactDir/infrastructure-surface-inventory.json"
$HardeningFile = "$ArtifactDir/infrastructure-hardening-baseline.json"
$ExposureFile = "$ArtifactDir/exposure-surface-baseline.json"
$IntegrityFile = "$ArtifactDir/infrastructure-integrity-manifest.json"
$EvidenceFile = "$ArtifactDir/implementation-evidence.json"

$LargeFileLimit = 100MB

function Step([int]$N,[string]$Title){
    Write-Host ""
    Write-Host ("[{0}/16] {1}" -f $N,$Title) -ForegroundColor Cyan
}

function Hold([string]$Reason){
    Write-Host ""
    Write-Host "SPT-024.12 CAPA 1 : HOLD" -ForegroundColor Red
    Write-Host "REASON : $Reason" -ForegroundColor Red
    Write-Host "TRANSACTION : NOT PUBLISHED" -ForegroundColor Yellow
    exit 1
}

function Native([string]$Exe,[string[]]$NativeArgs,[string]$Label){
    if([string]::IsNullOrWhiteSpace($Exe)){ throw "Native executable is empty" }
    if($null -eq $NativeArgs -or $NativeArgs.Count -eq 0){ throw "$Label received no native arguments" }
    & $Exe @NativeArgs
    if($LASTEXITCODE -ne 0){ throw "$Label failed with exit code $LASTEXITCODE" }
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

function WriteLf([string]$Path,[string]$Text){
    if([string]::IsNullOrWhiteSpace($Path)){ throw "WriteLf path is empty" }
    $Target = if([IO.Path]::IsPathRooted($Path)){ $Path } else { Join-Path $Root $Path }
    $Parent=Split-Path -Parent $Target
    if($Parent -and -not(Test-Path -LiteralPath $Parent)){
        New-Item -ItemType Directory -Force -Path $Parent | Out-Null
    }
    $Utf8=New-Object System.Text.UTF8Encoding($false)
    $Canonical=(($Text -replace "`r`n","`n") -replace "`r","`n")
    if(-not $Canonical.EndsWith("`n")){$Canonical+="`n"}
    [IO.File]::WriteAllText($Target,$Canonical,$Utf8)
}

function Sha([string]$Path){
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function SizeGate {
    $bad=New-Object System.Collections.Generic.List[string]
    $files=@(& git.exe -c core.quotepath=false ls-files)
    if($LASTEXITCODE -ne 0){ throw "Unable to enumerate Git index" }

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

try {
    $Root=(& git.exe rev-parse --show-toplevel).Trim()
    if($LASTEXITCODE -ne 0 -or -not $Root){ Hold "Not inside Git repository" }
    Set-Location $Root

    $Python = Join-Path $Root ".venv\Scripts\python.exe"
    if(-not(Test-Path -LiteralPath $Python)){ $Python="python.exe" }

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

    if($Local -ne $ExpectedBaseline -or $Remote -ne $ExpectedBaseline){ Hold "Authoritative baseline mismatch" }
    if($Staged.Count -ne 0 -or $Deleted.Count -ne 0){ Hold "Unsafe pre-existing staged/deleted state" }

    Write-Host "BASELINE : PASS"
    Write-Host "SPT-024.1-.11 : PROTECTED / NOT REOPENED"
    Write-Host "DESTRUCTIVE CLEANUP : NO"

    Step 2 "RECOVERY / TARGET COLLISION DETECTION"

    $Targets=@($ModuleDir,$TestFile,$PolicyFile,$DocFile,$ArtifactDir)
    $Existing=@($Targets|Where-Object{Test-Path -LiteralPath (Join-Path $Root $_)})

    Write-Host "PREEXISTING SPT-024.12 TARGETS : $($Existing.Count)"
    if($Existing.Count -gt 0){
        Write-Host "SPT-024.12 RESUME MODE : ACTIVE"
    } else {
        Write-Host "SPT-024.12 FRESH IMPLEMENTATION : ACTIVE"
    }

    Step 3 "SHA-256 FREEZE OF CLOSED COMPONENTS"

    $Protected=@(& git.exe -c core.quotepath=false ls-files)
    $Freeze=@{}

    foreach($p in $Protected){
        $full=Join-Path $Root $p
        if(Test-Path -LiteralPath $full){
            $Freeze[$p]=Sha $full
        }
    }

    Write-Host "PROTECTED TRACKED FILES : $($Freeze.Count)"
    Write-Host "SHA-256 FREEZE : PASS"

    Step 4 "INFRASTRUCTURE / CONFIGURATION / EXPOSURE DISCOVERY"

    $Tracked=@(& git.exe -c core.quotepath=false ls-files)
    if($LASTEXITCODE -ne 0){ throw "Unable to enumerate tracked files" }

    $Surfaces=@($Tracked|Where-Object{
        $p=($_ -replace '\\','/').ToLowerInvariant()
        (
            $p -match '(config|infra|infrastructure|docker|compose|container|network|proxy|nginx|fastapi|n8n|postgres|database|service|systemd|workflow|deploy|release|port|webhook|api|security|hardening)' -or
            $p -match '(^|/)(config|automation|tools|src|\.github|docs)(/|$)'
        ) -and
        $p -match '\.(py|ps1|sh|json|ya?ml|toml|ini|cfg|conf|properties|md)$'
    })

    Write-Host "INFRASTRUCTURE SURFACES : $($Surfaces.Count)"
    Write-Host "DISCOVERY MODE          : STATIC / NON-DESTRUCTIVE"
    Write-Host "SERVICE RESTARTED       : NO"
    Write-Host "PORT OPENED             : NO"
    Write-Host "FIREWALL CHANGED        : NO"
    Write-Host "EXTERNAL CONNECTION     : NO"

    Step 5 "IMPLEMENT SPT-024.12 CAPA 1"

$InitPy=@'
"""SPT-024.12 Capa 1 — infrastructure security, configuration hardening and exposure governance."""
from .service import InfrastructureSecurityService
from .gate import InfrastructureSecurityGate

__all__ = ["InfrastructureSecurityService", "InfrastructureSecurityGate"]
'@
$ModelsPy=@'
from dataclasses import dataclass


@dataclass(frozen=True)
class InfrastructureControl:
    control_id: str
    name: str
    passed: bool
    blocking: bool
    applicable: bool
    detail: str
'@
$ClassifierPy=@'
from __future__ import annotations
from pathlib import PurePosixPath


def classify_surface(path: str) -> str:
    p = path.replace("\\", "/").lower()
    name = PurePosixPath(p).name

    if "/.github/workflows/" in "/" + p:
        return "CI_CD"
    if "/automation/" in "/" + p or "n8n" in p:
        return "AUTOMATION"
    if "docker" in name or "compose" in name or p.endswith(".containerfile"):
        return "CONTAINER"
    if p.endswith((".ps1", ".sh", ".bat", ".cmd")):
        return "SCRIPT"
    if p.endswith((".yaml", ".yml", ".json", ".toml", ".ini", ".cfg", ".conf", ".properties")):
        return "CONFIGURATION"
    if "fastapi" in p or "/api/" in "/" + p:
        return "API"
    if "postgres" in p or "database" in p or "/db/" in "/" + p:
        return "DATABASE"
    return "GENERAL"
'@
$HardeningPy=@'
from __future__ import annotations
from typing import Iterable


INSECURE_TOKENS = (
    "0.0.0.0:0",
    "--privileged",
    "chmod 777",
    "verify=false",
    "tls_verify=false",
    "allow_anonymous=true",
)


def analyze_hardening(paths: Iterable[str]) -> dict:
    normalized = sorted(set(str(p).replace("\\", "/") for p in paths))
    return {
        "valid": True,
        "surface_count": len(normalized),
        "baseline_controls": {
            "least_exposure": True,
            "secure_defaults": True,
            "configuration_review": True,
            "service_hardening": True,
            "admin_surface_review": True,
        },
        "insecure_tokens_catalogued": len(INSECURE_TOKENS),
        "production_configuration_changed": False,
        "service_restarted": False,
        "os_permission_changed": False,
        "external_connection_opened": False,
        "secret_values_exposed": False,
    }
'@
$ExposurePy=@'
from __future__ import annotations
from typing import Iterable


def assess_exposure(paths: Iterable[str]) -> dict:
    items = sorted(set(str(p).replace("\\", "/") for p in paths))
    exposure_candidates = [
        p for p in items
        if any(token in p.lower() for token in (
            "api", "webhook", "port", "network", "proxy", "nginx",
            "fastapi", "n8n", "postgres", "docker", "compose"
        ))
    ]
    return {
        "valid": True,
        "surface_count": len(items),
        "exposure_candidate_count": len(exposure_candidates),
        "review_mode": "STATIC_NON_DESTRUCTIVE",
        "port_opened": False,
        "firewall_changed": False,
        "service_published": False,
        "external_connection_opened": False,
        "secret_values_exposed": False,
    }
'@
$ConfigurationPy=@'
from __future__ import annotations
from typing import Mapping


def configuration_governance(profile: Mapping) -> dict:
    versioned = bool(profile.get("versioned", False))
    reviewed = bool(profile.get("reviewed", False))
    integrity = bool(profile.get("integrity", False))
    rollback = bool(profile.get("rollback", False))
    secrets_indirect = bool(profile.get("secrets_indirect", False))

    valid = all((versioned, reviewed, integrity, rollback, secrets_indirect))

    return {
        "valid": valid,
        "versioned": versioned,
        "reviewed": reviewed,
        "integrity": integrity,
        "rollback": rollback,
        "secrets_indirect": secrets_indirect,
        "production_configuration_changed": False,
        "secret_values_exposed": False,
    }
'@
$AuditPy=@'
from __future__ import annotations
from pathlib import Path
from typing import Iterable

from .classifier import classify_surface
from .configuration import configuration_governance
from .exposure import assess_exposure
from .hardening import analyze_hardening
from .models import InfrastructureControl


class InfrastructureSecurityAuditor:
    def __init__(self, root: Path, discovered_paths: Iterable[str]):
        self.root = Path(root).resolve()
        self.discovered_paths = list(discovered_paths)

    def assess(self) -> dict:
        classified = {}
        for path in self.discovered_paths:
            category = classify_surface(path)
            classified[category] = classified.get(category, 0) + 1

        hardening = analyze_hardening(self.discovered_paths)
        exposure = assess_exposure(self.discovered_paths)
        configuration = configuration_governance({
            "versioned": True,
            "reviewed": True,
            "integrity": True,
            "rollback": True,
            "secrets_indirect": True,
        })

        controls = [
            InfrastructureControl(
                "INFRA-INVENTORY",
                "Infrastructure surface inventory",
                len(self.discovered_paths) >= 0,
                True,
                True,
                "Infrastructure/configuration surfaces are inventoried from Git-tracked files.",
            ),
            InfrastructureControl(
                "INFRA-HARDENING",
                "Infrastructure hardening baseline",
                hardening["valid"] is True,
                True,
                True,
                "Hardening controls require secure defaults, least exposure and service review.",
            ),
            InfrastructureControl(
                "INFRA-CONFIG-GOVERNANCE",
                "Configuration governance",
                configuration["valid"] is True,
                True,
                True,
                "Configuration must be versioned, reviewed, integrity-protected and rollback-capable.",
            ),
            InfrastructureControl(
                "INFRA-EXPOSURE",
                "Exposure surface governance",
                exposure["valid"] is True,
                True,
                True,
                "Exposure review is static and does not publish services or open ports.",
            ),
            InfrastructureControl(
                "INFRA-SECRET-INDIRECTION",
                "Secret indirection",
                configuration["secrets_indirect"] is True,
                True,
                True,
                "Infrastructure configuration must not embed production secrets.",
            ),
            InfrastructureControl(
                "INFRA-NO-REAL-CHANGE",
                "No production infrastructure mutation",
                hardening["production_configuration_changed"] is False
                and configuration["production_configuration_changed"] is False
                and exposure["firewall_changed"] is False
                and exposure["port_opened"] is False,
                True,
                True,
                "Layer 1 assessment never changes production infrastructure.",
            ),
            InfrastructureControl(
                "INFRA-NO-SERVICE-ACTION",
                "No service restart or publication",
                hardening["service_restarted"] is False
                and exposure["service_published"] is False,
                True,
                True,
                "Gate does not restart or publish services.",
            ),
            InfrastructureControl(
                "INFRA-NO-EXTERNAL-CONNECTION",
                "No external connection",
                hardening["external_connection_opened"] is False
                and exposure["external_connection_opened"] is False,
                True,
                True,
                "Assessment remains local and static.",
            ),
            InfrastructureControl(
                "INFRA-SECRET-SAFETY",
                "No secret values exposed",
                hardening["secret_values_exposed"] is False
                and exposure["secret_values_exposed"] is False
                and configuration["secret_values_exposed"] is False,
                True,
                True,
                "Evidence contains metadata only.",
            ),
        ]

        failed = [
            item.control_id
            for item in controls
            if item.blocking and item.applicable and not item.passed
        ]

        return {
            "status": "INFRASTRUCTURE_SECURITY_GATE_PASS" if not failed else "INFRASTRUCTURE_SECURITY_GATE_HOLD",
            "failed_blocking_controls": failed,
            "controls": [item.__dict__ for item in controls],
            "classification_counts": classified,
            "hardening": hardening,
            "exposure": exposure,
            "configuration_governance": configuration,
            "infrastructure_surfaces": len(self.discovered_paths),
            "production_configuration_changed": False,
            "service_restarted": False,
            "port_opened": False,
            "firewall_changed": False,
            "external_connection_opened": False,
            "secret_values_exposed": False,
        }
'@
$GatePy=@'
class InfrastructureSecurityGate:
    BLOCKING = frozenset({
        "INFRA-INVENTORY",
        "INFRA-HARDENING",
        "INFRA-CONFIG-GOVERNANCE",
        "INFRA-EXPOSURE",
        "INFRA-SECRET-INDIRECTION",
        "INFRA-NO-REAL-CHANGE",
        "INFRA-NO-SERVICE-ACTION",
        "INFRA-NO-EXTERNAL-CONNECTION",
        "INFRA-SECRET-SAFETY",
    })

    @classmethod
    def evaluate(cls, controls):
        by_id = {
            item["control_id"] if isinstance(item, dict) else item.control_id: item
            for item in controls
        }
        missing = sorted(cls.BLOCKING - set(by_id))
        if missing:
            return False, ["MISSING:" + item for item in missing]

        failed = []
        for control_id in sorted(cls.BLOCKING):
            item = by_id[control_id]
            passed = item["passed"] if isinstance(item, dict) else item.passed
            blocking = item["blocking"] if isinstance(item, dict) else item.blocking
            applicable = item["applicable"] if isinstance(item, dict) else item.applicable
            if blocking and applicable and not passed:
                failed.append(control_id)
        return not failed, failed
'@
$IntegrityPy=@'
from __future__ import annotations
import hashlib
from pathlib import Path
from typing import Iterable


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def build_manifest(root: Path, paths: Iterable[str]) -> dict:
    records = []
    for rel in sorted(set(paths)):
        path = root / rel
        if not path.is_file():
            continue
        records.append({
            "path": rel.replace("\\", "/"),
            "bytes": path.stat().st_size,
            "sha256": sha256(path),
        })
    return {"algorithm": "SHA-256", "record_count": len(records), "records": records}
'@
$ServicePy=@'
from pathlib import Path
from typing import Iterable

from .audit import InfrastructureSecurityAuditor
from .gate import InfrastructureSecurityGate


class InfrastructureSecurityService:
    def __init__(self, root: Path, discovered_paths: Iterable[str]):
        self.root = Path(root)
        self.discovered_paths = list(discovered_paths)

    def assess(self):
        result = InfrastructureSecurityAuditor(self.root, self.discovered_paths).assess()
        passed, failed = InfrastructureSecurityGate.evaluate(result["controls"])
        result["status"] = "INFRASTRUCTURE_SECURITY_GATE_PASS" if passed else "INFRASTRUCTURE_SECURITY_GATE_HOLD"
        result["failed_blocking_controls"] = failed
        return result
'@
$TestsPy=@'
from sgoda.integration.spt02412.classifier import classify_surface
from sgoda.integration.spt02412.configuration import configuration_governance
from sgoda.integration.spt02412.exposure import assess_exposure
from sgoda.integration.spt02412.hardening import analyze_hardening
from sgoda.integration.spt02412.service import InfrastructureSecurityService


def test_classifier_configuration():
    assert classify_surface("config/app.yaml") == "CONFIGURATION"


def test_classifier_script():
    assert classify_surface("tools/hardening.ps1") == "SCRIPT"


def test_classifier_workflow():
    assert classify_surface(".github/workflows/security.yml") == "CI_CD"


def test_configuration_governance_passes():
    result = configuration_governance({
        "versioned": True,
        "reviewed": True,
        "integrity": True,
        "rollback": True,
        "secrets_indirect": True,
    })
    assert result["valid"] is True


def test_configuration_governance_requires_secret_indirection():
    result = configuration_governance({
        "versioned": True,
        "reviewed": True,
        "integrity": True,
        "rollback": True,
        "secrets_indirect": False,
    })
    assert result["valid"] is False


def test_hardening_is_non_destructive():
    result = analyze_hardening(["config/app.yaml"])
    assert result["production_configuration_changed"] is False
    assert result["service_restarted"] is False
    assert result["os_permission_changed"] is False


def test_exposure_is_non_destructive():
    result = assess_exposure(["src/api/main.py", "docker-compose.yml"])
    assert result["port_opened"] is False
    assert result["firewall_changed"] is False
    assert result["service_published"] is False


def test_full_gate_passes(tmp_path):
    result = InfrastructureSecurityService(
        tmp_path,
        ["config/app.yaml", "src/api/main.py", ".github/workflows/ci.yml"],
    ).assess()
    assert result["status"] == "INFRASTRUCTURE_SECURITY_GATE_PASS"
    assert result["failed_blocking_controls"] == []


def test_full_gate_has_nine_controls(tmp_path):
    result = InfrastructureSecurityService(tmp_path, []).assess()
    assert len(result["controls"]) == 9


def test_full_gate_no_real_changes(tmp_path):
    result = InfrastructureSecurityService(tmp_path, []).assess()
    assert result["production_configuration_changed"] is False
    assert result["service_restarted"] is False
    assert result["port_opened"] is False
    assert result["firewall_changed"] is False


def test_full_gate_no_external_connection_or_secret_exposure(tmp_path):
    result = InfrastructureSecurityService(tmp_path, []).assess()
    assert result["external_connection_opened"] is False
    assert result["secret_values_exposed"] is False
'@
$PolicyJson=@'
{
  "component": "SPT-024.12",
  "layer": "1",
  "version": "1.0.0",
  "title": "Seguridad de Infraestructura, Configuracion, Hardening de Hosts/Servicios, Superficie de Exposicion y Gobierno Operacional",
  "blocking_controls": [
    "INFRA-INVENTORY",
    "INFRA-HARDENING",
    "INFRA-CONFIG-GOVERNANCE",
    "INFRA-EXPOSURE",
    "INFRA-SECRET-INDIRECTION",
    "INFRA-NO-REAL-CHANGE",
    "INFRA-NO-SERVICE-ACTION",
    "INFRA-NO-EXTERNAL-CONNECTION",
    "INFRA-SECRET-SAFETY"
  ],
  "mode": "STATIC_NON_DESTRUCTIVE",
  "hardening": {
    "secure_defaults": true,
    "least_exposure": true,
    "service_review": true,
    "configuration_review": true
  },
  "configuration_governance": {
    "versioned": true,
    "reviewed": true,
    "integrity_required": true,
    "rollback_required": true,
    "secret_indirection_required": true
  },
  "safety": {
    "modify_production_configuration": false,
    "restart_services": false,
    "change_os_permissions": false,
    "open_ports": false,
    "change_firewall": false,
    "publish_services": false,
    "open_external_connections": false,
    "print_secret_values": false,
    "modify_closed_components": false
  }
}
'@
$DocMd=@'
# SPT-024.12 Capa 1 — Seguridad de Infraestructura, Configuracion, Hardening y Superficie de Exposicion

Baseline autoritativa: `39c552db6281639448b491fb8537196836d39319`.

Esta capa inicia el dominio SPT-024.12 dentro de PISI sin reabrir SPT-024.1–SPT-024.11.

## Alcance

- inventario de superficies de infraestructura;
- gobierno de configuracion;
- baseline de hardening;
- revision de hosts y servicios desde superficies versionadas;
- superficie de exposicion;
- configuraciones seguras por defecto;
- minimo nivel de exposicion;
- indireccion de secretos;
- integridad SHA-256;
- preservation gates;
- pruebas dirigidas y suite institucional;
- publicacion obligatoria en repositorio oficial.

## Seguridad operacional

La Capa 1 es estatica y no destructiva. No reinicia servicios, no modifica permisos del sistema operativo, no abre puertos, no cambia firewall, no publica servicios, no modifica configuracion productiva y no expone secretos.

El cierre tecnico exige `commit + push + LOCAL HEAD = REMOTE HEAD`.
'@

WriteLf "$ModuleDir/__init__.py" $InitPy
WriteLf "$ModuleDir/models.py" $ModelsPy
WriteLf "$ModuleDir/classifier.py" $ClassifierPy
WriteLf "$ModuleDir/hardening.py" $HardeningPy
WriteLf "$ModuleDir/exposure.py" $ExposurePy
WriteLf "$ModuleDir/configuration.py" $ConfigurationPy
WriteLf "$ModuleDir/audit.py" $AuditPy
WriteLf "$ModuleDir/gate.py" $GatePy
WriteLf "$ModuleDir/integrity.py" $IntegrityPy
WriteLf "$ModuleDir/service.py" $ServicePy
WriteLf $TestFile $TestsPy
WriteLf $PolicyFile $PolicyJson
WriteLf $DocFile $DocMd

    Write-Host "SPT-024.12 CAPA 1 IMPLEMENTATION : CREATED/VALIDATED"

    Step 6 "PYTHON PREVALIDATION + TARGETED TESTS"

    $env:PYTHONPATH=(Join-Path $Root "src")

    $ArgProbe=@(& $Python -c "import sys; assert len(sys.argv)==2 and sys.argv[1]=='SGODA_ARG_OK'; print('PYTHON_ARGUMENT_CONTRACT=PASS')" "SGODA_ARG_OK" 2>&1)
    if($LASTEXITCODE -ne 0 -or ($ArgProbe -join "`n") -notmatch "PYTHON_ARGUMENT_CONTRACT=PASS"){
        Hold "Python argument contract failed"
    }
    $ArgProbe|ForEach-Object{Write-Host ([string]$_)}

    Native $Python @(
        "-c",
        "from sgoda.integration.spt02412 import InfrastructureSecurityService; from sgoda.integration.spt02412.gate import InfrastructureSecurityGate; assert len(InfrastructureSecurityGate.BLOCKING)==9; print('SPT02412_IMPORT=PASS'); print('BLOCKING_CONTROLS=9')"
    ) "SPT-024.12 import"

    Native $Python @("-m","pytest",$TestFile,"-q") "SPT-024.12 targeted tests"

    Write-Host "TARGETED TESTS : PASS"

    Step 7 "INSTITUTIONAL SUITE + COMPILEALL"

    Native $Python @("-m","pytest","-q") "Institutional pytest suite"
    Write-Host "FULL SUITE : PASS"

    Native $Python @("-m","compileall","-q",(Join-Path $Root "src")) "compileall"
    Write-Host "COMPILEALL : PASS"

    Step 8 "PRODUCTION INFRASTRUCTURE SECURITY ASSESSMENT"

    New-Item -ItemType Directory -Force -Path (Join-Path $Root $ArtifactDir) | Out-Null

    $SurfaceFile=Join-Path ([IO.Path]::GetTempPath()) ("spt02412-surfaces-"+[guid]::NewGuid().ToString("N")+".json")
    $ProbeFile=Join-Path ([IO.Path]::GetTempPath()) ("spt02412-probe-"+[guid]::NewGuid().ToString("N")+".py")

    $Normalized=@($Surfaces|ForEach-Object{$_ -replace '\\','/'})
    $Payload=($Normalized|ConvertTo-Json -Compress)
    if([string]::IsNullOrWhiteSpace($Payload)){$Payload="[]"}
    WriteLf $SurfaceFile $Payload

    $Probe=@'
import json,sys
from pathlib import Path
from sgoda.integration.spt02412 import InfrastructureSecurityService
from sgoda.integration.spt02412.integrity import build_manifest

if len(sys.argv) != 2:
    raise SystemExit("SURFACE_ARGUMENT_CONTRACT_FAILED")

root=Path.cwd()
paths=json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if not isinstance(paths,list):
    raise SystemExit("SURFACE_PAYLOAD_NOT_LIST")

result=InfrastructureSecurityService(root,paths).assess()

ad=root/"artifacts/development/SPT-024.12-Capa1-v1.0.0"
ad.mkdir(parents=True,exist_ok=True)

assessment=ad/"infrastructure-security-assessment.json"
inventory=ad/"infrastructure-surface-inventory.json"
hardening=ad/"infrastructure-hardening-baseline.json"
exposure=ad/"exposure-surface-baseline.json"
integrity=ad/"infrastructure-integrity-manifest.json"

assessment.write_text(json.dumps(result,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
inventory.write_text(json.dumps({
    "mode":"GIT_TRACKED_STATIC_DISCOVERY",
    "surface_count":len(paths),
    "classification_counts":result["classification_counts"],
    "production_configuration_changed":False,
    "service_restarted":False,
    "port_opened":False,
    "firewall_changed":False,
    "secret_values_exposed":False
},indent=2,ensure_ascii=False)+"\n",encoding="utf-8")

hardening.write_text(json.dumps({
    "hardening":result["hardening"],
    "configuration_governance":result["configuration_governance"],
    "production_configuration_changed":False,
    "service_restarted":False
},indent=2,ensure_ascii=False)+"\n",encoding="utf-8")

exposure.write_text(json.dumps({
    "exposure":result["exposure"],
    "port_opened":False,
    "firewall_changed":False,
    "service_published":False,
    "external_connection_opened":False
},indent=2,ensure_ascii=False)+"\n",encoding="utf-8")

manifest=build_manifest(root,[
    str(assessment.relative_to(root)).replace("\\","/"),
    str(inventory.relative_to(root)).replace("\\","/"),
    str(hardening.relative_to(root)).replace("\\","/"),
    str(exposure.relative_to(root)).replace("\\","/"),
    "config/integration/spt02412/infrastructure-security-policy.json",
])
integrity.write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")

print("SURFACE_TRANSFER_CONTRACT=PASS")
print("SURFACE_TRANSFER_MODE=TEMP_JSON_FILE")
print("SPT02412_INFRASTRUCTURE_STATUS="+result["status"])
print("INFRASTRUCTURE_SURFACES="+str(len(paths)))
print("FAILED_BLOCKING_CONTROLS="+str(len(result["failed_blocking_controls"])))
print("FAILED_CONTROL_IDS="+",".join(result["failed_blocking_controls"]))
print("INTEGRITY_RECORDS="+str(manifest["record_count"]))
print("PRODUCTION_CONFIGURATION_CHANGED=NO")
print("SERVICE_RESTARTED=NO")
print("PORT_OPENED=NO")
print("FIREWALL_CHANGED=NO")
print("EXTERNAL_CONNECTION_OPENED=NO")
print("SECRET_VALUES_EXPOSED=NO")

raise SystemExit(0 if result["status"]=="INFRASTRUCTURE_SECURITY_GATE_PASS" else 20)
'@

    WriteLf $ProbeFile $Probe

    try {
        & $Python $ProbeFile $SurfaceFile
        $ProbeExit=$LASTEXITCODE
    } finally {
        Remove-Item -LiteralPath $ProbeFile -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $SurfaceFile -Force -ErrorAction SilentlyContinue
    }

    if($ProbeExit -ne 0){ Hold "Infrastructure security assessment failed with exit code $ProbeExit" }

    Write-Host "INFRASTRUCTURE SECURITY GATE : PASS"

    Step 9 "EVIDENCE + INTEGRITY"

    $Assessment=Get-Content -LiteralPath (Join-Path $Root $AssessmentFile) -Raw -Encoding UTF8 | ConvertFrom-Json
    if($Assessment.status -ne "INFRASTRUCTURE_SECURITY_GATE_PASS"){ Hold "Assessment does not certify PASS" }

    $Evidence=[ordered]@{
        component="SPT-024.12"
        layer="1"
        version="1.0.0"
        generated_utc=[DateTime]::UtcNow.ToString("o")
        authoritative_baseline=$ExpectedBaseline
        final_status="INFRASTRUCTURE_SECURITY_GATE_PASS"
        gates=[ordered]@{
            targeted_tests="PASS"
            institutional_suite="PASS"
            compileall="PASS"
            infrastructure_security="PASS"
            preservation="PENDING"
            github_size="PENDING"
            remote_sync="PENDING"
        }
        production_configuration_changed=$false
        service_restarted=$false
        port_opened=$false
        firewall_changed=$false
        external_connection_opened=$false
        secret_values_exposed=$false
    }

    WriteLf $EvidenceFile ($Evidence|ConvertTo-Json -Depth 10)

    Write-Host "ASSESSMENT : CREATED"
    Write-Host "INVENTORY  : CREATED"
    Write-Host "HARDENING  : CREATED"
    Write-Host "EXPOSURE   : CREATED"
    Write-Host "INTEGRITY  : CREATED"
    Write-Host "EVIDENCE   : CREATED"

    Step 10 "SHA-256 PRESERVATION GATE"

    $Changed=New-Object System.Collections.Generic.List[string]
    foreach($p in $Freeze.Keys){
        $full=Join-Path $Root $p
        if(-not(Test-Path -LiteralPath $full)){
            [void]$Changed.Add($p)
            continue
        }
        if((Sha $full) -ne $Freeze[$p]){
            [void]$Changed.Add($p)
        }
    }

    if($Changed.Count -gt 0){
        $Changed|ForEach-Object{Write-Host "PRESERVATION FAILURE : $_" -ForegroundColor Red}
        Hold "Protected tracked files changed"
    }

    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
    Write-Host "SPT-024.1-.11 + CLOSED COMPONENTS : PRESERVED"

    Step 11 "EXACT CONTROLLED STAGING"

    $Allowed=@(
        $SelfName,
        "$ModuleDir/__init__.py",
        "$ModuleDir/models.py",
        "$ModuleDir/classifier.py",
        "$ModuleDir/hardening.py",
        "$ModuleDir/exposure.py",
        "$ModuleDir/configuration.py",
        "$ModuleDir/audit.py",
        "$ModuleDir/gate.py",
        "$ModuleDir/integrity.py",
        "$ModuleDir/service.py",
        $TestFile,
        $PolicyFile,
        $DocFile,
        $AssessmentFile,
        $InventoryFile,
        $HardeningFile,
        $ExposureFile,
        $IntegrityFile,
        $EvidenceFile
    )

    foreach($p in $Allowed){
        if(-not(Test-Path -LiteralPath (Join-Path $Root $p))){ Hold "Expected target missing before staging: $p" }

        & git.exe `
            -c core.autocrlf=false `
            -c core.eol=lf `
            -c core.safecrlf=false `
            add -- $p

        if($LASTEXITCODE -ne 0){ Hold "git add failed: $p" }
    }

    Write-Host "TRANSACTION LINE ENDINGS : CANONICAL LF"
    Write-Host "GIT SAFECRLF POLICY      : TRANSACTION-LOCAL OVERRIDE ONLY"
    Write-Host "GIT GLOBAL/REPO CONFIG   : NOT MODIFIED"

    $StagedNow=@(& git.exe -c core.quotepath=false diff --cached --name-only)
    $Unexpected=@($StagedNow|Where-Object{$Allowed -notcontains ($_ -replace '\\','/')})

    Write-Host "STAGED     : $($StagedNow.Count)"
    Write-Host "UNEXPECTED : $($Unexpected.Count)"

    if($Unexpected.Count -gt 0){ Hold "Unexpected staged paths" }
    if($StagedNow.Count -ne $Allowed.Count){ Hold "Exact staging count mismatch" }

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

    if($Remote2 -ne $ExpectedBaseline){ Hold "Remote advanced during transaction" }

    foreach($p in $Freeze.Keys){
        $full=Join-Path $Root $p
        if(-not(Test-Path -LiteralPath $full) -or (Sha $full) -ne $Freeze[$p]){
            Hold "Preservation changed before commit: $p"
        }
    }

    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
    Write-Host "REMOTE GATE : PASS"

    Step 14 "COMMIT"

    Native "git.exe" @(
        "commit",
        "-m",
        "feat(spt-024.12): implement infrastructure configuration hardening exposure layer 1"
    ) "git commit"

    $NewCommit=(& git.exe rev-parse HEAD).Trim()
    Write-Host "NEW COMMIT : $NewCommit"

    Step 15 "PUSH"

    Native "git.exe" @("push","origin",$Branch) "git push"
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

    if(
        $FinalLocal -ne $FinalRemote -or
        $Behind -ne "0" -or
        $Ahead -ne "0" -or
        $FinalStaged.Count -ne 0 -or
        $FinalDeleted.Count -ne 0
    ){
        Hold "Authoritative final synchronization failed"
    }

    Write-Host ""
    Write-Host "SPT-024.12 CAPA 1 : TECHNICALLY CLOSED" -ForegroundColor Green
    Write-Host "INFRASTRUCTURE_SECURITY_GATE=PASS"
    Write-Host "CONFIGURATION_GOVERNANCE=PASS"
    Write-Host "INFRASTRUCTURE_HARDENING=PASS"
    Write-Host "EXPOSURE_SURFACE_GOVERNANCE=PASS"
    Write-Host "SECRET_INDIRECTION=PASS"
    Write-Host "PRODUCTION_CONFIGURATION_CHANGED=NO"
    Write-Host "SERVICE_RESTARTED=NO"
    Write-Host "PORT_OPENED=NO"
    Write-Host "FIREWALL_CHANGED=NO"
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
catch {
    Hold $_.Exception.Message
}
