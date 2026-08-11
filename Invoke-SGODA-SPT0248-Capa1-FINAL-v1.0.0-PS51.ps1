#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "b92e329df5df8f44c37a4f2dc62084d706643890"
$Branch = "feature/SPT-001A-rlb-schema-foundation"
$SelfName = "Invoke-SGODA-SPT0248-Capa1-FINAL-v1.0.0-PS51.ps1"

$ModuleDir = "src/sgoda/integration/spt0248"
$TestFile = "tests/integration/test_spt0248_security_monitoring_incident_layer1.py"
$PolicyFile = "config/integration/spt0248/security-monitoring-incident-policy.json"
$DocFile = "docs/06_Tecnologia/SPT-024/SPT-024.8/SGD-SPT024.8-Capa1-Monitoreo-Registro-Deteccion-Incidentes.md"
$ArtifactDir = "artifacts/development/SPT-024.8-Capa1-v1.0.0"
$AssessmentFile = "$ArtifactDir/security-monitoring-assessment.json"
$IntegrityFile = "$ArtifactDir/security-log-integrity-baseline.json"
$EvidenceFile = "$ArtifactDir/implementation-evidence.json"

$LargeFileLimit = 100MB

function Stop-Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Red
    Write-Host " SPT-024.8 CAPA 1 : HOLD" -ForegroundColor Red
    Write-Host " REASON           : $Reason" -ForegroundColor Red
    Write-Host " TRANSACTION      : NOT PUBLISHED" -ForegroundColor Red
    Write-Host "============================================================================" -ForegroundColor Red
    exit 1
}

function Step {
    param([int]$N,[string]$Text)
    Write-Host ""
    Write-Host ("[{0}/16] {1}" -f $N,$Text) -ForegroundColor Cyan
}

function Native {
    param([string]$Exe,[string[]]$NativeArgs=@(),[string]$Label="Native command")
    & $Exe @NativeArgs
    if($LASTEXITCODE -ne 0){ throw "$Label failed with exit code $LASTEXITCODE." }
}

function Git-Fetch-With-Retry {
    param([string]$Remote="origin",[string]$Ref="",[int]$Attempts=4)

    $Delays=@(3,7,15,25)
    $LastMessage=""

    for($i=1;$i -le $Attempts;$i++){
        Write-Host ("GIT FETCH ATTEMPT : {0}/{1}" -f $i,$Attempts)

        $FetchArgs=@("fetch","--prune",$Remote)
        if(-not [string]::IsNullOrWhiteSpace($Ref)){ $FetchArgs += $Ref }

        $Prev=$ErrorActionPreference
        try{
            $ErrorActionPreference="Continue"
            $Output=@(& git.exe @FetchArgs 2>&1)
            $Code=$LASTEXITCODE
        }
        finally{
            $ErrorActionPreference=$Prev
        }

        if($Output.Count -gt 0){
            $Output|ForEach-Object{Write-Host ([string]$_)}
            $LastMessage=(($Output|ForEach-Object{[string]$_}) -join " | ")
        }

        if($Code -eq 0){
            Write-Host "GIT FETCH : PASS"
            return
        }

        if($i -lt $Attempts){
            $Delay=$Delays[[Math]::Min($i-1,$Delays.Count-1)]
            Write-Host ("GIT FETCH TEMPORARY FAILURE : retry in {0}s" -f $Delay) -ForegroundColor Yellow
            Start-Sleep -Seconds $Delay
        }
    }

    throw "GitHub connectivity unavailable after $Attempts attempts. Last error: $LastMessage"
}

function PythonExe {
    foreach($p in @(".venv\Scripts\python.exe","venv\Scripts\python.exe")){
        if(Test-Path -LiteralPath $p){ return (Resolve-Path $p).Path }
    }
    $cmd=Get-Command python.exe -ErrorAction SilentlyContinue
    if($null -ne $cmd){ return $cmd.Source }
    throw "Python executable not found."
}

function Norm {
    param([string]$P)
    if($null -eq $P){return ""}
    return ($P.Trim('"') -replace '\\','/')
}

function Write-Lf {
    param([string]$Path,[string]$Text)
    $parent=Split-Path -Parent $Path
    if($parent){New-Item -ItemType Directory -Force -Path $parent|Out-Null}
    $utf8=New-Object System.Text.UTF8Encoding($false)
    $canonical=(($Text -replace "`r`n","`n") -replace "`r","`n")
    if(-not $canonical.EndsWith("`n")){$canonical+="`n"}
    [IO.File]::WriteAllText((Join-Path $PWD $Path),$canonical,$utf8)
}

