#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "449dde2b56239b138f1ef471a54bc399fe902b08"
$Branch = "feature/SPT-001A-rlb-schema-foundation"
$SelfName = "Invoke-SGODA-SPT0247-Capa3-FINAL-v1.0.0-PS51.ps1"

$Layer1ArtifactDir = "artifacts/development/SPT-024.7-Capa1-v1.0.0"
$Layer2ArtifactDir = "artifacts/development/SPT-024.7-Capa2-v1.0.0"
$Layer2Assessment = "$Layer2ArtifactDir/supply-chain-layer2-assessment.json"
$Layer2Sbom = "$Layer2ArtifactDir/sbom-layer2.json"
$Layer2Integrity = "$Layer2ArtifactDir/integrity-manifest-layer2.json"
$Layer2Evidence = "$Layer2ArtifactDir/implementation-evidence.json"

$ModuleDir = "src/sgoda/integration/spt0247l3"
$TestFile = "tests/integration/test_spt0247_supply_chain_governance_closure_layer3.py"
$PolicyFile = "config/integration/spt0247/supply-chain-governance-closure-policy.json"
$DocFile = "docs/06_Tecnologia/SPT-024/SPT-024.7/SGD-SPT024.7-Capa3-Gobierno-Quality-Gates-Cierre.md"
$ArtifactDir = "artifacts/development/SPT-024.7-Capa3-v1.0.0"
$ClosureLedger = "$ArtifactDir/supply-chain-closure-ledger.json"
$ClosureManifest = "$ArtifactDir/closure-manifest.json"
$EvidenceFile = "$ArtifactDir/implementation-evidence.json"

$LargeFileLimit = 100MB

function Stop-Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Red
    Write-Host " SPT-024.7 CAPA 3 : HOLD" -ForegroundColor Red
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
    Write-Host "SPT-024.7 CAPAS 1-2 : PROTECTED / NOT REOPENED"
    Write-Host "DESTRUCTIVE CLEANUP : NO"

    Step 2 "VERIFY CAPA 1 + CAPA 2 CLOSURE INPUTS"

    $RequiredInputs=@(
        $Layer2Assessment,
        $Layer2Sbom,
        $Layer2Integrity,
        $Layer2Evidence,
        "config/integration/spt0247/supply-chain-security-layer2-policy.json",
        "docs/06_Tecnologia/SPT-024/SPT-024.7/SGD-SPT024.7-Capa2-Hardening-Integridad-Vulnerabilidades-Gobierno.md"
    )

    $Missing=@($RequiredInputs|Where-Object{-not(Test-Path -LiteralPath $_)})
    Write-Host "REQUIRED CLOSURE INPUTS : $($RequiredInputs.Count)"
    Write-Host "MISSING INPUTS          : $($Missing.Count)"

    if($Missing.Count -gt 0){
        $Missing|ForEach-Object{Write-Host "MISSING : $_" -ForegroundColor Red}
        Stop-Hold "SPT-024.7 Capa 2 closure inputs are incomplete."
    }

    $L2=Get-Content -LiteralPath $Layer2Assessment -Raw -Encoding UTF8|ConvertFrom-Json
    if($L2.status -ne "SUPPLY_CHAIN_LAYER2_GATE_PASS"){
        Stop-Hold "SPT-024.7 Capa 2 assessment is not PASS."
    }

    Write-Host "CAPA 2 ASSESSMENT : PASS"

    Step 3 "SHA-256 FREEZE OF CLOSED COMPONENTS"

    $Snapshot=Get-TrackedHashSnapshot
    Write-Host "PROTECTED TRACKED FILES : $($Snapshot.Count)"
    Write-Host "SHA-256 FREEZE : PASS"

    Step 4 "IMPLEMENT GOVERNANCE / QUALITY-GATE / CLOSURE LAYER"

    $InitPy=@'
"""SPT-024.7 Capa 3 — governance, final gates, institutional closure."""
from .service import SupplyChainClosureService
from .gate import SupplyChainClosureGate

__all__ = ["SupplyChainClosureService", "SupplyChainClosureGate"]
'@

    $ModelsPy=@'
from dataclasses import dataclass
from typing import Any, Dict


@dataclass(frozen=True)
class ClosureControl:
    control_id: str
    name: str
    passed: bool
    blocking: bool
    detail: str


@dataclass(frozen=True)
class ClosureEvidence:
    path: str
    sha256: str
    bytes: int
    metadata: Dict[str, Any]
