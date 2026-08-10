param(
    [string]$ProjectRoot = "",
    [string]$ExpectedBaseline = "d68adbe21c245f70b08a131046dc463fe4c6196a"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$CommitMessage = "feat(spt-023.4): implement multimedia planner layer 1"
$ExpectedTargetedTests = 16
$ExpectedFullSuiteMinimum = 912
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
    param(
        [string]$Path,
        [string]$Content,
        [switch]$TrackCreated
    )

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

    if ($TrackCreated) {
        [void]$CreatedFiles.Add($Path)
    }
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
        $Path,
        [ref]$Tokens,
        [ref]$Errors
    )

    if ($Errors.Count -ne 0) {
        throw ("PowerShell syntax validation failed: " + (($Errors | ForEach-Object { $_.Message }) -join " | "))
    }
}

function Emit-FinalBanner {
    param(
        [string]$Commit,
        [int]$Targeted,
        [int]$FullSuite
    )

    Write-Output ""
    Write-Output "======================================================================"
    Write-Output " SPT-023.4 CAPA 1 : INSTITUTIONALLY CLOSED"
    Write-Output " COMMIT           : $Commit"
    Write-Output " TARGETED TESTS   : $Targeted PASSED"
    Write-Output " FULL SUITE       : $FullSuite PASSED"
    Write-Output " SPT-023.1-.3     : PRESERVED"
    Write-Output " LEGACY MULTIMEDIA: REUSED / PRESERVED"
    Write-Output " SGD-002          : UPDATED"
    Write-Output " LOCAL/REMOTE     : IDENTICAL"
    Write-Output " AHEAD            : 0"
    Write-Output " BEHIND           : 0"
    Write-Output " STAGING          : CLEAN"
    Write-Output " DELETED TRACKED  : 0"
    Write-Output " ERRORS PENDING   : 0"
    Write-Output " NEXT             : SPT-023.4 CAPA 2"
    Write-Output "======================================================================"
    Write-Output "FINAL_CLOSURE_EXIT_CODE=0"
}

