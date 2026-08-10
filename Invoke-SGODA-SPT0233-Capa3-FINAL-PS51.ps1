param(
    [string]$ProjectRoot = "",
    [string]$ExpectedBaseline = "cf69edf73bc3612812d683beaf94b7aabbfbb645"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$CommitMessage = "feat(spt-023.3): close institutional category catalog"
$ExpectedTargetedTests = 14
$ExpectedFullSuiteMinimum = 896
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
    Write-Output " SPT-023.3 CAPA 3 : INSTITUTIONALLY CLOSED"
    Write-Output " SPT-023.3        : INSTITUTIONALLY CLOSED"
    Write-Output " COMMIT           : $Commit"
    Write-Output " TARGETED TESTS   : $Targeted PASSED"
    Write-Output " FULL SUITE       : $FullSuite PASSED"
    Write-Output " CAPAS 1-2        : PRESERVED"
    Write-Output " SPT-023.1/.2     : PRESERVED"
    Write-Output " SGD-002          : UPDATED"
    Write-Output " LOCAL/REMOTE     : IDENTICAL"
    Write-Output " AHEAD            : 0"
    Write-Output " BEHIND           : 0"
    Write-Output " STAGING          : CLEAN"
    Write-Output " DELETED TRACKED  : 0"
    Write-Output " ERRORS PENDING   : 0"
    Write-Output " NEXT             : SPT-023.4 GENERADOR MULTIMEDIA"
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
    Write-Output " SPT-023.3 CAPA 3 : HOLD"
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
    Write-Output " SGODA-PUINAVE - SPT-023.3 CAPA 3 - FINAL MASTER TRANSACTION"
    Write-Output " GOVERNANCE / PERSISTENCE / TRACEABILITY / CLOSE SPT-023.3"
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
            $EvidenceResume = Join-Path $Root "artifacts\development\SPT-023.3-Capa3-v1.0.0\implementation-evidence.json"

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
                Write-Host "RESUME MODE : LOCAL COMMIT EXISTS; PUSH PENDING" -ForegroundColor Yellow
                $CommitCreated = $true

                & git push origin $Branch
                if ($LASTEXITCODE -ne 0) {
                    throw "Resume push failed."
                }

                & git fetch origin $Branch --no-tags
                if ($LASTEXITCODE -ne 0) {
                    throw "Resume verification fetch failed."
                }

                $RemoteResume = Git-One @("rev-parse","origin/$Branch")
                if ($RemoteResume -ne $Local) {
                    throw "Resume verification failed: local/remote mismatch."
                }

                Emit-FinalBanner -Commit $Local -Targeted ([int]$DataResume.targeted_tests_passed) -FullSuite ([int]$DataResume.institutional_tests_passed)
                exit 0
            }
        }

        throw "HEAD is neither certified baseline nor a resumable Capa 3 commit."
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
            $_ -match '(?i)SPT-023\.1' -or
            $_ -match '(?i)SPT-023\.2' -or
            $_ -match '(?i)spt0231' -or
            $_ -match '(?i)spt0232' -or
            $_ -match '(?i)SPT-023\.3' -or
            $_ -match '(?i)spt0233'
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
        "src\sgoda\integration\spt0233\registry.py",
        "src\sgoda\integration\spt0233\governance.py",
        "src\sgoda\integration\spt0233\ledger.py",
        "src\sgoda\integration\spt0233\layer3.py",
        "tests\integration\test_spt0233_category_governance_layer3.py",
        "docs\06_Tecnologia\SPT-023.3\SGD-SPT023.3-Capa3-Gobernanza-Persistencia-Cierre.md",
        "config\integration\spt0233\governance-config.json",
        "artifacts\development\SPT-023.3-Capa3-v1.0.0\implementation-evidence.json"
    )

    foreach ($Rel in $Targets) {
        if (Test-Path -LiteralPath (Join-Path $Root $Rel)) {
            throw "Target already exists before fresh Capa 3 transaction: $Rel"
        }
    }

    $MasterBookPath = Join-Path $Root "docs\00_Estado_Maestro\SGD-002-Libro-Maestro-Institucional-SGODA-PUINAVE-v1.0.0.md"
    if (-not (Test-Path -LiteralPath $MasterBookPath -PathType Leaf)) {
        throw "SGD-002 master book not found."
    }

    $MasterBookOriginal = [System.IO.File]::ReadAllText($MasterBookPath)
    $Marker = "<!-- SPT-023.3-CAPA3-CLOSE-V1.0.0 -->"
    if ($MasterBookOriginal.Contains($Marker)) {
        throw "SGD-002 already contains Capa 3 closure marker while HEAD is baseline."
    }

    Write-Host "TARGET COLLISIONS : 0" -ForegroundColor Green

    Write-Host ""
    Write-Host "[4/12] IMPLEMENT SPT-023.3 CAPA 3" -ForegroundColor Yellow

    $Files = @{}
    $Files["src\sgoda\integration\spt0233\registry.py"] = @'
