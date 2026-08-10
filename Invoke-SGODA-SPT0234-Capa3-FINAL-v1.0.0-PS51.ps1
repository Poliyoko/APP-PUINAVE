param(
    [string]$ProjectRoot = "",
    [string]$ExpectedBaseline = "c9ee7996d0b979887ad788c4181c17b01f387374"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$CommitMessage = "feat(spt-023.4): close multimedia governance layer 3"
$ExpectedTargetedTests = 18
$ExpectedFullSuiteMinimum = 952
$CommitCreated = $false
$CreatedFiles = New-Object System.Collections.ArrayList
$MasterBookOriginal = $null
$MasterBookTouched = $false
$MasterBookPath = $null

function Invoke-Git {
    param([string[]]$Arguments)
    $Previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $Output = @(& git @Arguments 2>&1)
        $Code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $Previous
    }
    if ($Code -ne 0) {
        throw ("git " + ($Arguments -join " ") + " failed with exit code " + $Code + ": " + ($Output -join " "))
    }
    return @($Output | ForEach-Object { [string]$_ })
}

function Git-One {
    param([string[]]$Arguments)
    $Result = @(Invoke-Git -Arguments $Arguments)
    if ($Result.Count -eq 0) {
        throw ("git " + ($Arguments -join " ") + " returned no output.")
    }
    return ([string]$Result[0]).Trim()
}

function Write-Utf8Lf {
    param([string]$Path,[string]$Content,[switch]$TrackCreated)
    $Parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }
    $Text = $Content.Replace("`r`n","`n").Replace("`r","`n").TrimEnd([char[]]@("`r","`n")) + "`n"
    [System.IO.File]::WriteAllText(
        $Path,
        $Text,
        (New-Object System.Text.UTF8Encoding($false))
    )
    if ($TrackCreated) { [void]$CreatedFiles.Add($Path) }
}

function Get-HashMap {
    param([string]$Root,[string[]]$Paths)
    $Map = @{}
    foreach ($Rel in $Paths) {
        $Full = Join-Path $Root $Rel
        if (Test-Path -LiteralPath $Full -PathType Leaf) {
            $Map[$Rel] = (Get-FileHash -LiteralPath $Full -Algorithm SHA256).Hash
        }
    }
    return $Map
}

function Compare-HashMaps {
    param($Before,$After)
    $Changed = @()
    foreach ($Key in @($Before.Keys + $After.Keys | Sort-Object -Unique)) {
        if (-not $Before.ContainsKey($Key) -or -not $After.ContainsKey($Key) -or $Before[$Key] -ne $After[$Key]) {
            $Changed += $Key
        }
    }
    return @($Changed)
}

function Test-PowerShellSyntax {
    param([string]$Path)
    $Tokens = $null
    $Errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $Path,[ref]$Tokens,[ref]$Errors
    )
    if ($Errors.Count -ne 0) {
        throw ("PowerShell syntax validation failed: " + (($Errors | ForEach-Object { $_.Message }) -join " | "))
    }
}

function Emit-FinalBanner {
    param([string]$Commit,[int]$Targeted,[int]$FullSuite)
    Write-Output ""
    Write-Output "======================================================================"
    Write-Output " SPT-023.4 CAPA 3 : INSTITUTIONALLY CLOSED"
    Write-Output " SPT-023.4        : INSTITUTIONALLY CLOSED"
    Write-Output " COMMIT           : $Commit"
    Write-Output " TARGETED TESTS   : $Targeted PASSED"
    Write-Output " FULL SUITE       : $FullSuite PASSED"
    Write-Output " CAPAS 1-2        : PRESERVED"
    Write-Output " SPT-023.1-.3     : PRESERVED"
    Write-Output " SGD-002          : UPDATED"
    Write-Output " LOCAL/REMOTE     : IDENTICAL"
    Write-Output " AHEAD            : 0"
    Write-Output " BEHIND           : 0"
    Write-Output " STAGING          : CLEAN"
    Write-Output " DELETED TRACKED  : 0"
    Write-Output " ERRORS PENDING   : 0"
    Write-Output " NEXT             : SPT-023.5 CONSTRUCTOR FLD/ODA"
    Write-Output "======================================================================"
    Write-Output "FINAL_CLOSURE_EXIT_CODE=0"
}

function Rollback-PreCommit {
    if ($CommitCreated) { return }

    $Previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try { & git reset -q HEAD -- 2>$null | Out-Null }
    finally { $ErrorActionPreference = $Previous }

    if ($MasterBookTouched -and $null -ne $MasterBookOriginal -and $null -ne $MasterBookPath) {
        [System.IO.File]::WriteAllText(
            $MasterBookPath,
            $MasterBookOriginal,
            (New-Object System.Text.UTF8Encoding($false))
        )
    }

    foreach ($Path in @($CreatedFiles) | Sort-Object Length -Descending) {
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
        }
    }
}

function Fail {
    param([string]$Message)
    Rollback-PreCommit
    Write-Output ""
    Write-Output "======================================================================"
    Write-Output " SPT-023.4 CAPA 3 : HOLD"
    Write-Output (" REASON           : " + $Message)
    if ($CommitCreated) {
        Write-Output " LOCAL COMMIT     : PRESERVED FOR SAME-FILE RESUME"
    }
    else {
        Write-Output " TRANSACTION      : ROLLED BACK BEFORE COMMIT"
    }
    Write-Output " ERRORS PENDING   : 1"
    Write-Output "======================================================================"
    exit 20
}

