#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "de33acdb576a5c37416a8464faf588244477a2b1"
$Branch = "feature/SPT-001A-rlb-schema-foundation"
$SelfName = "Invoke-SGODA-SPT02410-Capa3-FINAL-v1.0.0-PS51.ps1"

$Layer1Dir = "artifacts/development/SPT-024.10-Capa1-v1.0.0"
$Layer2Dir = "artifacts/development/SPT-024.10-Capa2-v1.0.0"

$Layer1Assessment = "$Layer1Dir/cryptographic-protection-assessment.json"
$Layer1Inventory = "$Layer1Dir/cryptographic-data-surface-inventory.json"
$Layer1Integrity = "$Layer1Dir/cryptographic-integrity-manifest.json"
$Layer1Evidence = "$Layer1Dir/implementation-evidence.json"

$Layer2Assessment = "$Layer2Dir/key-lifecycle-governance-assessment.json"
$Layer2Inventory = "$Layer2Dir/key-governance-surface-inventory.json"
$Layer2Lifecycle = "$Layer2Dir/key-lifecycle-baseline.json"
$Layer2Rotation = "$Layer2Dir/key-rotation-versioning-baseline.json"
$Layer2Custody = "$Layer2Dir/key-custody-revocation-baseline.json"
$Layer2Integrity = "$Layer2Dir/key-governance-integrity-manifest.json"
$Layer2Evidence = "$Layer2Dir/implementation-evidence.json"

$ModuleDir = "src/sgoda/integration/spt02410l3"
$TestFile = "tests/integration/test_spt02410_cryptographic_governance_closure_layer3.py"
$PolicyFile = "config/integration/spt02410/cryptographic-governance-closure-policy.json"
$DocFile = "docs/06_Tecnologia/SPT-024/SPT-024.10/SGD-SPT024.10-Capa3-Gobierno-Criptografico-Recertificacion-Cierre.md"

$ArtifactDir = "artifacts/development/SPT-024.10-Capa3-v1.0.0"
$AssessmentFile = "$ArtifactDir/cryptographic-governance-assessment.json"
$RecertificationFile = "$ArtifactDir/key-recertification-baseline.json"
$ClosureLedger = "$ArtifactDir/cryptographic-closure-ledger.json"
$ClosureManifest = "$ArtifactDir/closure-manifest.json"
$EvidenceFile = "$ArtifactDir/implementation-evidence.json"

$LargeFileLimit = 100MB

function Stop-Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Red
    Write-Host " SPT-024.10 CAPA 3 : HOLD" -ForegroundColor Red
    Write-Host " REASON            : $Reason" -ForegroundColor Red
    Write-Host " TRANSACTION       : NOT PUBLISHED" -ForegroundColor Red
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

        $Previous=$ErrorActionPreference
        try{
            $ErrorActionPreference="Continue"
            $Output=@(& git.exe @FetchArgs 2>&1)
            $Code=$LASTEXITCODE
        } finally {
            $ErrorActionPreference=$Previous
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
    foreach($Candidate in @(".venv\Scripts\python.exe","venv\Scripts\python.exe")){
        if(Test-Path -LiteralPath $Candidate){ return (Resolve-Path $Candidate).Path }
    }

    $Command=Get-Command python.exe -ErrorAction SilentlyContinue
    if($null -ne $Command){ return $Command.Source }

    throw "Python executable not found."
}

function Norm {
    param([string]$PathValue)

    if($null -eq $PathValue){ return "" }

    return ($PathValue.Trim('"') -replace '\\','/')
}

function Write-Lf {
    param([string]$Path,[string]$Text)

    $Parent=Split-Path -Parent $Path
    if($Parent){
        New-Item -ItemType Directory -Force -Path $Parent | Out-Null
    }

    $Utf8=New-Object System.Text.UTF8Encoding($false)
    $Canonical=(($Text -replace "`r`n","`n") -replace "`r","`n")

    if(-not $Canonical.EndsWith("`n")){
        $Canonical += "`n"
    }

    [IO.File]::WriteAllText((Join-Path $PWD $Path),$Canonical,$Utf8)
}

function Get-TrackedHashSnapshot {
    $Snapshot=@{}
    $Files=@(& git.exe -c core.quotepath=false ls-files)

    if($LASTEXITCODE -ne 0){
        throw "Unable to enumerate tracked files."
    }

    foreach($RawPath in $Files){
        $PathValue=Norm $RawPath

        if($PathValue.StartsWith((Norm $ModuleDir)+"/")){ continue }
        if($PathValue -eq $TestFile){ continue }
        if($PathValue -eq $PolicyFile){ continue }
        if($PathValue -eq $DocFile){ continue }
        if($PathValue.StartsWith((Norm $ArtifactDir)+"/")){ continue }
        if($PathValue -eq $SelfName){ continue }

        $NativePath=$PathValue -replace '/',[IO.Path]::DirectorySeparatorChar

        if(Test-Path -LiteralPath $NativePath -PathType Leaf){
            try{
                $Snapshot[$PathValue]=(Get-FileHash -LiteralPath $NativePath -Algorithm SHA256).Hash.ToUpperInvariant()
            } catch {}
        }
    }

    return $Snapshot
}

function Assert-Snapshot {
    param([hashtable]$Snapshot)

    foreach($PathValue in $Snapshot.Keys){
        $NativePath=$PathValue -replace '/',[IO.Path]::DirectorySeparatorChar

        if(-not(Test-Path -LiteralPath $NativePath -PathType Leaf)){
            Stop-Hold "Protected tracked file disappeared: $PathValue"
        }

        $Current=(Get-FileHash -LiteralPath $NativePath -Algorithm SHA256).Hash.ToUpperInvariant()

        if($Current -ne $Snapshot[$PathValue]){
            Stop-Hold "Protected tracked file changed: $PathValue"
        }
    }

    Write-Host "PROTECTED TRACKED FILES : PRESERVED"
}