from __future__ import annotations

import hashlib
import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


def _canonical_json(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def _fingerprint(version: int, categories: Iterable[dict[str, Any]]) -> str:
    payload = {
        "version": int(version),
        "categories": list(categories),
    }
    return hashlib.sha256(_canonical_json(payload)).hexdigest().upper()


@dataclass(frozen=True)
class CatalogSnapshot:
    version: int
    categories: tuple[dict[str, Any], ...]
    sha256: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "schema_version": "1.0.0",
            "version": self.version,
            "sha256": self.sha256,
            "categories": [dict(item) for item in self.categories],
        }


class CategoryRegistryStore:
    """Persistencia institucional del catálogo con validación jerárquica."""

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)

    @staticmethod
    def validate(categories: Iterable[dict[str, Any]]) -> tuple[dict[str, Any], ...]:
        normalized: list[dict[str, Any]] = []
        ids: set[str] = set()
        names: set[str] = set()

        for raw in categories:
            if not isinstance(raw, dict):
                raise TypeError("Each category must be a dictionary.")

            category_id = str(raw.get("id") or raw.get("category_id") or "").strip()
            name = str(raw.get("name") or raw.get("nombre") or "").strip()

            if not category_id or not name:
                raise ValueError("Each category requires id and name.")
            if category_id in ids:
                raise ValueError(f"Duplicate category id: {category_id}")

            normalized_name = name.casefold()
            if normalized_name in names:
                raise ValueError(f"Duplicate category name: {name}")

            ids.add(category_id)
            names.add(normalized_name)

            item = dict(raw)
            item["id"] = category_id
            item["name"] = name
            item.setdefault("aliases", [])
            item.setdefault("keywords", [])
            item.setdefault("metadata", {})
            normalized.append(item)

        by_id = {item["id"]: item for item in normalized}

        for item in normalized:
            metadata = dict(item.get("metadata") or {})
            parent_id = str(metadata.get("parent_id") or "").strip() or None
            if parent_id and parent_id not in by_id:
                raise ValueError(
                    f"Unknown parent category {parent_id!r} for {item['id']!r}"
                )
            if parent_id == item["id"]:
                raise ValueError(f"Category {item['id']!r} cannot parent itself")
            metadata["parent_id"] = parent_id
            item["metadata"] = metadata

        parent = {
            item["id"]: item["metadata"].get("parent_id")
            for item in normalized
        }

        for category_id in by_id:
            seen: set[str] = set()
            current: str | None = category_id
            while current is not None:
                if current in seen:
                    raise ValueError(
                        f"Category hierarchy cycle detected at {current!r}"
                    )
                seen.add(current)
                current = parent.get(current)

        return tuple(normalized)

    def load(self) -> CatalogSnapshot:
        if not self.path.exists():
            return CatalogSnapshot(
                version=0,
                categories=(),
                sha256=_fingerprint(0, ()),
            )

        data = json.loads(self.path.read_text(encoding="utf-8"))
        if str(data.get("schema_version")) != "1.0.0":
            raise ValueError("Unsupported category registry schema_version.")

        version = int(data.get("version", 0))
        categories = self.validate(data.get("categories", []))
        expected = _fingerprint(version, categories)
        recorded = str(data.get("sha256") or "").upper()

        if recorded != expected:
            raise ValueError("Category registry SHA-256 does not match content.")

        return CatalogSnapshot(
            version=version,
            categories=categories,
            sha256=expected,
        )

    def save(
        self,
        *,
        version: int,
        categories: Iterable[dict[str, Any]],
    ) -> CatalogSnapshot:
        if int(version) < 1:
            raise ValueError("Registry version must be >= 1.")

        validated = self.validate(categories)
        digest = _fingerprint(int(version), validated)
        snapshot = CatalogSnapshot(
            version=int(version),
            categories=validated,
            sha256=digest,
        )

        self.path.parent.mkdir(parents=True, exist_ok=True)
        temp = self.path.with_name(self.path.name + ".tmp")
        temp.write_text(
            json.dumps(
                snapshot.to_dict(),
                ensure_ascii=False,
                indent=2,
                sort_keys=True,
            )
            + "\n",
            encoding="utf-8",
            newline="\n",
        )
        os.replace(temp, self.path)
        return snapshot