try {
    if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
        $ProjectRoot = Git-One @("rev-parse","--show-toplevel")
    }

    Set-Location $ProjectRoot
    $Root = Git-One @("rev-parse","--show-toplevel")
    $Branch = Git-One @("branch","--show-current")

    $ScriptName = [System.IO.Path]::GetFileName($MyInvocation.MyCommand.Path)
    if ([string]::IsNullOrWhiteSpace($ScriptName)) {
        throw "Unable to resolve current master script file name."
    }

    $ScriptCandidate = Join-Path $Root $ScriptName
    if (-not (Test-Path -LiteralPath $ScriptCandidate -PathType Leaf)) {
        throw "Master script file is not present in the official repository root."
    }

    Test-PowerShellSyntax -Path $ScriptCandidate
    $ScriptRel = $ScriptName.Replace("\","/")

    Write-Output ""
    Write-Output "======================================================================"
    Write-Output " SGODA-PUINAVE - SPT-023.4 CAPA 3 - FINAL MASTER TRANSACTION"
    Write-Output " QUALITY GOVERNANCE / COMPLETENESS / FLD-ODA HANDOFF / CLOSE SPT-023.4"
    Write-Output "======================================================================"

    Write-Host ""
    Write-Host "[1/12] AUTHORITATIVE BASELINE / RESUME CHECK" -ForegroundColor Yellow

    $Previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & git fetch origin $Branch --no-tags
        $FetchCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $Previous
    }
    if ($FetchCode -ne 0) { throw "Unable to fetch official remote." }

    $Local = Git-One @("rev-parse","HEAD")
    $Remote = Git-One @("rev-parse","origin/$Branch")

    if ($Local -ne $ExpectedBaseline) {
        $Subject = Git-One @("log","-1","--pretty=%s")
        $Parent = Git-One @("rev-parse","HEAD^")

        if ($Subject -eq $CommitMessage -and $Parent -eq $ExpectedBaseline) {
            $EvidenceResume = Join-Path $Root "artifacts\development\SPT-023.4-Capa3-v1.0.0\implementation-evidence.json"
            if (-not (Test-Path -LiteralPath $EvidenceResume -PathType Leaf)) {
                throw "Resumable Capa 3 commit detected but evidence file is missing."
            }
            $DataResume = Get-Content -LiteralPath $EvidenceResume -Raw -Encoding UTF8 | ConvertFrom-Json

            if ($Local -eq $Remote) {
                $FinalStaged = @(Invoke-Git @("diff","--cached","--name-only")).Count
                $FinalDeleted = @(Invoke-Git @("ls-files","--deleted")).Count
                if ($FinalStaged -ne 0 -or $FinalDeleted -ne 0) {
                    throw "Published Capa 3 commit exists but repository safety is not clean."
                }
                Emit-FinalBanner -Commit $Local -Targeted ([int]$DataResume.targeted_tests_passed) -FullSuite ([int]$DataResume.institutional_tests_passed)
                exit 0
            }

            if ($Remote -eq $ExpectedBaseline) {
                $CommitCreated = $true
                Write-Host "RESUME MODE : LOCAL COMMIT EXISTS; PUSH PENDING" -ForegroundColor Yellow
                & git push origin $Branch
                if ($LASTEXITCODE -ne 0) { throw "Resume push failed." }
                & git fetch origin $Branch --no-tags
                if ($LASTEXITCODE -ne 0) { throw "Resume verification fetch failed." }
                $RemoteResume = Git-One @("rev-parse","origin/$Branch")
                if ($RemoteResume -ne $Local) {
                    throw "Resume verification failed: local/remote mismatch."
                }
                Emit-FinalBanner -Commit $Local -Targeted ([int]$DataResume.targeted_tests_passed) -FullSuite ([int]$DataResume.institutional_tests_passed)
                exit 0
            }
        }

        throw "HEAD is neither certified baseline nor a resumable SPT-023.4 Capa 3 commit."
    }

    if ($Remote -ne $ExpectedBaseline) {
        throw "Official remote moved away from certified baseline."
    }

    $StagedBefore = @(Invoke-Git @("diff","--cached","--name-only"))
    $DeletedBefore = @(Invoke-Git @("ls-files","--deleted"))

    Write-Host "LOCAL HEAD      : $Local"
    Write-Host "REMOTE HEAD     : $Remote"
    Write-Host "STAGED          : $($StagedBefore.Count)"
    Write-Host "DELETED TRACKED : $($DeletedBefore.Count)"

    if ($StagedBefore.Count -ne 0) { throw "Staging is not clean." }
    if ($DeletedBefore.Count -ne 0) { throw "Tracked deletions detected." }

    $VenvPython = Join-Path $Root ".venv\Scripts\python.exe"
    if (-not (Test-Path -LiteralPath $VenvPython -PathType Leaf)) {
        throw "Project .venv Python not found."
    }

    Write-Host "BASELINE : PASS" -ForegroundColor Green
    Write-Host "POWERSHELL SYNTAX : PASS" -ForegroundColor Green

    Write-Host ""
    Write-Host "[2/12] SHA-256 FREEZE OF CLOSED COMPONENTS" -ForegroundColor Yellow

    $Tracked = @(Invoke-Git @("-c","core.quotepath=false","ls-files"))
    $Protected = @(
        $Tracked | Where-Object {
            $_ -match '(?i)SPT-023\.[123]' -or
            $_ -match '(?i)spt023[123]' -or
            $_ -match '(?i)SPT-023\.4' -or
            $_ -match '(?i)spt0234'
        }
    )

    $ProtectedBefore = Get-HashMap -Root $Root -Paths $Protected
    if ($ProtectedBefore.Count -lt 1) {
        throw "Unable to establish protected SHA-256 baseline."
    }

    Write-Host "PROTECTED FILES : $($ProtectedBefore.Count)"
    Write-Host "SHA-256 FREEZE  : PASS" -ForegroundColor Green

    Write-Host ""
    Write-Host "[3/12] TARGET COLLISION GATE" -ForegroundColor Yellow

    $Targets = @(
        "src\sgoda\integration\spt0234\quality.py",
        "src\sgoda\integration\spt0234\manifest.py",
        "src\sgoda\integration\spt0234\handoff.py",
        "src\sgoda\integration\spt0234\layer3.py",
        "tests\integration\test_spt0234_multimedia_governance_layer3.py",
        "docs\06_Tecnologia\SPT-023.4\SGD-SPT023.4-Capa3-Gobernanza-Calidad-Cierre.md",
        "config\integration\spt0234\quality-governance.json",
        "artifacts\development\SPT-023.4-Capa3-v1.0.0\implementation-evidence.json"
    )

    foreach ($Rel in $Targets) {
        if (Test-Path -LiteralPath (Join-Path $Root $Rel)) {
            throw "Target already exists before fresh SPT-023.4 Capa 3 transaction: $Rel"
        }
    }

    $MasterBookPath = Join-Path $Root "docs\00_Estado_Maestro\SGD-002-Libro-Maestro-Institucional-SGODA-PUINAVE-v1.0.0.md"
    if (-not (Test-Path -LiteralPath $MasterBookPath -PathType Leaf)) {
        throw "SGD-002 master book not found."
    }

    $MasterBookOriginal = [System.IO.File]::ReadAllText($MasterBookPath)
    $Marker = "<!-- SPT-023.4-CAPA3-CLOSE-V1.0.0 -->"
    if ($MasterBookOriginal.Contains($Marker)) {
        throw "SGD-002 already contains SPT-023.4 Capa 3 closure marker while HEAD is baseline."
    }

    Write-Host "TARGET COLLISIONS : 0" -ForegroundColor Green

    Write-Host ""
    Write-Host "[4/12] IMPLEMENT SPT-023.4 CAPA 3" -ForegroundColor Yellow

    $Files = @{}
    $Files["src\sgoda\integration\spt0234\quality.py"] = @'