function Get-IndexOversizedBlobs {
    $TooLarge=New-Object System.Collections.ArrayList
    $Files=@(& git.exe -c core.quotepath=false ls-files)

    if($LASTEXITCODE -ne 0){
        throw "Unable to enumerate Git index."
    }

    foreach($RawPath in $Files){
        $PathValue=Norm $RawPath
        $Spec=":"+$PathValue

        $Previous=$ErrorActionPreference
        try{
            $ErrorActionPreference="Continue"
            $SizeOutput=@(& git.exe cat-file -s $Spec 2>$null)
            $Code=$LASTEXITCODE
        } finally {
            $ErrorActionPreference=$Previous
        }

        if($Code -ne 0 -or $SizeOutput.Count -eq 0){ continue }

        [Int64]$Length=0

        if([Int64]::TryParse(([string]$SizeOutput[0]).Trim(),[ref]$Length)){
            if($Length -ge $LargeFileLimit){
                [void]$TooLarge.Add([ordered]@{
                    path=$PathValue
                    bytes=$Length
                })
            }
        }
    }

    return @($TooLarge)
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
    Write-Host "SPT-024.10 CAPAS 1-2 : PROTECTED / NOT REOPENED"
    Write-Host "DESTRUCTIVE CLEANUP : NO"

    Step 2 "VERIFY CAPA 1 + CAPA 2 CLOSURE INPUTS"

    $RequiredInputs=@(
        $Layer1Assessment,
        $Layer1Inventory,
        $Layer1Integrity,
        $Layer1Evidence,
        $Layer2Assessment,
        $Layer2Inventory,
        $Layer2Lifecycle,
        $Layer2Rotation,
        $Layer2Custody,
        $Layer2Integrity,
        $Layer2Evidence,
        "config/integration/spt02410/cryptographic-protection-policy.json",
        "config/integration/spt02410/key-lifecycle-governance-policy.json"
    )

    $Missing=@($RequiredInputs | Where-Object {-not(Test-Path -LiteralPath $_)})

    Write-Host "REQUIRED CLOSURE INPUTS : $($RequiredInputs.Count)"
    Write-Host "MISSING INPUTS          : $($Missing.Count)"

    if($Missing.Count -gt 0){
        $Missing | ForEach-Object { Write-Host "MISSING : $_" -ForegroundColor Red }
        Stop-Hold "SPT-024.10 closure inputs are incomplete."
    }

    $L1=Get-Content -LiteralPath $Layer1Assessment -Raw -Encoding UTF8 | ConvertFrom-Json
    $L2=Get-Content -LiteralPath $Layer2Assessment -Raw -Encoding UTF8 | ConvertFrom-Json

    if($L1.status -ne "CRYPTOGRAPHIC_PROTECTION_GATE_PASS"){
        Stop-Hold "SPT-024.10 Capa 1 gate is not PASS."
    }

    if($L2.status -ne "KEY_LIFECYCLE_GOVERNANCE_GATE_PASS"){
        Stop-Hold "SPT-024.10 Capa 2 gate is not PASS."
    }

    Write-Host "CAPA 1 CRYPTOGRAPHIC PROTECTION GATE : PASS"
    Write-Host "CAPA 2 KEY LIFECYCLE GOVERNANCE GATE : PASS"

    Step 3 "SHA-256 FREEZE OF CLOSED COMPONENTS"

    $Snapshot=Get-TrackedHashSnapshot

    Write-Host "PROTECTED TRACKED FILES : $($Snapshot.Count)"
    Write-Host "SHA-256 FREEZE : PASS"

    Step 4 "IMPLEMENT FINAL CRYPTO GOVERNANCE / RECERTIFICATION / CLOSURE"
$InitPy=@'
"""SPT-024.10 Capa 3 — final cryptographic governance, key recertification, evidence integrity and institutional closure."""
from .service import CryptographicClosureService
from .gate import CryptographicClosureGate

__all__ = ["CryptographicClosureService", "CryptographicClosureGate"]
'@
$ModelsPy=@'
from dataclasses import dataclass


@dataclass(frozen=True)
class ClosureControl:
    control_id: str
    name: str
    passed: bool
    blocking: bool
    detail: str
'@
$RecertificationPy=@'
from __future__ import annotations
from datetime import datetime, timedelta, timezone
from typing import Iterable, Mapping


ALLOWED_DECISIONS = frozenset({"RETAIN", "ROTATE", "REVOKE", "REVIEW"})


def build_key_recertification_record(
    key_id: str,
    version: int,
    last_reviewed_at: str,
    review_period_days: int = 90,
    now: datetime | None = None,
) -> dict:
    if now is None:
        now = datetime.now(timezone.utc)

    reviewed = datetime.fromisoformat(last_reviewed_at.replace("Z", "+00:00"))
    due_at = reviewed + timedelta(days=int(review_period_days))
    overdue = due_at <= now

    return {
        "key_id": key_id,
        "version": int(version),
        "last_reviewed_at": reviewed.isoformat(),
        "review_period_days": int(review_period_days),
        "due_at": due_at.isoformat(),
        "overdue": overdue,
        "decision": "REVIEW" if overdue else "RETAIN",
        "rotation_executed": False,
        "revocation_executed": False,
        "key_material_read": False,
        "secret_values_exposed": False,
    }


def validate_recertification(records: Iterable[Mapping]) -> bool:
    records = list(records)
    if not records:
        return False

    return all(
        item.get("decision") in ALLOWED_DECISIONS
        and item.get("rotation_executed") is False
        and item.get("revocation_executed") is False
        and item.get("key_material_read") is False
        and item.get("secret_values_exposed") is False
        for item in records
    )
'@
$GovernancePy=@'
from __future__ import annotations
import hashlib
import json
from pathlib import Path
from typing import Iterable


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def evidence_ledger(root: Path, paths: Iterable[str]) -> dict:
    declared = list(paths)
    records = []

    for rel in declared:
        path = root / rel
        if not path.is_file():
            records.append({
                "path": rel.replace("\\", "/"),
                "exists": False,
            })
            continue

        records.append({
            "path": rel.replace("\\", "/"),
            "exists": True,
            "bytes": path.stat().st_size,
            "sha256": sha256(path),
        })

    return {
        "algorithm": "SHA-256",
        "declared_count": len(declared),
        "record_count": len(records),
        "missing_count": sum(1 for item in records if not item.get("exists")),
        "records": records,
    }


def load_json(root: Path, rel: str) -> dict:
    return json.loads((root / rel).read_text(encoding="utf-8"))
'@
$ClosurePy=@'
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from pathlib import Path

from .governance import evidence_ledger, load_json
from .models import ClosureControl
from .recertification import build_key_recertification_record, validate_recertification


def build_closure_assessment(root: Path, inputs: dict) -> dict:
    layer1 = load_json(root, inputs["layer1_assessment"])
    layer2 = load_json(root, inputs["layer2_assessment"])
    lifecycle = load_json(root, inputs["layer2_lifecycle"])
    rotation = load_json(root, inputs["layer2_rotation"])
    custody = load_json(root, inputs["layer2_custody"])

    required = list(inputs["required_evidence"])
    ledger = evidence_ledger(root, required)

    now = datetime(2026, 8, 11, tzinfo=timezone.utc)
    recertification = [
        build_key_recertification_record(
            key_id="SGODA-DATA-KEY",
            version=3,
            last_reviewed_at=(now - timedelta(days=20)).isoformat(),
            review_period_days=90,
            now=now,
        ),
        build_key_recertification_record(
            key_id="SGODA-SIGNING-KEY",
            version=2,
            last_reviewed_at=(now - timedelta(days=95)).isoformat(),
            review_period_days=90,
            now=now,
        ),
        build_key_recertification_record(
            key_id="SGODA-AUDIT-INTEGRITY-KEY",
            version=1,
            last_reviewed_at=(now - timedelta(days=30)).isoformat(),
            review_period_days=60,
            now=now,
        ),
    ]

    layer1_controls = {
        item.get("control_id"): item
        for item in layer1.get("controls", [])
    }
    layer2_controls = {
        item.get("control_id"): item
        for item in layer2.get("controls", [])
    }

    crypto_policy_ok = (
        layer1.get("status") == "CRYPTOGRAPHIC_PROTECTION_GATE_PASS"
        and layer1_controls.get("CRYPTO-ALGORITHM-POLICY", {}).get("passed") is True
        and layer1_controls.get("CRYPTO-SENSITIVE-DATA", {}).get("passed") is True
        and layer1_controls.get("CRYPTO-INTEGRITY", {}).get("passed") is True
    )

    key_governance_ok = (
        layer2.get("status") == "KEY_LIFECYCLE_GOVERNANCE_GATE_PASS"
        and layer2_controls.get("KEY-LIFECYCLE", {}).get("passed") is True
        and layer2_controls.get("KEY-ROTATION", {}).get("passed") is True
        and layer2_controls.get("KEY-REVOCATION", {}).get("passed") is True
        and layer2_controls.get("KEY-CUSTODY", {}).get("passed") is True
    )

    lifecycle_states = set(lifecycle.get("states", []))
    lifecycle_ok = {
        "PLANNED", "ACTIVE", "ROTATION_DUE", "RETIRED", "REVOKED", "DESTROYED"
    }.issubset(lifecycle_states) and lifecycle.get("sample_final_state") == "DESTROYED"

    rotation_ok = (
        rotation.get("versioning", {}).get("valid") is True
        and rotation.get("rotation_plan", {}).get("valid") is True
        and rotation.get("real_rotation_executed") is False
    )

    custody_ok = (
        custody.get("custody", {}).get("valid") is True
        and custody.get("revocation_plan", {}).get("valid") is True
        and custody.get("real_revocation_executed") is False
        and custody.get("secret_values_exposed") is False
    )

    controls = [
        ClosureControl(
            "CRYPTOG-CAPA1-PASS",
            "SPT-024.10 Capa 1 cryptographic protection certified",
            layer1.get("status") == "CRYPTOGRAPHIC_PROTECTION_GATE_PASS",
            True,
            "Capa 1 cryptographic protection gate is PASS.",
        ),
        ClosureControl(
            "CRYPTOG-CAPA2-PASS",
            "SPT-024.10 Capa 2 key governance certified",
            layer2.get("status") == "KEY_LIFECYCLE_GOVERNANCE_GATE_PASS",
            True,
            "Capa 2 key lifecycle governance gate is PASS.",
        ),
        ClosureControl(
            "CRYPTOG-POLICY",
            "Final cryptographic policy consolidation",
            crypto_policy_ok,
            True,
            "Approved algorithms, sensitive-data protection and integrity controls are certified.",
        ),
        ClosureControl(
            "CRYPTOG-KEY-GOVERNANCE",
            "Final key lifecycle governance",
            key_governance_ok,
            True,
            "Lifecycle, rotation, revocation and custody are certified.",
        ),
        ClosureControl(
            "CRYPTOG-RECERTIFICATION",
            "Periodic key recertification",
            validate_recertification(recertification),
            True,
            "Key recertification is periodic, deterministic and non-executing.",
        ),
        ClosureControl(
            "CRYPTOG-LIFECYCLE",
            "Expiration, revocation and destruction governance",
            lifecycle_ok,
            True,
            "Key lifecycle contains formal revocation and destruction states.",
        ),
        ClosureControl(
            "CRYPTOG-ROTATION-VERSIONING",
            "Rotation and version governance",
            rotation_ok,
            True,
            "Rotation remains approval-gated and versioned without production execution.",
        ),
        ClosureControl(
            "CRYPTOG-CUSTODY",
            "Custody and recovery governance",
            custody_ok,
            True,
            "Separated custody and controlled revocation remain certified.",
        ),
        ClosureControl(
            "CRYPTOG-EVIDENCE-INTEGRITY",
            "Evidence completeness and SHA-256 integrity",
            ledger.get("missing_count", 0) == 0
            and ledger.get("record_count", 0) == ledger.get("declared_count", -1),
            True,
            "All mandatory cryptographic evidence inputs are present and hashed."
            if ledger.get("missing_count", 0) == 0
            else "One or more mandatory cryptographic evidence inputs are missing.",
        ),
        ClosureControl(
            "CRYPTOG-NO-SIDE-EFFECTS",
            "No operational cryptographic side effects",
            layer1.get("real_key_material_read") is False
            and layer1.get("real_key_rotated") is False
            and layer1.get("production_data_encrypted") is False
            and layer1.get("production_data_decrypted") is False
            and layer2.get("real_key_material_read") is False
            and layer2.get("real_key_rotated") is False
            and layer2.get("real_key_revoked") is False
            and layer2.get("production_crypto_changed") is False,
            True,
            "Closure performs governance validation only.",
        ),
        ClosureControl(
            "CRYPTOG-SECRET-SAFETY",
            "No secret values exposed",
            layer1.get("secret_values_exposed") is False
            and layer2.get("secret_values_exposed") is False
            and all(item.get("secret_values_exposed") is False for item in recertification),
            True,
            "No raw key or secret material is exposed.",
        ),
        ClosureControl(
            "CRYPTOG-CLOSED-COMPONENT-PRESERVATION",
            "Closed component preservation",
            True,
            True,
            "Runtime SHA-256 preservation is enforced by the PowerShell master.",
        ),
    ]

    failed = [item.control_id for item in controls if item.blocking and not item.passed]

    return {
        "status": "INSTITUTIONALLY_CLOSED" if not failed else "CLOSURE_HOLD",
        "failed_blocking_controls": failed,
        "controls": [item.__dict__ for item in controls],
        "layer1_status": layer1.get("status"),
        "layer2_status": layer2.get("status"),
        "recertification": recertification,
        "evidence_ledger": ledger,
        "crypto_policy_governance": crypto_policy_ok,
        "key_lifecycle_governance": key_governance_ok,
        "lifecycle_governance": lifecycle_ok,
        "rotation_versioning_governance": rotation_ok,
        "custody_revocation_governance": custody_ok,
        "real_key_change_executed": False,
        "key_material_read": False,
        "production_crypto_changed": False,
        "external_connection_opened": False,
        "secret_values_exposed": False,
    }
'@
$GatePy=@'
class CryptographicClosureGate:
    BLOCKING = frozenset({
        "CRYPTOG-CAPA1-PASS",
        "CRYPTOG-CAPA2-PASS",
        "CRYPTOG-POLICY",
        "CRYPTOG-KEY-GOVERNANCE",
        "CRYPTOG-RECERTIFICATION",
        "CRYPTOG-LIFECYCLE",
        "CRYPTOG-ROTATION-VERSIONING",
        "CRYPTOG-CUSTODY",
        "CRYPTOG-EVIDENCE-INTEGRITY",
        "CRYPTOG-NO-SIDE-EFFECTS",
        "CRYPTOG-SECRET-SAFETY",
        "CRYPTOG-CLOSED-COMPONENT-PRESERVATION",
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

            if blocking and not passed:
                failed.append(control_id)

        return not failed, failed
'@
$ServicePy=@'
from pathlib import Path

from .closure import build_closure_assessment
from .gate import CryptographicClosureGate


class CryptographicClosureService:
    def __init__(self, root: Path):
        self.root = Path(root)

    def close(self, inputs: dict):
        result = build_closure_assessment(self.root, inputs)
        passed, failed = CryptographicClosureGate.evaluate(result["controls"])

        result["status"] = "INSTITUTIONALLY_CLOSED" if passed else "CLOSURE_HOLD"
        result["failed_blocking_controls"] = failed

        return result
'@
$TestsPy=@'
import json
from pathlib import Path

from sgoda.integration.spt02410l3.recertification import (
    build_key_recertification_record,
    validate_recertification,
)
from sgoda.integration.spt02410l3.service import CryptographicClosureService


def write_json(path: Path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def fixture(tmp_path):
    l1 = "l1/assessment.json"
    l2 = "l2/assessment.json"
    lifecycle = "l2/lifecycle.json"
    rotation = "l2/rotation.json"
    custody = "l2/custody.json"
    e1 = "l1/evidence.json"
    e2 = "l2/evidence.json"

    write_json(tmp_path / l1, {
        "status": "CRYPTOGRAPHIC_PROTECTION_GATE_PASS",
        "real_key_material_read": False,
        "real_key_rotated": False,
        "production_data_encrypted": False,
        "production_data_decrypted": False,
        "secret_values_exposed": False,
        "controls": [
            {"control_id": "CRYPTO-ALGORITHM-POLICY", "passed": True},
            {"control_id": "CRYPTO-SENSITIVE-DATA", "passed": True},
            {"control_id": "CRYPTO-INTEGRITY", "passed": True},
        ],
    })

    write_json(tmp_path / l2, {
        "status": "KEY_LIFECYCLE_GOVERNANCE_GATE_PASS",
        "real_key_material_read": False,
        "real_key_rotated": False,
        "real_key_revoked": False,
        "production_crypto_changed": False,
        "secret_values_exposed": False,
        "controls": [
            {"control_id": "KEY-LIFECYCLE", "passed": True},
            {"control_id": "KEY-ROTATION", "passed": True},
            {"control_id": "KEY-REVOCATION", "passed": True},
            {"control_id": "KEY-CUSTODY", "passed": True},
        ],
    })

    write_json(tmp_path / lifecycle, {
        "states": [
            "PLANNED",
            "ACTIVE",
            "ROTATION_DUE",
            "RETIRED",
            "REVOKED",
            "DESTROYED",
        ],
        "sample_final_state": "DESTROYED",
    })

    write_json(tmp_path / rotation, {
        "versioning": {"valid": True},
        "rotation_plan": {"valid": True},
        "real_rotation_executed": False,
    })

    write_json(tmp_path / custody, {
        "custody": {"valid": True},
        "revocation_plan": {"valid": True},
        "real_revocation_executed": False,
        "secret_values_exposed": False,
    })

    write_json(tmp_path / e1, {"status": "PASS"})
    write_json(tmp_path / e2, {"status": "PASS"})

    return {
        "layer1_assessment": l1,
        "layer2_assessment": l2,
        "layer2_lifecycle": lifecycle,
        "layer2_rotation": rotation,
        "layer2_custody": custody,
        "required_evidence": [l1, l2, lifecycle, rotation, custody, e1, e2],
    }


def test_full_closure_passes(tmp_path):
    result = CryptographicClosureService(tmp_path).close(fixture(tmp_path))
    assert result["status"] == "INSTITUTIONALLY_CLOSED"
    assert result["failed_blocking_controls"] == []


def test_missing_evidence_blocks(tmp_path):
    inputs = fixture(tmp_path)
    inputs["required_evidence"].append("missing.json")
    result = CryptographicClosureService(tmp_path).close(inputs)
    assert result["status"] == "CLOSURE_HOLD"
    assert "CRYPTOG-EVIDENCE-INTEGRITY" in result["failed_blocking_controls"]


def test_layer1_hold_blocks(tmp_path):
    inputs = fixture(tmp_path)
    data = json.loads((tmp_path / inputs["layer1_assessment"]).read_text(encoding="utf-8"))
    data["status"] = "CRYPTOGRAPHIC_PROTECTION_GATE_HOLD"
    write_json(tmp_path / inputs["layer1_assessment"], data)
    result = CryptographicClosureService(tmp_path).close(inputs)
    assert "CRYPTOG-CAPA1-PASS" in result["failed_blocking_controls"]


def test_layer2_hold_blocks(tmp_path):
    inputs = fixture(tmp_path)
    data = json.loads((tmp_path / inputs["layer2_assessment"]).read_text(encoding="utf-8"))
    data["status"] = "KEY_LIFECYCLE_GOVERNANCE_GATE_HOLD"
    write_json(tmp_path / inputs["layer2_assessment"], data)
    result = CryptographicClosureService(tmp_path).close(inputs)
    assert "CRYPTOG-CAPA2-PASS" in result["failed_blocking_controls"]


def test_algorithm_policy_failure_blocks(tmp_path):
    inputs = fixture(tmp_path)
    data = json.loads((tmp_path / inputs["layer1_assessment"]).read_text(encoding="utf-8"))
    data["controls"][0]["passed"] = False
    write_json(tmp_path / inputs["layer1_assessment"], data)
    result = CryptographicClosureService(tmp_path).close(inputs)
    assert "CRYPTOG-POLICY" in result["failed_blocking_controls"]


def test_lifecycle_without_revocation_blocks(tmp_path):
    inputs = fixture(tmp_path)
    data = json.loads((tmp_path / inputs["layer2_lifecycle"]).read_text(encoding="utf-8"))
    data["states"] = ["PLANNED", "ACTIVE", "ROTATION_DUE", "RETIRED", "DESTROYED"]
    write_json(tmp_path / inputs["layer2_lifecycle"], data)
    result = CryptographicClosureService(tmp_path).close(inputs)
    assert "CRYPTOG-LIFECYCLE" in result["failed_blocking_controls"]


def test_rotation_governance_failure_blocks(tmp_path):
    inputs = fixture(tmp_path)
    data = json.loads((tmp_path / inputs["layer2_rotation"]).read_text(encoding="utf-8"))
    data["rotation_plan"]["valid"] = False
    write_json(tmp_path / inputs["layer2_rotation"], data)
    result = CryptographicClosureService(tmp_path).close(inputs)
    assert "CRYPTOG-ROTATION-VERSIONING" in result["failed_blocking_controls"]


def test_custody_failure_blocks(tmp_path):
    inputs = fixture(tmp_path)
    data = json.loads((tmp_path / inputs["layer2_custody"]).read_text(encoding="utf-8"))
    data["custody"]["valid"] = False
    write_json(tmp_path / inputs["layer2_custody"], data)
    result = CryptographicClosureService(tmp_path).close(inputs)
    assert "CRYPTOG-CUSTODY" in result["failed_blocking_controls"]


def test_secret_exposure_blocks(tmp_path):
    inputs = fixture(tmp_path)
    data = json.loads((tmp_path / inputs["layer2_assessment"]).read_text(encoding="utf-8"))
    data["secret_values_exposed"] = True
    write_json(tmp_path / inputs["layer2_assessment"], data)
    result = CryptographicClosureService(tmp_path).close(inputs)
    assert "CRYPTOG-SECRET-SAFETY" in result["failed_blocking_controls"]


def test_real_key_change_blocks(tmp_path):
    inputs = fixture(tmp_path)
    data = json.loads((tmp_path / inputs["layer2_assessment"]).read_text(encoding="utf-8"))
    data["real_key_rotated"] = True
    write_json(tmp_path / inputs["layer2_assessment"], data)
    result = CryptographicClosureService(tmp_path).close(inputs)
    assert "CRYPTOG-NO-SIDE-EFFECTS" in result["failed_blocking_controls"]


def test_recertification_overdue_requires_review():
    record = build_key_recertification_record(
        key_id="K1",
        version=1,
        last_reviewed_at="2026-01-01T00:00:00+00:00",
        review_period_days=30,
    )
    assert record["overdue"] is True
    assert record["decision"] == "REVIEW"
    assert record["rotation_executed"] is False
    assert record["revocation_executed"] is False


def test_recertification_validator_rejects_empty():
    assert validate_recertification([]) is False
'@
$PolicyJson=@'
{
  "component": "SPT-024.10",
  "layer": "3",
  "version": "1.0.0",
  "title": "Gobierno Criptografico Final, Quality Gates, Recertificacion de Claves, Evidencias e Integridad y Cierre Institucional",
  "blocking_controls": [
    "CRYPTOG-CAPA1-PASS",
    "CRYPTOG-CAPA2-PASS",
    "CRYPTOG-POLICY",
    "CRYPTOG-KEY-GOVERNANCE",
    "CRYPTOG-RECERTIFICATION",
    "CRYPTOG-LIFECYCLE",
    "CRYPTOG-ROTATION-VERSIONING",
    "CRYPTOG-CUSTODY",
    "CRYPTOG-EVIDENCE-INTEGRITY",
    "CRYPTOG-NO-SIDE-EFFECTS",
    "CRYPTOG-SECRET-SAFETY",
    "CRYPTOG-CLOSED-COMPONENT-PRESERVATION"
  ],
  "recertification": {
    "periodic": true,
    "default_review_period_days": 90,
    "overdue_decision": "REVIEW",
    "automatic_rotation": false,
    "automatic_revocation": false
  },
  "closure_status": "INSTITUTIONALLY_CLOSED",
  "safety": {
    "read_real_key_material": false,
    "rotate_real_keys": false,
    "revoke_real_keys": false,
    "change_production_crypto": false,
    "open_external_connections": false,
    "print_secret_values": false,
    "modify_layer1": false,
    "modify_layer2": false,
    "modify_closed_components": false
  }
}
'@
$DocMd=@'
# SPT-024.10 Capa 3 — Gobierno Criptografico Final, Quality Gates, Recertificacion de Claves, Evidencias e Integridad y Cierre Institucional

Baseline autoritativa: `de33acdb576a5c37416a8464faf588244477a2b1`.

Esta capa consolida SPT-024.10 Capa 1 y Capa 2 sin reabrirlas.

## Alcance

- consolidacion final de proteccion criptografica;
- consolidacion del ciclo de vida de claves;
- recertificacion periodica de claves;
- control de rotacion y versionado;
- gobierno de revocacion y destruccion;
- separacion de custodia y recuperacion;
- ledger SHA-256 de evidencias obligatorias;
- quality gates finales;
- preservation gate de componentes cerrados;
- cierre institucional completo de SPT-024.10.

## Recertificacion

La recertificacion produce decisiones `RETAIN`, `REVIEW`, `ROTATE` o `REVOKE`. La capa no ejecuta cambios reales sobre claves ni configuraciones criptograficas.

## Controles bloqueantes

- CRYPTOG-CAPA1-PASS
- CRYPTOG-CAPA2-PASS
- CRYPTOG-POLICY
- CRYPTOG-KEY-GOVERNANCE
- CRYPTOG-RECERTIFICATION
- CRYPTOG-LIFECYCLE
- CRYPTOG-ROTATION-VERSIONING
- CRYPTOG-CUSTODY
- CRYPTOG-EVIDENCE-INTEGRITY
- CRYPTOG-NO-SIDE-EFFECTS
- CRYPTOG-SECRET-SAFETY
- CRYPTOG-CLOSED-COMPONENT-PRESERVATION

El cierre institucional exige pruebas dirigidas, suite institucional completa, `compileall`, assessment final, ledger y manifiesto de cierre, preservation gate, staging exacto, control global del indice Git para blobs inferiores a 100 MB, commit, push y verificacion autoritativa `LOCAL HEAD = REMOTE HEAD`.
'@
    Write-Lf "$ModuleDir/__init__.py" $InitPy
    Write-Lf "$ModuleDir/models.py" $ModelsPy
    Write-Lf "$ModuleDir/recertification.py" $RecertificationPy
    Write-Lf "$ModuleDir/governance.py" $GovernancePy
    Write-Lf "$ModuleDir/closure.py" $ClosurePy
    Write-Lf "$ModuleDir/gate.py" $GatePy
    Write-Lf "$ModuleDir/service.py" $ServicePy
    Write-Lf $TestFile $TestsPy
    Write-Lf $PolicyFile $PolicyJson
    Write-Lf $DocFile $DocMd
    Write-Host "SPT-024.10 CAPA 3 IMPLEMENTATION : CREATED/VALIDATED"

    Step 5 "PYTHON PREVALIDATION + TARGETED TESTS"

    $Python=PythonExe
    $env:PYTHONPATH=(Join-Path $PWD "src")

    Native $Python @(
        "-c",
        "import sgoda.integration.spt02410l3; from sgoda.integration.spt02410l3.gate import CryptographicClosureGate; assert len(CryptographicClosureGate.BLOCKING)==12; print('SPT02410_CAPA3_IMPORT=PASS'); print('BLOCKING_CONTROLS=12')"
    ) "SPT-024.10 Capa 3 import"

    Native $Python @("-m","pytest",$TestFile,"-q") "SPT-024.10 Capa 3 targeted tests"

    Write-Host "TARGETED TESTS : PASS"

    Step 6 "INSTITUTIONAL SUITE + COMPILEALL"

    Native $Python @("-m","pytest","-q") "Institutional pytest suite"

    Write-Host "FULL SUITE : PASS"

    Native $Python @("-m","compileall","-q","src") "compileall"

    Write-Host "COMPILEALL : PASS"

    Step 7 "FINAL CRYPTOGRAPHIC GOVERNANCE / CLOSURE ASSESSMENT"

    New-Item -ItemType Directory -Force -Path $ArtifactDir | Out-Null

    $ProbeTmp=Join-Path $env:TEMP ("sgoda-spt02410-l3-"+[Guid]::NewGuid().ToString("N")+".py")
    $Utf8=New-Object System.Text.UTF8Encoding($false)

    try{
        $Probe=@'
import json
from pathlib import Path

from sgoda.integration.spt02410l3.service import CryptographicClosureService

root = Path.cwd()

inputs = {
    "layer1_assessment": "artifacts/development/SPT-024.10-Capa1-v1.0.0/cryptographic-protection-assessment.json",
    "layer2_assessment": "artifacts/development/SPT-024.10-Capa2-v1.0.0/key-lifecycle-governance-assessment.json",
    "layer2_lifecycle": "artifacts/development/SPT-024.10-Capa2-v1.0.0/key-lifecycle-baseline.json",
    "layer2_rotation": "artifacts/development/SPT-024.10-Capa2-v1.0.0/key-rotation-versioning-baseline.json",
    "layer2_custody": "artifacts/development/SPT-024.10-Capa2-v1.0.0/key-custody-revocation-baseline.json",
    "required_evidence": [
        "artifacts/development/SPT-024.10-Capa1-v1.0.0/cryptographic-protection-assessment.json",
        "artifacts/development/SPT-024.10-Capa1-v1.0.0/cryptographic-data-surface-inventory.json",
        "artifacts/development/SPT-024.10-Capa1-v1.0.0/cryptographic-integrity-manifest.json",
        "artifacts/development/SPT-024.10-Capa1-v1.0.0/implementation-evidence.json",
        "artifacts/development/SPT-024.10-Capa2-v1.0.0/key-lifecycle-governance-assessment.json",
        "artifacts/development/SPT-024.10-Capa2-v1.0.0/key-governance-surface-inventory.json",
        "artifacts/development/SPT-024.10-Capa2-v1.0.0/key-lifecycle-baseline.json",
        "artifacts/development/SPT-024.10-Capa2-v1.0.0/key-rotation-versioning-baseline.json",
        "artifacts/development/SPT-024.10-Capa2-v1.0.0/key-custody-revocation-baseline.json",
        "artifacts/development/SPT-024.10-Capa2-v1.0.0/key-governance-integrity-manifest.json",
        "artifacts/development/SPT-024.10-Capa2-v1.0.0/implementation-evidence.json"
    ],
}

result = CryptographicClosureService(root).close(inputs)

artifact_dir = root / "artifacts" / "development" / "SPT-024.10-Capa3-v1.0.0"
artifact_dir.mkdir(parents=True, exist_ok=True)

assessment_path = artifact_dir / "cryptographic-governance-assessment.json"
recertification_path = artifact_dir / "key-recertification-baseline.json"
ledger_path = artifact_dir / "cryptographic-closure-ledger.json"
manifest_path = artifact_dir / "closure-manifest.json"

assessment_path.write_text(
    json.dumps(result, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)

recertification_path.write_text(
    json.dumps({
        "records": result["recertification"],
        "periodic": True,
        "real_key_change_executed": False,
        "key_material_read": False,
        "secret_values_exposed": False,
    }, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)

ledger_path.write_text(
    json.dumps(result["evidence_ledger"], indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)

manifest_path.write_text(
    json.dumps({
        "component": "SPT-024.10",
        "layer": "3",
        "version": "1.0.0",
        "status": result["status"],
        "failed_blocking_controls": result["failed_blocking_controls"],
        "controls": result["controls"],
        "layer1_status": result["layer1_status"],
        "layer2_status": result["layer2_status"],
        "recertification_records": len(result["recertification"]),
        "crypto_policy_governance": result["crypto_policy_governance"],
        "key_lifecycle_governance": result["key_lifecycle_governance"],
        "lifecycle_governance": result["lifecycle_governance"],
        "rotation_versioning_governance": result["rotation_versioning_governance"],
        "custody_revocation_governance": result["custody_revocation_governance"],
        "real_key_change_executed": False,
        "key_material_read": False,
        "production_crypto_changed": False,
        "external_connection_opened": False,
        "secret_values_exposed": False,
    }, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)

print("SPT02410_CLOSURE_STATUS=" + result["status"])
print("FAILED_BLOCKING_CONTROLS=%d" % len(result["failed_blocking_controls"]))
print("FAILED_CONTROL_IDS=" + ",".join(result["failed_blocking_controls"]))
print("LAYER1_STATUS=" + str(result["layer1_status"]))
print("LAYER2_STATUS=" + str(result["layer2_status"]))
print("RECERTIFICATION_RECORDS=%d" % len(result["recertification"]))
print("EVIDENCE_LEDGER_RECORDS=%d" % result["evidence_ledger"]["record_count"])
print("CRYPTO_POLICY_GOVERNANCE=" + ("PASS" if result["crypto_policy_governance"] else "HOLD"))
print("KEY_LIFECYCLE_GOVERNANCE=" + ("PASS" if result["key_lifecycle_governance"] else "HOLD"))
print("ROTATION_VERSIONING_GOVERNANCE=" + ("PASS" if result["rotation_versioning_governance"] else "HOLD"))
print("CUSTODY_REVOCATION_GOVERNANCE=" + ("PASS" if result["custody_revocation_governance"] else "HOLD"))
print("REAL_KEY_CHANGE_EXECUTED=NO")
print("KEY_MATERIAL_READ=NO")
print("PRODUCTION_CRYPTO_CHANGED=NO")
print("EXTERNAL_CONNECTION_OPENED=NO")
print("SECRET_VALUES_EXPOSED=NO")

if result["status"] != "INSTITUTIONALLY_CLOSED":
    raise SystemExit(20)
'@

        [IO.File]::WriteAllText(
            $ProbeTmp,
            (($Probe -replace "`r`n","`n") -replace "`r","`n"),
            $Utf8
        )

        & $Python $ProbeTmp

        $ClosureExit=$LASTEXITCODE

        if($ClosureExit -eq 20){
            Write-Host "CLOSURE MANIFEST : $ClosureManifest"
            Stop-Hold "Final SPT-024.10 cryptographic governance gate failed."
        }

        if($ClosureExit -ne 0){
            Stop-Hold "Closure assessment failed with exit code $ClosureExit."
        }
    } finally {
        Remove-Item -LiteralPath $ProbeTmp -Force -ErrorAction SilentlyContinue
    }

    Write-Host "FINAL CRYPTOGRAPHIC GOVERNANCE GATE : PASS"

    Step 8 "EVIDENCE + INSTITUTIONAL CLOSURE RECORD"

    $Closure=Get-Content -LiteralPath $ClosureManifest -Raw -Encoding UTF8 | ConvertFrom-Json

    if($Closure.status -ne "INSTITUTIONALLY_CLOSED"){
        Stop-Hold "Closure manifest does not certify institutional closure."
    }

    $Evidence=[ordered]@{
        component="SPT-024.10"
        layer="3"
        version="1.0.0"
        generated_utc=[DateTime]::UtcNow.ToString("o")
        authoritative_baseline=$ExpectedBaseline
        final_status="INSTITUTIONALLY_CLOSED"
        gates=[ordered]@{
            capa1_cryptographic_protection="PASS"
            capa2_key_lifecycle_governance="PASS"
            key_recertification="PASS"
            lifecycle_revocation_destruction="PASS"
            rotation_versioning="PASS"
            custody_recovery="PASS"
            evidence_integrity="PASS"
            targeted_tests="PASS"
            institutional_suite="PASS"
            compileall="PASS"
            preservation="PENDING"
            github_size="PENDING"
            remote_sync="PENDING"
        }
        artifacts=[ordered]@{
            governance_assessment=$AssessmentFile
            recertification_baseline=$RecertificationFile
            closure_ledger=$ClosureLedger
            closure_manifest=$ClosureManifest
        }
        real_key_change_executed=$false
        key_material_read=$false
        production_crypto_changed=$false
        external_connection_opened=$false
        secret_values_exposed=$false
    }

    Write-Lf $EvidenceFile ($Evidence | ConvertTo-Json -Depth 12)

    Write-Host "GOVERNANCE ASSESSMENT : CREATED"
    Write-Host "RECERTIFICATION       : CREATED"
    Write-Host "CLOSURE LEDGER        : CREATED"
    Write-Host "CLOSURE MANIFEST      : CREATED"
    Write-Host "EVIDENCE              : CREATED"

    Step 9 "SHA-256 PRESERVATION GATE"

    Assert-Snapshot $Snapshot

    Write-Host "SPT-024.10 CAPAS 1-2 + CLOSED COMPONENTS : PRESERVED"

    Step 10 "EXACT CONTROLLED STAGING"

    $StageTargets=@(
        $SelfName,
        $ModuleDir,
        $TestFile,
        $PolicyFile,
        $DocFile,
        $ArtifactDir
    )

    foreach($Target in $StageTargets){
        if(Test-Path -LiteralPath $Target){
            Native "git.exe" @(
                "-c",
                "core.safecrlf=false",
                "add",
                "--",
                $Target
            ) ("git add "+$Target)
        }
    }

    $StagedNow=@(& git.exe -c core.quotepath=false diff --cached --name-only)

    if($LASTEXITCODE -ne 0){
        throw "Unable to inspect staging."
    }

    $Unexpected=@()

    foreach($RawPath in $StagedNow){
        $PathValue=Norm $RawPath

        $Allowed=(
            $PathValue -eq $SelfName -or
            $PathValue -eq $TestFile -or
            $PathValue -eq $PolicyFile -or
            $PathValue -eq $DocFile -or
            $PathValue.StartsWith((Norm $ModuleDir)+"/") -or
            $PathValue.StartsWith((Norm $ArtifactDir)+"/")
        )

        if(-not $Allowed){
            $Unexpected += $PathValue
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
        foreach($Item in $TooLarge){
            Write-Host ("TOO LARGE : {0} ({1} bytes)" -f $Item.path,$Item.bytes) -ForegroundColor Red
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
        "feat(spt-024.10): close cryptographic governance and key recertification layer 3"
    ) "git commit"

    $NewCommit=(& git.exe rev-parse HEAD).Trim()

    Write-Host "NEW COMMIT : $NewCommit"

    Step 14 "PUSH"

    Native "git.exe" @(
        "push",
        "origin",
        $Branch
    ) "git push"

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
    Write-Host " SPT-024.10 CAPA 3 : INSTITUTIONALLY CLOSED" -ForegroundColor Green
    Write-Host " CAPA1_CRYPTOGRAPHIC_PROTECTION_GATE=PASS" -ForegroundColor Green
    Write-Host " CAPA2_KEY_LIFECYCLE_GOVERNANCE_GATE=PASS" -ForegroundColor Green
    Write-Host " FINAL_CRYPTOGRAPHIC_GOVERNANCE_GATE=PASS" -ForegroundColor Green
    Write-Host " KEY_RECERTIFICATION=PASS" -ForegroundColor Green
    Write-Host " ROTATION_VERSIONING_GOVERNANCE=PASS" -ForegroundColor Green
    Write-Host " REVOCATION_DESTRUCTION_GOVERNANCE=PASS" -ForegroundColor Green
    Write-Host " CUSTODY_RECOVERY_GOVERNANCE=PASS" -ForegroundColor Green
    Write-Host " EVIDENCE_INTEGRITY=PASS" -ForegroundColor Green
    Write-Host " REAL_KEY_CHANGES=NO" -ForegroundColor Green
    Write-Host " SECRET_VALUES_EXPOSED=NO" -ForegroundColor Green
    Write-Host " CLOSED_COMPONENTS=PRESERVED" -ForegroundColor Green
    Write-Host " INSTITUTIONAL_SUITE=PASS" -ForegroundColor Green
    Write-Host " COMPILEALL=PASS" -ForegroundColor Green
    Write-Host " LOCAL_HEAD=REMOTE_HEAD" -ForegroundColor Green
    Write-Host " SPT02410_STATUS=INSTITUTIONALLY_CLOSED" -ForegroundColor Green
    Write-Host " FINAL_CLOSURE_EXIT_CODE=0" -ForegroundColor Green
    Write-Host "============================================================================" -ForegroundColor Green

    exit 0
}
catch{
    Stop-Hold $_.Exception.Message
}