'@
    $Files["src\sgoda\integration\spt0233\governance.py"] = @'
from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from .proposal import CategoryProposal


@dataclass(frozen=True)
class GovernanceDecision:
    proposal_id: str
    decision: str
    reviewer: str
    reason: str
    category: dict[str, Any] | None
    automatic_creation: bool = False
    human_approval: bool = True

    def to_dict(self) -> dict[str, Any]:
        return {
            "proposal_id": self.proposal_id,
            "decision": self.decision,
            "reviewer": self.reviewer,
            "reason": self.reason,
            "category": None if self.category is None else dict(self.category),
            "automatic_creation": self.automatic_creation,
            "human_approval": self.human_approval,
        }


class CategoryGovernance:
    """Gobierna propuestas sin permitir creación automática de categorías."""

    def review(
        self,
        proposal: CategoryProposal,
        *,
        approve: bool,
        reviewer: str,
        reason: str,
        category_id: str | None = None,
        parent_id: str | None = None,
    ) -> GovernanceDecision:
        reviewer = str(reviewer or "").strip()
        reason = str(reason or "").strip()

        if not reviewer:
            raise ValueError("Human reviewer is required.")
        if not reason:
            raise ValueError("Decision reason is required.")

        if not approve:
            return GovernanceDecision(
                proposal_id=proposal.proposal_id,
                decision="REJECTED",
                reviewer=reviewer,
                reason=reason,
                category=None,
            )

        category_id = str(category_id or "").strip()
        if not category_id:
            raise ValueError("Approved proposal requires institutional category_id.")

        category = {
            "id": category_id,
            "name": proposal.proposed_name,
            "aliases": [],
            "keywords": [],
            "metadata": {
                "parent_id": str(parent_id).strip() if parent_id else None,
                "source_proposal_id": proposal.proposal_id,
                "approved_by": reviewer,
                "approval_reason": reason,
            },
        }

        return GovernanceDecision(
            proposal_id=proposal.proposal_id,
            decision="APPROVED_FOR_REGISTRY",
            reviewer=reviewer,
            reason=reason,
            category=category,
        )
'@
    $Files["src\sgoda\integration\spt0233\ledger.py"] = @'