from __future__ import annotations

from dataclasses import dataclass
from typing import Any


REQUIRED_RESOURCE_TYPES = (
    "image",
    "audio_puinave",
    "audio_es",
    "audio_en",
    "audio_it",
)


@dataclass(frozen=True)
class ResourceQualityDecision:
    resource_id: str
    resource_type: str
    status: str
    approved: bool
    reviewer: str | None
    reason: str | None
    sha256: str
    output_path: str
    validation: dict[str, Any]

    def to_dict(self) -> dict[str, Any]:
        return {
            "resource_id": self.resource_id,
            "resource_type": self.resource_type,
            "status": self.status,
            "approved": self.approved,
            "reviewer": self.reviewer,
            "reason": self.reason,
            "sha256": self.sha256,
            "output_path": self.output_path,
            "validation": dict(self.validation),
        }


def validate_resource_record(record: dict[str, Any]) -> None:
    required = (
        "resource_id",
        "resource_type",
        "status",
        "sha256",
        "output_path",
        "validation",
    )
    missing = [key for key in required if key not in record]
    if missing:
        raise ValueError(f"Resource record missing fields: {missing}")

    resource_type = str(record["resource_type"])
    if resource_type not in REQUIRED_RESOURCE_TYPES:
        raise ValueError(f"Unsupported resource_type: {resource_type}")

    if not str(record["sha256"]).strip():
        raise ValueError("Resource SHA-256 is required.")

    if not bool((record.get("validation") or {}).get("valid")):
        raise ValueError("Resource validation must be valid before quality review.")


def review_resource(
    record: dict[str, Any],
    *,
    approve: bool,
    reviewer: str,
    reason: str,
) -> ResourceQualityDecision:
    validate_resource_record(record)

    reviewer = str(reviewer or "").strip()
    reason = str(reason or "").strip()

    if not reviewer:
        raise ValueError("Human reviewer is required.")
    if not reason:
        raise ValueError("Quality decision reason is required.")

    return ResourceQualityDecision(
        resource_id=str(record["resource_id"]),
        resource_type=str(record["resource_type"]),
        status="APPROVED" if approve else "REJECTED",
        approved=bool(approve),
        reviewer=reviewer,
        reason=reason,
        sha256=str(record["sha256"]),
        output_path=str(record["output_path"]),
        validation=dict(record["validation"]),
    )
'@
    $Files["src\sgoda\integration\spt0234\manifest.py"] = @'
from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from typing import Any, Iterable

from .quality import REQUIRED_RESOURCE_TYPES


def _canonical(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


@dataclass(frozen=True)
class MultimediaCompletenessManifest:
    lexical_id: str
    complete: bool
    required_resources: tuple[str, ...]
    approved_resources: tuple[str, ...]
    missing_resources: tuple[str, ...]
    rejected_resources: tuple[str, ...]
    manifest_sha256: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "lexical_id": self.lexical_id,
            "complete": self.complete,
            "required_resources": list(self.required_resources),
            "approved_resources": list(self.approved_resources),
            "missing_resources": list(self.missing_resources),
            "rejected_resources": list(self.rejected_resources),
            "manifest_sha256": self.manifest_sha256,
        }