function Rollback-PreCommit {
    if ($CommitCreated) {
        return
    }

    $Previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & git reset -q HEAD -- 2>$null | Out-Null
    }
    finally {
        $ErrorActionPreference = $Previous
    }

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
    Write-Output " SPT-023.4 CAPA 1 : HOLD"
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
    Write-Output " SGODA-PUINAVE - SPT-023.4 CAPA 1 - MASTER TRANSACTION"
    Write-Output " MULTIMEDIA PLANNER / LEGACY REUSE / FREE-LOCAL POLICY"
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
            $EvidenceResume = Join-Path $Root "artifacts\development\SPT-023.4-Capa1-v1.0.0\implementation-evidence.json"

            if (-not (Test-Path -LiteralPath $EvidenceResume -PathType Leaf)) {
                throw "Resumable Capa 1 commit detected but evidence file is missing."
            }

            $DataResume = Get-Content -LiteralPath $EvidenceResume -Raw -Encoding UTF8 | ConvertFrom-Json

            if ($Local -eq $Remote) {
                $FinalStaged = @(Invoke-Git @("diff","--cached","--name-only")).Count
                $FinalDeleted = @(Invoke-Git @("ls-files","--deleted")).Count
                if ($FinalStaged -ne 0 -or $FinalDeleted -ne 0) {
                    throw "Published Capa 1 commit exists but repository safety is not clean."
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

        throw "HEAD is neither certified baseline nor a resumable SPT-023.4 Capa 1 commit."
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
    Write-Host "[2/12] REUSE CONTRACT + SHA-256 FREEZE" -ForegroundColor Yellow

    $RequiredLegacy = @(
        "src\sgoda\automation\planner.py",
        "src\sgoda\automation\adapters\providers.py",
        "src\sgoda\automation\adapters\storage.py",
        "src\sgoda\enrichment\pipeline.py",
        "src\sgoda\language_engine\tts.py"
    )

    foreach ($Rel in $RequiredLegacy) {
        if (-not (Test-Path -LiteralPath (Join-Path $Root $Rel) -PathType Leaf)) {
            throw "Required reusable multimedia component missing: $Rel"
        }
    }

    $Tracked = @(Invoke-Git @("-c","core.quotepath=false","ls-files"))
    $Protected = @(
        $Tracked | Where-Object {
            $_ -match '(?i)SPT-023\.[123]' -or
            $_ -match '(?i)spt023[123]' -or
            $_ -match '(?i)^src/sgoda/automation/' -or
            $_ -match '(?i)^src/sgoda/enrichment/' -or
            $_ -match '(?i)^src/sgoda/language_engine/' -or
            $_ -match '(?i)^src/sgoda/media/'
        }
    )

    $ProtectedBefore = Get-HashMap -Root $Root -Paths $Protected
    if ($ProtectedBefore.Count -lt 1) {
        throw "Unable to establish protected SHA-256 baseline."
    }

    Write-Host "REUSABLE COMPONENTS : 5 REQUIRED / PRESENT"
    Write-Host "PROTECTED FILES     : $($ProtectedBefore.Count)"
    Write-Host "SHA-256 FREEZE      : PASS" -ForegroundColor Green

    Write-Host ""
    Write-Host "[3/12] TARGET COLLISION GATE" -ForegroundColor Yellow

    $Targets = @(
        "src\sgoda\integration\spt0234\__init__.py",
        "src\sgoda\integration\spt0234\models.py",
        "src\sgoda\integration\spt0234\policy.py",
        "src\sgoda\integration\spt0234\planner.py",
        "src\sgoda\integration\spt0234\service.py",
        "tests\integration\test_spt0234_multimedia_planner_layer1.py",
        "docs\06_Tecnologia\SPT-023.4\SGD-SPT023.4-Capa1-Planificador-Multimedia.md",
        "config\integration\spt0234\multimedia-policy.json",
        "artifacts\development\SPT-023.4-Capa1-v1.0.0\implementation-evidence.json"
    )

    foreach ($Rel in $Targets) {
        if (Test-Path -LiteralPath (Join-Path $Root $Rel)) {
            throw "Target already exists before fresh SPT-023.4 Capa 1 transaction: $Rel"
        }
    }

    $MasterBookPath = Join-Path $Root "docs\00_Estado_Maestro\SGD-002-Libro-Maestro-Institucional-SGODA-PUINAVE-v1.0.0.md"
    if (-not (Test-Path -LiteralPath $MasterBookPath -PathType Leaf)) {
        throw "SGD-002 master book not found."
    }

    $MasterBookOriginal = [System.IO.File]::ReadAllText($MasterBookPath)
    $Marker = "<!-- SPT-023.4-CAPA1-V1.0.0 -->"
    if ($MasterBookOriginal.Contains($Marker)) {
        throw "SGD-002 already contains SPT-023.4 Capa 1 marker while HEAD is baseline."
    }

    Write-Host "TARGET COLLISIONS : 0" -ForegroundColor Green

    Write-Host ""
    Write-Host "[4/12] IMPLEMENT SPT-023.4 CAPA 1" -ForegroundColor Yellow

    $Files = @{}
    $Files["src\sgoda\integration\spt0234\__init__.py"] = @'
"""SPT-023.4 — Generador Multimedia, Capa 1."""
from .models import MultimediaPlan, MultimediaResourcePlan
from .planner import build_multimedia_plan
from .service import Spt0234Layer1Service

__all__ = [
    "MultimediaPlan",
    "MultimediaResourcePlan",
    "Spt0234Layer1Service",
    "build_multimedia_plan",
]
'@
    $Files["src\sgoda\integration\spt0234\models.py"] = @'
from __future__ import annotations

from dataclasses import dataclass, asdict
from typing import Any


@dataclass(frozen=True)
class MultimediaResourcePlan:
    resource_id: str
    lexical_id: str
    resource_type: str
    language: str | None
    route: str
    provider_family: str
    status: str
    required: bool
    requires_human_validation: bool
    existing_resource_reused: bool
    metadata: dict[str, Any]

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True)
class MultimediaPlan:
    lexical_id: str
    puinave: str
    category_id: str | None
    plans: tuple[MultimediaResourcePlan, ...]
    automatic_external_calls: bool = False
    paid_api_allowed: bool = False
    next_component: str = "SPT-023.4-CAPA-2"

    def to_dict(self) -> dict[str, Any]:
        return {
            "component": "SPT-023.4",
            "layer": "1",
            "lexical_id": self.lexical_id,
            "puinave": self.puinave,
            "category_id": self.category_id,
            "plans": [item.to_dict() for item in self.plans],
            "automatic_external_calls": self.automatic_external_calls,
            "paid_api_allowed": self.paid_api_allowed,
            "next_component": self.next_component,
        }
'@
    $Files["src\sgoda\integration\spt0234\policy.py"] = @'
from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class MultimediaRoute:
    resource_type: str
    language: str | None
    route: str
    provider_family: str
    requires_human_validation: bool


ROUTES: tuple[MultimediaRoute, ...] = (
    MultimediaRoute(
        resource_type="image",
        language=None,
        route="SPT-003A->SPT-003B->ADR-010",
        provider_family="LOCAL_OR_MOCK_IMAGE",
        requires_human_validation=True,
    ),
    MultimediaRoute(
        resource_type="audio_puinave",
        language="pui",
        route="NATIVE_RECORDING->SPT-003B->ADR-010",
        provider_family="NATIVE_HUMAN_RECORDING",
        requires_human_validation=True,
    ),
    MultimediaRoute(
        resource_type="audio_es",
        language="es-CO",
        route="SPT-006A->SPT-003B->ADR-010",
        provider_family="FREE_LOCAL_TTS",
        requires_human_validation=False,
    ),
    MultimediaRoute(
        resource_type="audio_en",
        language="en-US",
        route="SPT-006A->SPT-003B->ADR-010",
        provider_family="FREE_LOCAL_TTS",
        requires_human_validation=False,
    ),
    MultimediaRoute(
        resource_type="audio_it",
        language="it-IT",
        route="SPT-006A->SPT-003B->ADR-010",
        provider_family="FREE_LOCAL_TTS",
        requires_human_validation=False,
    ),
)


def validate_policy() -> None:
    expected = {
        "image",
        "audio_puinave",
        "audio_es",
        "audio_en",
        "audio_it",
    }
    actual = {item.resource_type for item in ROUTES}
    if actual != expected:
        raise ValueError("SPT-023.4 multimedia policy must define exactly five resources.")

    for item in ROUTES:
        if "PAID" in item.provider_family.upper():
            raise ValueError("Paid provider families are forbidden.")
        if item.resource_type == "audio_puinave":
            if item.provider_family != "NATIVE_HUMAN_RECORDING":
                raise ValueError("Puinave audio must use native human recording.")
'@
    $Files["src\sgoda\integration\spt0234\planner.py"] = @'
from __future__ import annotations

import hashlib
import json
from typing import Any, Iterable

from .models import MultimediaPlan, MultimediaResourcePlan
from .policy import ROUTES, validate_policy


def _stable_id(lexical_id: str, resource_type: str, language: str | None) -> str:
    canonical = json.dumps(
        {
            "lexical_id": lexical_id,
            "resource_type": resource_type,
            "language": language,
        },
        sort_keys=True,
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    digest = hashlib.sha256(canonical).hexdigest()[:16].upper()
    return f"MM-{digest}"


def _existing_types(existing_resources: Iterable[dict[str, Any]] | None) -> set[str]:
    found: set[str] = set()
    for item in existing_resources or ():
        if not isinstance(item, dict):
            continue
        resource_type = str(item.get("resource_type") or "").strip()
        status = str(item.get("status") or "").strip().upper()
        if resource_type and status in {"READY", "VALID", "APPROVED", "PUBLISHED"}:
            found.add(resource_type)
    return found


def build_multimedia_plan(
    record: dict[str, Any],
    *,
    existing_resources: Iterable[dict[str, Any]] | None = None,
) -> MultimediaPlan:
    validate_policy()

    lexical_id = str(
        record.get("canonical_id")
        or record.get("lexical_id")
        or record.get("lexical_hash")
        or ""
    ).strip()
    puinave = str(record.get("puinave") or "").strip()
    category_id = str(
        record.get("selected_category_id")
        or record.get("principal_category_id")
        or record.get("category_id")
        or ""
    ).strip() or None

    if not lexical_id:
        raise ValueError("A stable lexical identifier is required.")
    if not puinave:
        raise ValueError("Puinave text is required.")

    existing = _existing_types(existing_resources)
    plans: list[MultimediaResourcePlan] = []

    for route in ROUTES:
        reused = route.resource_type in existing

        if reused:
            status = "REUSE_EXISTING"
        elif route.resource_type == "audio_puinave":
            status = "NATIVE_RECORDING_REQUIRED"
        elif route.resource_type == "image":
            status = "READY_FOR_LOCAL_IMAGE"
        else:
            status = "READY_FOR_LOCAL_TTS"

        metadata = {
            "source_component": "SPT-023.3",
            "target_component": "SPT-023.4",
            "legacy_components_reused": [
                "SPT-003A",
                "SPT-003B",
                "SPT-006",
                "SPT-006A",
                "ADR-010",
            ],
            "no_paid_api": True,
            "no_external_call_in_layer1": True,
        }

        plans.append(
            MultimediaResourcePlan(
                resource_id=_stable_id(
                    lexical_id,
                    route.resource_type,
                    route.language,
                ),
                lexical_id=lexical_id,
                resource_type=route.resource_type,
                language=route.language,
                route=route.route,
                provider_family=route.provider_family,
                status=status,
                required=True,
                requires_human_validation=route.requires_human_validation,
                existing_resource_reused=reused,
                metadata=metadata,
            )
        )

    return MultimediaPlan(
        lexical_id=lexical_id,
        puinave=puinave,
        category_id=category_id,
        plans=tuple(plans),
    )
'@
    $Files["src\sgoda\integration\spt0234\service.py"] = @'
from __future__ import annotations

from typing import Any, Iterable

from .planner import build_multimedia_plan


class Spt0234Layer1Service:
    """Planificador multimedia institucional.

    Esta capa no llama proveedores externos. Integra y reutiliza los contratos
    existentes para dejar cada recurso en una ruta institucional explícita.
    """

    def plan_one(
        self,
        record: dict[str, Any],
        *,
        existing_resources: Iterable[dict[str, Any]] | None = None,
    ) -> dict[str, Any]:
        return build_multimedia_plan(
            record,
            existing_resources=existing_resources,
        ).to_dict()

    def plan_batch(
        self,
        records: Iterable[dict[str, Any]],
        *,
        existing_by_lexical_id: dict[str, list[dict[str, Any]]] | None = None,
    ) -> dict[str, Any]:
        existing_by_lexical_id = existing_by_lexical_id or {}
        results: list[dict[str, Any]] = []

        for record in records:
            lexical_id = str(
                record.get("canonical_id")
                or record.get("lexical_id")
                or record.get("lexical_hash")
                or ""
            ).strip()

            results.append(
                self.plan_one(
                    record,
                    existing_resources=existing_by_lexical_id.get(lexical_id, []),
                )
            )

        status_counts: dict[str, int] = {}
        for result in results:
            for plan in result["plans"]:
                status = plan["status"]
                status_counts[status] = status_counts.get(status, 0) + 1

        return {
            "component": "SPT-023.4",
            "layer": "1",
            "records_processed": len(results),
            "resource_plans": sum(len(item["plans"]) for item in results),
            "status_counts": status_counts,
            "automatic_external_calls": False,
            "paid_api_allowed": False,
            "results": results,
            "next_component": "SPT-023.4-CAPA-2",
        }
'@
    $Files["tests\integration\test_spt0234_multimedia_planner_layer1.py"] = @'
import pytest

from sgoda.integration.spt0234.planner import build_multimedia_plan
from sgoda.integration.spt0234.policy import ROUTES, validate_policy
from sgoda.integration.spt0234.service import Spt0234Layer1Service


def record():
    return {
        "canonical_id": "LEX-001",
        "puinave": "AMDA",
        "selected_category_id": "CAT-NATURE",
    }


def test_policy_has_exactly_five_resources():
    validate_policy()
    assert len(ROUTES) == 5


def test_plan_has_image_and_four_audio_resources():
    result = build_multimedia_plan(record()).to_dict()
    assert {item["resource_type"] for item in result["plans"]} == {
        "image",
        "audio_puinave",
        "audio_es",
        "audio_en",
        "audio_it",
    }


def test_image_routes_to_existing_multimedia_stack():
    result = build_multimedia_plan(record()).to_dict()
    image = next(item for item in result["plans"] if item["resource_type"] == "image")
    assert image["route"] == "SPT-003A->SPT-003B->ADR-010"
    assert image["status"] == "READY_FOR_LOCAL_IMAGE"


def test_puinave_audio_requires_native_recording():
    result = build_multimedia_plan(record()).to_dict()
    audio = next(item for item in result["plans"] if item["resource_type"] == "audio_puinave")
    assert audio["provider_family"] == "NATIVE_HUMAN_RECORDING"
    assert audio["status"] == "NATIVE_RECORDING_REQUIRED"
    assert audio["requires_human_validation"] is True


@pytest.mark.parametrize(
    ("resource_type", "locale"),
    [
        ("audio_es", "es-CO"),
        ("audio_en", "en-US"),
        ("audio_it", "it-IT"),
    ],
)
def test_multilingual_audio_routes_to_free_local_tts(resource_type, locale):
    result = build_multimedia_plan(record()).to_dict()
    audio = next(item for item in result["plans"] if item["resource_type"] == resource_type)
    assert audio["language"] == locale
    assert audio["provider_family"] == "FREE_LOCAL_TTS"
    assert audio["route"] == "SPT-006A->SPT-003B->ADR-010"


def test_paid_api_is_disabled():
    result = build_multimedia_plan(record()).to_dict()
    assert result["paid_api_allowed"] is False
    assert result["automatic_external_calls"] is False


def test_existing_resource_is_reused():
    result = build_multimedia_plan(
        record(),
        existing_resources=[
            {"resource_type": "image", "status": "APPROVED"},
        ],
    ).to_dict()
    image = next(item for item in result["plans"] if item["resource_type"] == "image")
    assert image["status"] == "REUSE_EXISTING"
    assert image["existing_resource_reused"] is True


def test_invalid_existing_resource_is_not_reused():
    result = build_multimedia_plan(
        record(),
        existing_resources=[
            {"resource_type": "image", "status": "FAILED"},
        ],
    ).to_dict()
    image = next(item for item in result["plans"] if item["resource_type"] == "image")
    assert image["status"] == "READY_FOR_LOCAL_IMAGE"


def test_resource_ids_are_deterministic():
    one = build_multimedia_plan(record()).to_dict()
    two = build_multimedia_plan(record()).to_dict()
    assert [x["resource_id"] for x in one["plans"]] == [x["resource_id"] for x in two["plans"]]


def test_different_lexical_ids_have_different_resource_ids():
    one = build_multimedia_plan(record()).to_dict()
    other = record()
    other["canonical_id"] = "LEX-002"
    two = build_multimedia_plan(other).to_dict()
    assert [x["resource_id"] for x in one["plans"]] != [x["resource_id"] for x in two["plans"]]


def test_missing_lexical_id_is_rejected():
    item = record()
    item.pop("canonical_id")
    with pytest.raises(ValueError):
        build_multimedia_plan(item)


def test_missing_puinave_text_is_rejected():
    item = record()
    item["puinave"] = ""
    with pytest.raises(ValueError):
        build_multimedia_plan(item)


def test_batch_plans_five_resources_per_record():
    service = Spt0234Layer1Service()
    second = record()
    second["canonical_id"] = "LEX-002"
    second["puinave"] = "WAI"
    result = service.plan_batch([record(), second])
    assert result["records_processed"] == 2
    assert result["resource_plans"] == 10


def test_batch_never_enables_paid_api():
    result = Spt0234Layer1Service().plan_batch([record()])
    assert result["paid_api_allowed"] is False
    assert result["automatic_external_calls"] is False


def test_layer1_points_to_layer2():
    result = build_multimedia_plan(record()).to_dict()
    assert result["next_component"] == "SPT-023.4-CAPA-2"
'@
    $Files["docs\06_Tecnologia\SPT-023.4\SGD-SPT023.4-Capa1-Planificador-Multimedia.md"] = @'
# SPT-023.4 — Generador Multimedia — Capa 1

## Objetivo

Iniciar SPT-023.4 mediante una capa de planificación e integración que reutiliza
los componentes multimedia ya existentes en SGODA-PUINAVE en lugar de duplicar
sus responsabilidades.

## Reutilización institucional

- SPT-003A: planificación y cola de trabajos multimedia.
- SPT-003B: contratos de proveedor, almacenamiento local, eventos y RMR.
- SPT-006: pipeline de enriquecimiento multimedia.
- SPT-006A: traducción/TTS local, gratuito y gobernado para es-CO, en-US e it-IT.
- ADR-010: Registro Multimedia Reutilizable (RMR).

## Recursos obligatorios por palabra

1. imagen ilustrativa;
2. audio Puinave;
3. audio español;
4. audio inglés;
5. audio italiano.

## Política

La Capa 1 no ejecuta APIs externas ni servicios de pago.

El audio Puinave se mantiene como grabación humana nativa y requiere validación.
Los audios español, inglés e italiano se enrutan al motor local y gratuito
SPT-006A. La imagen se enruta al stack SPT-003A/SPT-003B y queda preparada para
un proveedor local de imagen en la siguiente capa.

Los recursos existentes con estado aprobado/válido se reutilizan y no se
regeneran.

## Siguiente desarrollo

SPT-023.4 Capa 2 deberá implementar la ejecución local gobernada de imagen y TTS,
persistencia efectiva en ADR-010/RMR y validación de los archivos generados.
'@
    $Files["config\integration\spt0234\multimedia-policy.json"] = @'
{
  "schema_version": "1.0.0",
  "component": "SPT-023.4",
  "layer": "1",
  "resources_per_lexical_entry": [
    "image",
    "audio_puinave",
    "audio_es",
    "audio_en",
    "audio_it"
  ],
  "reuse_existing_resources": true,
  "automatic_external_calls": false,
  "paid_api_allowed": false,
  "routes": {
    "image": "SPT-003A->SPT-003B->ADR-010",
    "audio_puinave": "NATIVE_RECORDING->SPT-003B->ADR-010",
    "audio_es": "SPT-006A->SPT-003B->ADR-010",
    "audio_en": "SPT-006A->SPT-003B->ADR-010",
    "audio_it": "SPT-006A->SPT-003B->ADR-010"
  },
  "next_component": "SPT-023.4-CAPA-2"
}
'@

    foreach ($Rel in $Files.Keys) {
        $Full = Join-Path $Root $Rel
        Write-Utf8Lf -Path $Full -Content $Files[$Rel] -TrackCreated
        Write-Host ("CREATED : " + $Rel)
    }

    Write-Host ""
    Write-Host "[5/12] PYTHON PREVALIDATION + 16 TARGETED TESTS" -ForegroundColor Yellow

    $env:PYTHONPATH = Join-Path $Root "src"

    $PyFiles = @(
        "src\sgoda\integration\spt0234\__init__.py",
        "src\sgoda\integration\spt0234\models.py",
        "src\sgoda\integration\spt0234\policy.py",
        "src\sgoda\integration\spt0234\planner.py",
        "src\sgoda\integration\spt0234\service.py",
        "tests\integration\test_spt0234_multimedia_planner_layer1.py"
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
                "tests/integration/test_spt0234_multimedia_planner_layer1.py" `
                -q 2>&1
        )
        $TargetCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $Previous
    }

    $TargetOutput | ForEach-Object { Write-Host $_ }
    if ($TargetCode -ne 0) {
        throw "Targeted SPT-023.4 Capa 1 tests failed."
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
        throw ("Closed/reused component SHA-256 changed: " + ($ChangedProtected -join ", "))
    }

    Write-Host "CLOSED + REUSED COMPONENTS : PRESERVED" -ForegroundColor Green

    Write-Host ""
    Write-Host "[8/12] EVIDENCE + SGD-002 UPDATE" -ForegroundColor Yellow

    $EvidencePath = Join-Path $Root "artifacts\development\SPT-023.4-Capa1-v1.0.0\implementation-evidence.json"
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
        layer = "1"
        title = "Planificador e Integracion Multimedia"
        generated_utc = [DateTime]::UtcNow.ToString("o")
        certified_baseline = $ExpectedBaseline
        targeted_tests_passed = $TargetPassed
        institutional_tests_passed = $SuitePassed
        protected_files = $ProtectedBefore.Count
        protected_files_changed = $ChangedProtected.Count
        resources_per_word = 5
        image_planning = $true
        puinave_native_audio = $true
        spanish_local_tts = $true
        english_local_tts = $true
        italian_local_tts = $true
        reuse_existing_resources = $true
        reused_components = @("SPT-003A","SPT-003B","SPT-006","SPT-006A","ADR-010")
        automatic_external_calls = $false
        paid_api_allowed = $false
        next_component = "SPT-023.4-CAPA-2"
        generated_files = $Generated
    }

    Write-Utf8Lf -Path $EvidencePath -Content ($Evidence | ConvertTo-Json -Depth 8) -TrackCreated

    $MasterAppend = @"

$Marker
## SPT-023.4 — Generador Multimedia — Capa 1

- Estado institucional: CLOSED.
- Línea base de entrada: `$ExpectedBaseline`.
- Pruebas específicas: `$TargetPassed` aprobadas.
- Suite institucional: `$SuitePassed` aprobadas.
- Recursos planificados por palabra: imagen + audio Puinave + audio ES + audio EN + audio IT.
- Reutilización: SPT-003A, SPT-003B, SPT-006, SPT-006A y ADR-010.
- Audio Puinave: grabación humana nativa, con validación.
- Audio ES/EN/IT: ruta local y gratuita SPT-006A.
- APIs de pago: deshabilitadas.
- Llamadas externas automáticas en Capa 1: deshabilitadas.
- Componentes cerrados/reutilizados: preservados por SHA-256.
- Siguiente desarrollo: SPT-023.4 Capa 2 — ejecución local y persistencia multimedia.
"@

    $UpdatedMaster = $MasterBookOriginal.TrimEnd([char[]]@("`r","`n")) + "`n" + $MasterAppend.Replace("`r`n","`n").Replace("`r","`n").TrimStart([char[]]@("`r","`n"))

    [System.IO.File]::WriteAllText(
        $MasterBookPath,
        $UpdatedMaster,
        (New-Object System.Text.UTF8Encoding($false))
    )
    $MasterBookTouched = $true

    Write-Host "EVIDENCE : CREATED" -ForegroundColor Green
    Write-Host "SGD-002  : UPDATED" -ForegroundColor Green

    Write-Host ""
    Write-Host "[9/12] EXACT CONTROLLED STAGING" -ForegroundColor Yellow

    $Allowed = @(
        $Files.Keys | ForEach-Object { $_.Replace("\","/") }
    )
    $Allowed += "artifacts/development/SPT-023.4-Capa1-v1.0.0/implementation-evidence.json"
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
        throw "Repository moved during SPT-023.4 Capa 1 transaction."
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