from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def _canonical(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


class CategoryChangeLedger:
    """Ledger JSONL append-only con encadenamiento SHA-256."""

    GENESIS = "0" * 64

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)

    def read(self) -> list[dict[str, Any]]:
        if not self.path.exists():
            return []

        events: list[dict[str, Any]] = []
        for line in self.path.read_text(encoding="utf-8").splitlines():
            if line.strip():
                events.append(json.loads(line))
        return events

    @classmethod
    def _event_hash(cls, event_without_hash: dict[str, Any]) -> str:
        return hashlib.sha256(_canonical(event_without_hash)).hexdigest().upper()

    def verify(self) -> bool:
        previous = self.GENESIS

        for expected_sequence, event in enumerate(self.read(), start=1):
            if int(event.get("sequence", 0)) != expected_sequence:
                return False
            if str(event.get("previous_hash") or "") != previous:
                return False

            recorded_hash = str(event.get("event_hash") or "").upper()
            body = dict(event)
            body.pop("event_hash", None)
            calculated = self._event_hash(body)

            if recorded_hash != calculated:
                return False

            previous = recorded_hash

        return True

    def append(
        self,
        *,
        action: str,
        proposal_id: str,
        reviewer: str,
        reason: str,
        registry_version_before: int,
        registry_version_after: int,
        registry_sha_before: str,
        registry_sha_after: str,
        category_id: str | None,
    ) -> dict[str, Any]:
        if not self.verify():
            raise ValueError("Category change ledger integrity check failed.")

        existing = self.read()
        previous_hash = (
            self.GENESIS
            if not existing
            else str(existing[-1]["event_hash"]).upper()
        )

        event = {
            "sequence": len(existing) + 1,
            "timestamp_utc": datetime.now(timezone.utc).isoformat(),
            "previous_hash": previous_hash,
            "action": str(action),
            "proposal_id": str(proposal_id),
            "reviewer": str(reviewer),
            "reason": str(reason),
            "registry_version_before": int(registry_version_before),
            "registry_version_after": int(registry_version_after),
            "registry_sha_before": str(registry_sha_before),
            "registry_sha_after": str(registry_sha_after),
            "category_id": category_id,
        }
        event["event_hash"] = self._event_hash(event)

        self.path.parent.mkdir(parents=True, exist_ok=True)
        with self.path.open("a", encoding="utf-8", newline="\n") as handle:
            handle.write(
                json.dumps(event, ensure_ascii=False, sort_keys=True)
                + "\n"
            )

        if not self.verify():
            raise ValueError("Category change ledger failed post-append verification.")

        return event
'@
    $Files["src\sgoda\integration\spt0233\layer3.py"] = @'
from __future__ import annotations

from pathlib import Path
from typing import Any

from .governance import CategoryGovernance, GovernanceDecision
from .ledger import CategoryChangeLedger
from .proposal import CategoryProposal
from .registry import CatalogSnapshot, CategoryRegistryStore


class Spt0233Layer3GovernanceService:
    """Capa final de SPT-023.3: persistencia, aprobación y trazabilidad de cambios."""

    def __init__(
        self,
        registry_path: str | Path,
        ledger_path: str | Path,
    ) -> None:
        self.registry = CategoryRegistryStore(registry_path)
        self.ledger = CategoryChangeLedger(ledger_path)
        self.governance = CategoryGovernance()

    def review_proposal(
        self,
        proposal: CategoryProposal,
        *,
        approve: bool,
        reviewer: str,
        reason: str,
        category_id: str | None = None,
        parent_id: str | None = None,
    ) -> dict[str, Any]:
        before = self.registry.load()

        decision = self.governance.review(
            proposal,
            approve=approve,
            reviewer=reviewer,
            reason=reason,
            category_id=category_id,
            parent_id=parent_id,
        )

        if decision.decision == "REJECTED":
            event = self.ledger.append(
                action="PROPOSAL_REJECTED",
                proposal_id=proposal.proposal_id,
                reviewer=decision.reviewer,
                reason=decision.reason,
                registry_version_before=before.version,
                registry_version_after=before.version,
                registry_sha_before=before.sha256,
                registry_sha_after=before.sha256,
                category_id=None,
            )
            return self._result(decision, before, before, event)

        assert decision.category is not None

        candidate = [dict(item) for item in before.categories]

        existing_ids = {str(item["id"]) for item in candidate}
        existing_names = {str(item["name"]).casefold() for item in candidate}

        if decision.category["id"] in existing_ids:
            raise ValueError("Approved category_id already exists.")
        if str(decision.category["name"]).casefold() in existing_names:
            raise ValueError("Approved category name already exists.")

        candidate.append(dict(decision.category))

        had_registry = self.registry.path.exists()
        previous_bytes = (
            self.registry.path.read_bytes()
            if had_registry
            else None
        )

        try:
            after = self.registry.save(
                version=before.version + 1,
                categories=candidate,
            )

            event = self.ledger.append(
                action="CATEGORY_APPROVED_AND_REGISTERED",
                proposal_id=proposal.proposal_id,
                reviewer=decision.reviewer,
                reason=decision.reason,
                registry_version_before=before.version,
                registry_version_after=after.version,
                registry_sha_before=before.sha256,
                registry_sha_after=after.sha256,
                category_id=str(decision.category["id"]),
            )
        except Exception:
            if had_registry and previous_bytes is not None:
                self.registry.path.write_bytes(previous_bytes)
            elif self.registry.path.exists():
                self.registry.path.unlink()
            raise

        return self._result(decision, before, after, event)

    @staticmethod
    def _result(
        decision: GovernanceDecision,
        before: CatalogSnapshot,
        after: CatalogSnapshot,
        event: dict[str, Any],
    ) -> dict[str, Any]:
        return {
            "component": "SPT-023.3",
            "layer": "3",
            "scope_status": "COMPLETE",
            "decision": decision.to_dict(),
            "registry_before": before.to_dict(),
            "registry_after": after.to_dict(),
            "ledger_event": dict(event),
            "automatic_category_creation": False,
            "human_approval_required": True,
            "traceability": "SHA256_CHAIN",
            "next_component": "SPT-023.4",
        }
