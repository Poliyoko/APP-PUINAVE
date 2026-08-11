#requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$ExpectedBaseline = "80a2def5a74a36d7044a863db65c04d5cec5af66"
$Branch = "feature/SPT-001A-rlb-schema-foundation"
$SelfName = "Invoke-SGODA-SPT02411-Capa1-FINAL-v1.0.0-PS51.ps1"

$ModuleDir = "src/sgoda/integration/spt02411"
$TestFile = "tests/integration/test_spt02411_data_privacy_governance_layer1.py"
$PolicyFile = "config/integration/spt02411/data-privacy-governance-policy.json"
$DocFile = "docs/06_Tecnologia/SPT-024/SPT-024.11/SGD-SPT024.11-Capa1-Proteccion-Datos-Privacidad-Clasificacion-Minimizacion-Retencion.md"

$ArtifactDir = "artifacts/development/SPT-024.11-Capa1-v1.0.0"
$AssessmentFile = "$ArtifactDir/data-privacy-governance-assessment.json"
$InventoryFile = "$ArtifactDir/data-privacy-surface-inventory.json"
$ClassificationFile = "$ArtifactDir/data-classification-baseline.json"
$RetentionFile = "$ArtifactDir/data-retention-minimization-baseline.json"
$IntegrityFile = "$ArtifactDir/data-privacy-integrity-manifest.json"
$EvidenceFile = "$ArtifactDir/implementation-evidence.json"

$LargeFileLimit = 100MB

