param(
    [string]$ProjectRoot = "",
    [string]$ExpectedBaseline = "11918a9ed27dc2f7eb6edbe7fb255271ef136807"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$CommitMessage = "feat(spt-023.3): implement category intelligence layer 2"
$ExpectedTargetedTests = 12
$ExpectedFullSuiteMinimum = 882
$CommitCreated = $false
$CreatedFiles = New-Object System.Collections.ArrayList
$MasterBookOriginal = $null
$MasterBookTouched = $false

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
    param(
        [string]$Root,
        [string[]]$Paths
    )

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

function Emit-FinalBanner {
    param(
        [string]$Commit,
        [int]$Targeted,
        [int]$FullSuite
    )

    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Green
    Write-Host " SPT-023.3 CAPA 2 : INSTITUTIONALLY CLOSED" -ForegroundColor Green
    Write-Host " COMMIT           : $Commit" -ForegroundColor Green
    Write-Host " TARGETED TESTS   : $Targeted PASSED" -ForegroundColor Green
    Write-Host " FULL SUITE       : $FullSuite PASSED" -ForegroundColor Green
    Write-Host " SPT-023.1/.2     : PRESERVED" -ForegroundColor Green
    Write-Host " SPT-023.3 CAPA 1 : PRESERVED" -ForegroundColor Green
    Write-Host " SGD-002          : UPDATED" -ForegroundColor Green
    Write-Host " LOCAL/REMOTE     : IDENTICAL" -ForegroundColor Green
    Write-Host " AHEAD            : 0" -ForegroundColor Green
    Write-Host " BEHIND           : 0" -ForegroundColor Green
    Write-Host " STAGING          : CLEAN" -ForegroundColor Green
    Write-Host " DELETED TRACKED  : 0" -ForegroundColor Green
    Write-Host " ERRORS PENDING   : 0" -ForegroundColor Green
    Write-Host " NEXT             : COMPLETE REMAINING SPT-023.3 SCOPE" -ForegroundColor Green
    Write-Host "======================================================================" -ForegroundColor Green
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

    if ($MasterBookTouched -and $null -ne $MasterBookOriginal) {
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

    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Red
    Write-Host " SPT-023.3 CAPA 2 : HOLD" -ForegroundColor Red
    Write-Host (" REASON           : " + $Message) -ForegroundColor Red
    if ($CommitCreated) {
        Write-Host " LOCAL COMMIT     : PRESERVED FOR SAME-FILE RESUME" -ForegroundColor Yellow
    }
    else {
        Write-Host " TRANSACTION      : ROLLED BACK BEFORE COMMIT" -ForegroundColor Red
    }
    Write-Host " ERRORS PENDING   : 1" -ForegroundColor Red
    Write-Host "======================================================================" -ForegroundColor Red
    exit 20
}

try {
    if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
        $ProjectRoot = Git-One @("rev-parse","--show-toplevel")
    }

    Set-Location $ProjectRoot
    $Root = Git-One @("rev-parse","--show-toplevel")
    $Branch = Git-One @("branch","--show-current")

    # Resolve the running script by file name relative to the certified repository root.
    # This avoids false mismatches between Git paths (C:/...) and native Windows paths (C:\...).
    $ScriptName = [System.IO.Path]::GetFileName($MyInvocation.MyCommand.Path)

    if ([string]::IsNullOrWhiteSpace($ScriptName)) {
        throw "Unable to resolve current master script file name."
    }

    $ScriptCandidate = Join-Path $Root $ScriptName

    if (-not (Test-Path -LiteralPath $ScriptCandidate -PathType Leaf)) {
        throw "Master script file is not present in the official repository root."
    }

    $ScriptRel = $ScriptName.Replace("\","/")


    Write-Host ""
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host " SGODA-PUINAVE - SPT-023.3 CAPA 2 - MASTER TRANSACTION" -ForegroundColor Cyan
    Write-Host " ONE FILE / IMPLEMENT / TEST / EVIDENCE / SGD-002 / COMMIT / PUSH" -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan

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
            if ($Local -eq $Remote) {
                $FinalStaged = @(Invoke-Git @("diff","--cached","--name-only")).Count
                $FinalDeleted = @(Invoke-Git @("ls-files","--deleted")).Count
                if ($FinalStaged -ne 0 -or $FinalDeleted -ne 0) {
                    throw "Previously published Capa 2 commit exists but repository safety is not clean."
                }

                $EvidenceResume = Join-Path $Root "artifacts\development\SPT-023.3-Capa2-v1.0.0\implementation-evidence.json"
                $DataResume = Get-Content -LiteralPath $EvidenceResume -Raw -Encoding UTF8 | ConvertFrom-Json
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

                $RemoteAfterResume = Git-One @("rev-parse","origin/$Branch")
                if ($RemoteAfterResume -ne $Local) {
                    throw "Resume verification failed: local/remote mismatch."
                }

                $EvidenceResume = Join-Path $Root "artifacts\development\SPT-023.3-Capa2-v1.0.0\implementation-evidence.json"
                $DataResume = Get-Content -LiteralPath $EvidenceResume -Raw -Encoding UTF8 | ConvertFrom-Json
                Emit-FinalBanner -Commit $Local -Targeted ([int]$DataResume.targeted_tests_passed) -FullSuite ([int]$DataResume.institutional_tests_passed)
                exit 0
            }
        }

        throw "HEAD is neither certified baseline nor a resumable Capa 2 commit."
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

    Write-Host ""
    Write-Host "[2/12] SHA-256 FREEZE OF CLOSED COMPONENTS" -ForegroundColor Yellow

    $Tracked = @(Invoke-Git @("-c","core.quotepath=false","ls-files"))
    $Protected = @(
        $Tracked | Where-Object {
            $_ -match '(?i)^src/sgoda/integration/spt0231/' -or
            $_ -match '(?i)^src/sgoda/integration/spt0232/' -or
            $_ -match '(?i)^docs/06_Tecnologia/SPT-023\.1/' -or
            $_ -match '(?i)^docs/06_Tecnologia/SPT-023\.2/' -or
            $_ -eq 'src/sgoda/integration/spt0233/__init__.py' -or
            $_ -eq 'src/sgoda/integration/spt0233/models.py' -or
            $_ -eq 'src/sgoda/integration/spt0233/catalog.py' -or
            $_ -eq 'src/sgoda/integration/spt0233/service.py' -or
            $_ -eq 'tests/integration/test_spt0233_category_engine.py' -or
            $_ -eq 'docs/06_Tecnologia/SPT-023.3/SGD-SPT023.3-Capa1-Motor-Categorias.md' -or
            $_ -eq 'artifacts/development/SPT-023.3-v1.0.1/runs/20260810-001831/implementation-evidence.json' -or
            $_ -eq 'Invoke-SGODA-SPT0233-Capa1-FINAL-PS51.ps1'
        }
    )

    $ProtectedBefore = Get-HashMap -Root $Root -Paths $Protected
    if ($ProtectedBefore.Count -lt 1) { throw "Unable to establish protected SHA-256 baseline." }

    Write-Host "PROTECTED FILES : $($ProtectedBefore.Count)"
    Write-Host "SHA-256 FREEZE  : PASS" -ForegroundColor Green

    Write-Host ""
    Write-Host "[3/12] TARGET COLLISION GATE" -ForegroundColor Yellow

    $Targets = @(
        "src\sgoda\integration\spt0233\hierarchy.py",
        "src\sgoda\integration\spt0233\proposal.py",
        "src\sgoda\integration\spt0233\traceability.py",
        "src\sgoda\integration\spt0233\layer2.py",
        "tests\integration\test_spt0233_category_engine_layer2.py",
        "docs\06_Tecnologia\SPT-023.3\SGD-SPT023.3-Capa2-Inteligencia-Clasificacion.md",
        "artifacts\development\SPT-023.3-Capa2-v1.0.0\implementation-evidence.json"
    )

    foreach ($Rel in $Targets) {
        if (Test-Path -LiteralPath (Join-Path $Root $Rel)) {
            throw "Target already exists before fresh Capa 2 transaction: $Rel"
        }
    }

    $MasterBookPath = Join-Path $Root "docs\00_Estado_Maestro\SGD-002-Libro-Maestro-Institucional-SGODA-PUINAVE-v1.0.0.md"
    if (-not (Test-Path -LiteralPath $MasterBookPath -PathType Leaf)) {
        throw "SGD-002 master book not found."
    }

    $MasterBookOriginal = [System.IO.File]::ReadAllText($MasterBookPath)
    $Marker = "<!-- SPT-023.3-CAPA2-V1.0.0 -->"
    if ($MasterBookOriginal.Contains($Marker)) {
        throw "SGD-002 already contains Capa 2 marker while HEAD is baseline; refusing inconsistent state."
    }

    Write-Host "TARGET COLLISIONS : 0" -ForegroundColor Green

    Write-Host ""
    Write-Host "[4/12] IMPLEMENT SPT-023.3 CAPA 2" -ForegroundColor Yellow

    $Files = @{}
    $Files["src\sgoda\integration\spt0233\hierarchy.py"] = @'
from __future__ import annotations

from dataclasses import dataclass

from .catalog import CategoryCatalog, CategoryDefinition


@dataclass(frozen=True)
class CategoryNode:
    category_id: str
    name: str
    parent_id: str | None


class CategoryHierarchy:
    """Jerarquía de solo lectura construida desde CategoryCatalog.

    La relación padre se obtiene de metadata["parent_id"]. La capa valida
    referencias y ciclos, pero nunca modifica el catálogo institucional.
    """

    def __init__(self, catalog: CategoryCatalog) -> None:
        self._by_id: dict[str, CategoryDefinition] = {
            item.category_id: item for item in catalog.categories
        }
        self._parent: dict[str, str | None] = {}

        for item in catalog.categories:
            metadata = item.metadata or {}
            raw_parent = metadata.get("parent_id")
            parent_id = str(raw_parent).strip() if raw_parent else None

            if parent_id and parent_id not in self._by_id:
                raise ValueError(
                    f"Unknown parent category {parent_id!r} for {item.category_id!r}"
                )
            if parent_id == item.category_id:
                raise ValueError(f"Category {item.category_id!r} cannot parent itself")

            self._parent[item.category_id] = parent_id

        for category_id in self._by_id:
            self._validate_no_cycle(category_id)

    def _validate_no_cycle(self, category_id: str) -> None:
        seen: set[str] = set()
        current: str | None = category_id

        while current is not None:
            if current in seen:
                raise ValueError(f"Category hierarchy cycle detected at {current!r}")
            seen.add(current)
            current = self._parent.get(current)

    def lineage(self, category_id: str) -> tuple[CategoryNode, ...]:
        if category_id not in self._by_id:
            raise KeyError(category_id)

        chain: list[CategoryNode] = []
        current: str | None = category_id

        while current is not None:
            definition = self._by_id[current]
            parent_id = self._parent[current]
            chain.append(
                CategoryNode(
                    category_id=definition.category_id,
                    name=definition.name,
                    parent_id=parent_id,
                )
            )
            current = parent_id

        chain.reverse()
        return tuple(chain)

    def principal(self, category_id: str) -> CategoryNode:
        return self.lineage(category_id)[0]

    def subcategories(self, category_id: str) -> tuple[CategoryNode, ...]:
        lineage = self.lineage(category_id)
        return lineage[1:]

    def children(self, category_id: str) -> tuple[CategoryNode, ...]:
        if category_id not in self._by_id:
            raise KeyError(category_id)

        nodes = [
            CategoryNode(
                category_id=item.category_id,
                name=item.name,
                parent_id=self._parent[item.category_id],
            )
            for item in self._by_id.values()
            if self._parent[item.category_id] == category_id
        ]
        return tuple(sorted(nodes, key=lambda item: item.category_id))
'@
    $Files["src\sgoda\integration\spt0233\proposal.py"] = @'
from __future__ import annotations

import hashlib
import json
import unicodedata
from dataclasses import dataclass
from typing import Iterable


def _normalize(value: object) -> str:
    text = str(value or "").strip()
    text = unicodedata.normalize("NFKD", text)
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    return text.casefold()


@dataclass(frozen=True)
class CategoryProposal:
    proposal_id: str
    proposed_name: str
    normalized_name: str
    status: str = "PROPOSED_FOR_HUMAN_REVIEW"
    automatic_creation: bool = False
    requires_human_validation: bool = True

    def to_dict(self) -> dict[str, object]:
        return {
            "proposal_id": self.proposal_id,
            "proposed_name": self.proposed_name,
            "normalized_name": self.normalized_name,
            "status": self.status,
            "automatic_creation": self.automatic_creation,
            "requires_human_validation": self.requires_human_validation,
        }


def build_category_proposal(evidence: Iterable[str]) -> CategoryProposal | None:
    candidates = [str(value).strip() for value in evidence if str(value).strip()]
    if not candidates:
        return None

    proposed_name = candidates[0]
    normalized = _normalize(proposed_name)
    if not normalized:
        return None

    canonical = json.dumps(
        {"normalized_name": normalized},
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")

    proposal_id = "CAT-PROP-" + hashlib.sha256(canonical).hexdigest()[:12].upper()

    return CategoryProposal(
        proposal_id=proposal_id,
        proposed_name=proposed_name,
        normalized_name=normalized,
    )
'@
    $Files["src\sgoda\integration\spt0233\traceability.py"] = @'
from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class CategoryDecisionTrace:
    decision_id: str
    source_component: str
    target_component: str
    source_index: int
    lexical_hash: str
    status: str
    principal_category_id: str | None
    selected_category_id: str | None
    confidence: float
    proposal_id: str | None

    def to_dict(self) -> dict[str, Any]:
        return {
            "decision_id": self.decision_id,
            "source_component": self.source_component,
            "target_component": self.target_component,
            "source_index": self.source_index,
            "lexical_hash": self.lexical_hash,
            "status": self.status,
            "principal_category_id": self.principal_category_id,
            "selected_category_id": self.selected_category_id,
            "confidence": self.confidence,
            "proposal_id": self.proposal_id,
        }


def build_trace(
    *,
    source_index: int,
    lexical_hash: str,
    status: str,
    principal_category_id: str | None,
    selected_category_id: str | None,
    confidence: float,
    proposal_id: str | None,
) -> CategoryDecisionTrace:
    payload = {
        "source_component": "SPT-023.2",
        "target_component": "SPT-023.3",
        "source_index": int(source_index),
        "lexical_hash": str(lexical_hash or ""),
        "status": status,
        "principal_category_id": principal_category_id,
        "selected_category_id": selected_category_id,
        "confidence": round(float(confidence), 6),
        "proposal_id": proposal_id,
    }
    canonical = json.dumps(
        payload,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    decision_id = "SPT0233-" + hashlib.sha256(canonical).hexdigest()[:16].upper()

    return CategoryDecisionTrace(
        decision_id=decision_id,
        **payload,
    )
'@
    $Files["src\sgoda\integration\spt0233\layer2.py"] = @'
from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Iterable

from .catalog import CategoryCatalog
from .hierarchy import CategoryHierarchy
from .proposal import CategoryProposal, build_category_proposal
from .traceability import CategoryDecisionTrace, build_trace


_EVIDENCE_KEYS = (
    "category",
    "categories",
    "semantic_category",
    "semantic_categories",
    "domain",
    "domains",
    "label",
    "labels",
    "part_of_speech",
    "pos",
)


def _flatten(value: object) -> list[str]:
    out: list[str] = []

    if value is None:
        return out
    if isinstance(value, str):
        text = value.strip()
        if text:
            out.append(text)
        return out
    if isinstance(value, dict):
        for key, item in value.items():
            if str(key).casefold() in _EVIDENCE_KEYS:
                out.extend(_flatten(item))
        return out
    if isinstance(value, (list, tuple, set)):
        for item in value:
            out.extend(_flatten(item))
        return out

    return out


@dataclass(frozen=True)
class Layer2Classification:
    source_index: int
    puinave: str
    lexical_hash: str
    status: str
    principal_category_id: str | None
    principal_category_name: str | None
    selected_category_id: str | None
    selected_category_name: str | None
    subcategory_ids: tuple[str, ...]
    confidence: float
    reasons: tuple[str, ...]
    proposal: CategoryProposal | None
    trace: CategoryDecisionTrace
    automatic_category_creation: bool = False
    requires_human_validation: bool = True

    def to_dict(self) -> dict[str, Any]:
        return {
            "source_index": self.source_index,
            "puinave": self.puinave,
            "lexical_hash": self.lexical_hash,
            "status": self.status,
            "principal_category_id": self.principal_category_id,
            "principal_category_name": self.principal_category_name,
            "selected_category_id": self.selected_category_id,
            "selected_category_name": self.selected_category_name,
            "subcategory_ids": list(self.subcategory_ids),
            "confidence": self.confidence,
            "reasons": list(self.reasons),
            "proposal": None if self.proposal is None else self.proposal.to_dict(),
            "trace": self.trace.to_dict(),
            "automatic_category_creation": self.automatic_category_creation,
            "requires_human_validation": self.requires_human_validation,
        }


class Spt0233Layer2Classifier:
    """Capa 2: reutilización, jerarquía, confianza, propuestas y trazabilidad."""

    def __init__(
        self,
        catalog: CategoryCatalog,
        minimum_confidence: float = 0.85,
    ) -> None:
        self.catalog = catalog
        self.hierarchy = CategoryHierarchy(catalog)
        self.minimum_confidence = max(0.0, min(1.0, float(minimum_confidence)))

    @staticmethod
    def _eligible(item: dict[str, Any]) -> bool:
        decision = str(
            item.get("institutional_decision")
            or item.get("decision")
            or ""
        ).strip().upper()

        if decision == "READY_FOR_CATEGORY":
            return True

        return (
            bool(item.get("downstream_allowed"))
            and str(item.get("semantic_status") or "").strip().upper() == "MATCHED"
        )

    @staticmethod
    def _evidence(item: dict[str, Any]) -> list[str]:
        evidence: list[str] = []
        evidence.extend(_flatten(item.get("semantic_candidates")))
        evidence.extend(_flatten(item.get("metadata")))
        evidence.extend(_flatten(item.get("context")))
        return evidence

    def classify(self, item: dict[str, Any]) -> Layer2Classification:
        source_index = int(item.get("source_index") or 0)
        puinave = str(item.get("puinave") or "").strip()
        lexical_hash = str(item.get("lexical_hash") or "").strip()

        if not self._eligible(item):
            trace = build_trace(
                source_index=source_index,
                lexical_hash=lexical_hash,
                status="NOT_ELIGIBLE",
                principal_category_id=None,
                selected_category_id=None,
                confidence=0.0,
                proposal_id=None,
            )
            return Layer2Classification(
                source_index=source_index,
                puinave=puinave,
                lexical_hash=lexical_hash,
                status="NOT_ELIGIBLE",
                principal_category_id=None,
                principal_category_name=None,
                selected_category_id=None,
                selected_category_name=None,
                subcategory_ids=(),
                confidence=0.0,
                reasons=("input_not_ready_for_category",),
                proposal=None,
                trace=trace,
            )

        evidence = self._evidence(item)
        ranked = self.catalog.rank(evidence)

        if not ranked:
            proposal = build_category_proposal(evidence)
            status = "PROPOSAL_REQUIRED" if proposal is not None else "REVIEW_REQUIRED"
            reason = (
                "no_existing_category_match"
                if proposal is not None
                else "insufficient_category_evidence"
            )
            trace = build_trace(
                source_index=source_index,
                lexical_hash=lexical_hash,
                status=status,
                principal_category_id=None,
                selected_category_id=None,
                confidence=0.0,
                proposal_id=None if proposal is None else proposal.proposal_id,
            )
            return Layer2Classification(
                source_index=source_index,
                puinave=puinave,
                lexical_hash=lexical_hash,
                status=status,
                principal_category_id=None,
                principal_category_name=None,
                selected_category_id=None,
                selected_category_name=None,
                subcategory_ids=(),
                confidence=0.0,
                reasons=(reason,),
                proposal=proposal,
                trace=trace,
            )

        best_score = ranked[0][0]
        best = [entry for entry in ranked if entry[0] == best_score]

        if len(best) != 1:
            trace = build_trace(
                source_index=source_index,
                lexical_hash=lexical_hash,
                status="AMBIGUOUS",
                principal_category_id=None,
                selected_category_id=None,
                confidence=best_score,
                proposal_id=None,
            )
            return Layer2Classification(
                source_index=source_index,
                puinave=puinave,
                lexical_hash=lexical_hash,
                status="AMBIGUOUS",
                principal_category_id=None,
                principal_category_name=None,
                selected_category_id=None,
                selected_category_name=None,
                subcategory_ids=(),
                confidence=best_score,
                reasons=("multiple_existing_categories_match",),
                proposal=None,
                trace=trace,
            )

        score, selected, reason = best[0]

        if score < self.minimum_confidence:
            trace = build_trace(
                source_index=source_index,
                lexical_hash=lexical_hash,
                status="REVIEW_REQUIRED",
                principal_category_id=None,
                selected_category_id=selected.category_id,
                confidence=score,
                proposal_id=None,
            )
            return Layer2Classification(
                source_index=source_index,
                puinave=puinave,
                lexical_hash=lexical_hash,
                status="REVIEW_REQUIRED",
                principal_category_id=None,
                principal_category_name=None,
                selected_category_id=selected.category_id,
                selected_category_name=selected.name,
                subcategory_ids=(),
                confidence=score,
                reasons=("confidence_below_threshold", reason),
                proposal=None,
                trace=trace,
            )

        lineage = self.hierarchy.lineage(selected.category_id)
        principal = lineage[0]
        subcategories = tuple(node.category_id for node in lineage[1:])

        trace = build_trace(
            source_index=source_index,
            lexical_hash=lexical_hash,
            status="ASSIGNED",
            principal_category_id=principal.category_id,
            selected_category_id=selected.category_id,
            confidence=score,
            proposal_id=None,
        )

        return Layer2Classification(
            source_index=source_index,
            puinave=puinave,
            lexical_hash=lexical_hash,
            status="ASSIGNED",
            principal_category_id=principal.category_id,
            principal_category_name=principal.name,
            selected_category_id=selected.category_id,
            selected_category_name=selected.name,
            subcategory_ids=subcategories,
            confidence=score,
            reasons=(reason, "existing_category_reused"),
            proposal=None,
            trace=trace,
        )

    def classify_batch(
        self,
        payload: dict[str, Any] | Iterable[dict[str, Any]],
    ) -> dict[str, Any]:
        if isinstance(payload, dict):
            records = payload.get("results", [])
            source_batch_hash = payload.get("source_batch_hash")
        else:
            records = payload
            source_batch_hash = None

        results = [
            self.classify(item)
            for item in records
            if isinstance(item, dict)
        ]

        counts: dict[str, int] = {}
        for result in results:
            counts[result.status] = counts.get(result.status, 0) + 1

        return {
            "component": "SPT-023.3",
            "layer": "2",
            "source_component": "SPT-023.2",
            "source_batch_hash": source_batch_hash,
            "records_processed": len(results),
            "status_counts": counts,
            "automatic_category_creation": False,
            "requires_human_validation": True,
            "next_component": "SPT-023.3-CAPA-3",
            "results": [result.to_dict() for result in results],
        }
'@
    $Files["tests\integration\test_spt0233_category_engine_layer2.py"] = @'
from sgoda.integration.spt0233.catalog import CategoryCatalog
from sgoda.integration.spt0233.hierarchy import CategoryHierarchy
from sgoda.integration.spt0233.layer2 import Spt0233Layer2Classifier
from sgoda.integration.spt0233.proposal import build_category_proposal


def catalog():
    return CategoryCatalog(
        [
            {
                "id": "CAT-NATURE",
                "name": "Naturaleza",
                "aliases": ["naturaleza"],
                "keywords": ["entorno"],
            },
            {
                "id": "CAT-ANIMAL",
                "name": "Animales",
                "aliases": ["animal"],
                "keywords": ["fauna"],
                "metadata": {"parent_id": "CAT-NATURE"},
            },
            {
                "id": "CAT-BIRD",
                "name": "Aves",
                "aliases": ["ave"],
                "keywords": ["pajaro"],
                "metadata": {"parent_id": "CAT-ANIMAL"},
            },
            {
                "id": "CAT-PLANT",
                "name": "Plantas",
                "aliases": ["planta"],
                "keywords": ["flora"],
                "metadata": {"parent_id": "CAT-NATURE"},
            },
        ]
    )


def ready(**extra):
    item = {
        "source_index": 7,
        "puinave": "AMDA",
        "lexical_hash": "lex-001",
        "institutional_decision": "READY_FOR_CATEGORY",
        "semantic_candidates": [],
        "metadata": {},
        "context": {},
    }
    item.update(extra)
    return item


def test_hierarchy_resolves_principal_category():
    hierarchy = CategoryHierarchy(catalog())
    principal = hierarchy.principal("CAT-BIRD")
    assert principal.category_id == "CAT-NATURE"


def test_hierarchy_resolves_nested_subcategories():
    hierarchy = CategoryHierarchy(catalog())
    assert [item.category_id for item in hierarchy.subcategories("CAT-BIRD")] == [
        "CAT-ANIMAL",
        "CAT-BIRD",
    ]


def test_exact_match_reuses_existing_category():
    classifier = Spt0233Layer2Classifier(catalog())
    result = classifier.classify(
        ready(semantic_candidates=[{"category": "Aves"}])
    )
    assert result.status == "ASSIGNED"
    assert result.principal_category_id == "CAT-NATURE"
    assert result.selected_category_id == "CAT-BIRD"
    assert result.subcategory_ids == ("CAT-ANIMAL", "CAT-BIRD")
    assert result.confidence == 1.0


def test_keyword_match_reuses_existing_category_with_confidence():
    classifier = Spt0233Layer2Classifier(catalog())
    result = classifier.classify(
        ready(semantic_candidates=[{"domain": "flora"}])
    )
    assert result.status == "ASSIGNED"
    assert result.selected_category_id == "CAT-PLANT"
    assert result.confidence == 0.85


def test_no_existing_match_creates_proposal_only():
    cat = catalog()
    before = cat.categories
    classifier = Spt0233Layer2Classifier(cat)
    result = classifier.classify(
        ready(semantic_candidates=[{"category": "Astronomia"}])
    )
    assert result.status == "PROPOSAL_REQUIRED"
    assert result.proposal is not None
    assert result.proposal.automatic_creation is False
    assert cat.categories == before


def test_proposal_is_deterministic():
    one = build_category_proposal(["Astronomia"])
    two = build_category_proposal(["Astronomia"])
    assert one is not None
    assert two is not None
    assert one.proposal_id == two.proposal_id


def test_empty_category_evidence_requires_review_without_proposal():
    classifier = Spt0233Layer2Classifier(catalog())
    result = classifier.classify(ready())
    assert result.status == "REVIEW_REQUIRED"
    assert result.proposal is None


def test_ambiguous_best_match_requires_review():
    classifier = Spt0233Layer2Classifier(catalog())
    result = classifier.classify(
        ready(
            semantic_candidates=[
                {"category": "Aves"},
                {"category": "Plantas"},
            ]
        )
    )
    assert result.status == "AMBIGUOUS"
    assert result.selected_category_id is None


def test_not_eligible_input_is_blocked():
    classifier = Spt0233Layer2Classifier(catalog())
    result = classifier.classify(
        ready(institutional_decision="HUMAN_REVIEW_REQUIRED")
    )
    assert result.status == "NOT_ELIGIBLE"


def test_traceability_decision_id_is_deterministic():
    classifier = Spt0233Layer2Classifier(catalog())
    item = ready(semantic_candidates=[{"category": "Aves"}])
    one = classifier.classify(item)
    two = classifier.classify(item)
    assert one.trace.decision_id == two.trace.decision_id


def test_batch_contract_reports_status_counts():
    classifier = Spt0233Layer2Classifier(catalog())
    batch = classifier.classify_batch(
        {
            "source_batch_hash": "batch-001",
            "results": [
                ready(semantic_candidates=[{"category": "Aves"}]),
                ready(
                    source_index=8,
                    lexical_hash="lex-002",
                    semantic_candidates=[{"category": "Astronomia"}],
                ),
            ],
        }
    )
    assert batch["records_processed"] == 2
    assert batch["status_counts"]["ASSIGNED"] == 1
    assert batch["status_counts"]["PROPOSAL_REQUIRED"] == 1
    assert batch["automatic_category_creation"] is False


def test_invalid_hierarchy_parent_is_rejected():
    broken = CategoryCatalog(
        [
            {
                "id": "CAT-X",
                "name": "X",
                "metadata": {"parent_id": "CAT-NOT-FOUND"},
            }
        ]
    )
    try:
        CategoryHierarchy(broken)
    except ValueError:
        pass
    else:
        raise AssertionError("unknown parent must fail")
'@
    $Files["docs\06_Tecnologia\SPT-023.3\SGD-SPT023.3-Capa2-Inteligencia-Clasificacion.md"] = @'
# SPT-023.3 — Capa 2 — Inteligencia de Clasificación y Reutilización

## Objetivo

Completar la segunda capa del Catálogo Institucional de Categorías sin
reconstruir la Capa 1.

La Capa 2 añade:

- resolución de categoría principal;
- manejo jerárquico de subcategorías;
- reutilización prioritaria de categorías existentes;
- evaluación de confianza;
- detección de ambigüedad;
- propuesta controlada de nueva categoría cuando no exista coincidencia;
- trazabilidad determinística de cada decisión.

## Reglas institucionales

1. SPT-023.2 continúa siendo la fuente semántica.
2. La Capa 1 de SPT-023.3 permanece congelada y se reutiliza.
3. No se crean categorías institucionales automáticamente.
4. Toda nueva categoría es solamente una propuesta para validación humana.
5. La asignación principal y las subcategorías se derivan de la jerarquía
   existente del catálogo.
6. Las decisiones ambiguas o con confianza insuficiente se bloquean para
   revisión humana.
7. Cada decisión genera un identificador determinístico de trazabilidad.
8. El siguiente desarrollo permanece dentro de SPT-023.3 hasta completar
   el alcance institucional del Catálogo.

## Estados de decisión

- `ASSIGNED`: categoría existente reutilizada.
- `AMBIGUOUS`: múltiples categorías con la misma mejor evidencia.
- `REVIEW_REQUIRED`: evidencia insuficiente o confianza baja.
- `PROPOSAL_REQUIRED`: no existe categoría adecuada y se genera propuesta.
- `NOT_ELIGIBLE`: la entrada no fue habilitada por el flujo semántico.

## Seguridad

La Capa 2 no modifica SPT-023.1, SPT-023.2 ni SPT-023.3 Capa 1.
Su cierre requiere SHA-256 sin cambios sobre esos componentes, pruebas
específicas, suite institucional completa, actualización de SGD-002,
evidencia, publicación Git y verificación local/remota.
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
        "src\sgoda\integration\spt0233\hierarchy.py",
        "src\sgoda\integration\spt0233\proposal.py",
        "src\sgoda\integration\spt0233\traceability.py",
        "src\sgoda\integration\spt0233\layer2.py",
        "tests\integration\test_spt0233_category_engine_layer2.py"
    ) | ForEach-Object { Join-Path $Root $_ }

    & $VenvPython -m py_compile @PyFiles
    if ($LASTEXITCODE -ne 0) { throw "Python syntax prevalidation failed." }

    $Previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $TargetOutput = @(& $VenvPython -m pytest "tests/integration/test_spt0233_category_engine_layer2.py" -q 2>&1)
        $TargetCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $Previous
    }

    $TargetOutput | ForEach-Object { Write-Host $_ }
    if ($TargetCode -ne 0) { throw "Targeted Capa 2 tests failed." }

    $TargetText = ($TargetOutput | ForEach-Object { [string]$_ }) -join "`n"
    $TargetMatch = [regex]::Match($TargetText, '(\d+)\s+passed')
    if (-not $TargetMatch.Success) { throw "Unable to certify targeted test count." }

    $TargetPassed = [int]$TargetMatch.Groups[1].Value
    if ($TargetPassed -lt $ExpectedTargetedTests) {
        throw "Targeted test count below expected $ExpectedTargetedTests."
    }

    Write-Host "TARGETED TESTS : $TargetPassed PASSED" -ForegroundColor Green

    Write-Host ""
    Write-Host "[6/12] INSTITUTIONAL SUITE" -ForegroundColor Yellow

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
    if ($SuiteCode -ne 0) { throw "Institutional pytest suite failed." }

    $SuiteText = ($SuiteOutput | ForEach-Object { [string]$_ }) -join "`n"
    $SuiteMatch = [regex]::Match($SuiteText, '(\d+)\s+passed')
    if (-not $SuiteMatch.Success) { throw "Unable to certify institutional test count." }

    $SuitePassed = [int]$SuiteMatch.Groups[1].Value
    if ($SuitePassed -lt $ExpectedFullSuiteMinimum) {
        throw "Institutional suite below expected minimum $ExpectedFullSuiteMinimum."
    }

    & $VenvPython -m compileall -q src
    if ($LASTEXITCODE -ne 0) { throw "Python compileall failed." }

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
    Write-Host "[8/12] EVIDENCE + SGD-002 UPDATE" -ForegroundColor Yellow

    $EvidencePath = Join-Path $Root "artifacts\development\SPT-023.3-Capa2-v1.0.0\implementation-evidence.json"
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
        layer = "2"
        title = "Inteligencia de Clasificacion y Reutilizacion"
        generated_utc = [DateTime]::UtcNow.ToString("o")
        certified_baseline = $ExpectedBaseline
        source_component = "SPT-023.2"
        targeted_tests_passed = $TargetPassed
        institutional_tests_passed = $SuitePassed
        protected_files = $ProtectedBefore.Count
        protected_files_changed = $ChangedProtected.Count
        category_reuse = $true
        hierarchy_support = $true
        subcategory_support = $true
        controlled_proposals = $true
        automatic_category_creation = $false
        traceability = $true
        generated_files = $Generated
    }

    Write-Utf8Lf -Path $EvidencePath -Content ($Evidence | ConvertTo-Json -Depth 8) -TrackCreated

    $MasterAppend = @"

$Marker
## SPT-023.3 Capa 2 — Inteligencia de Clasificación y Reutilización

- Estado técnico: QUALITY GATE PASS.
- Línea base certificada: `$ExpectedBaseline`.
- Pruebas específicas: `$TargetPassed` aprobadas.
- Suite institucional: `$SuitePassed` aprobadas.
- Categorías existentes: reutilización prioritaria.
- Subcategorías: jerarquía institucional habilitada.
- Nuevas categorías: propuesta controlada; creación automática deshabilitada.
- Trazabilidad: decisión determinística habilitada.
- Componentes cerrados anteriores: preservados por SHA-256.
- Publicación: gestionada por la misma transacción PowerShell de Capa 2.
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
    $Allowed += "artifacts/development/SPT-023.3-Capa2-v1.0.0/implementation-evidence.json"
    $Allowed += "docs/00_Estado_Maestro/SGD-002-Libro-Maestro-Institucional-SGODA-PUINAVE-v1.0.0.md"
    $Allowed += $ScriptRel
    $Allowed = @($Allowed | Sort-Object -Unique)

    & git reset -q HEAD --
    if ($LASTEXITCODE -ne 0) { throw "Unable to guarantee clean index." }

    & git -c core.safecrlf=false add -- @Allowed
    if ($LASTEXITCODE -ne 0) { throw "Controlled staging failed." }

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
    if ($LASTEXITCODE -ne 0) { throw "git diff --cached --check failed." }

    Write-Host "STAGING QUALITY : PASS" -ForegroundColor Green

    Write-Host ""
    Write-Host "[10/12] FINAL REMOTE GATE" -ForegroundColor Yellow

    & git fetch origin $Branch --no-tags
    if ($LASTEXITCODE -ne 0) { throw "Final fetch failed." }

    $HeadBeforeCommit = Git-One @("rev-parse","HEAD")
    $RemoteBeforeCommit = Git-One @("rev-parse","origin/$Branch")

    if ($HeadBeforeCommit -ne $ExpectedBaseline -or $RemoteBeforeCommit -ne $ExpectedBaseline) {
        throw "Repository moved during Capa 2 transaction."
    }

    Write-Host "REMOTE GATE : PASS" -ForegroundColor Green

    Write-Host ""
    Write-Host "[11/12] COMMIT + PUSH" -ForegroundColor Yellow

    & git commit -m $CommitMessage
    if ($LASTEXITCODE -ne 0) { throw "Commit failed." }

    $CommitCreated = $true
    $NewHead = Git-One @("rev-parse","HEAD")
    Write-Host "NEW COMMIT : $NewHead"

    & git push origin $Branch
    if ($LASTEXITCODE -ne 0) {
        throw "Push failed. Re-run this SAME file to resume; do not create another script."
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

    if ($LocalFinal -ne $RemoteFinal) { throw "Local/remote mismatch after publication." }
    if ($AheadFinal -ne 0 -or $BehindFinal -ne 0) { throw "Repository divergence after publication." }
    if ($StagedFinal -ne 0) { throw "Staging is not clean after publication." }
    if ($DeletedFinal -ne 0) { throw "Tracked deletions detected after publication." }

    Emit-FinalBanner -Commit $LocalFinal -Targeted $TargetPassed -FullSuite $SuitePassed
    exit 0
}
catch {
    Fail $_.Exception.Message
}