'@
    $Files["tests\integration\test_spt0233_category_governance_layer3.py"] = @'
import json

from sgoda.integration.spt0233.governance import CategoryGovernance
from sgoda.integration.spt0233.layer3 import Spt0233Layer3GovernanceService
from sgoda.integration.spt0233.ledger import CategoryChangeLedger
from sgoda.integration.spt0233.proposal import build_category_proposal
from sgoda.integration.spt0233.registry import CategoryRegistryStore


def proposal(name="Astronomia"):
    value = build_category_proposal([name])
    assert value is not None
    return value


def initial_categories():
    return [
        {
            "id": "CAT-NATURE",
            "name": "Naturaleza",
            "aliases": [],
            "keywords": [],
            "metadata": {"parent_id": None},
        },
        {
            "id": "CAT-ANIMAL",
            "name": "Animales",
            "aliases": ["animal"],
            "keywords": ["fauna"],
            "metadata": {"parent_id": "CAT-NATURE"},
        },
    ]


def seed_registry(path):
    store = CategoryRegistryStore(path)
    return store.save(version=1, categories=initial_categories())


def test_registry_roundtrip_and_hash(tmp_path):
    path = tmp_path / "catalog.json"
    saved = seed_registry(path)
    loaded = CategoryRegistryStore(path).load()
    assert loaded.version == 1
    assert loaded.sha256 == saved.sha256
    assert len(loaded.categories) == 2


def test_registry_rejects_duplicate_ids(tmp_path):
    store = CategoryRegistryStore(tmp_path / "catalog.json")
    categories = initial_categories() + [
        {"id": "CAT-ANIMAL", "name": "Otro", "metadata": {}}
    ]
    try:
        store.save(version=1, categories=categories)
    except ValueError:
        pass
    else:
        raise AssertionError("duplicate ids must fail")


def test_registry_rejects_unknown_parent(tmp_path):
    store = CategoryRegistryStore(tmp_path / "catalog.json")
    categories = [
        {
            "id": "CAT-X",
            "name": "X",
            "metadata": {"parent_id": "CAT-NOT-FOUND"},
        }
    ]
    try:
        store.save(version=1, categories=categories)
    except ValueError:
        pass
    else:
        raise AssertionError("unknown parent must fail")


def test_registry_detects_content_tampering(tmp_path):
    path = tmp_path / "catalog.json"
    seed_registry(path)
    data = json.loads(path.read_text(encoding="utf-8"))
    data["categories"][0]["name"] = "ALTERADO"
    path.write_text(json.dumps(data), encoding="utf-8")
    try:
        CategoryRegistryStore(path).load()
    except ValueError:
        pass
    else:
        raise AssertionError("tampered registry must fail")


def test_governance_requires_human_reviewer():
    governance = CategoryGovernance()
    try:
        governance.review(
            proposal(),
            approve=True,
            reviewer="",
            reason="validada",
            category_id="CAT-ASTRONOMY",
        )
    except ValueError:
        pass
    else:
        raise AssertionError("human reviewer must be required")