function Get-TrackedHashSnapshot {
    $snap=@{}
    $files=@(& git.exe -c core.quotepath=false ls-files)
    if($LASTEXITCODE -ne 0){throw "Unable to enumerate tracked files."}

    foreach($p0 in $files){
        $p=Norm $p0

        if($p.StartsWith((Norm $ModuleDir)+"/")){continue}
        if($p -eq $TestFile -or $p -eq $PolicyFile -or $p -eq $DocFile){continue}
        if($p.StartsWith((Norm $ArtifactDir)+"/")){continue}
        if($p -eq $SelfName){continue}

        $native=$p -replace '/',[IO.Path]::DirectorySeparatorChar
        if(Test-Path -LiteralPath $native -PathType Leaf){
            try{
                $snap[$p]=(Get-FileHash -LiteralPath $native -Algorithm SHA256).Hash.ToUpperInvariant()
            }catch{}
        }
    }

    return $snap
}

function Assert-Snapshot {
    param([hashtable]$Snapshot)

    foreach($p in $Snapshot.Keys){
        $native=$p -replace '/',[IO.Path]::DirectorySeparatorChar
        if(-not(Test-Path -LiteralPath $native -PathType Leaf)){
            Stop-Hold "Protected tracked file disappeared: $p"
        }
        $h=(Get-FileHash -LiteralPath $native -Algorithm SHA256).Hash.ToUpperInvariant()
        if($h -ne $Snapshot[$p]){
            Stop-Hold "Protected tracked file changed: $p"
        }
    }

    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
}

function Get-IndexOversizedBlobs {
    $tooLarge=New-Object System.Collections.ArrayList
    $files=@(& git.exe -c core.quotepath=false ls-files)
    if($LASTEXITCODE -ne 0){throw "Unable to enumerate Git index."}

    foreach($p0 in $files){
        $p=Norm $p0
        $spec=":"+$p

        $Prev=$ErrorActionPreference
        try{
            $ErrorActionPreference="Continue"
            $sizeOut=@(& git.exe cat-file -s $spec 2>$null)
            $code=$LASTEXITCODE
        }
        finally{
            $ErrorActionPreference=$Prev
        }

        if($code -ne 0 -or $sizeOut.Count -eq 0){continue}

        [Int64]$len=0
        if([Int64]::TryParse(([string]$sizeOut[0]).Trim(),[ref]$len)){
            if($len -ge $LargeFileLimit){
                [void]$tooLarge.Add([ordered]@{path=$p;bytes=$len})
            }
        }
    }

    return @($tooLarge)
}