def build_completeness_manifest(
    lexical_id: str,
    decisions: Iterable[dict[str, Any]],
) -> MultimediaCompletenessManifest:
    lexical_id = str(lexical_id or "").strip()
    if not lexical_id:
        raise ValueError("lexical_id is required.")

    by_type: dict[str, dict[str, Any]] = {}
    for raw in decisions:
        resource_type = str(raw.get("resource_type") or "").strip()
        if resource_type not in REQUIRED_RESOURCE_TYPES:
            raise ValueError(f"Unsupported resource_type in decision: {resource_type}")
        if resource_type in by_type:
            raise ValueError(f"Duplicate quality decision for {resource_type}")
        by_type[resource_type] = dict(raw)

    approved = tuple(
        resource_type
        for resource_type in REQUIRED_RESOURCE_TYPES
        if resource_type in by_type and bool(by_type[resource_type].get("approved"))
    )
    rejected = tuple(
        resource_type
        for resource_type in REQUIRED_RESOURCE_TYPES
        if resource_type in by_type and not bool(by_type[resource_type].get("approved"))
    )
    missing = tuple(
        resource_type
        for resource_type in REQUIRED_RESOURCE_TYPES
        if resource_type not in by_type
    )

    complete = not missing and not rejected and len(approved) == len(REQUIRED_RESOURCE_TYPES)

    payload = {
        "lexical_id": lexical_id,
        "required_resources": list(REQUIRED_RESOURCE_TYPES),
        "approved_resources": list(approved),
        "missing_resources": list(missing),
        "rejected_resources": list(rejected),
        "complete": complete,
    }
    digest = hashlib.sha256(_canonical(payload)).hexdigest().upper()

    return MultimediaCompletenessManifest(
        lexical_id=lexical_id,
        complete=complete,
        required_resources=tuple(REQUIRED_RESOURCE_TYPES),
        approved_resources=approved,
        missing_resources=missing,
        rejected_resources=rejected,
        manifest_sha256=digest,
    )
'@
    $Files["src\sgoda\integration\spt0234\handoff.py"] = @'
from __future__ import annotations

from typing import Any


def build_fld_oda_handoff(
    *,
    lexical_id: str,
    puinave: str,
    category_id: str | None,
    manifest: dict[str, Any],
    approved_resources: list[dict[str, Any]],
) -> dict[str, Any]:
    lexical_id = str(lexical_id or "").strip()
    puinave = str(puinave or "").strip()

    if not lexical_id:
        raise ValueError("lexical_id is required.")
    if not puinave:
        raise ValueError("Puinave text is required.")
    if not bool(manifest.get("complete")):
        raise ValueError("Multimedia manifest must be complete before FLD/ODA handoff.")

    if len(approved_resources) != 5:
        raise ValueError("Exactly five approved multimedia resources are required.")

    return {
        "component": "SPT-023.4",
        "layer": "3",
        "status": "READY_FOR_FLD_ODA",
        "lexical_id": lexical_id,
        "puinave": puinave,
        "category_id": category_id,
        "multimedia_manifest_sha256": manifest["manifest_sha256"],
        "resources": list(approved_resources),
        "requires_human_validation": False,
        "paid_api_used": False,
        "next_component": "SPT-023.5",
    }
'@
    $Files["src\sgoda\integration\spt0234\layer3.py"] = @'
from __future__ import annotations

from typing import Any

from .handoff import build_fld_oda_handoff
from .manifest import build_completeness_manifest
from .quality import review_resource


class Spt0234Layer3GovernanceService:
    """Gobernanza de calidad, completitud y salida a SPT-023.5."""

    def review_bundle(
        self,
        *,
        lexical_id: str,
        puinave: str,
        category_id: str | None,
        resources: list[dict[str, Any]],
        decisions: dict[str, dict[str, Any]],
    ) -> dict[str, Any]:
        reviewed: list[dict[str, Any]] = []

        for resource in resources:
            resource_type = str(resource.get("resource_type") or "")
            decision_input = decisions.get(resource_type)
            if decision_input is None:
                continue

            reviewed.append(
                review_resource(
                    resource,
                    approve=bool(decision_input.get("approve")),
                    reviewer=str(decision_input.get("reviewer") or ""),
                    reason=str(decision_input.get("reason") or ""),
                ).to_dict()
            )

        manifest = build_completeness_manifest(
            lexical_id,
            reviewed,
        ).to_dict()

        result: dict[str, Any] = {
            "component": "SPT-023.4",
            "layer": "3",
            "lexical_id": lexical_id,
            "quality_decisions": reviewed,
            "manifest": manifest,
            "status": "READY_FOR_FLD_ODA" if manifest["complete"] else "MULTIMEDIA_REVIEW_REQUIRED",
            "paid_api_used": False,
            "next_component": "SPT-023.5" if manifest["complete"] else "SPT-023.4-CAPA-3",
        }

        if manifest["complete"]:
            approved_resources = [
                item for item in reviewed if item["approved"]
            ]
            result["handoff"] = build_fld_oda_handoff(
                lexical_id=lexical_id,
                puinave=puinave,
                category_id=category_id,
                manifest=manifest,
                approved_resources=approved_resources,
            )
        else:
            result["handoff"] = None

        return result
'@
    $Files["tests\integration\test_spt0234_multimedia_governance_layer3.py"] = @'
import pytest