def test_governance_rejection_never_creates_category():
    decision = CategoryGovernance().review(
        proposal(),
        approve=False,
        reviewer="linguista-01",
        reason="evidencia insuficiente",
    )
    assert decision.decision == "REJECTED"
    assert decision.category is None
    assert decision.automatic_creation is False


def test_governance_approval_produces_registry_candidate():
    decision = CategoryGovernance().review(
        proposal(),
        approve=True,
        reviewer="linguista-01",
        reason="categoria necesaria",
        category_id="CAT-ASTRONOMY",
        parent_id="CAT-NATURE",
    )
    assert decision.decision == "APPROVED_FOR_REGISTRY"
    assert decision.category["id"] == "CAT-ASTRONOMY"
    assert decision.category["metadata"]["parent_id"] == "CAT-NATURE"
    assert decision.human_approval is True


def test_ledger_hash_chain_verifies(tmp_path):
    ledger = CategoryChangeLedger(tmp_path / "ledger.jsonl")
    ledger.append(
        action="TEST",
        proposal_id="P1",
        reviewer="r1",
        reason="ok",
        registry_version_before=1,
        registry_version_after=1,
        registry_sha_before="A",
        registry_sha_after="A",
        category_id=None,
    )
    ledger.append(
        action="TEST2",
        proposal_id="P2",
        reviewer="r2",
        reason="ok",
        registry_version_before=1,
        registry_version_after=2,
        registry_sha_before="A",
        registry_sha_after="B",
        category_id="CAT-B",
    )
    assert ledger.verify() is True
    assert ledger.read()[1]["previous_hash"] == ledger.read()[0]["event_hash"]


def test_ledger_detects_tampering(tmp_path):
    path = tmp_path / "ledger.jsonl"
    ledger = CategoryChangeLedger(path)
    ledger.append(
        action="TEST",
        proposal_id="P1",
        reviewer="r1",
        reason="ok",
        registry_version_before=1,
        registry_version_after=1,
        registry_sha_before="A",
        registry_sha_after="A",
        category_id=None,
    )
    text = path.read_text(encoding="utf-8").replace('"reason": "ok"', '"reason": "x"')
    path.write_text(text, encoding="utf-8")
    assert ledger.verify() is False


def test_layer3_rejection_preserves_registry_version(tmp_path):
    registry = tmp_path / "catalog.json"
    ledger = tmp_path / "ledger.jsonl"
    before = seed_registry(registry)
    service = Spt0233Layer3GovernanceService(registry, ledger)
    result = service.review_proposal(
        proposal(),
        approve=False,
        reviewer="linguista-01",
        reason="no procede",
    )
    assert result["decision"]["decision"] == "REJECTED"
    assert result["registry_after"]["version"] == before.version
    assert result["next_component"] == "SPT-023.4"


def test_layer3_human_approval_versions_registry(tmp_path):
    registry = tmp_path / "catalog.json"
    ledger = tmp_path / "ledger.jsonl"
    seed_registry(registry)
    service = Spt0233Layer3GovernanceService(registry, ledger)
    result = service.review_proposal(
        proposal(),
        approve=True,
        reviewer="linguista-01",
        reason="aprobada",
        category_id="CAT-ASTRONOMY",
        parent_id="CAT-NATURE",
    )
    assert result["registry_before"]["version"] == 1
    assert result["registry_after"]["version"] == 2
    assert result["decision"]["category"]["id"] == "CAT-ASTRONOMY"
    assert result["automatic_category_creation"] is False


def test_layer3_blocks_duplicate_category_id(tmp_path):
    registry = tmp_path / "catalog.json"
    ledger = tmp_path / "ledger.jsonl"
    seed_registry(registry)
    service = Spt0233Layer3GovernanceService(registry, ledger)
    try:
        service.review_proposal(
            proposal(),
            approve=True,
            reviewer="linguista-01",
            reason="intento duplicado",
            category_id="CAT-ANIMAL",
            parent_id="CAT-NATURE",
        )
    except ValueError:
        pass
    else:
        raise AssertionError("duplicate category id must fail")