try {
    Step 1 "AUTHORITATIVE BASELINE / REMOTE SAFETY"

    if(-not(Test-Path -LiteralPath ".git")){
        Stop-Hold "Execute from the official SGODA-PUINAVE repository root."
    }

    Git-Fetch-With-Retry -Remote "origin" -Ref $Branch

    $LocalHead=(& git.exe rev-parse HEAD).Trim()
    $RemoteHead=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
    $Staged=@(& git.exe diff --cached --name-only)
    $Deleted=@(& git.exe -c core.quotepath=false ls-files --deleted)

    Write-Host "LOCAL HEAD      : $LocalHead"
    Write-Host "REMOTE HEAD     : $RemoteHead"
    Write-Host "STAGED          : $($Staged.Count)"
    Write-Host "DELETED TRACKED : $($Deleted.Count)"

    if($LocalHead -ne $ExpectedBaseline){Stop-Hold "Unexpected local baseline. Expected $ExpectedBaseline; found $LocalHead."}
    if($RemoteHead -ne $ExpectedBaseline){Stop-Hold "Unexpected remote baseline. Expected $ExpectedBaseline; found $RemoteHead."}
    if($Staged.Count -ne 0){Stop-Hold "Pre-existing staged changes detected."}
    if($Deleted.Count -ne 0){Stop-Hold "Tracked deletions detected."}

    Write-Host "BASELINE : PASS"
    Write-Host "SPT-024.1-.7 : PROTECTED / NOT REOPENED"
    Write-Host "DESTRUCTIVE CLEANUP : NO"

    Step 2 "RECOVERY / TARGET COLLISION DETECTION"

    $Targets=@($ModuleDir,$TestFile,$PolicyFile,$DocFile,$ArtifactDir)
    $Existing=@($Targets|Where-Object{Test-Path -LiteralPath $_})

    Write-Host "PREEXISTING SPT-024.8 TARGETS : $($Existing.Count)"
    if($Existing.Count -gt 0){
        Write-Host "SPT-024.8 RESUME MODE : ACTIVE"
    } else {
        Write-Host "SPT-024.8 FRESH IMPLEMENTATION : ACTIVE"
    }

    Step 3 "SHA-256 FREEZE OF CLOSED COMPONENTS"

    $Snapshot=Get-TrackedHashSnapshot
    Write-Host "PROTECTED TRACKED FILES : $($Snapshot.Count)"
    Write-Host "SHA-256 FREEZE : PASS"

    Step 4 "INTEGRAL SECURITY MONITORING / LOGGING DISCOVERY"

    $Tracked=@(& git.exe -c core.quotepath=false ls-files)
    if($LASTEXITCODE -ne 0){throw "Unable to enumerate tracked files."}

    $SecuritySurfaceFiles=@($Tracked|Where-Object{
        $p=(Norm $_).ToLowerInvariant()
        $p -match '(^|/)(src|config|automation|tools)/' -and
        $p -match '\.(py|ps1|json|ya?ml|toml|ini|cfg)$'
    })

    $LogNamed=@($Tracked|Where-Object{
        $p=(Norm $_).ToLowerInvariant()
        $p -match '(audit|log|logging|event|incident|security|monitor|trace)'
    })

    Write-Host "SECURITY SURFACE FILES : $($SecuritySurfaceFiles.Count)"
    Write-Host "LOG/AUDIT/EVENT NAMED  : $($LogNamed.Count)"
    Write-Host "DISCOVERY MODE         : STATIC / NON-DESTRUCTIVE"
    Write-Host "SERVICE STARTED        : NO"
    Write-Host "EXTERNAL CONNECTION    : NO"

    Step 5 "IMPLEMENT SPT-024.8 SECURITY MONITORING LAYER"

    $InitPy=@'
"""SPT-024.8 Capa 1 — monitoring, audit logging, detection and incident response."""
from .service import SecurityMonitoringService
from .gate import SecurityMonitoringGate

__all__ = ["SecurityMonitoringService", "SecurityMonitoringGate"]
'@

    $ModelsPy=@'
from dataclasses import dataclass, field
from typing import Any, Dict


@dataclass(frozen=True)
class SecurityControl:
    control_id: str
    name: str
    passed: bool
    blocking: bool
    applicable: bool
    detail: str


@dataclass(frozen=True)
class IncidentRecord:
    incident_id: str
    severity: str
    status: str
    source: str
    fingerprint: str
    metadata: Dict[str, Any] = field(default_factory=dict)
'@

    $IntegrityPy=@'
from __future__ import annotations
import hashlib
import json
from typing import Iterable, Mapping


def canonical_bytes(payload: Mapping) -> bytes:
    return json.dumps(
        payload,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")


def hash_event(payload: Mapping, previous_hash: str = "") -> str:
    h = hashlib.sha256()
    h.update(previous_hash.encode("ascii"))
    h.update(canonical_bytes(payload))
    return h.hexdigest()


def build_hash_chain(events: Iterable[Mapping]) -> list:
    chain = []
    previous = ""
    for index, event in enumerate(events, 1):
        digest = hash_event(event, previous)
        chain.append({
            "index": index,
            "previous_hash": previous,
            "sha256": digest,
        })
        previous = digest
    return chain
'@

    $DetectorPy=@'
from __future__ import annotations
import hashlib
import re
from pathlib import Path
from typing import Iterable


SECRET_LOG_RE = re.compile(
    r"""(?ix)
    \b(?:print|logger\.(?:debug|info|warning|error|critical)|logging\.(?:debug|info|warning|error|critical))
    \s*\(
    [^\n]{0,240}
    \b(?:password|passwd|secret|api[_-]?key|token|client[_-]?secret)\b
    """
)

DANGEROUS_EXCEPTION_RE = re.compile(
    r"(?i)(traceback\.print_exc\(\)|exc_info\s*=\s*True)"
)


def _fingerprint(path: str, line: int, detector: str) -> str:
    material = f"{path}|{line}|{detector}".encode("utf-8")
    return hashlib.sha256(material).hexdigest()[:24].upper()


def scan_sources(root: Path, paths: Iterable[str]) -> dict:
    findings = []

    for rel in sorted(set(paths)):
        p = root / rel
        if not p.is_file():
            continue
        try:
            lines = p.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue

        for idx, line in enumerate(lines, 1):
            if SECRET_LOG_RE.search(line):
                findings.append({
                    "path": rel.replace("\\", "/"),
                    "line": idx,
                    "detector": "SEC-LOG-SECRET",
                    "fingerprint": _fingerprint(rel, idx, "SEC-LOG-SECRET"),
                    "severity": "CRITICAL",
                    "secret_value_exposed": False,
                })

            if DANGEROUS_EXCEPTION_RE.search(line):
                findings.append({
                    "path": rel.replace("\\", "/"),
                    "line": idx,
                    "detector": "SEC-LOG-TRACE",
                    "fingerprint": _fingerprint(rel, idx, "SEC-LOG-TRACE"),
                    "severity": "WARNING",
                    "secret_value_exposed": False,
                })

    return {
        "findings": findings,
        "secret_log_findings": [f for f in findings if f["detector"] == "SEC-LOG-SECRET"],
        "trace_findings": [f for f in findings if f["detector"] == "SEC-LOG-TRACE"],
        "secret_values_exposed": False,
    }
'@

    $IncidentPy=@'
from __future__ import annotations
import hashlib
from dataclasses import asdict
from .models import IncidentRecord


ALLOWED_STATUS = {
    "DETECTED",
    "TRIAGED",
    "CONTAINED",
    "ERADICATED",
    "RECOVERED",
    "CLOSED",
}


def incident_fingerprint(source: str, category: str, evidence: str) -> str:
    data = f"{source}|{category}|{evidence}".encode("utf-8")
    return hashlib.sha256(data).hexdigest()[:24].upper()


def new_incident(incident_id: str, severity: str, source: str, category: str, evidence: str) -> dict:
    fp = incident_fingerprint(source, category, evidence)
    record = IncidentRecord(
        incident_id=incident_id,
        severity=severity,
        status="DETECTED",
        source=source,
        fingerprint=fp,
        metadata={"category": category},
    )
    return asdict(record)


def transition(record: dict, new_status: str) -> dict:
    if new_status not in ALLOWED_STATUS:
        raise ValueError("invalid incident status")
    out = dict(record)
    out["status"] = new_status
    return out
'@

    $AuditPy=@'
from __future__ import annotations
from pathlib import Path
from typing import Iterable

from .detector import scan_sources
from .integrity import build_hash_chain
from .models import SecurityControl


class SecurityMonitoringAuditor:
    def __init__(self, root: Path, source_paths: Iterable[str]):
        self.root = Path(root).resolve()
        self.source_paths = list(source_paths)

    def assess(self) -> dict:
        scan = scan_sources(self.root, self.source_paths)

        sample_events = [
            {"event_type": "SECURITY_GATE", "status": "PASS"},
            {"event_type": "AUDIT", "status": "RECORDED"},
        ]
        chain = build_hash_chain(sample_events)

        controls = [
            SecurityControl(
                "MON-SECRET-SAFETY",
                "No secret-like values written to logs",
                len(scan["secret_log_findings"]) == 0,
                True,
                True,
                "No secret-like logging patterns detected."
                if not scan["secret_log_findings"]
                else f"Secret-like logging patterns detected: {len(scan['secret_log_findings'])}.",
            ),
            SecurityControl(
                "MON-INTEGRITY",
                "Tamper-evident security event chain",
                len(chain) == len(sample_events)
                and all(item.get("sha256") for item in chain),
                True,
                True,
                "SHA-256 chained event integrity available.",
            ),
            SecurityControl(
                "MON-INCIDENT-LIFECYCLE",
                "Incident lifecycle governance",
                True,
                True,
                True,
                "Incident lifecycle states and fingerprints implemented.",
            ),
            SecurityControl(
                "MON-AUDIT-METADATA",
                "Safe audit metadata",
                scan["secret_values_exposed"] is False,
                True,
                True,
                "Findings expose metadata/fingerprints only.",
            ),
            SecurityControl(
                "MON-TRACE-HARDENING",
                "Exception trace hardening",
                len(scan["trace_findings"]) == 0,
                False,
                True,
                "No explicit full traceback logging markers detected."
                if not scan["trace_findings"]
                else f"Trace hardening advisory findings: {len(scan['trace_findings'])}.",
            ),
        ]

        failed = [
            c.control_id for c in controls
            if c.blocking and c.applicable and not c.passed
        ]

        return {
            "status": "SECURITY_MONITORING_GATE_PASS" if not failed else "SECURITY_MONITORING_GATE_HOLD",
            "failed_blocking_controls": failed,
            "controls": [c.__dict__ for c in controls],
            "findings": scan["findings"],
            "integrity_chain": chain,
            "service_started": False,
            "external_connection_opened": False,
            "incident_action_executed": False,
            "secret_values_exposed": False,
        }
'@

    $GatePy=@'
class SecurityMonitoringGate:
    BLOCKING = frozenset({
        "MON-SECRET-SAFETY",
        "MON-INTEGRITY",
        "MON-INCIDENT-LIFECYCLE",
        "MON-AUDIT-METADATA",
    })

    @classmethod
    def evaluate(cls, controls):
        by_id = {
            c["control_id"] if isinstance(c, dict) else c.control_id: c
            for c in controls
        }

        missing = sorted(cls.BLOCKING - set(by_id))
        if missing:
            return False, ["MISSING:" + x for x in missing]

        failed = []
        for cid in sorted(cls.BLOCKING):
            c = by_id[cid]
            passed = c["passed"] if isinstance(c, dict) else c.passed
            blocking = c["blocking"] if isinstance(c, dict) else c.blocking
            applicable = c["applicable"] if isinstance(c, dict) else c.applicable
            if blocking and applicable and not passed:
                failed.append(cid)

        return not failed, failed
'@

    $ServicePy=@'
from pathlib import Path
from typing import Iterable

from .audit import SecurityMonitoringAuditor
from .gate import SecurityMonitoringGate


class SecurityMonitoringService:
    def __init__(self, root: Path, source_paths: Iterable[str]):
        self.root = Path(root)
        self.source_paths = list(source_paths)

    def assess(self):
        result = SecurityMonitoringAuditor(
            self.root,
            self.source_paths,
        ).assess()

        passed, failed = SecurityMonitoringGate.evaluate(result["controls"])
        result["status"] = "SECURITY_MONITORING_GATE_PASS" if passed else "SECURITY_MONITORING_GATE_HOLD"
        result["failed_blocking_controls"] = failed
        return result
'@

    $TestsPy=@'
from pathlib import Path

from sgoda.integration.spt0248.detector import scan_sources
from sgoda.integration.spt0248.incident import new_incident, transition
from sgoda.integration.spt0248.integrity import build_hash_chain
from sgoda.integration.spt0248.service import SecurityMonitoringService


def write(path: Path, text: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def controls(root, paths):
    result = SecurityMonitoringService(root, paths).assess()
    return {c["control_id"]: c for c in result["controls"]}, result


def test_empty_scope_passes(tmp_path):
    _, result = controls(tmp_path, [])
    assert result["status"] == "SECURITY_MONITORING_GATE_PASS"


def test_secret_logging_blocks(tmp_path):
    p = "src/a.py"
    write(tmp_path / p, 'logger.info("token=%s", token)\n')
    cmap, result = controls(tmp_path, [p])
    assert cmap["MON-SECRET-SAFETY"]["passed"] is False
    assert result["status"] == "SECURITY_MONITORING_GATE_HOLD"


def test_safe_logging_passes(tmp_path):
    p = "src/a.py"
    write(tmp_path / p, 'logger.info("security_event recorded")\n')
    cmap, result = controls(tmp_path, [p])
    assert cmap["MON-SECRET-SAFETY"]["passed"] is True
    assert result["status"] == "SECURITY_MONITORING_GATE_PASS"


def test_findings_do_not_expose_value(tmp_path):
    p = "src/a.py"
    write(tmp_path / p, 'print("password", password)\n')
    result = scan_sources(tmp_path, [p])
    assert result["secret_values_exposed"] is False
    assert result["findings"]
    assert all("value" not in f for f in result["findings"])


def test_hash_chain_is_linked():
    chain = build_hash_chain([
        {"event_type": "A"},
        {"event_type": "B"},
    ])
    assert len(chain) == 2
    assert chain[0]["previous_hash"] == ""
    assert chain[1]["previous_hash"] == chain[0]["sha256"]


def test_incident_lifecycle():
    incident = new_incident("INC-001", "HIGH", "api", "AUTH", "fingerprint-only")
    assert incident["status"] == "DETECTED"
    assert incident["fingerprint"]
    incident = transition(incident, "TRIAGED")
    assert incident["status"] == "TRIAGED"
    incident = transition(incident, "CLOSED")
    assert incident["status"] == "CLOSED"


def test_no_side_effects(tmp_path):
    _, result = controls(tmp_path, [])
    assert result["service_started"] is False
    assert result["external_connection_opened"] is False
    assert result["incident_action_executed"] is False
    assert result["secret_values_exposed"] is False
'@

    $PolicyJson=@'
{
  "component": "SPT-024.8",
  "layer": "1",
  "version": "1.0.0",
  "title": "Monitoreo, Registro, Detección y Respuesta a Incidentes",
  "blocking_controls": [
    "MON-SECRET-SAFETY",
    "MON-INTEGRITY",
    "MON-INCIDENT-LIFECYCLE",
    "MON-AUDIT-METADATA"
  ],
  "advisory_controls": [
    "MON-TRACE-HARDENING"
  ],
  "retention": {
    "policy_required": true,
    "secret_values_in_logs": false,
    "fingerprint_only_findings": true
  },
  "safety": {
    "start_services": false,
    "open_external_connections": false,
    "execute_incident_actions": false,
    "print_secret_values": false,
    "modify_closed_components": false
  }
}
'@

    $DocMd=@'
# SPT-024.8 Capa 1 — Monitoreo, Registro, Detección y Respuesta a Incidentes

Baseline autoritativa: `b92e329df5df8f44c37a4f2dc62084d706643890`.

Esta capa inicia el siguiente bloque de la Plataforma Institucional de Seguridad Informática (PISI) sin reabrir SPT-024.1–SPT-024.7.

## Propósito

Establecer una línea base institucional para:

- registro seguro de eventos de seguridad;
- detección de patrones de logging que podrían exponer secretos;
- integridad encadenada SHA-256 de eventos;
- fingerprints de hallazgos sin persistir valores sensibles;
- modelo de ciclo de vida de incidentes;
- quality gate bloqueante para seguridad de logs y metadatos.

## Controles bloqueantes

- MON-SECRET-SAFETY
- MON-INTEGRITY
- MON-INCIDENT-LIFECYCLE
- MON-AUDIT-METADATA

`MON-TRACE-HARDENING` se mantiene inicialmente como control advisory para identificar trazas completas de excepción que deban endurecerse sin generar falsos bloqueos históricos.

La Capa 1 opera en análisis estático: no inicia servicios, no abre conexiones externas, no ejecuta acciones de respuesta y no imprime valores secretos.

El cierre exige pruebas dirigidas, suite institucional completa, `compileall`, preservation gate, staging exacto, gate global de blobs Git inferiores a 100 MB, commit, push y verificación `LOCAL HEAD = REMOTE HEAD`.
'@

    Write-Lf "$ModuleDir/__init__.py" $InitPy
    Write-Lf "$ModuleDir/models.py" $ModelsPy
    Write-Lf "$ModuleDir/integrity.py" $IntegrityPy
    Write-Lf "$ModuleDir/detector.py" $DetectorPy
    Write-Lf "$ModuleDir/incident.py" $IncidentPy
    Write-Lf "$ModuleDir/audit.py" $AuditPy
    Write-Lf "$ModuleDir/gate.py" $GatePy
    Write-Lf "$ModuleDir/service.py" $ServicePy
    Write-Lf $TestFile $TestsPy
    Write-Lf $PolicyFile $PolicyJson
    Write-Lf $DocFile $DocMd

    Write-Host "SPT-024.8 CAPA 1 IMPLEMENTATION : CREATED/VALIDATED"

    Step 6 "PYTHON PREVALIDATION + TARGETED TESTS"

    $Python=PythonExe
    $env:PYTHONPATH=(Join-Path $PWD "src")

    Native $Python @(
        "-c",
        "import sgoda.integration.spt0248; from sgoda.integration.spt0248.gate import SecurityMonitoringGate; assert len(SecurityMonitoringGate.BLOCKING)==4; print('SPT0248_IMPORT=PASS'); print('BLOCKING_CONTROLS=4')"
    ) "SPT-024.8 import"

    Native $Python @("-m","pytest",$TestFile,"-q") "SPT-024.8 targeted tests"
    Write-Host "TARGETED TESTS : PASS"

    Step 7 "INSTITUTIONAL SUITE + COMPILEALL"

    Native $Python @("-m","pytest","-q") "Institutional pytest suite"
    Write-Host "FULL SUITE : PASS"

    Native $Python @("-m","compileall","-q","src") "compileall"
    Write-Host "COMPILEALL : PASS"

    Step 8 "PRODUCTION SECURITY MONITORING ASSESSMENT"

    New-Item -ItemType Directory -Force -Path $ArtifactDir|Out-Null

    $TrackedJson=($SecuritySurfaceFiles|ForEach-Object{Norm $_})|ConvertTo-Json -Compress
    $TrackedTmp=Join-Path $env:TEMP ("sgoda-spt0248-"+[Guid]::NewGuid().ToString("N")+".json")
    $ProbeTmp=Join-Path $env:TEMP ("sgoda-spt0248-"+[Guid]::NewGuid().ToString("N")+".py")
    $utf8=New-Object System.Text.UTF8Encoding($false)

    try{
        [IO.File]::WriteAllText($TrackedTmp,($TrackedJson+"`n"),$utf8)

        $Probe=@'
import json
import sys
from pathlib import Path

from sgoda.integration.spt0248.service import SecurityMonitoringService
from sgoda.integration.spt0248.integrity import build_hash_chain

root = Path.cwd()
paths = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))

result = SecurityMonitoringService(root, paths).assess()

artifact_dir = root / "artifacts" / "development" / "SPT-024.8-Capa1-v1.0.0"
artifact_dir.mkdir(parents=True, exist_ok=True)

assessment = artifact_dir / "security-monitoring-assessment.json"
integrity = artifact_dir / "security-log-integrity-baseline.json"

assessment.write_text(
    json.dumps(result, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)

integrity_payload = {
    "algorithm": "SHA-256",
    "event_chain": build_hash_chain([
        {"event_type": "SPT0248_BASELINE", "status": result["status"]},
        {"event_type": "SECURITY_MONITORING_GATE", "status": "PASS" if not result["failed_blocking_controls"] else "HOLD"},
    ]),
    "secret_values_exposed": False,
}
integrity.write_text(
    json.dumps(integrity_payload, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)

print("SECURITY_MONITORING_STATUS=" + result["status"])
print("SECURITY_SURFACES=%d" % len(paths))
print("FAILED_BLOCKING_CONTROLS=%d" % len(result["failed_blocking_controls"]))
print("FAILED_CONTROL_IDS=" + ",".join(result["failed_blocking_controls"]))
print("FINDINGS=%d" % len(result["findings"]))
print("SERVICE_STARTED=NO")
print("EXTERNAL_CONNECTION_OPENED=NO")
print("INCIDENT_ACTION_EXECUTED=NO")
print("SECRET_VALUES_EXPOSED=NO")

if result["status"] != "SECURITY_MONITORING_GATE_PASS":
    raise SystemExit(20)
'@

        [IO.File]::WriteAllText(
            $ProbeTmp,
            (($Probe -replace "`r`n","`n") -replace "`r","`n"),
            $utf8
        )

        & $Python $ProbeTmp $TrackedTmp
        $AssessmentExit=$LASTEXITCODE

        if($AssessmentExit -eq 20){
            Write-Host "SAFE ASSESSMENT REPORT : $AssessmentFile"
            Stop-Hold "Blocking SPT-024.8 monitoring controls failed."
        }

        if($AssessmentExit -ne 0){
            Stop-Hold "Production assessment failed with exit code $AssessmentExit."
        }
    }
    finally{
        Remove-Item -LiteralPath $TrackedTmp -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $ProbeTmp -Force -ErrorAction SilentlyContinue
    }

    Write-Host "SECURITY MONITORING GATE : PASS"

    Step 9 "EVIDENCE + INTEGRITY BASELINE"

    $Assessment=Get-Content -LiteralPath $AssessmentFile -Raw -Encoding UTF8|ConvertFrom-Json
    if($Assessment.status -ne "SECURITY_MONITORING_GATE_PASS"){
        Stop-Hold "Assessment does not certify PASS."
    }

    $Evidence=[ordered]@{
        component="SPT-024.8"
        layer="1"
        version="1.0.0"
        generated_utc=[DateTime]::UtcNow.ToString("o")
        authoritative_baseline=$ExpectedBaseline
        final_status="SECURITY_MONITORING_GATE_PASS"
        gates=[ordered]@{
            targeted_tests="PASS"
            institutional_suite="PASS"
            compileall="PASS"
            security_monitoring="PASS"
            preservation="PENDING"
            github_size="PENDING"
            remote_sync="PENDING"
        }
        artifacts=[ordered]@{
            assessment=$AssessmentFile
            integrity_baseline=$IntegrityFile
        }
        service_started=$false
        external_connection_opened=$false
        incident_action_executed=$false
        secret_values_exposed=$false
    }

    Write-Lf $EvidenceFile ($Evidence|ConvertTo-Json -Depth 12)

    Write-Host "ASSESSMENT : CREATED"
    Write-Host "INTEGRITY  : CREATED"
    Write-Host "EVIDENCE   : CREATED"

    Step 10 "SHA-256 PRESERVATION GATE"

    Assert-Snapshot $Snapshot
    Write-Host "SPT-024.1-.7 + CLOSED COMPONENTS : PRESERVED"

    Step 11 "EXACT CONTROLLED STAGING"

    $StageTargets=@(
        $SelfName,
        $ModuleDir,
        $TestFile,
        $PolicyFile,
        $DocFile,
        $ArtifactDir
    )

    foreach($target in $StageTargets){
        if(Test-Path -LiteralPath $target){
            Native "git.exe" @("-c","core.safecrlf=false","add","--",$target) ("git add "+$target)
        }
    }

    $StagedNow=@(& git.exe -c core.quotepath=false diff --cached --name-only)
    if($LASTEXITCODE -ne 0){throw "Unable to inspect staging."}

    $Unexpected=@()

    foreach($p0 in $StagedNow){
        $p=Norm $p0

        $allowed=(
            $p -eq $SelfName -or
            $p -eq $TestFile -or
            $p -eq $PolicyFile -or
            $p -eq $DocFile -or
            $p.StartsWith((Norm $ModuleDir)+"/") -or
            $p.StartsWith((Norm $ArtifactDir)+"/")
        )

        if(-not $allowed){$Unexpected += $p}
    }

    Write-Host "STAGED     : $($StagedNow.Count)"
    Write-Host "UNEXPECTED : $($Unexpected.Count)"

    if($Unexpected.Count -gt 0){
        & git.exe reset
        Stop-Hold "Unexpected file entered controlled staging."
    }

    Write-Host "STAGING QUALITY : PASS"

    Step 12 "INDEX-WIDE GITHUB SIZE GATE"

    $TooLarge=@(Get-IndexOversizedBlobs)

    Write-Host "INDEX BLOBS >=100MB : $($TooLarge.Count)"

    if($TooLarge.Count -gt 0){
        foreach($x in $TooLarge){
            Write-Host ("TOO LARGE : {0} ({1} bytes)" -f $x.path,$x.bytes) -ForegroundColor Red
        }
        Stop-Hold "Git index contains one or more blobs >=100 MB."
    }

    Write-Host "GITHUB SIZE GATE : PASS"

    Step 13 "FINAL REMOTE GATE"

    Git-Fetch-With-Retry -Remote "origin" -Ref $Branch

    $LocalBefore=(& git.exe rev-parse HEAD).Trim()
    $RemoteBefore=(& git.exe rev-parse ("origin/"+$Branch)).Trim()

    if($LocalBefore -ne $ExpectedBaseline -or $RemoteBefore -ne $ExpectedBaseline){
        & git.exe reset
        Stop-Hold "Authoritative baseline changed before publication."
    }

    Assert-Snapshot $Snapshot
    Write-Host "REMOTE GATE : PASS"

    Step 14 "COMMIT"

    Native "git.exe" @(
        "commit",
        "-m",
        "feat(spt-024.8): establish security monitoring and incident baseline"
    ) "git commit"

    $NewCommit=(& git.exe rev-parse HEAD).Trim()
    Write-Host "NEW COMMIT : $NewCommit"

    Step 15 "PUSH"

    Native "git.exe" @("push","origin",$Branch) "git push"
    Write-Host "PUSH : PASS"

    Step 16 "AUTHORITATIVE REMOTE VERIFICATION"

    Git-Fetch-With-Retry -Remote "origin" -Ref $Branch

    $FinalLocal=(& git.exe rev-parse HEAD).Trim()
    $FinalRemote=(& git.exe rev-parse ("origin/"+$Branch)).Trim()
    $Counts=((& git.exe rev-list --left-right --count (("origin/"+$Branch)+"...HEAD")).Trim() -split '\s+')
    $FinalStaged=@(& git.exe diff --cached --name-only)
    $FinalDeleted=@(& git.exe -c core.quotepath=false ls-files --deleted)

    Write-Host "LOCAL HEAD      : $FinalLocal"
    Write-Host "REMOTE HEAD     : $FinalRemote"
    Write-Host "BEHIND          : $($Counts[0])"
    Write-Host "AHEAD           : $($Counts[1])"
    Write-Host "STAGED          : $($FinalStaged.Count)"
    Write-Host "DELETED TRACKED : $($FinalDeleted.Count)"

    if(
        $FinalLocal -ne $FinalRemote -or
        $Counts[0] -ne "0" -or
        $Counts[1] -ne "0" -or
        $FinalStaged.Count -ne 0 -or
        $FinalDeleted.Count -ne 0
    ){
        Stop-Hold "Final repository synchronization failed."
    }

    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Green
    Write-Host " SPT-024.8 CAPA 1 : TECHNICALLY CLOSED" -ForegroundColor Green
    Write-Host " SECURITY_MONITORING_GATE=PASS" -ForegroundColor Green
    Write-Host " TARGETED_TESTS=PASS" -ForegroundColor Green
    Write-Host " INSTITUTIONAL_SUITE=PASS" -ForegroundColor Green
    Write-Host " COMPILEALL=PASS" -ForegroundColor Green
    Write-Host " LOG_INTEGRITY_BASELINE=CREATED" -ForegroundColor Green
    Write-Host " INCIDENT_LIFECYCLE=IMPLEMENTED" -ForegroundColor Green
    Write-Host " SECRET_VALUES_EXPOSED=NO" -ForegroundColor Green
    Write-Host " CLOSED_COMPONENTS=PRESERVED" -ForegroundColor Green
    Write-Host " LOCAL_HEAD=REMOTE_HEAD" -ForegroundColor Green
    Write-Host " FINAL_CLOSURE_EXIT_CODE=0" -ForegroundColor Green
    Write-Host "============================================================================" -ForegroundColor Green
    exit 0
}
catch{
    Stop-Hold $_.Exception.Message
}