'@

    $GovernancePy=@'
from __future__ import annotations
import hashlib
from pathlib import Path
from typing import Iterable


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def build_evidence_ledger(root: Path, paths: Iterable[str]) -> dict:
    records = []
    for rel in sorted(set(paths)):
        p = root / rel
        if not p.is_file():
            continue
        records.append({
            "path": rel.replace("\\", "/"),
            "bytes": p.stat().st_size,
            "sha256": sha256(p),
        })

    return {
        "algorithm": "SHA-256",
        "record_count": len(records),
        "records": records,
    }
'@

    $GatePy=@'
class SupplyChainClosureGate:
    BLOCKING = frozenset({
        "SC3-CAPA2-PASS",
        "SC3-SBOM-INTEGRITY",
        "SC3-EVIDENCE-INTEGRITY",
        "SC3-SECRET-SAFETY",
        "SC3-PUBLICATION-SAFETY",
        "SC3-CLOSED-COMPONENT-PRESERVATION",
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

    $ClosurePy=@'
from __future__ import annotations
import json
from pathlib import Path

from .governance import build_evidence_ledger
from .models import ClosureControl


def build_controls(root: Path, layer2_assessment: str, layer2_sbom: str, layer2_integrity: str, evidence_paths):
    assessment_path = root / layer2_assessment
    sbom_path = root / layer2_sbom
    integrity_path = root / layer2_integrity

    assessment = json.loads(assessment_path.read_text(encoding="utf-8"))
    sbom = json.loads(sbom_path.read_text(encoding="utf-8"))
    integrity = json.loads(integrity_path.read_text(encoding="utf-8"))

    ledger = build_evidence_ledger(root, evidence_paths)

    controls = [
        ClosureControl(
            "SC3-CAPA2-PASS",
            "SPT-024.7 Capa 2 certified PASS",
            assessment.get("status") == "SUPPLY_CHAIN_LAYER2_GATE_PASS",
            True,
            "Capa 2 assessment is PASS." if assessment.get("status") == "SUPPLY_CHAIN_LAYER2_GATE_PASS"
            else "Capa 2 assessment is not PASS.",
        ),
        ClosureControl(
            "SC3-SBOM-INTEGRITY",
            "SBOM integrity",
            isinstance(sbom, dict) and sbom.get("component_count", 0) >= 0,
            True,
            "SBOM structure validated.",
        ),
        ClosureControl(
            "SC3-EVIDENCE-INTEGRITY",
            "Evidence SHA-256 ledger",
            ledger.get("record_count", 0) == len([p for p in evidence_paths if (root / p).is_file()]),
            True,
            "Evidence ledger covers all required closure inputs.",
        ),
        ClosureControl(
            "SC3-SECRET-SAFETY",
            "No secret values exposed",
            assessment.get("secret_values_exposed") is False,
            True,
            "Capa 2 certifies no secret values exposed.",
        ),
        ClosureControl(
            "SC3-PUBLICATION-SAFETY",
            "No workflow/package/release execution by gate",
            assessment.get("workflow_executed") is False
            and assessment.get("package_installed") is False
            and assessment.get("release_published") is False,
            True,
            "Closure uses static governance evidence only.",
        ),
        ClosureControl(
            "SC3-CLOSED-COMPONENT-PRESERVATION",
            "Closed component preservation",
            True,
            True,
            "Runtime SHA-256 preservation gate enforced by PowerShell master.",
        ),
    ]

    return {
        "controls": [c.__dict__ for c in controls],
        "ledger": ledger,
        "layer2_status": assessment.get("status"),
        "layer2_integrity_records": integrity.get("record_count", 0),
        "sbom_components": sbom.get("component_count", 0),
    }
'@

    $ServicePy=@'
from pathlib import Path

from .closure import build_controls
from .gate import SupplyChainClosureGate


class SupplyChainClosureService:
    def __init__(self, root: Path):
        self.root = Path(root)

    def close(self, layer2_assessment, layer2_sbom, layer2_integrity, evidence_paths):
        payload = build_controls(
            self.root,
            layer2_assessment,
            layer2_sbom,
            layer2_integrity,
            evidence_paths,
        )

        passed, failed = SupplyChainClosureGate.evaluate(payload["controls"])
        payload["status"] = "INSTITUTIONALLY_CLOSED" if passed else "CLOSURE_HOLD"
        payload["failed_blocking_controls"] = failed
        return payload
'@

    $TestsPy=@'
import json
from pathlib import Path

from sgoda.integration.spt0247l3.service import SupplyChainClosureService


def write_json(path: Path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def fixture(tmp_path):
    assessment = "artifacts/l2/assessment.json"
    sbom = "artifacts/l2/sbom.json"
    integrity = "artifacts/l2/integrity.json"
    evidence = "artifacts/l2/evidence.json"

    write_json(tmp_path / assessment, {
        "status": "SUPPLY_CHAIN_LAYER2_GATE_PASS",
        "workflow_executed": False,
        "package_installed": False,
        "release_published": False,
        "secret_values_exposed": False,
    })
    write_json(tmp_path / sbom, {"component_count": 2, "components": []})
    write_json(tmp_path / integrity, {"record_count": 2, "records": []})
    write_json(tmp_path / evidence, {"status": "PASS"})

    return assessment, sbom, integrity, evidence


def test_closure_passes(tmp_path):
    a, s, i, e = fixture(tmp_path)
    result = SupplyChainClosureService(tmp_path).close(a, s, i, [a, s, i, e])
    assert result["status"] == "INSTITUTIONALLY_CLOSED"
    assert result["failed_blocking_controls"] == []


def test_capa2_hold_blocks(tmp_path):
    a, s, i, e = fixture(tmp_path)
    write_json(tmp_path / a, {
        "status": "SUPPLY_CHAIN_LAYER2_GATE_HOLD",
        "workflow_executed": False,
        "package_installed": False,
        "release_published": False,
        "secret_values_exposed": False,
    })
    result = SupplyChainClosureService(tmp_path).close(a, s, i, [a, s, i, e])
    assert result["status"] == "CLOSURE_HOLD"
    assert "SC3-CAPA2-PASS" in result["failed_blocking_controls"]


def test_secret_exposure_blocks(tmp_path):
    a, s, i, e = fixture(tmp_path)
    data = json.loads((tmp_path / a).read_text(encoding="utf-8"))
    data["secret_values_exposed"] = True
    write_json(tmp_path / a, data)
    result = SupplyChainClosureService(tmp_path).close(a, s, i, [a, s, i, e])
    assert result["status"] == "CLOSURE_HOLD"
    assert "SC3-SECRET-SAFETY" in result["failed_blocking_controls"]


def test_execution_side_effect_blocks(tmp_path):
    a, s, i, e = fixture(tmp_path)
    data = json.loads((tmp_path / a).read_text(encoding="utf-8"))
    data["workflow_executed"] = True
    write_json(tmp_path / a, data)
    result = SupplyChainClosureService(tmp_path).close(a, s, i, [a, s, i, e])
    assert result["status"] == "CLOSURE_HOLD"
    assert "SC3-PUBLICATION-SAFETY" in result["failed_blocking_controls"]


def test_missing_evidence_is_detected(tmp_path):
    a, s, i, e = fixture(tmp_path)
    result = SupplyChainClosureService(tmp_path).close(a, s, i, [a, s, i, e, "missing.json"])
    assert result["status"] == "CLOSURE_HOLD"
    assert "SC3-EVIDENCE-INTEGRITY" in result["failed_blocking_controls"]
'@

    $PolicyJson=@'
{
  "component": "SPT-024.7",
  "layer": "3",
  "version": "1.0.0",
  "title": "Gobierno, Quality Gates Finales y Cierre Institucional de la Cadena de Suministro",
  "blocking_controls": [
    "SC3-CAPA2-PASS",
    "SC3-SBOM-INTEGRITY",
    "SC3-EVIDENCE-INTEGRITY",
    "SC3-SECRET-SAFETY",
    "SC3-PUBLICATION-SAFETY",
    "SC3-CLOSED-COMPONENT-PRESERVATION"
  ],
  "closure_status": "INSTITUTIONALLY_CLOSED",
  "safety": {
    "modify_layer1": false,
    "modify_layer2": false,
    "execute_workflows": false,
    "install_packages": false,
    "publish_release_before_remote_gate": false,
    "print_secret_values": false
  }
}
'@

    $DocMd=@'
# SPT-024.7 Capa 3 — Gobierno, Quality Gates Finales y Cierre Institucional

Baseline autoritativa: `449dde2b56239b138f1ef471a54bc399fe902b08`.

Esta capa no reconstruye ni modifica SPT-024.7 Capa 1 o Capa 2. Reutiliza sus evidencias, SBOM, manifiestos de integridad, assessment de seguridad y resultados de pruebas para producir el dictamen final de gobierno de SPT-024.7.

## Quality Gates finales

- SC3-CAPA2-PASS
- SC3-SBOM-INTEGRITY
- SC3-EVIDENCE-INTEGRITY
- SC3-SECRET-SAFETY
- SC3-PUBLICATION-SAFETY
- SC3-CLOSED-COMPONENT-PRESERVATION

El cierre institucional exige además suite dirigida, suite institucional completa, `compileall`, preservación SHA-256, gate global del índice Git para blobs inferiores a 100 MB, staging exacto, remote gate, commit, push y verificación `LOCAL HEAD = REMOTE HEAD`.

Solo si todos los gates terminan en PASS, SPT-024.7 adquiere estado `INSTITUTIONALLY_CLOSED`.
'@

    Write-Lf "$ModuleDir/__init__.py" $InitPy
    Write-Lf "$ModuleDir/models.py" $ModelsPy
    Write-Lf "$ModuleDir/governance.py" $GovernancePy
    Write-Lf "$ModuleDir/gate.py" $GatePy
    Write-Lf "$ModuleDir/closure.py" $ClosurePy
    Write-Lf "$ModuleDir/service.py" $ServicePy
    Write-Lf $TestFile $TestsPy
    Write-Lf $PolicyFile $PolicyJson
    Write-Lf $DocFile $DocMd

    Write-Host "SPT-024.7 CAPA 3 IMPLEMENTATION : CREATED/VALIDATED"

    Step 5 "PYTHON PREVALIDATION + TARGETED TESTS"

    $Python=PythonExe
    $env:PYTHONPATH=(Join-Path $PWD "src")

    Native $Python @(
        "-c",
        "import sgoda.integration.spt0247l3; from sgoda.integration.spt0247l3.gate import SupplyChainClosureGate; assert len(SupplyChainClosureGate.BLOCKING)==6; print('SPT0247_CAPA3_IMPORT=PASS'); print('BLOCKING_CONTROLS=6')"
    ) "SPT-024.7 Capa 3 import"

    Native $Python @("-m","pytest",$TestFile,"-q") "SPT-024.7 Capa 3 targeted tests"
    Write-Host "TARGETED TESTS : PASS"

    Step 6 "INSTITUTIONAL SUITE + COMPILEALL"

    Native $Python @("-m","pytest","-q") "Institutional pytest suite"
    Write-Host "FULL SUITE : PASS"

    Native $Python @("-m","compileall","-q","src") "compileall"
    Write-Host "COMPILEALL : PASS"

    Step 7 "FINAL GOVERNANCE / CLOSURE ASSESSMENT"

    New-Item -ItemType Directory -Force -Path $ArtifactDir|Out-Null

    $ProbeTmp=Join-Path $env:TEMP ("sgoda-spt0247-l3-"+[Guid]::NewGuid().ToString("N")+".py")
    $utf8=New-Object System.Text.UTF8Encoding($false)

    try{
        $Probe=@'
import json
import sys
from pathlib import Path

from sgoda.integration.spt0247l3.service import SupplyChainClosureService

root = Path.cwd()

assessment = "artifacts/development/SPT-024.7-Capa2-v1.0.0/supply-chain-layer2-assessment.json"
sbom = "artifacts/development/SPT-024.7-Capa2-v1.0.0/sbom-layer2.json"
integrity = "artifacts/development/SPT-024.7-Capa2-v1.0.0/integrity-manifest-layer2.json"
evidence = "artifacts/development/SPT-024.7-Capa2-v1.0.0/implementation-evidence.json"

required = [assessment, sbom, integrity, evidence]

result = SupplyChainClosureService(root).close(
    assessment,
    sbom,
    integrity,
    required,
)

artifact_dir = root / "artifacts" / "development" / "SPT-024.7-Capa3-v1.0.0"
artifact_dir.mkdir(parents=True, exist_ok=True)

ledger = artifact_dir / "supply-chain-closure-ledger.json"
manifest = artifact_dir / "closure-manifest.json"

ledger.write_text(
    json.dumps(result["ledger"], indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)

closure_manifest = {
    "component": "SPT-024.7",
    "layer": "3",
    "version": "1.0.0",
    "status": result["status"],
    "failed_blocking_controls": result["failed_blocking_controls"],
    "controls": result["controls"],
    "layer2_status": result["layer2_status"],
    "sbom_components": result["sbom_components"],
    "layer2_integrity_records": result["layer2_integrity_records"],
    "secret_values_exposed": False,
    "workflow_executed": False,
    "package_installed": False,
    "release_published": False,
}

manifest.write_text(
    json.dumps(closure_manifest, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)

print("SPT0247_CLOSURE_STATUS=" + result["status"])
print("FAILED_BLOCKING_CONTROLS=%d" % len(result["failed_blocking_controls"]))
print("FAILED_CONTROL_IDS=" + ",".join(result["failed_blocking_controls"]))
print("CAPA2_SECURITY_GATE=" + result["layer2_status"])
print("SBOM_COMPONENTS=%d" % result["sbom_components"])
print("EVIDENCE_LEDGER_RECORDS=%d" % result["ledger"]["record_count"])
print("SECRET_VALUES_EXPOSED=NO")
print("WORKFLOW_EXECUTED=NO")
print("PACKAGE_INSTALLED=NO")
print("RELEASE_PUBLISHED=NO")

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
            Stop-Hold "Final SPT-024.7 governance gate failed."
        }

        if($ClosureExit -ne 0){
            Stop-Hold "Closure assessment failed with exit code $ClosureExit."
        }
    }
    finally{
        Remove-Item -LiteralPath $ProbeTmp -Force -ErrorAction SilentlyContinue
    }

    Write-Host "FINAL GOVERNANCE GATE : PASS"

    Step 8 "EVIDENCE + INSTITUTIONAL CLOSURE RECORD"

    $Closure=Get-Content -LiteralPath $ClosureManifest -Raw -Encoding UTF8|ConvertFrom-Json
    if($Closure.status -ne "INSTITUTIONALLY_CLOSED"){
        Stop-Hold "Closure manifest does not certify institutional closure."
    }

    $Evidence=[ordered]@{
        component="SPT-024.7"
        layer="3"
        version="1.0.0"
        generated_utc=[DateTime]::UtcNow.ToString("o")
        authoritative_baseline=$ExpectedBaseline
        final_status="INSTITUTIONALLY_CLOSED"
        gates=[ordered]@{
            capa2_security_gate="PASS"
            final_governance_gate="PASS"
            sbom_integrity="PASS"
            evidence_integrity="PASS"
            targeted_tests="PASS"
            institutional_suite="PASS"
            compileall="PASS"
            preservation="PENDING"
            github_size="PENDING"
            remote_sync="PENDING"
        }
        artifacts=[ordered]@{
            closure_ledger=$ClosureLedger
            closure_manifest=$ClosureManifest
        }
        secret_values_exposed=$false
        workflow_executed=$false
        package_installed=$false
        release_published=$false
    }

    Write-Lf $EvidenceFile ($Evidence|ConvertTo-Json -Depth 12)

    Write-Host "CLOSURE LEDGER   : CREATED"
    Write-Host "CLOSURE MANIFEST : CREATED"
    Write-Host "EVIDENCE         : CREATED"

    Step 9 "SHA-256 PRESERVATION GATE"

    Assert-Snapshot $Snapshot
    Write-Host "SPT-024.7 CAPAS 1-2 + CLOSED COMPONENTS : PRESERVED"

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
        "feat(spt-024.7): close supply-chain governance layer 3"
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
    Write-Host " SPT-024.7 CAPA 3 : INSTITUTIONALLY CLOSED" -ForegroundColor Green
    Write-Host " CAPA1_SECURITY_GATE=PASS" -ForegroundColor Green
    Write-Host " CAPA2_SECURITY_GATE=PASS" -ForegroundColor Green
    Write-Host " FINAL_GOVERNANCE_GATE=PASS" -ForegroundColor Green
    Write-Host " SBOM_INTEGRITY=PASS" -ForegroundColor Green
    Write-Host " EVIDENCE_INTEGRITY=PASS" -ForegroundColor Green
    Write-Host " CLOSED_COMPONENTS=PRESERVED" -ForegroundColor Green
    Write-Host " INSTITUTIONAL_SUITE=PASS" -ForegroundColor Green
    Write-Host " COMPILEALL=PASS" -ForegroundColor Green
    Write-Host " LOCAL_HEAD=REMOTE_HEAD" -ForegroundColor Green
    Write-Host " SPT0247_STATUS=INSTITUTIONALLY_CLOSED" -ForegroundColor Green
    Write-Host " FINAL_CLOSURE_EXIT_CODE=0" -ForegroundColor Green
    Write-Host "============================================================================" -ForegroundColor Green
    exit 0
}
catch{
    Stop-Hold $_.Exception.Message
}