def test_layer3_blocks_duplicate_category_name(tmp_path):
    registry = tmp_path / "catalog.json"
    ledger = tmp_path / "ledger.jsonl"
    seed_registry(registry)
    service = Spt0233Layer3GovernanceService(registry, ledger)
    try:
        service.review_proposal(
            proposal("Animales"),
            approve=True,
            reviewer="linguista-01",
            reason="intento duplicado",
            category_id="CAT-OTHER",
            parent_id="CAT-NATURE",
        )
    except ValueError:
        pass
    else:
        raise AssertionError("duplicate category name must fail")


def test_layer3_output_closes_spt0233_scope(tmp_path):
    registry = tmp_path / "catalog.json"
    ledger = tmp_path / "ledger.jsonl"
    seed_registry(registry)
    service = Spt0233Layer3GovernanceService(registry, ledger)
    result = service.review_proposal(
        proposal(),
        approve=True,
        reviewer="linguista-01",
        reason="aprobada",
        category_id="CAT-ASTRONOMY",
        parent_id="CAT-NATURE",
    )
    assert result["scope_status"] == "COMPLETE"
    assert result["human_approval_required"] is True
    assert result["traceability"] == "SHA256_CHAIN"
    assert result["next_component"] == "SPT-023.4"
'@
    $Files["docs\06_Tecnologia\SPT-023.3\SGD-SPT023.3-Capa3-Gobernanza-Persistencia-Cierre.md"] = @'
# SPT-023.3 — Capa 3 — Gobernanza, Persistencia y Cierre

## Objetivo

Cerrar funcionalmente el paquete **SPT-023.3 — Catálogo Institucional de
Categorías**, complementando las Capas 1 y 2 sin reconstruirlas.

## Capacidades cerradas

La Capa 3 incorpora:

- persistencia versionada del catálogo institucional;
- validación de identificadores, nombres, jerarquías y ciclos;
- aprobación o rechazo humano de propuestas de nuevas categorías;
- prohibición de creación automática de categorías;
- registro de categoría principal y relaciones padre/subcategoría;
- ledger append-only de cambios con encadenamiento SHA-256;
- detección de alteraciones en catálogo y ledger;
- trazabilidad de versión anterior y posterior;
- contrato de salida hacia SPT-023.4.

## Cobertura consolidada de SPT-023.3

Con las tres capas quedan cubiertas las responsabilidades institucionales:

1. categorías;
2. subcategorías;
3. reutilización de categorías existentes;
4. propuestas controladas de nuevas categorías;
5. trazabilidad de decisiones y cambios.

## Regla de gobernanza

Una propuesta nunca crea por sí misma una categoría. La incorporación al
registro requiere `reviewer`, `reason` y una decisión humana explícita.

## Cierre

La aprobación técnica de esta capa, junto con la preservación SHA-256 de
SPT-023.1, SPT-023.2 y las Capas 1–2 de SPT-023.3, permite declarar
**SPT-023.3 institucionalmente cerrado**.