from sgoda.integration.spt0234.handoff import build_fld_oda_handoff
from sgoda.integration.spt0234.layer3 import Spt0234Layer3GovernanceService
from sgoda.integration.spt0234.manifest import build_completeness_manifest
from sgoda.integration.spt0234.quality import review_resource


RESOURCE_TYPES = (
    "image",
    "audio_puinave",
    "audio_es",
    "audio_en",
    "audio_it",
)


def resource(resource_type):
    return {
        "resource_id": f"MM-{resource_type}",
        "resource_type": resource_type,
        "status": "GENERATED_LOCAL",
        "sha256": "A" * 64,
        "output_path": f"media/LEX-001/{resource_type}.bin",
        "validation": {"valid": True},
    }


def approval():
    return {
        resource_type: {
            "approve": True,
            "reviewer": "reviewer-01",
            "reason": "validado",
        }
        for resource_type in RESOURCE_TYPES
    }


def test_resource_approval_requires_human_reviewer():
    with pytest.raises(ValueError):
        review_resource(
            resource("image"),
            approve=True,
            reviewer="",
            reason="ok",
        )


def test_resource_approval_requires_reason():
    with pytest.raises(ValueError):
        review_resource(
            resource("image"),
            approve=True,
            reviewer="r1",
            reason="",
        )


def test_invalid_resource_cannot_be_approved():
    bad = resource("image")
    bad["validation"] = {"valid": False}
    with pytest.raises(ValueError):
        review_resource(
            bad,
            approve=True,
            reviewer="r1",
            reason="ok",
        )


def test_approved_resource_status_is_approved():
    decision = review_resource(
        resource("image"),
        approve=True,
        reviewer="r1",
        reason="ok",
    )
    assert decision.status == "APPROVED"
    assert decision.approved is True


def test_rejected_resource_status_is_rejected():
    decision = review_resource(
        resource("image"),
        approve=False,
        reviewer="r1",
        reason="quality",
    )
    assert decision.status == "REJECTED"
    assert decision.approved is False


def test_complete_manifest_requires_five_approved_resources():
    decisions = [
        review_resource(
            resource(rt),
            approve=True,
            reviewer="r1",
            reason="ok",
        ).to_dict()
        for rt in RESOURCE_TYPES
    ]
    manifest = build_completeness_manifest("LEX-001", decisions)
    assert manifest.complete is True
    assert len(manifest.approved_resources) == 5


def test_manifest_detects_missing_resource():
    decisions = [
        review_resource(
            resource(rt),
            approve=True,
            reviewer="r1",
            reason="ok",
        ).to_dict()
        for rt in RESOURCE_TYPES[:-1]
    ]
    manifest = build_completeness_manifest("LEX-001", decisions)
    assert manifest.complete is False
    assert manifest.missing_resources == ("audio_it",)


def test_manifest_detects_rejected_resource():
    decisions = []
    for rt in RESOURCE_TYPES:
        decisions.append(
            review_resource(
                resource(rt),
                approve=(rt != "image"),
                reviewer="r1",
                reason="ok",
            ).to_dict()
        )
    manifest = build_completeness_manifest("LEX-001", decisions)
    assert manifest.complete is False
    assert manifest.rejected_resources == ("image",)


def test_manifest_is_deterministic():
    decisions = [
        review_resource(
            resource(rt),
            approve=True,
            reviewer="r1",
            reason="ok",
        ).to_dict()
        for rt in RESOURCE_TYPES
    ]
    one = build_completeness_manifest("LEX-001", decisions)
    two = build_completeness_manifest("LEX-001", decisions)
    assert one.manifest_sha256 == two.manifest_sha256


def test_duplicate_resource_decision_is_rejected():
    decisions = [
        review_resource(resource("image"), approve=True, reviewer="r1", reason="ok").to_dict(),
        review_resource(resource("image"), approve=True, reviewer="r2", reason="ok").to_dict(),
    ]
    with pytest.raises(ValueError):
        build_completeness_manifest("LEX-001", decisions)


def test_handoff_requires_complete_manifest():
    with pytest.raises(ValueError):
        build_fld_oda_handoff(
            lexical_id="LEX-001",
            puinave="AMDA",
            category_id="CAT-NATURE",
            manifest={"complete": False, "manifest_sha256": "X"},
            approved_resources=[],
        )


def test_handoff_requires_exactly_five_resources():
    with pytest.raises(ValueError):
        build_fld_oda_handoff(
            lexical_id="LEX-001",
            puinave="AMDA",
            category_id="CAT-NATURE",
            manifest={"complete": True, "manifest_sha256": "X"},
            approved_resources=[resource("image")],
        )


def test_full_bundle_is_ready_for_fld_oda():
    service = Spt0234Layer3GovernanceService()
    result = service.review_bundle(
        lexical_id="LEX-001",
        puinave="AMDA",
        category_id="CAT-NATURE",
        resources=[resource(rt) for rt in RESOURCE_TYPES],
        decisions=approval(),
    )
    assert result["status"] == "READY_FOR_FLD_ODA"
    assert result["manifest"]["complete"] is True
    assert result["handoff"]["next_component"] == "SPT-023.5"


def test_bundle_with_missing_decision_requires_review():
    service = Spt0234Layer3GovernanceService()
    decisions = approval()
    decisions.pop("audio_it")
    result = service.review_bundle(
        lexical_id="LEX-001",
        puinave="AMDA",
        category_id="CAT-NATURE",
        resources=[resource(rt) for rt in RESOURCE_TYPES],
        decisions=decisions,
    )
    assert result["status"] == "MULTIMEDIA_REVIEW_REQUIRED"
    assert result["handoff"] is None


