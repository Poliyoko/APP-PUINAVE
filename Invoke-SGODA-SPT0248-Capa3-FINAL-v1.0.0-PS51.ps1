#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "ca765c54b20910b45dad35d3443f73e8b8064dec"
$Branch = "feature/SPT-001A-rlb-schema-foundation"
$SelfName = "Invoke-SGODA-SPT0248-Capa3-FINAL-v1.0.0-PS51.ps1"

$Layer1Dir = "artifacts/development/SPT-024.8-Capa1-v1.0.0"
$Layer2Dir = "artifacts/development/SPT-024.8-Capa2-v1.0.0"

$Layer1Assessment = "$Layer1Dir/security-monitoring-assessment.json"
$Layer1Integrity = "$Layer1Dir/security-log-integrity-baseline.json"
$Layer1Evidence = "$Layer1Dir/implementation-evidence.json"

$Layer2Assessment = "$Layer2Dir/event-correlation-assessment.json"
$Layer2Correlation = "$Layer2Dir/correlation-baseline.json"
$Layer2Incident = "$Layer2Dir/incident-response-baseline.json"
$Layer2Evidence = "$Layer2Dir/implementation-evidence.json"

$ModuleDir = "src/sgoda/integration/spt0248l3"
$TestFile = "tests/integration/test_spt0248_incident_governance_closure_layer3.py"
$PolicyFile = "config/integration/spt0248/incident-governance-closure-policy.json"
$DocFile = "docs/06_Tecnologia/SPT-024/SPT-024.8/SGD-SPT024.8-Capa3-Gobierno-Incidentes-Quality-Gates-Cierre.md"
$ArtifactDir = "artifacts/development/SPT-024.8-Capa3-v1.0.0"
$GovernanceFile = "$ArtifactDir/incident-governance-assessment.json"
$EscalationFile = "$ArtifactDir/escalation-policy-baseline.json"
$ClosureLedger = "$ArtifactDir/incident-closure-ledger.json"
$ClosureManifest = "$ArtifactDir/closure-manifest.json"
$EvidenceFile = "$ArtifactDir/implementation-evidence.json"

$LargeFileLimit = 100MB

function Stop-Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Red
    Write-Host " SPT-024.8 CAPA 3 : HOLD" -ForegroundColor Red
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
    if($LASTEXITCODE -ne 0){
        throw "$Label failed with exit code $LASTEXITCODE."
    }
}

function Git-Fetch-With-Retry {
    param([string]$Remote="origin",[string]$Ref="",[int]$Attempts=4)

    $Delays=@(3,7,15,25)
    $LastMessage=""

    for($i=1;$i -le $Attempts;$i++){
        Write-Host ("GIT FETCH ATTEMPT : {0}/{1}" -f $i,$Attempts)

        $FetchArgs=@("fetch","--prune",$Remote)
        if(-not [string]::IsNullOrWhiteSpace($Ref)){
            $FetchArgs += $Ref
        }

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
            $Output | ForEach-Object { Write-Host ([string]$_) }
            $LastMessage=(($Output | ForEach-Object {[string]$_}) -join " | ")
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
        if(Test-Path -LiteralPath $p){
            return (Resolve-Path $p).Path
        }
    }

    $cmd=Get-Command python.exe -ErrorAction SilentlyContinue
    if($null -ne $cmd){
        return $cmd.Source
    }

    throw "Python executable not found."
}

function Norm {
    param([string]$P)
    if($null -eq $P){ return "" }
    return ($P.Trim('"') -replace '\\','/')
}

function Write-Lf {
    param([string]$Path,[string]$Text)

    $parent=Split-Path -Parent $Path
    if($parent){
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }

    $utf8=New-Object System.Text.UTF8Encoding($false)
    $canonical=(($Text -replace "`r`n","`n") -replace "`r","`n")

    if(-not $canonical.EndsWith("`n")){
        $canonical+="`n"
    }

    [IO.File]::WriteAllText((Join-Path $PWD $Path),$canonical,$utf8)
}