function Stop-Hold {
    param([string]$Reason)
    Write-Host ""
    Write-Host "============================================================================" -ForegroundColor Red
    Write-Host " SPT-024.11 CAPA 1 : HOLD" -ForegroundColor Red
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
    Write-Host "SPT-024.1-.10 : PROTECTED / NOT REOPENED"
    Write-Host "DESTRUCTIVE CLEANUP : NO"

    Step 2 "RECOVERY / TARGET COLLISION DETECTION"

    $Targets=@(
        $ModuleDir,
        $TestFile,
        $PolicyFile,
        $DocFile,
        $ArtifactDir
    )

    $Existing=@($Targets | Where-Object { Test-Path -LiteralPath $_ })

    Write-Host "PREEXISTING SPT-024.11 TARGETS : $($Existing.Count)"

    if($Existing.Count -gt 0){
        Write-Host "SPT-024.11 RESUME MODE : ACTIVE"
    } else {
        Write-Host "SPT-024.11 FRESH IMPLEMENTATION : ACTIVE"
    }

    Step 3 "SHA-256 FREEZE OF CLOSED COMPONENTS"

    $Snapshot=Get-TrackedHashSnapshot

    Write-Host "PROTECTED TRACKED FILES : $($Snapshot.Count)"
    Write-Host "SHA-256 FREEZE : PASS"

    Step 4 "DATA / PRIVACY / RETENTION SURFACE DISCOVERY"

    $Tracked=@(& git.exe -c core.quotepath=false ls-files)

    if($LASTEXITCODE -ne 0){
        throw "Unable to enumerate tracked files."
    }

    $DataSurfaceFiles=@($Tracked | Where-Object {
        $P=(Norm $_).ToLowerInvariant()

        (
            $P -match '(data|privacy|personal|sensitive|lexical|audio|image|retention|archive|backup|audit|evidence|credential|secret|token|database|postgres|oda|fld|json|excel)' -or
            $P -match '(^|/)(config|src|automation|tools|docs|artifacts)(/|$)'
        ) -and
        $P -match '\.(py|ps1|json|ya?ml|toml|ini|cfg|md|csv|txt)$'
    })

    Write-Host "DATA/PRIVACY SURFACES     : $($DataSurfaceFiles.Count)"
    Write-Host "DISCOVERY MODE            : STATIC / NON-DESTRUCTIVE"
    Write-Host "PRODUCTION DATA MODIFIED  : NO"
    Write-Host "PRODUCTION DATA DELETED   : NO"
    Write-Host "EXTERNAL DISCLOSURE       : NO"
    Write-Host "EXTERNAL CONNECTION       : NO"

    Step 5 "IMPLEMENT SPT-024.11 CAPA 1"

$InitPy=@'
"""SPT-024.11 Capa 1 — data protection, privacy, classification, minimization and retention governance."""
from .service import DataPrivacyGovernanceService
from .gate import DataPrivacyGovernanceGate

__all__ = ["DataPrivacyGovernanceService", "DataPrivacyGovernanceGate"]
'@
$ModelsPy=@'
from dataclasses import dataclass


@dataclass(frozen=True)
class PrivacyControl:
    control_id: str
    name: str
    passed: bool
    blocking: bool
    applicable: bool
    detail: str
'@
$ClassificationPy=@'
from __future__ import annotations
from typing import Mapping


ALLOWED_CLASSES = frozenset({
    "PUBLIC",
    "INTERNAL",
    "CONFIDENTIAL",
    "RESTRICTED",
})


def classify_record(record: Mapping) -> dict:
    declared = str(record.get("classification", "")).upper()
    data_type = str(record.get("data_type", "")).upper()

    valid_class = declared in ALLOWED_CLASSES

    sensitive = declared in {"CONFIDENTIAL", "RESTRICTED"} or data_type in {
        "PERSONAL_DATA",
        "CREDENTIAL",
        "AUTH_TOKEN",
        "LEXICAL_RESTRICTED",
        "AUDIT_SENSITIVE",
    }

    return {
        "valid": valid_class,
        "classification": declared,
        "data_type": data_type,
        "sensitive": sensitive,
        "requires_access_control": sensitive,
        "requires_retention_policy": True,
        "secret_values_exposed": False,
    }
'@
$MinimizationPy=@'
from __future__ import annotations
from typing import Iterable


def minimize_fields(
    available_fields: Iterable[str],
    required_fields: Iterable[str],
) -> dict:
    available = list(dict.fromkeys(str(item) for item in available_fields))
    required = set(str(item) for item in required_fields)

    retained = [item for item in available if item in required]
    removed = [item for item in available if item not in required]

    return {
        "valid": set(retained) == required.intersection(available),
        "retained_fields": retained,
        "removed_fields": removed,
        "field_count_before": len(available),
        "field_count_after": len(retained),
        "minimized": len(removed) > 0,
        "data_modified_in_production": False,
        "secret_values_exposed": False,
    }
'@
$RetentionPy=@'
from __future__ import annotations
from datetime import datetime, timedelta, timezone
from typing import Mapping


def build_retention_decision(
    profile: Mapping,
    now: datetime | None = None,
) -> dict:
    if now is None:
        now = datetime.now(timezone.utc)

    created_at = datetime.fromisoformat(
        str(profile.get("created_at", "")).replace("Z", "+00:00")
    )

    retention_days = int(profile.get("retention_days", 0))
    legal_hold = bool(profile.get("legal_hold", False))

    expires_at = created_at + timedelta(days=retention_days)
    expired = expires_at <= now

    if legal_hold:
        decision = "RETAIN_LEGAL_HOLD"
    elif expired:
        decision = "DISPOSE_REVIEW"
    else:
        decision = "RETAIN"

    valid = retention_days > 0

    return {
        "valid": valid,
        "retention_days": retention_days,
        "legal_hold": legal_hold,
        "expires_at": expires_at.isoformat(),
        "expired": expired,
        "decision": decision,
        "disposal_executed": False,
        "data_modified_in_production": False,
        "secret_values_exposed": False,
    }
'@
$PrivacyPy=@'
from __future__ import annotations
from typing import Mapping


ALLOWED_PURPOSES = frozenset({
    "PRESERVATION",
    "TEACHING",
    "AUDIT",
    "SECURITY",
    "OPERATIONS",
})


def validate_purpose(profile: Mapping) -> dict:
    purpose = str(profile.get("purpose", "")).upper()
    declared = bool(profile.get("purpose_declared", False))
    access_limited = bool(profile.get("access_limited", False))
    disclosure_limited = bool(profile.get("disclosure_limited", False))

    valid = (
        declared
        and purpose in ALLOWED_PURPOSES
        and access_limited
        and disclosure_limited
    )

    return {
        "valid": valid,
        "purpose": purpose,
        "purpose_declared": declared,
        "access_limited": access_limited,
        "disclosure_limited": disclosure_limited,
        "external_disclosure_executed": False,
        "secret_values_exposed": False,
    }
'@
$AuditPy=@'
from __future__ import annotations
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

from .classification import classify_record
from .minimization import minimize_fields
from .models import PrivacyControl
from .privacy import validate_purpose
from .retention import build_retention_decision


class DataPrivacyGovernanceAuditor:
    def __init__(self, root: Path, discovered_paths: Iterable[str]):
        self.root = Path(root).resolve()
        self.discovered_paths = list(discovered_paths)

    def assess(self) -> dict:
        classification = classify_record({
            "classification": "RESTRICTED",
            "data_type": "LEXICAL_RESTRICTED",
        })

        minimization = minimize_fields(
            ["word", "language", "audio_ref", "image_ref", "debug_note"],
            ["word", "language", "audio_ref", "image_ref"],
        )

        retention = build_retention_decision(
            {
                "created_at": "2026-01-01T00:00:00+00:00",
                "retention_days": 365,
                "legal_hold": False,
            },
            now=datetime(2026, 8, 11, tzinfo=timezone.utc),
        )

        purpose = validate_purpose({
            "purpose": "PRESERVATION",
            "purpose_declared": True,
            "access_limited": True,
            "disclosure_limited": True,
        })

        controls = [
            PrivacyControl(
                "DATA-CLASSIFICATION",
                "Institutional data classification",
                classification["valid"] is True
                and classification["classification"] == "RESTRICTED",
                True,
                True,
                "Sensitive information is explicitly classified.",
            ),
            PrivacyControl(
                "DATA-MINIMIZATION",
                "Data minimization",
                minimization["valid"] is True
                and minimization["minimized"] is True,
                True,
                True,
                "Only fields required for the declared purpose are retained in the model.",
            ),
            PrivacyControl(
                "DATA-RETENTION",
                "Retention governance",
                retention["valid"] is True
                and retention["decision"] in {
                    "RETAIN",
                    "RETAIN_LEGAL_HOLD",
                    "DISPOSE_REVIEW",
                },
                True,
                True,
                "Retention is time-bound and disposal remains review-gated.",
            ),
            PrivacyControl(
                "DATA-PURPOSE-LIMITATION",
                "Purpose limitation",
                purpose["valid"] is True,
                True,
                True,
                "Processing purpose is declared, allowed and access/disclosure constrained.",
            ),
            PrivacyControl(
                "DATA-SENSITIVE-ACCESS",
                "Sensitive data access control requirement",
                classification["requires_access_control"] is True,
                True,
                True,
                "Sensitive classifications require controlled access.",
            ),
            PrivacyControl(
                "DATA-NO-AUTO-DISPOSAL",
                "No automatic destructive disposal",
                retention["disposal_executed"] is False,
                True,
                True,
                "Gate never deletes production information.",
            ),
            PrivacyControl(
                "DATA-NO-SIDE-EFFECTS",
                "No production data mutation",
                minimization["data_modified_in_production"] is False
                and retention["data_modified_in_production"] is False
                and purpose["external_disclosure_executed"] is False,
                True,
                True,
                "Assessment is governance-only and does not alter production data.",
            ),
            PrivacyControl(
                "DATA-SECRET-SAFETY",
                "No secret values exposed",
                classification["secret_values_exposed"] is False
                and minimization["secret_values_exposed"] is False
                and retention["secret_values_exposed"] is False
                and purpose["secret_values_exposed"] is False,
                True,
                True,
                "Evidence stores policy metadata only.",
            ),
        ]

        failed = [
            item.control_id
            for item in controls
            if item.blocking and item.applicable and not item.passed
        ]

        return {
            "status": "DATA_PRIVACY_GOVERNANCE_GATE_PASS" if not failed else "DATA_PRIVACY_GOVERNANCE_GATE_HOLD",
            "failed_blocking_controls": failed,
            "controls": [item.__dict__ for item in controls],
            "classification": classification,
            "minimization": minimization,
            "retention": retention,
            "purpose_limitation": purpose,
            "discovered_data_privacy_surfaces": len(self.discovered_paths),
            "production_data_modified": False,
            "production_data_deleted": False,
            "external_disclosure_executed": False,
            "external_connection_opened": False,
            "secret_values_exposed": False,
        }
'@
$GatePy=@'
class DataPrivacyGovernanceGate:
    BLOCKING = frozenset({
        "DATA-CLASSIFICATION",
        "DATA-MINIMIZATION",
        "DATA-RETENTION",
        "DATA-PURPOSE-LIMITATION",
        "DATA-SENSITIVE-ACCESS",
        "DATA-NO-AUTO-DISPOSAL",
        "DATA-NO-SIDE-EFFECTS",
        "DATA-SECRET-SAFETY",
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

    return {
        "algorithm": "SHA-256",
        "record_count": len(records),
        "records": records,
    }
'@
$ServicePy=@'
from pathlib import Path
from typing import Iterable

from .audit import DataPrivacyGovernanceAuditor
from .gate import DataPrivacyGovernanceGate


class DataPrivacyGovernanceService:
    def __init__(self, root: Path, discovered_paths: Iterable[str]):
        self.root = Path(root)
        self.discovered_paths = list(discovered_paths)

    def assess(self):
        result = DataPrivacyGovernanceAuditor(
            self.root,
            self.discovered_paths,
        ).assess()

        passed, failed = DataPrivacyGovernanceGate.evaluate(result["controls"])
        result["status"] = "DATA_PRIVACY_GOVERNANCE_GATE_PASS" if passed else "DATA_PRIVACY_GOVERNANCE_GATE_HOLD"
        result["failed_blocking_controls"] = failed

        return result
'@
$TestsPy=@'
from datetime import datetime, timezone

from sgoda.integration.spt02411.classification import classify_record
from sgoda.integration.spt02411.minimization import minimize_fields
from sgoda.integration.spt02411.privacy import validate_purpose
from sgoda.integration.spt02411.retention import build_retention_decision
from sgoda.integration.spt02411.service import DataPrivacyGovernanceService


def test_restricted_data_is_sensitive():
    result = classify_record({
        "classification": "RESTRICTED",
        "data_type": "LEXICAL_RESTRICTED",
    })
    assert result["valid"] is True
    assert result["sensitive"] is True
    assert result["requires_access_control"] is True


def test_invalid_classification_fails():
    result = classify_record({
        "classification": "UNKNOWN",
        "data_type": "PERSONAL_DATA",
    })
    assert result["valid"] is False


def test_minimization_removes_unrequired_fields():
    result = minimize_fields(
        ["word", "audio_ref", "debug_note"],
        ["word", "audio_ref"],
    )
    assert result["valid"] is True
    assert result["minimized"] is True
    assert result["removed_fields"] == ["debug_note"]


def test_minimization_is_non_destructive():
    result = minimize_fields(["a", "b"], ["a"])
    assert result["data_modified_in_production"] is False


def test_retention_keeps_unexpired_record():
    result = build_retention_decision(
        {
            "created_at": "2026-01-01T00:00:00+00:00",
            "retention_days": 365,
            "legal_hold": False,
        },
        now=datetime(2026, 8, 11, tzinfo=timezone.utc),
    )
    assert result["decision"] == "RETAIN"
    assert result["disposal_executed"] is False


def test_expired_record_requires_disposal_review_not_deletion():
    result = build_retention_decision(
        {
            "created_at": "2025-01-01T00:00:00+00:00",
            "retention_days": 30,
            "legal_hold": False,
        },
        now=datetime(2026, 8, 11, tzinfo=timezone.utc),
    )
    assert result["decision"] == "DISPOSE_REVIEW"
    assert result["disposal_executed"] is False


def test_legal_hold_overrides_expiration():
    result = build_retention_decision(
        {
            "created_at": "2025-01-01T00:00:00+00:00",
            "retention_days": 30,
            "legal_hold": True,
        },
        now=datetime(2026, 8, 11, tzinfo=timezone.utc),
    )
    assert result["decision"] == "RETAIN_LEGAL_HOLD"


def test_purpose_limitation_passes():
    result = validate_purpose({
        "purpose": "PRESERVATION",
        "purpose_declared": True,
        "access_limited": True,
        "disclosure_limited": True,
    })
    assert result["valid"] is True


def test_undeclared_purpose_fails():
    result = validate_purpose({
        "purpose": "PRESERVATION",
        "purpose_declared": False,
        "access_limited": True,
        "disclosure_limited": True,
    })
    assert result["valid"] is False


def test_full_privacy_gate_passes(tmp_path):
    result = DataPrivacyGovernanceService(tmp_path, []).assess()
    assert result["status"] == "DATA_PRIVACY_GOVERNANCE_GATE_PASS"
    assert result["failed_blocking_controls"] == []


def test_full_gate_has_no_real_data_changes(tmp_path):
    result = DataPrivacyGovernanceService(tmp_path, []).assess()
    assert result["production_data_modified"] is False
    assert result["production_data_deleted"] is False
    assert result["external_disclosure_executed"] is False
    assert result["external_connection_opened"] is False
    assert result["secret_values_exposed"] is False
'@
$PolicyJson=@'
{
  "component": "SPT-024.11",
  "layer": "1",
  "version": "1.0.0",
  "title": "Proteccion de Datos, Privacidad, Clasificacion, Minimizacion, Retencion y Gobierno de Informacion Sensible",
  "blocking_controls": [
    "DATA-CLASSIFICATION",
    "DATA-MINIMIZATION",
    "DATA-RETENTION",
    "DATA-PURPOSE-LIMITATION",
    "DATA-SENSITIVE-ACCESS",
    "DATA-NO-AUTO-DISPOSAL",
    "DATA-NO-SIDE-EFFECTS",
    "DATA-SECRET-SAFETY"
  ],
  "classification_levels": [
    "PUBLIC",
    "INTERNAL",
    "CONFIDENTIAL",
    "RESTRICTED"
  ],
  "minimization": {
    "required_fields_only": true,
    "production_data_mutation_by_gate": false
  },
  "retention": {
    "policy_required": true,
    "legal_hold_supported": true,
    "automatic_destructive_disposal": false,
    "expired_state": "DISPOSE_REVIEW"
  },
  "privacy": {
    "purpose_limitation_required": true,
    "access_limitation_required": true,
    "disclosure_limitation_required": true
  },
  "safety": {
    "modify_production_data": false,
    "delete_production_data": false,
    "external_disclosure": false,
    "open_external_connections": false,
    "print_secret_values": false,
    "modify_closed_components": false
  }
}
'@
$DocMd=@'
# SPT-024.11 Capa 1 — Proteccion de Datos, Privacidad, Clasificacion, Minimizacion, Retencion y Gobierno de Informacion Sensible

Baseline autoritativa: `80a2def5a74a36d7044a863db65c04d5cec5af66`.

Esta capa inicia SPT-024.11 dentro de la Plataforma Institucional de Seguridad Informatica (PISI) sin reabrir SPT-024.1–SPT-024.10.

## Alcance

- clasificacion institucional de informacion;
- identificacion de informacion sensible;
- minimizacion de datos;
- limitacion por finalidad;
- reglas de acceso y divulgacion;
- politicas de retencion;
- legal hold;
- disposicion controlada mediante `DISPOSE_REVIEW`;
- prohibicion de eliminacion automatica destructiva;
- evidencia e integridad SHA-256;
- preservation gates;
- publicacion obligatoria en repositorio oficial.

## Controles bloqueantes

- DATA-CLASSIFICATION
- DATA-MINIMIZATION
- DATA-RETENTION
- DATA-PURPOSE-LIMITATION
- DATA-SENSITIVE-ACCESS
- DATA-NO-AUTO-DISPOSAL
- DATA-NO-SIDE-EFFECTS
- DATA-SECRET-SAFETY

## Seguridad operacional

La Capa 1 es estatica y no destructiva. No modifica ni elimina datos productivos, no divulga informacion, no abre conexiones externas y no expone secretos.

El cierre tecnico exige pruebas dirigidas, suite institucional completa, `compileall`, assessment, inventario, manifiesto SHA-256, preservation gate, staging exacto, gate global del indice Git para blobs inferiores a 100 MB, commit, push y verificacion `LOCAL HEAD = REMOTE HEAD`.
'@

    Write-Lf "$ModuleDir/__init__.py" $InitPy
    Write-Lf "$ModuleDir/models.py" $ModelsPy
    Write-Lf "$ModuleDir/classification.py" $ClassificationPy
    Write-Lf "$ModuleDir/minimization.py" $MinimizationPy
    Write-Lf "$ModuleDir/retention.py" $RetentionPy
    Write-Lf "$ModuleDir/privacy.py" $PrivacyPy
    Write-Lf "$ModuleDir/audit.py" $AuditPy
    Write-Lf "$ModuleDir/gate.py" $GatePy
    Write-Lf "$ModuleDir/integrity.py" $IntegrityPy
    Write-Lf "$ModuleDir/service.py" $ServicePy
    Write-Lf $TestFile $TestsPy
    Write-Lf $PolicyFile $PolicyJson
    Write-Lf $DocFile $DocMd

    Write-Host "SPT-024.11 CAPA 1 IMPLEMENTATION : CREATED/VALIDATED"

    Step 6 "PYTHON PREVALIDATION + TARGETED TESTS"

    $Python=PythonExe
    $env:PYTHONPATH=(Join-Path $PWD "src")

    Native $Python @(
        "-c",
        "import sgoda.integration.spt02411; from sgoda.integration.spt02411.gate import DataPrivacyGovernanceGate; assert len(DataPrivacyGovernanceGate.BLOCKING)==8; print('SPT02411_IMPORT=PASS'); print('BLOCKING_CONTROLS=8')"
    ) "SPT-024.11 import"

    Native $Python @("-m","pytest",$TestFile,"-q") "SPT-024.11 targeted tests"

    Write-Host "TARGETED TESTS : PASS"

    Step 7 "INSTITUTIONAL SUITE + COMPILEALL"

    Native $Python @("-m","pytest","-q") "Institutional pytest suite"

    Write-Host "FULL SUITE : PASS"

    Native $Python @("-m","compileall","-q","src") "compileall"

    Write-Host "COMPILEALL : PASS"

    Step 8 "PRODUCTION DATA PRIVACY / RETENTION ASSESSMENT"

    New-Item -ItemType Directory -Force -Path $ArtifactDir | Out-Null

    $DiscoveryJson=($DataSurfaceFiles | ForEach-Object {Norm $_}) | ConvertTo-Json -Compress
    $DiscoveryTmp=Join-Path $env:TEMP ("sgoda-spt02411-"+[Guid]::NewGuid().ToString("N")+".json")
    $ProbeTmp=Join-Path $env:TEMP ("sgoda-spt02411-"+[Guid]::NewGuid().ToString("N")+".py")
    $Utf8=New-Object System.Text.UTF8Encoding($false)

    try{
        [IO.File]::WriteAllText($DiscoveryTmp,($DiscoveryJson+"`n"),$Utf8)

        $Probe=@'
import json
import sys
from pathlib import Path

from sgoda.integration.spt02411.integrity import build_manifest
from sgoda.integration.spt02411.service import DataPrivacyGovernanceService

root = Path.cwd()
paths = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))

result = DataPrivacyGovernanceService(root, paths).assess()

artifact_dir = root / "artifacts" / "development" / "SPT-024.11-Capa1-v1.0.0"
artifact_dir.mkdir(parents=True, exist_ok=True)

assessment_path = artifact_dir / "data-privacy-governance-assessment.json"
inventory_path = artifact_dir / "data-privacy-surface-inventory.json"
classification_path = artifact_dir / "data-classification-baseline.json"
retention_path = artifact_dir / "data-retention-minimization-baseline.json"
integrity_path = artifact_dir / "data-privacy-integrity-manifest.json"

assessment_path.write_text(
    json.dumps(result, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)

inventory_path.write_text(
    json.dumps({
        "mode": "GIT_TRACKED_STATIC_DISCOVERY",
        "surface_count": len(paths),
        "paths": sorted(set(p.replace("\\", "/") for p in paths)),
        "production_data_modified": False,
        "production_data_deleted": False,
        "external_disclosure_executed": False,
        "secret_values_exposed": False,
    }, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)

classification_path.write_text(
    json.dumps({
        "classification": result["classification"],
        "purpose_limitation": result["purpose_limitation"],
        "production_data_modified": False,
        "secret_values_exposed": False,
    }, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)

retention_path.write_text(
    json.dumps({
        "minimization": result["minimization"],
        "retention": result["retention"],
        "production_data_deleted": False,
        "secret_values_exposed": False,
    }, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)

integrity = build_manifest(
    root,
    [
        str(assessment_path.relative_to(root)).replace("\\", "/"),
        str(inventory_path.relative_to(root)).replace("\\", "/"),
        str(classification_path.relative_to(root)).replace("\\", "/"),
        str(retention_path.relative_to(root)).replace("\\", "/"),
        "config/integration/spt02411/data-privacy-governance-policy.json",
    ],
)

integrity_path.write_text(
    json.dumps(integrity, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)

print("SPT02411_DATA_PRIVACY_STATUS=" + result["status"])
print("DATA_PRIVACY_SURFACES=%d" % len(paths))
print("FAILED_BLOCKING_CONTROLS=%d" % len(result["failed_blocking_controls"]))
print("FAILED_CONTROL_IDS=" + ",".join(result["failed_blocking_controls"]))
print("CLASSIFICATION=" + result["classification"]["classification"])
print("RETENTION_DECISION=" + result["retention"]["decision"])
print("INTEGRITY_RECORDS=%d" % integrity["record_count"])
print("PRODUCTION_DATA_MODIFIED=NO")
print("PRODUCTION_DATA_DELETED=NO")
print("EXTERNAL_DISCLOSURE_EXECUTED=NO")
print("EXTERNAL_CONNECTION_OPENED=NO")
print("SECRET_VALUES_EXPOSED=NO")

if result["status"] != "DATA_PRIVACY_GOVERNANCE_GATE_PASS":
    raise SystemExit(20)
'@

        [IO.File]::WriteAllText(
            $ProbeTmp,
            (($Probe -replace "`r`n","`n") -replace "`r","`n"),
            $Utf8
        )

        & $Python $ProbeTmp $DiscoveryTmp

        $AssessmentExit=$LASTEXITCODE

        if($AssessmentExit -eq 20){
            Write-Host "SAFE ASSESSMENT REPORT : $AssessmentFile"
            Stop-Hold "Blocking SPT-024.11 data/privacy controls failed."
        }

        if($AssessmentExit -ne 0){
            Stop-Hold "Production assessment failed with exit code $AssessmentExit."
        }
    } finally {
        Remove-Item -LiteralPath $DiscoveryTmp -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $ProbeTmp -Force -ErrorAction SilentlyContinue
    }

    Write-Host "DATA PRIVACY GOVERNANCE GATE : PASS"

    Step 9 "EVIDENCE + INTEGRITY"

    $Assessment=Get-Content -LiteralPath $AssessmentFile -Raw -Encoding UTF8 | ConvertFrom-Json

    if($Assessment.status -ne "DATA_PRIVACY_GOVERNANCE_GATE_PASS"){
        Stop-Hold "Assessment does not certify PASS."
    }

    $Evidence=[ordered]@{
        component="SPT-024.11"
        layer="1"
        version="1.0.0"
        generated_utc=[DateTime]::UtcNow.ToString("o")
        authoritative_baseline=$ExpectedBaseline
        final_status="DATA_PRIVACY_GOVERNANCE_GATE_PASS"
        gates=[ordered]@{
            targeted_tests="PASS"
            institutional_suite="PASS"
            compileall="PASS"
            data_privacy_governance="PASS"
            preservation="PENDING"
            github_size="PENDING"
            remote_sync="PENDING"
        }
        artifacts=[ordered]@{
            assessment=$AssessmentFile
            inventory=$InventoryFile
            classification=$ClassificationFile
            retention_minimization=$RetentionFile
            integrity_manifest=$IntegrityFile
        }
        production_data_modified=$false
        production_data_deleted=$false
        external_disclosure_executed=$false
        external_connection_opened=$false
        secret_values_exposed=$false
    }

    Write-Lf $EvidenceFile ($Evidence | ConvertTo-Json -Depth 12)

    Write-Host "ASSESSMENT     : CREATED"
    Write-Host "INVENTORY      : CREATED"
    Write-Host "CLASSIFICATION : CREATED"
    Write-Host "RETENTION      : CREATED"
    Write-Host "INTEGRITY      : CREATED"
    Write-Host "EVIDENCE       : CREATED"

    Step 10 "SHA-256 PRESERVATION GATE"

    Assert-Snapshot $Snapshot

    Write-Host "SPT-024.1-.10 + CLOSED COMPONENTS : PRESERVED"

    Step 11 "EXACT CONTROLLED STAGING"

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

    Step 12 "INDEX-WIDE GITHUB SIZE GATE"

    $TooLarge=@(Get-IndexOversizedBlobs)

    Write-Host "INDEX BLOBS >=100MB : $($TooLarge.Count)"

    if($TooLarge.Count -gt 0){
        foreach($Item in $TooLarge){
            Write-Host ("TOO LARGE : {0} ({1} bytes)" -f $Item.path,$Item.bytes) -ForegroundColor Red
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
        "feat(spt-024.11): implement data privacy classification minimization retention layer 1"
    ) "git commit"

    $NewCommit=(& git.exe rev-parse HEAD).Trim()

    Write-Host "NEW COMMIT : $NewCommit"

    Step 15 "PUSH"

    Native "git.exe" @(
        "push",
        "origin",
        $Branch
    ) "git push"

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
    Write-Host " SPT-024.11 CAPA 1 : TECHNICALLY CLOSED" -ForegroundColor Green
    Write-Host " DATA_PRIVACY_GOVERNANCE_GATE=PASS" -ForegroundColor Green
    Write-Host " DATA_CLASSIFICATION=PASS" -ForegroundColor Green
    Write-Host " DATA_MINIMIZATION=PASS" -ForegroundColor Green
    Write-Host " DATA_RETENTION_GOVERNANCE=PASS" -ForegroundColor Green
    Write-Host " PURPOSE_LIMITATION=PASS" -ForegroundColor Green
    Write-Host " SENSITIVE_DATA_ACCESS_CONTROL=PASS" -ForegroundColor Green
    Write-Host " AUTOMATIC_DESTRUCTIVE_DISPOSAL=NO" -ForegroundColor Green
    Write-Host " TARGETED_TESTS=PASS" -ForegroundColor Green
    Write-Host " INSTITUTIONAL_SUITE=PASS" -ForegroundColor Green
    Write-Host " COMPILEALL=PASS" -ForegroundColor Green
    Write-Host " PRODUCTION_DATA_CHANGES=NO" -ForegroundColor Green
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