def test_bundle_with_rejection_requires_review():
    service = Spt0234Layer3GovernanceService()
    decisions = approval()
    decisions["image"]["approve"] = False
    decisions["image"]["reason"] = "rechazada"
    result = service.review_bundle(
        lexical_id="LEX-001",
        puinave="AMDA",
        category_id="CAT-NATURE",
        resources=[resource(rt) for rt in RESOURCE_TYPES],
        decisions=decisions,
    )
    assert result["status"] == "MULTIMEDIA_REVIEW_REQUIRED"


def test_final_handoff_disables_paid_api():
    service = Spt0234Layer3GovernanceService()
    result = service.review_bundle(
        lexical_id="LEX-001",
        puinave="AMDA",
        category_id="CAT-NATURE",
        resources=[resource(rt) for rt in RESOURCE_TYPES],
        decisions=approval(),
    )
    assert result["handoff"]["paid_api_used"] is False


def test_final_handoff_contains_five_resources():
    service = Spt0234Layer3GovernanceService()
    result = service.review_bundle(
        lexical_id="LEX-001",
        puinave="AMDA",
        category_id="CAT-NATURE",
        resources=[resource(rt) for rt in RESOURCE_TYPES],
        decisions=approval(),
    )
    assert len(result["handoff"]["resources"]) == 5


def test_final_handoff_targets_spt0235():
    service = Spt0234Layer3GovernanceService()
    result = service.review_bundle(
        lexical_id="LEX-001",
        puinave="AMDA",
        category_id="CAT-NATURE",
        resources=[resource(rt) for rt in RESOURCE_TYPES],
        decisions=approval(),
    )
    assert result["next_component"] == "SPT-023.5"
'@
    $Files["docs\06_Tecnologia\SPT-023.4\SGD-SPT023.4-Capa3-Gobernanza-Calidad-Cierre.md"] = @'
# SPT-023.4 — Generador Multimedia — Capa 3

## Objetivo

Cerrar funcional e institucionalmente SPT-023.4 mediante gobernanza de calidad,
aprobación humana, verificación de completitud de los cinco recursos por palabra
y contrato de salida hacia SPT-023.5 — Constructor FLD/ODA.

## Recursos obligatorios

Cada palabra debe disponer de:

1. imagen;
2. audio Puinave;
3. audio español;
4. audio inglés;
5. audio italiano.

## Gobernanza de calidad

Ningún recurso se considera aprobado únicamente por haber sido generado o
importado. Cada recurso debe haber pasado su validación técnica y recibir una
decisión humana con reviewer y reason.

## Completitud

El manifiesto multimedia es completo solamente cuando existen cinco decisiones
de calidad y todas están aprobadas. Recursos faltantes o rechazados bloquean el
handoff.

## Trazabilidad

El manifiesto de completitud genera SHA-256 determinístico y el contrato de
salida conserva referencias a los cinco recursos aprobados.

## Salida institucional

Cuando el manifiesto queda completo, SPT-023.4 produce estado
`READY_FOR_FLD_ODA` y habilita **SPT-023.5 — Constructor FLD/ODA**.

## Cierre