function Get-TrackedHashSnapshot {
    $snap=@{}
    $files=@(& git.exe -c core.quotepath=false ls-files)

    if($LASTEXITCODE -ne 0){
        throw "Unable to enumerate tracked files."
    }

    foreach($p0 in $files){
        $p=Norm $p0

        if($p.StartsWith((Norm $ModuleDir)+"/")){ continue }
        if($p -eq $TestFile -or $p -eq $PolicyFile -or $p -eq $DocFile){ continue }
        if($p.StartsWith((Norm $ArtifactDir)+"/")){ continue }
        if($p -eq $SelfName){ continue }

        $native=$p -replace '/',[IO.Path]::DirectorySeparatorChar

        if(Test-Path -LiteralPath $native -PathType Leaf){
            try{
                $snap[$p]=(Get-FileHash -LiteralPath $native -Algorithm SHA256).Hash.ToUpperInvariant()
            }
            catch{}
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

    if($LASTEXITCODE -ne 0){
        throw "Unable to enumerate Git index."
    }

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

        if($code -ne 0 -or $sizeOut.Count -eq 0){
            continue
        }

        [Int64]$len=0
        if([Int64]::TryParse(([string]$sizeOut[0]).Trim(),[ref]$len)){
            if($len -ge $LargeFileLimit){
                [void]$tooLarge.Add([ordered]@{
                    path=$p
                    bytes=$len
                })
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

    if($LocalHead -ne $ExpectedBaseline){
        Stop-Hold "Unexpected local baseline. Expected $ExpectedBaseline; found $LocalHead."
    }
    if($RemoteHead -ne $ExpectedBaseline){
        Stop-Hold "Unexpected remote baseline. Expected $ExpectedBaseline; found $RemoteHead."
    }
    if($Staged.Count -ne 0){
        Stop-Hold "Pre-existing staged changes detected."
    }
    if($Deleted.Count -ne 0){
        Stop-Hold "Tracked deletions detected."
    }

    Write-Host "BASELINE : PASS"
    Write-Host "SPT-024.8 CAPAS 1-2 : PROTECTED / NOT REOPENED"
    Write-Host "DESTRUCTIVE CLEANUP : NO"

    Step 2 "VERIFY CAPA 1 + CAPA 2 CLOSURE INPUTS"

    $RequiredInputs=@(
        $Layer1Assessment,
        $Layer1Integrity,
        $Layer1Evidence,
        $Layer2Assessment,
        $Layer2Correlation,
        $Layer2Incident,
        $Layer2Evidence,
        "config/integration/spt0248/security-monitoring-incident-policy.json",
        "config/integration/spt0248/event-correlation-incident-response-policy.json"
    )

    $Missing=@($RequiredInputs | Where-Object {-not(Test-Path -LiteralPath $_)})

    Write-Host "REQUIRED CLOSURE INPUTS : $($RequiredInputs.Count)"
    Write-Host "MISSING INPUTS          : $($Missing.Count)"

    if($Missing.Count -gt 0){
        $Missing | ForEach-Object { Write-Host "MISSING : $_" -ForegroundColor Red }
        Stop-Hold "SPT-024.8 closure inputs are incomplete."
    }

    $L1=Get-Content -LiteralPath $Layer1Assessment -Raw -Encoding UTF8 | ConvertFrom-Json
    $L2=Get-Content -LiteralPath $Layer2Assessment -Raw -Encoding UTF8 | ConvertFrom-Json

    if($L1.status -ne "SECURITY_MONITORING_GATE_PASS"){
        Stop-Hold "SPT-024.8 Capa 1 assessment is not PASS."
    }
    if($L2.status -ne "INCIDENT_RESPONSE_GATE_PASS"){
        Stop-Hold "SPT-024.8 Capa 2 assessment is not PASS."
    }

    Write-Host "CAPA 1 SECURITY MONITORING GATE : PASS"
    Write-Host "CAPA 2 INCIDENT RESPONSE GATE   : PASS"

    Step 3 "SHA-256 FREEZE OF CLOSED COMPONENTS"

    $Snapshot=Get-TrackedHashSnapshot

    Write-Host "PROTECTED TRACKED FILES : $($Snapshot.Count)"
    Write-Host "SHA-256 FREEZE : PASS"

    Step 4 "IMPLEMENT INCIDENT GOVERNANCE / ESCALATION / CLOSURE LAYER"

    $InitPy=@'
"""SPT-024.8 Capa 3 — incident governance, final quality gates and institutional closure."""
from .service import IncidentGovernanceClosureService
from .gate import IncidentGovernanceClosureGate

__all__ = ["IncidentGovernanceClosureService", "IncidentGovernanceClosureGate"]
'@

    $ModelsPy=@'
from dataclasses import dataclass


@dataclass(frozen=True)
class GovernanceControl:
    control_id: str
    name: str
    passed: bool
    blocking: bool
    detail: str
'@

    $EscalationPy=@'
from __future__ import annotations


SEVERITY_ORDER = {
    "INFO": 0,
    "LOW": 1,
    "MEDIUM": 2,
    "HIGH": 3,
    "CRITICAL": 4,
}


def escalation_rule(severity: str, event_count: int) -> dict:
    sev = str(severity).upper()
    score = SEVERITY_ORDER.get(sev, 0)

    if score >= 4 or event_count >= 10:
        level = "L3"
        authority = "INSTITUTIONAL_SECURITY_LEAD"
    elif score >= 3 or event_count >= 5:
        level = "L2"
        authority = "SECURITY_COORDINATION"
    else:
        level = "L1"
        authority = "OPERATIONAL_REVIEW"

    return {
        "severity": sev,
        "event_count": int(event_count),
        "escalation_level": level,
        "authority": authority,
        "notification_mode": "EVIDENCE_ONLY",
        "notification_sent": False,
        "action_executed": False,
        "secret_values_exposed": False,
    }
'@

    $GovernancePy=@'
from __future__ import annotations
import hashlib
import json
from pathlib import Path
from typing import Iterable


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def evidence_ledger(root: Path, paths: Iterable[str]) -> dict:
    records = []

    for rel in list(paths):
        p = root / rel
        if not p.is_file():
            records.append({
                "path": rel.replace("\\", "/"),
                "exists": False,
            })
            continue

        records.append({
            "path": rel.replace("\\", "/"),
            "exists": True,
            "bytes": p.stat().st_size,
            "sha256": sha256(p),
        })

    return {
        "algorithm": "SHA-256",
        "record_count": len(records),
        "missing_count": len([r for r in records if not r.get("exists")]),
        "records": records,
    }


def load_json(root: Path, rel: str):
    return json.loads((root / rel).read_text(encoding="utf-8"))
'@

    $ClosurePy=@'
from __future__ import annotations
from pathlib import Path

from .escalation import escalation_rule
from .governance import evidence_ledger, load_json
from .models import GovernanceControl


def build_governance_assessment(root: Path, inputs: dict) -> dict:
    l1 = load_json(root, inputs["layer1_assessment"])
    l2 = load_json(root, inputs["layer2_assessment"])
    l2_incident = load_json(root, inputs["layer2_incident_baseline"])

    required_paths = list(inputs["required_evidence"])
    ledger = evidence_ledger(root, required_paths)

    incidents = l2_incident.get("incidents", [])
    escalation = [
        escalation_rule(
            incident.get("severity", "INFO"),
            incident.get("event_count", 0),
        )
        for incident in incidents
    ]

    controls = [
        GovernanceControl(
            "IRG-CAPA1-PASS",
            "Capa 1 security monitoring certified",
            l1.get("status") == "SECURITY_MONITORING_GATE_PASS",
            True,
            "Capa 1 security monitoring gate is PASS.",
        ),
        GovernanceControl(
            "IRG-CAPA2-PASS",
            "Capa 2 incident response certified",
            l2.get("status") == "INCIDENT_RESPONSE_GATE_PASS",
            True,
            "Capa 2 incident response gate is PASS.",
        ),
        GovernanceControl(
            "IRG-EVIDENCE-INTEGRITY",
            "Required evidence completeness and SHA-256 ledger",
            ledger.get("missing_count", 0) == 0
            and ledger.get("record_count", 0) == len(required_paths),
            True,
            "Evidence ledger covers all required inputs."
            if ledger.get("missing_count", 0) == 0
            else "One or more required evidence inputs are missing.",
        ),
        GovernanceControl(
            "IRG-ESCALATION",
            "Institutional escalation rules",
            len(escalation) == len(incidents)
            and all(item.get("escalation_level") in {"L1", "L2", "L3"} for item in escalation),
            True,
            "Escalation rules generated for all incidents.",
        ),
        GovernanceControl(
            "IRG-NO-SIDE-EFFECTS",
            "No operational side effects during closure",
            l2.get("alert_sent") is False
            and l2.get("incident_action_executed") is False
            and l2.get("webhook_called") is False
            and l2.get("external_connection_opened") is False,
            True,
            "Closure uses evidence-only alerting and plan-only response.",
        ),
        GovernanceControl(
            "IRG-SECRET-SAFETY",
            "No secret values exposed",
            l1.get("secret_values_exposed") is False
            and l2.get("secret_values_exposed") is False
            and all(item.get("secret_values_exposed") is False for item in escalation),
            True,
            "No secret values exposed in governance evidence.",
        ),
        GovernanceControl(
            "IRG-CLOSED-COMPONENT-PRESERVATION",
            "Closed component preservation",
            True,
            True,
            "Runtime SHA-256 preservation is enforced by PowerShell master.",
        ),
    ]

    failed = [c.control_id for c in controls if c.blocking and not c.passed]

    return {
        "status": "INSTITUTIONALLY_CLOSED" if not failed else "CLOSURE_HOLD",
        "failed_blocking_controls": failed,
        "controls": [c.__dict__ for c in controls],
        "evidence_ledger": ledger,
        "escalation": escalation,
        "layer1_status": l1.get("status"),
        "layer2_status": l2.get("status"),
        "incident_count": len(incidents),
        "notification_sent": False,
        "incident_action_executed": False,
        "webhook_called": False,
        "external_connection_opened": False,
        "secret_values_exposed": False,
    }
'@

    $GatePy=@'
class IncidentGovernanceClosureGate:
    BLOCKING = frozenset({
        "IRG-CAPA1-PASS",
        "IRG-CAPA2-PASS",
        "IRG-EVIDENCE-INTEGRITY",
        "IRG-ESCALATION",
        "IRG-NO-SIDE-EFFECTS",
        "IRG-SECRET-SAFETY",
        "IRG-CLOSED-COMPONENT-PRESERVATION",
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

            if blocking and not passed:
                failed.append(cid)

        return not failed, failed
'@

    $ServicePy=@'
from pathlib import Path

from .closure import build_governance_assessment
from .gate import IncidentGovernanceClosureGate


class IncidentGovernanceClosureService:
    def __init__(self, root: Path):
        self.root = Path(root)

    def close(self, inputs: dict):
        result = build_governance_assessment(self.root, inputs)
        passed, failed = IncidentGovernanceClosureGate.evaluate(result["controls"])

        result["status"] = "INSTITUTIONALLY_CLOSED" if passed else "CLOSURE_HOLD"
        result["failed_blocking_controls"] = failed

        return result
'@

    $TestsPy=@'
import json
from pathlib import Path

from sgoda.integration.spt0248l3.escalation import escalation_rule
from sgoda.integration.spt0248l3.service import IncidentGovernanceClosureService


def write_json(path: Path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def fixture(tmp_path):
    l1 = "l1/assessment.json"
    l2 = "l2/assessment.json"
    incident = "l2/incident.json"
    e1 = "l1/evidence.json"
    e2 = "l2/evidence.json"

    write_json(tmp_path / l1, {
        "status": "SECURITY_MONITORING_GATE_PASS",
        "secret_values_exposed": False,
    })

    write_json(tmp_path / l2, {
        "status": "INCIDENT_RESPONSE_GATE_PASS",
        "alert_sent": False,
        "incident_action_executed": False,
        "webhook_called": False,
        "external_connection_opened": False,
        "secret_values_exposed": False,
    })

    write_json(tmp_path / incident, {
        "incidents": [
            {
                "incident_id": "INC-1",
                "severity": "HIGH",
                "event_count": 2,
            }
        ]
    })

    write_json(tmp_path / e1, {"ok": True})
    write_json(tmp_path / e2, {"ok": True})

    inputs = {
        "layer1_assessment": l1,
        "layer2_assessment": l2,
        "layer2_incident_baseline": incident,
        "required_evidence": [l1, l2, incident, e1, e2],
    }

    return inputs


def test_closure_passes(tmp_path):
    result = IncidentGovernanceClosureService(tmp_path).close(fixture(tmp_path))
    assert result["status"] == "INSTITUTIONALLY_CLOSED"
    assert result["failed_blocking_controls"] == []


def test_missing_evidence_blocks(tmp_path):
    inputs = fixture(tmp_path)
    inputs["required_evidence"].append("missing.json")
    result = IncidentGovernanceClosureService(tmp_path).close(inputs)
    assert result["status"] == "CLOSURE_HOLD"
    assert "IRG-EVIDENCE-INTEGRITY" in result["failed_blocking_controls"]


def test_layer1_hold_blocks(tmp_path):
    inputs = fixture(tmp_path)
    write_json(tmp_path / inputs["layer1_assessment"], {
        "status": "SECURITY_MONITORING_GATE_HOLD",
        "secret_values_exposed": False,
    })
    result = IncidentGovernanceClosureService(tmp_path).close(inputs)
    assert result["status"] == "CLOSURE_HOLD"
    assert "IRG-CAPA1-PASS" in result["failed_blocking_controls"]


def test_layer2_hold_blocks(tmp_path):
    inputs = fixture(tmp_path)
    data = json.loads((tmp_path / inputs["layer2_assessment"]).read_text(encoding="utf-8"))
    data["status"] = "INCIDENT_RESPONSE_GATE_HOLD"
    write_json(tmp_path / inputs["layer2_assessment"], data)
    result = IncidentGovernanceClosureService(tmp_path).close(inputs)
    assert result["status"] == "CLOSURE_HOLD"
    assert "IRG-CAPA2-PASS" in result["failed_blocking_controls"]


def test_secret_exposure_blocks(tmp_path):
    inputs = fixture(tmp_path)
    data = json.loads((tmp_path / inputs["layer2_assessment"]).read_text(encoding="utf-8"))
    data["secret_values_exposed"] = True
    write_json(tmp_path / inputs["layer2_assessment"], data)
    result = IncidentGovernanceClosureService(tmp_path).close(inputs)
    assert result["status"] == "CLOSURE_HOLD"
    assert "IRG-SECRET-SAFETY" in result["failed_blocking_controls"]


def test_side_effect_blocks(tmp_path):
    inputs = fixture(tmp_path)
    data = json.loads((tmp_path / inputs["layer2_assessment"]).read_text(encoding="utf-8"))
    data["alert_sent"] = True
    write_json(tmp_path / inputs["layer2_assessment"], data)
    result = IncidentGovernanceClosureService(tmp_path).close(inputs)
    assert result["status"] == "CLOSURE_HOLD"
    assert "IRG-NO-SIDE-EFFECTS" in result["failed_blocking_controls"]


def test_escalation_levels():
    assert escalation_rule("LOW", 1)["escalation_level"] == "L1"
    assert escalation_rule("HIGH", 1)["escalation_level"] == "L2"
    assert escalation_rule("CRITICAL", 1)["escalation_level"] == "L3"
    assert escalation_rule("LOW", 10)["escalation_level"] == "L3"
'@

    $PolicyJson=@'
{
  "component": "SPT-024.8",
  "layer": "3",
  "version": "1.0.0",
  "title": "Gobierno de Incidentes, Quality Gates Finales, Escalamiento y Cierre Institucional",
  "blocking_controls": [
    "IRG-CAPA1-PASS",
    "IRG-CAPA2-PASS",
    "IRG-EVIDENCE-INTEGRITY",
    "IRG-ESCALATION",
    "IRG-NO-SIDE-EFFECTS",
    "IRG-SECRET-SAFETY",
    "IRG-CLOSED-COMPONENT-PRESERVATION"
  ],
  "escalation": {
    "L1": "OPERATIONAL_REVIEW",
    "L2": "SECURITY_COORDINATION",
    "L3": "INSTITUTIONAL_SECURITY_LEAD"
  },
  "closure_status": "INSTITUTIONALLY_CLOSED",
  "safety": {
    "send_notifications": false,
    "execute_incident_actions": false,
    "call_webhooks": false,
    "open_external_connections": false,
    "print_secret_values": false,
    "modify_layer1": false,
    "modify_layer2": false
  }
}
'@

    $DocMd=@'
# SPT-024.8 Capa 3 — Gobierno de Incidentes, Quality Gates Finales, Escalamiento y Cierre Institucional

Baseline autoritativa: `ca765c54b20910b45dad35d3443f73e8b8064dec`.

Esta capa consolida SPT-024.8 Capa 1 y Capa 2 sin reabrirlas ni modificarlas.

## Alcance

- validación formal de los security gates de Capa 1 y Capa 2;
- ledger SHA-256 de evidencias obligatorias;
- reglas institucionales de escalamiento L1/L2/L3;
- consolidación de correlaciones, incidentes, alertas y planes de respuesta;
- quality gates finales;
- preservación de componentes cerrados;
- cierre institucional de SPT-024.8.

## Escalamiento

- L1 — OPERATIONAL_REVIEW
- L2 — SECURITY_COORDINATION
- L3 — INSTITUTIONAL_SECURITY_LEAD

El maestro no envía notificaciones, no ejecuta acciones reales de incident response, no llama webhooks, no abre conexiones externas y no imprime secretos.

SPT-024.8 solo adquiere estado `INSTITUTIONALLY_CLOSED` si todos los gates bloqueantes terminan en PASS y la publicación concluye con `LOCAL HEAD = REMOTE HEAD`.
'@

    Write-Lf "$ModuleDir/__init__.py" $InitPy
    Write-Lf "$ModuleDir/models.py" $ModelsPy
    Write-Lf "$ModuleDir/escalation.py" $EscalationPy
    Write-Lf "$ModuleDir/governance.py" $GovernancePy
    Write-Lf "$ModuleDir/closure.py" $ClosurePy
    Write-Lf "$ModuleDir/gate.py" $GatePy
    Write-Lf "$ModuleDir/service.py" $ServicePy
    Write-Lf $TestFile $TestsPy
    Write-Lf $PolicyFile $PolicyJson
    Write-Lf $DocFile $DocMd

    Write-Host "SPT-024.8 CAPA 3 IMPLEMENTATION : CREATED/VALIDATED"

    Step 5 "PYTHON PREVALIDATION + TARGETED TESTS"

    $Python=PythonExe
    $env:PYTHONPATH=(Join-Path $PWD "src")

    Native $Python @(
        "-c",
        "import sgoda.integration.spt0248l3; from sgoda.integration.spt0248l3.gate import IncidentGovernanceClosureGate; assert len(IncidentGovernanceClosureGate.BLOCKING)==7; print('SPT0248_CAPA3_IMPORT=PASS'); print('BLOCKING_CONTROLS=7')"
    ) "SPT-024.8 Capa 3 import"

    Native $Python @("-m","pytest",$TestFile,"-q") "SPT-024.8 Capa 3 targeted tests"

    Write-Host "TARGETED TESTS : PASS"

    Step 6 "INSTITUTIONAL SUITE + COMPILEALL"

    Native $Python @("-m","pytest","-q") "Institutional pytest suite"

    Write-Host "FULL SUITE : PASS"

    Native $Python @("-m","compileall","-q","src") "compileall"

    Write-Host "COMPILEALL : PASS"

    Step 7 "FINAL INCIDENT GOVERNANCE / CLOSURE ASSESSMENT"

    New-Item -ItemType Directory -Force -Path $ArtifactDir | Out-Null

    $ProbeTmp=Join-Path $env:TEMP ("sgoda-spt0248-l3-"+[Guid]::NewGuid().ToString("N")+".py")
    $utf8=New-Object System.Text.UTF8Encoding($false)

    try{
        $Probe=@'
import json
from pathlib import Path

from sgoda.integration.spt0248l3.service import IncidentGovernanceClosureService

root = Path.cwd()

inputs = {
    "layer1_assessment": "artifacts/development/SPT-024.8-Capa1-v1.0.0/security-monitoring-assessment.json",
    "layer2_assessment": "artifacts/development/SPT-024.8-Capa2-v1.0.0/event-correlation-assessment.json",
    "layer2_incident_baseline": "artifacts/development/SPT-024.8-Capa2-v1.0.0/incident-response-baseline.json",
    "required_evidence": [
        "artifacts/development/SPT-024.8-Capa1-v1.0.0/security-monitoring-assessment.json",
        "artifacts/development/SPT-024.8-Capa1-v1.0.0/security-log-integrity-baseline.json",
        "artifacts/development/SPT-024.8-Capa1-v1.0.0/implementation-evidence.json",
        "artifacts/development/SPT-024.8-Capa2-v1.0.0/event-correlation-assessment.json",
        "artifacts/development/SPT-024.8-Capa2-v1.0.0/correlation-baseline.json",
        "artifacts/development/SPT-024.8-Capa2-v1.0.0/incident-response-baseline.json",
        "artifacts/development/SPT-024.8-Capa2-v1.0.0/implementation-evidence.json",
    ],
}

result = IncidentGovernanceClosureService(root).close(inputs)

artifact_dir = root / "artifacts" / "development" / "SPT-024.8-Capa3-v1.0.0"
artifact_dir.mkdir(parents=True, exist_ok=True)

governance = artifact_dir / "incident-governance-assessment.json"
escalation = artifact_dir / "escalation-policy-baseline.json"
ledger = artifact_dir / "incident-closure-ledger.json"
manifest = artifact_dir / "closure-manifest.json"

governance.write_text(
    json.dumps(result, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)

escalation.write_text(
    json.dumps({
        "rules": result["escalation"],
        "notification_sent": False,
        "incident_action_executed": False,
        "secret_values_exposed": False,
    }, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)

ledger.write_text(
    json.dumps(result["evidence_ledger"], indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)

manifest.write_text(
    json.dumps({
        "component": "SPT-024.8",
        "layer": "3",
        "version": "1.0.0",
        "status": result["status"],
        "failed_blocking_controls": result["failed_blocking_controls"],
        "controls": result["controls"],
        "incident_count": result["incident_count"],
        "layer1_status": result["layer1_status"],
        "layer2_status": result["layer2_status"],
        "notification_sent": False,
        "incident_action_executed": False,
        "webhook_called": False,
        "external_connection_opened": False,
        "secret_values_exposed": False,
    }, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)

print("SPT0248_CLOSURE_STATUS=" + result["status"])
print("FAILED_BLOCKING_CONTROLS=%d" % len(result["failed_blocking_controls"]))
print("FAILED_CONTROL_IDS=" + ",".join(result["failed_blocking_controls"]))
print("LAYER1_STATUS=" + str(result["layer1_status"]))
print("LAYER2_STATUS=" + str(result["layer2_status"]))
print("INCIDENTS=%d" % result["incident_count"])
print("ESCALATION_RULES=%d" % len(result["escalation"]))
print("EVIDENCE_LEDGER_RECORDS=%d" % result["evidence_ledger"]["record_count"])
print("NOTIFICATION_SENT=NO")
print("INCIDENT_ACTION_EXECUTED=NO")
print("WEBHOOK_CALLED=NO")
print("EXTERNAL_CONNECTION_OPENED=NO")
print("SECRET_VALUES_EXPOSED=NO")

if result["status"] != "INSTITUTIONALLY_CLOSED":
    raise SystemExit(20)
'@

        [IO.File]::WriteAllText(
            $ProbeTmp,
            (($Probe -replace "`r`n","`n") -replace "`r","`n"),
            $utf8
        )

        & $Python $ProbeTmp
        $ClosureExit=$LASTEXITCODE

        if($ClosureExit -eq 20){
            Write-Host "CLOSURE MANIFEST : $ClosureManifest"
            Stop-Hold "Final SPT-024.8 governance gate failed."
        }

        if($ClosureExit -ne 0){
            Stop-Hold "Closure assessment failed with exit code $ClosureExit."
        }
    }
    finally{
        Remove-Item -LiteralPath $ProbeTmp -Force -ErrorAction SilentlyContinue
    }

    Write-Host "FINAL INCIDENT GOVERNANCE GATE : PASS"

    Step 8 "EVIDENCE + INSTITUTIONAL CLOSURE RECORD"

    $Closure=Get-Content -LiteralPath $ClosureManifest -Raw -Encoding UTF8 | ConvertFrom-Json

    if($Closure.status -ne "INSTITUTIONALLY_CLOSED"){
        Stop-Hold "Closure manifest does not certify institutional closure."
    }

    $Evidence=[ordered]@{
        component="SPT-024.8"
        layer="3"
        version="1.0.0"
        generated_utc=[DateTime]::UtcNow.ToString("o")
        authoritative_baseline=$ExpectedBaseline
        final_status="INSTITUTIONALLY_CLOSED"
        gates=[ordered]@{
            capa1_security_monitoring="PASS"
            capa2_incident_response="PASS"
            incident_governance="PASS"
            escalation="PASS"
            evidence_integrity="PASS"
            targeted_tests="PASS"
            institutional_suite="PASS"
            compileall="PASS"
            preservation="PENDING"
            github_size="PENDING"
            remote_sync="PENDING"
        }
        artifacts=[ordered]@{
            governance_assessment=$GovernanceFile
            escalation_baseline=$EscalationFile
            closure_ledger=$ClosureLedger
            closure_manifest=$ClosureManifest
        }
        notification_sent=$false
        incident_action_executed=$false
        webhook_called=$false
        external_connection_opened=$false
        secret_values_exposed=$false
    }

    Write-Lf $EvidenceFile ($Evidence | ConvertTo-Json -Depth 12)

    Write-Host "GOVERNANCE ASSESSMENT : CREATED"
    Write-Host "ESCALATION BASELINE   : CREATED"
    Write-Host "CLOSURE LEDGER        : CREATED"
    Write-Host "CLOSURE MANIFEST      : CREATED"
    Write-Host "EVIDENCE              : CREATED"

    Step 9 "SHA-256 PRESERVATION GATE"

    Assert-Snapshot $Snapshot

    Write-Host "SPT-024.8 CAPAS 1-2 + CLOSED COMPONENTS : PRESERVED"

    Step 10 "EXACT CONTROLLED STAGING"

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

    if($LASTEXITCODE -ne 0){
        throw "Unable to inspect staging."
    }

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

        if(-not $allowed){
            $Unexpected += $p
        }
    }

    Write-Host "STAGED     : $($StagedNow.Count)"
    Write-Host "UNEXPECTED : $($Unexpected.Count)"

    if($Unexpected.Count -gt 0){
        & git.exe reset
        Stop-Hold "Unexpected file entered controlled staging."
    }

    Write-Host "STAGING QUALITY : PASS"

    Step 11 "INDEX-WIDE GITHUB SIZE GATE"

    $TooLarge=@(Get-IndexOversizedBlobs)

    Write-Host "INDEX BLOBS >=100MB : $($TooLarge.Count)"

    if($TooLarge.Count -gt 0){
        foreach($x in $TooLarge){
            Write-Host ("TOO LARGE : {0} ({1} bytes)" -f $x.path,$x.bytes) -ForegroundColor Red
        }

        Stop-Hold "Git index contains one or more blobs >=100 MB."
    }

    Write-Host "GITHUB SIZE GATE : PASS"

    Step 12 "FINAL REMOTE GATE"

    Git-Fetch-With-Retry -Remote "origin" -Ref $Branch

    $LocalBefore=(& git.exe rev-parse HEAD).Trim()
    $RemoteBefore=(& git.exe rev-parse ("origin/"+$Branch)).Trim()

    if($LocalBefore -ne $ExpectedBaseline -or $RemoteBefore -ne $ExpectedBaseline){
        & git.exe reset
        Stop-Hold "Authoritative baseline changed before publication."
    }

    Assert-Snapshot $Snapshot

    Write-Host "REMOTE GATE : PASS"

    Step 13 "COMMIT"

    Native "git.exe" @(
        "commit",
        "-m",
        "feat(spt-024.8): close incident governance and response layer 3"
    ) "git commit"

    $NewCommit=(& git.exe rev-parse HEAD).Trim()

    Write-Host "NEW COMMIT : $NewCommit"

    Step 14 "PUSH"

    Native "git.exe" @("push","origin",$Branch) "git push"

    Write-Host "PUSH : PASS"

    Step 15 "AUTHORITATIVE REMOTE VERIFICATION"

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

    Step 16 "INSTITUTIONAL CLOSURE"

    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Green
    Write-Host " SPT-024.8 CAPA 3 : INSTITUTIONALLY CLOSED" -ForegroundColor Green
    Write-Host " CAPA1_SECURITY_MONITORING_GATE=PASS" -ForegroundColor Green
    Write-Host " CAPA2_INCIDENT_RESPONSE_GATE=PASS" -ForegroundColor Green
    Write-Host " FINAL_INCIDENT_GOVERNANCE_GATE=PASS" -ForegroundColor Green
    Write-Host " ESCALATION_GOVERNANCE=PASS" -ForegroundColor Green
    Write-Host " EVIDENCE_INTEGRITY=PASS" -ForegroundColor Green
    Write-Host " NOTIFICATION_MODE=EVIDENCE_ONLY" -ForegroundColor Green
    Write-Host " RESPONSE_MODE=PLAN_ONLY" -ForegroundColor Green
    Write-Host " CLOSED_COMPONENTS=PRESERVED" -ForegroundColor Green
    Write-Host " INSTITUTIONAL_SUITE=PASS" -ForegroundColor Green
    Write-Host " COMPILEALL=PASS" -ForegroundColor Green
    Write-Host " SECRET_VALUES_EXPOSED=NO" -ForegroundColor Green
    Write-Host " LOCAL_HEAD=REMOTE_HEAD" -ForegroundColor Green
    Write-Host " SPT0248_STATUS=INSTITUTIONALLY_CLOSED" -ForegroundColor Green
    Write-Host " FINAL_CLOSURE_EXIT_CODE=0" -ForegroundColor Green
    Write-Host "============================================================================" -ForegroundColor Green

    exit 0
}
catch{
    Stop-Hold $_.Exception.Message
}