El siguiente paquete es **SPT-023.4 — Generador Multimedia**.
'@
    $Files["config\integration\spt0233\governance-config.json"] = @'
{
  "schema_version": "1.0.0",
  "component": "SPT-023.3",
  "layer": "3",
  "automatic_category_creation": false,
  "human_approval_required": true,
  "registry_versioning": true,
  "hierarchy_validation": true,
  "duplicate_id_policy": "REJECT",
  "duplicate_name_policy": "REJECT",
  "change_ledger": {
    "format": "JSONL",
    "append_only": true,
    "hash_algorithm": "SHA-256",
    "hash_chain_required": true
  },
  "next_component": "SPT-023.4"
}
'@

    foreach ($Rel in $Files.Keys) {
        $Full = Join-Path $Root $Rel
        Write-Utf8Lf -Path $Full -Content $Files[$Rel] -TrackCreated
        Write-Host ("CREATED : " + $Rel)
    }

    Write-Host ""
    Write-Host "[5/12] PYTHON PREVALIDATION + 14 TARGETED TESTS" -ForegroundColor Yellow

    $env:PYTHONPATH = Join-Path $Root "src"

    $PyFiles = @(
        "src\sgoda\integration\spt0233\registry.py",
        "src\sgoda\integration\spt0233\governance.py",
        "src\sgoda\integration\spt0233\ledger.py",
        "src\sgoda\integration\spt0233\layer3.py",
        "tests\integration\test_spt0233_category_governance_layer3.py"
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
                "tests/integration/test_spt0233_category_governance_layer3.py" `
                -q 2>&1
        )
        $TargetCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $Previous
    }

    $TargetOutput | ForEach-Object { Write-Host $_ }
    if ($TargetCode -ne 0) {
        throw "Targeted Capa 3 tests failed."
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
    Write-Host "[8/12] EVIDENCE + SGD-002 FINAL SPT-023.3 CLOSURE" -ForegroundColor Yellow

    $EvidencePath = Join-Path $Root "artifacts\development\SPT-023.3-Capa3-v1.0.0\implementation-evidence.json"
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
        component = "SPT-023.3"
        layer = "3"
        title = "Gobernanza Persistencia y Cierre del Catalogo Institucional"
        generated_utc = [DateTime]::UtcNow.ToString("o")
        certified_baseline = $ExpectedBaseline
        targeted_tests_passed = $TargetPassed
        institutional_tests_passed = $SuitePassed
        protected_files = $ProtectedBefore.Count
        protected_files_changed = $ChangedProtected.Count
        category_management = $true
        subcategory_management = $true
        category_reuse = $true
        controlled_category_proposals = $true
        human_approval_required = $true
        automatic_category_creation = $false
        registry_persistence = $true
        registry_versioning = $true
        sha256_change_ledger = $true
        spt0233_scope_complete = $true
        next_component = "SPT-023.4"
        generated_files = $Generated
    }

    Write-Utf8Lf -Path $EvidencePath -Content ($Evidence | ConvertTo-Json -Depth 8) -TrackCreated

    $MasterAppend = @"

$Marker
## SPT-023.3 — Catálogo Institucional de Categorías — CIERRE

- Estado institucional: CLOSED.
- Capa 1: cerrada y preservada.
- Capa 2: cerrada y preservada.
- Capa 3: gobernanza, persistencia y trazabilidad implementadas.
- Línea base de entrada: `$ExpectedBaseline`.
- Pruebas específicas Capa 3: `$TargetPassed` aprobadas.
- Suite institucional: `$SuitePassed` aprobadas.
- Categorías y subcategorías: administradas mediante registro jerárquico validado.
- Reutilización: prioritaria sobre categorías existentes.
- Nuevas categorías: propuesta controlada y aprobación humana obligatoria.
- Creación automática de categorías: deshabilitada.
- Trazabilidad de cambios: ledger append-only encadenado con SHA-256.
- Componentes cerrados anteriores: preservados por SHA-256.
- Siguiente paquete autorizado: SPT-023.4 — Generador Multimedia.
"@

    $UpdatedMaster = $MasterBookOriginal.TrimEnd([char[]]@("`r","`n")) + "`n" + $MasterAppend.Replace("`r`n","`n").Replace("`r","`n").TrimStart([char[]]@("`r","`n"))

    [System.IO.File]::WriteAllText(
        $MasterBookPath,
        $UpdatedMaster,
        (New-Object System.Text.UTF8Encoding($false))
    )
    $MasterBookTouched = $true

    Write-Host "EVIDENCE : CREATED" -ForegroundColor Green
    Write-Host "SGD-002  : SPT-023.3 CLOSED" -ForegroundColor Green

    Write-Host ""
    Write-Host "[9/12] EXACT CONTROLLED STAGING" -ForegroundColor Yellow

    $Allowed = @(
        $Files.Keys | ForEach-Object { $_.Replace("\","/") }
    )
    $Allowed += "artifacts/development/SPT-023.3-Capa3-v1.0.0/implementation-evidence.json"
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
        throw "Repository moved during Capa 3 transaction."
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