La aprobación de esta capa, junto con la preservación por SHA-256 de Capa 1,
Capa 2 y componentes previos, permite declarar SPT-023.4 completamente cerrado.
'@
    $Files["config\integration\spt0234\quality-governance.json"] = @'
{
  "schema_version": "1.0.0",
  "component": "SPT-023.4",
  "layer": "3",
  "required_resources": [
    "image",
    "audio_puinave",
    "audio_es",
    "audio_en",
    "audio_it"
  ],
  "technical_validation_required": true,
  "human_quality_review_required": true,
  "reviewer_required": true,
  "reason_required": true,
  "all_five_resources_must_be_approved": true,
  "manifest_sha256_required": true,
  "paid_api_allowed": false,
  "success_status": "READY_FOR_FLD_ODA",
  "next_component": "SPT-023.5"
}
'@

    foreach ($Rel in $Files.Keys) {
        $Full = Join-Path $Root $Rel
        Write-Utf8Lf -Path $Full -Content $Files[$Rel] -TrackCreated
        Write-Host ("CREATED : " + $Rel)
    }

    Write-Host ""
    Write-Host "[5/12] PYTHON PREVALIDATION + TARGETED TESTS" -ForegroundColor Yellow

    $env:PYTHONPATH = Join-Path $Root "src"

    $PyFiles = @(
        "src\sgoda\integration\spt0234\quality.py",
        "src\sgoda\integration\spt0234\manifest.py",
        "src\sgoda\integration\spt0234\handoff.py",
        "src\sgoda\integration\spt0234\layer3.py",
        "tests\integration\test_spt0234_multimedia_governance_layer3.py"
    ) | ForEach-Object { Join-Path $Root $_ }

    & $VenvPython -m py_compile @PyFiles
    if ($LASTEXITCODE -ne 0) {
        throw "Python syntax prevalidation failed."
    }

    $Previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $TargetOutput = @(
            & $VenvPython -m pytest `
                "tests/integration/test_spt0234_multimedia_governance_layer3.py" `
                -q 2>&1
        )
        $TargetCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $Previous
    }

    $TargetOutput | ForEach-Object { Write-Host $_ }
    if ($TargetCode -ne 0) {
        throw "Targeted SPT-023.4 Capa 3 tests failed."
    }

    $TargetText = ($TargetOutput | ForEach-Object { [string]$_ }) -join "`n"
    $TargetMatch = [regex]::Match($TargetText, '(\d+)\s+passed')
    if (-not $TargetMatch.Success) {
        throw "Unable to certify targeted test count."
    }

    $TargetPassed = [int]$TargetMatch.Groups[1].Value
    if ($TargetPassed -lt $ExpectedTargetedTests) {
        throw "Targeted test count below expected $ExpectedTargetedTests."
    }

    Write-Host "TARGETED TESTS : $TargetPassed PASSED" -ForegroundColor Green

    Write-Host ""
    Write-Host "[6/12] INSTITUTIONAL SUITE + COMPILEALL" -ForegroundColor Yellow

    $Previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $SuiteOutput = @(& $VenvPython -m pytest -q 2>&1)
        $SuiteCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $Previous
    }

    $SuiteOutput | Select-Object -Last 20 | ForEach-Object { Write-Host $_ }
    if ($SuiteCode -ne 0) {
        throw "Institutional pytest suite failed."
    }

    $SuiteText = ($SuiteOutput | ForEach-Object { [string]$_ }) -join "`n"
    $SuiteMatch = [regex]::Match($SuiteText, '(\d+)\s+passed')
    if (-not $SuiteMatch.Success) {
        throw "Unable to certify institutional test count."
    }

    $SuitePassed = [int]$SuiteMatch.Groups[1].Value
    if ($SuitePassed -lt $ExpectedFullSuiteMinimum) {
        throw "Institutional suite below expected minimum $ExpectedFullSuiteMinimum."
    }

    & $VenvPython -m compileall -q src
    if ($LASTEXITCODE -ne 0) {
        throw "Python compileall failed."
    }

    Write-Host "FULL SUITE : $SuitePassed PASSED" -ForegroundColor Green
    Write-Host "COMPILEALL : PASS" -ForegroundColor Green

    Write-Host ""
    Write-Host "[7/12] SHA-256 PRESERVATION GATE" -ForegroundColor Yellow

    $ProtectedAfter = Get-HashMap -Root $Root -Paths $Protected
    $ChangedProtected = @(Compare-HashMaps -Before $ProtectedBefore -After $ProtectedAfter)

    Write-Host "PROTECTED FILES CHANGED : $($ChangedProtected.Count)"
    if ($ChangedProtected.Count -ne 0) {
        throw ("Closed component SHA-256 changed: " + ($ChangedProtected -join ", "))
    }

    Write-Host "CLOSED COMPONENTS : PRESERVED" -ForegroundColor Green

    Write-Host ""
    Write-Host "[8/12] EVIDENCE + SGD-002 FINAL SPT-023.4 CLOSURE" -ForegroundColor Yellow

    $EvidencePath = Join-Path $Root "artifacts\development\SPT-023.4-Capa3-v1.0.0\implementation-evidence.json"
    $EvidenceDir = Split-Path -Parent $EvidencePath
    if (-not (Test-Path -LiteralPath $EvidenceDir)) {
        New-Item -ItemType Directory -Path $EvidenceDir -Force | Out-Null
    }

    $Generated = @()
    foreach ($Rel in $Files.Keys | Sort-Object) {
        $Full = Join-Path $Root $Rel
        $Generated += [ordered]@{
            path = $Rel.Replace("\","/")
            sha256 = (Get-FileHash -LiteralPath $Full -Algorithm SHA256).Hash
        }
    }

    $Evidence = [ordered]@{
        schema_version = "1.0.0"
        component = "SPT-023.4"
        layer = "3"
        title = "Gobernanza de Calidad Completitud y Cierre Multimedia"
        generated_utc = [DateTime]::UtcNow.ToString("o")
        certified_baseline = $ExpectedBaseline
        targeted_tests_passed = $TargetPassed
        institutional_tests_passed = $SuitePassed
        protected_files = $ProtectedBefore.Count
        protected_files_changed = $ChangedProtected.Count
        human_quality_review = $true
        five_resource_completeness = $true
        deterministic_manifest_sha256 = $true
        fld_oda_handoff = $true
        paid_api_allowed = $false
        spt0234_scope_complete = $true
        next_component = "SPT-023.5"
        generated_files = $Generated
    }

    Write-Utf8Lf -Path $EvidencePath -Content ($Evidence | ConvertTo-Json -Depth 8) -TrackCreated

    $MasterAppend = @"

$Marker
## SPT-023.4 — Generador Multimedia — CIERRE

- Estado institucional: CLOSED.
- Capa 1: planificación e integración multimedia cerrada y preservada.
- Capa 2: ejecución local, validación y ADR-010/RMR cerrada y preservada.
- Capa 3: gobernanza de calidad y completitud implementada.
- Línea base de entrada: `$ExpectedBaseline`.
- Pruebas específicas Capa 3: `$TargetPassed` aprobadas.
- Suite institucional: `$SuitePassed` aprobadas.
- Recursos obligatorios por palabra: imagen + audio Puinave + audio ES + audio EN + audio IT.
- Aprobación humana de calidad: obligatoria.
- Completitud: exige cinco recursos aprobados.
- Manifiesto multimedia: SHA-256 determinístico.
- APIs de pago: deshabilitadas.
- Componentes cerrados anteriores: preservados por SHA-256.
- Contrato de salida: READY_FOR_FLD_ODA.
- Siguiente paquete autorizado: SPT-023.5 — Constructor FLD/ODA.
"@

    $UpdatedMaster = $MasterBookOriginal.TrimEnd([char[]]@("`r","`n")) + "`n" + $MasterAppend.Replace("`r`n","`n").Replace("`r","`n").TrimStart([char[]]@("`r","`n"))

    [System.IO.File]::WriteAllText(
        $MasterBookPath,
        $UpdatedMaster,
        (New-Object System.Text.UTF8Encoding($false))
    )
    $MasterBookTouched = $true

    Write-Host "EVIDENCE : CREATED" -ForegroundColor Green
    Write-Host "SGD-002  : SPT-023.4 CLOSED" -ForegroundColor Green

    Write-Host ""
    Write-Host "[9/12] EXACT CONTROLLED STAGING" -ForegroundColor Yellow

    $Allowed = @(
        $Files.Keys | ForEach-Object { $_.Replace("\","/") }
    )
    $Allowed += "artifacts/development/SPT-023.4-Capa3-v1.0.0/implementation-evidence.json"
    $Allowed += "docs/00_Estado_Maestro/SGD-002-Libro-Maestro-Institucional-SGODA-PUINAVE-v1.0.0.md"
    $Allowed += $ScriptRel
    $Allowed = @($Allowed | Sort-Object -Unique)

    & git reset -q HEAD --
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to guarantee clean index."
    }

    & git -c core.safecrlf=false add -- @Allowed
    if ($LASTEXITCODE -ne 0) {
        throw "Controlled staging failed."
    }

    $Actual = @(
        Invoke-Git @("-c","core.quotepath=false","diff","--cached","--name-only") |
        ForEach-Object { $_.Replace("\","/") } |
        Sort-Object -Unique
    )

    $Missing = @($Allowed | Where-Object { $Actual -notcontains $_ })
    $Unexpected = @($Actual | Where-Object { $Allowed -notcontains $_ })

    Write-Host "STAGED     : $($Actual.Count)"
    Write-Host "MISSING    : $($Missing.Count)"
    Write-Host "UNEXPECTED : $($Unexpected.Count)"

    if ($Missing.Count -ne 0 -or $Unexpected.Count -ne 0) {
        throw "Exact staging manifest mismatch."
    }

    & git diff --cached --check
    if ($LASTEXITCODE -ne 0) {
        throw "git diff --cached --check failed."
    }

    Write-Host "STAGING QUALITY : PASS" -ForegroundColor Green

    Write-Host ""
    Write-Host "[10/12] FINAL REMOTE GATE" -ForegroundColor Yellow

    & git fetch origin $Branch --no-tags
    if ($LASTEXITCODE -ne 0) {
        throw "Final fetch failed."
    }

    $HeadBeforeCommit = Git-One @("rev-parse","HEAD")
    $RemoteBeforeCommit = Git-One @("rev-parse","origin/$Branch")

    if ($HeadBeforeCommit -ne $ExpectedBaseline -or $RemoteBeforeCommit -ne $ExpectedBaseline) {
        throw "Repository moved during SPT-023.4 Capa 3 transaction."
    }

    Write-Host "REMOTE GATE : PASS" -ForegroundColor Green

    Write-Host ""
    Write-Host "[11/12] COMMIT + PUSH" -ForegroundColor Yellow

    & git commit -m $CommitMessage
    if ($LASTEXITCODE -ne 0) {
        throw "Commit failed."
    }

    $CommitCreated = $true
    $NewHead = Git-One @("rev-parse","HEAD")
    Write-Host "NEW COMMIT : $NewHead"

    & git push origin $Branch
    if ($LASTEXITCODE -ne 0) {
        throw "Push failed. Re-run this SAME file to resume."
    }

    Write-Host ""
    Write-Host "[12/12] AUTHORITATIVE REMOTE VERIFICATION" -ForegroundColor Yellow

    & git fetch origin $Branch --no-tags
    if ($LASTEXITCODE -ne 0) {
        throw "Verification fetch failed. Re-run this SAME file."
    }

    $LocalFinal = Git-One @("rev-parse","HEAD")
    $RemoteFinal = Git-One @("rev-parse","origin/$Branch")
    $AheadFinal = @(Invoke-Git @("rev-list","origin/$Branch..HEAD")).Count
    $BehindFinal = @(Invoke-Git @("rev-list","HEAD..origin/$Branch")).Count
    $StagedFinal = @(Invoke-Git @("diff","--cached","--name-only")).Count
    $DeletedFinal = @(Invoke-Git @("ls-files","--deleted")).Count

    Write-Host "LOCAL HEAD      : $LocalFinal"
    Write-Host "REMOTE HEAD     : $RemoteFinal"
    Write-Host "AHEAD           : $AheadFinal"
    Write-Host "BEHIND          : $BehindFinal"
    Write-Host "STAGED          : $StagedFinal"
    Write-Host "DELETED TRACKED : $DeletedFinal"

    if ($LocalFinal -ne $RemoteFinal) {
        throw "Local/remote mismatch after publication."
    }
    if ($AheadFinal -ne 0 -or $BehindFinal -ne 0) {
        throw "Repository divergence after publication."
    }
    if ($StagedFinal -ne 0) {
        throw "Staging is not clean after publication."
    }
    if ($DeletedFinal -ne 0) {
        throw "Tracked deletions detected after publication."
    }

    Emit-FinalBanner -Commit $LocalFinal -Targeted $TargetPassed -FullSuite $SuitePassed
    exit 0
}
catch {
    Fail $_.Exception.Message
}
