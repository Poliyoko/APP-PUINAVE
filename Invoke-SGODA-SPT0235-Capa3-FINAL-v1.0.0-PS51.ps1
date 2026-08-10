param(
    [string]$ProjectRoot = "",
    [string]$ExpectedBaseline = "9768f0486805a1a8fbc2f4ff9f84a5adaca884ae"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$CommitMessage = "feat(spt-023.5): close FLD ODA publication governance layer 3"
$ExpectedTargetedTests = 18
$ExpectedFullSuiteMinimum = 1010
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
    Write-Output " SPT-023.5 CAPA 3 : INSTITUTIONALLY CLOSED"
    Write-Output " SPT-023.5        : INSTITUTIONALLY CLOSED"
    Write-Output " COMMIT           : $Commit"
    Write-Output " TARGETED TESTS   : $Targeted PASSED"
    Write-Output " FULL SUITE       : $FullSuite PASSED"
    Write-Output " CAPAS 1-2        : PRESERVED"
    Write-Output " SPT-023.1-.4     : PRESERVED"
    Write-Output " SGD-002          : UPDATED"
    Write-Output " LOCAL/REMOTE     : IDENTICAL"
    Write-Output " AHEAD            : 0"
    Write-Output " BEHIND           : 0"
    Write-Output " STAGING          : CLEAN"
    Write-Output " DELETED TRACKED  : 0"
    Write-Output " ERRORS PENDING   : 0"
    Write-Output " NEXT             : SPT-023.6 ORQUESTADOR INTELIGENTE"
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
    Write-Output " SPT-023.5 CAPA 3 : HOLD"
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
    Write-Output " SGODA-PUINAVE - SPT-023.5 CAPA 3 - FINAL MASTER TRANSACTION"
    Write-Output " PUBLICATION GOVERNANCE / MANIFEST / CATALOG / CLOSE SPT-023.5"
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
            $EvidenceResume = Join-Path $Root "artifacts\development\SPT-023.5-Capa3-v1.0.0\implementation-evidence.json"
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

        throw "HEAD is neither certified baseline nor a resumable SPT-023.5 Capa 3 commit."
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
            $_ -match '(?i)SPT-023\.[12345]' -or
            $_ -match '(?i)spt023[12345]'
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
        "src\sgoda\integration\spt0235\publication.py",
        "src\sgoda\integration\spt0235\manifest.py",
        "src\sgoda\integration\spt0235\catalog.py",
        "src\sgoda\integration\spt0235\layer3.py",
        "tests\integration\test_spt0235_publication_governance_layer3.py",
        "docs\06_Tecnologia\SPT-023.5\SGD-SPT023.5-Capa3-Gobernanza-Publicacion-Cierre.md",
        "config\integration\spt0235\publication-governance.json",
        "artifacts\development\SPT-023.5-Capa3-v1.0.0\implementation-evidence.json"
    )

    foreach ($Rel in $Targets) {
        if (Test-Path -LiteralPath (Join-Path $Root $Rel)) {
            throw "Target already exists before fresh SPT-023.5 Capa 3 transaction: $Rel"
        }
    }

    $MasterBookPath = Join-Path $Root "docs\00_Estado_Maestro\SGD-002-Libro-Maestro-Institucional-SGODA-PUINAVE-v1.0.0.md"
    if (-not (Test-Path -LiteralPath $MasterBookPath -PathType Leaf)) {
        throw "SGD-002 master book not found."
    }

    $MasterBookOriginal = [System.IO.File]::ReadAllText($MasterBookPath)
    $Marker = "<!-- SPT-023.5-CAPA3-CLOSE-V1.0.0 -->"
    if ($MasterBookOriginal.Contains($Marker)) {
        throw "SGD-002 already contains SPT-023.5 Capa 3 closure marker while HEAD is baseline."
    }

    Write-Host "TARGET COLLISIONS : 0" -ForegroundColor Green

    Write-Host ""
    Write-Host "[4/12] IMPLEMENT SPT-023.5 CAPA 3" -ForegroundColor Yellow

    $Files = @{}
    $Files["src\sgoda\integration\spt0235\publication.py"] = @'
from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class PublicationDecision:
    lexical_id: str
    version: int
    status: str
    approved: bool
    reviewer: str
    reason: str
    fld_sha256: str
    oda_sha256: str
    version_sha256: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "lexical_id": self.lexical_id,
            "version": self.version,
            "status": self.status,
            "approved": self.approved,
            "reviewer": self.reviewer,
            "reason": self.reason,
            "fld_sha256": self.fld_sha256,
            "oda_sha256": self.oda_sha256,
            "version_sha256": self.version_sha256,
        }


def review_for_publication(
    stored_version: dict[str, Any],
    *,
    lexical_id: str,
    approve: bool,
    reviewer: str,
    reason: str,
) -> PublicationDecision:
    lexical_id = str(lexical_id or "").strip()
    reviewer = str(reviewer or "").strip()
    reason = str(reason or "").strip()

    if not lexical_id:
        raise ValueError("lexical_id is required.")
    if not reviewer:
        raise ValueError("Human reviewer is required.")
    if not reason:
        raise ValueError("Publication decision reason is required.")

    version = int(stored_version.get("version", 0))
    if version < 1:
        raise ValueError("Stored FLD/ODA version is invalid.")

    fld = dict(stored_version.get("fld") or {})
    oda = dict(stored_version.get("oda") or {})
    version_sha256 = str(stored_version.get("version_sha256") or "").strip()

    if fld.get("object_type") != "FLD":
        raise ValueError("Stored FLD is invalid.")
    if oda.get("object_type") != "ODA":
        raise ValueError("Stored ODA is invalid.")
    if str(fld.get("lexical_id") or "") != lexical_id:
        raise ValueError("FLD lexical_id mismatch.")
    if str(oda.get("lexical_id") or "") != lexical_id:
        raise ValueError("ODA lexical_id mismatch.")
    if str(oda.get("source_fld_sha256") or "") != str(fld.get("fld_sha256") or ""):
        raise ValueError("ODA does not reference the stored FLD hash.")
    if not version_sha256:
        raise ValueError("Stored version SHA-256 is required.")

    return PublicationDecision(
        lexical_id=lexical_id,
        version=version,
        status="APPROVED_FOR_PUBLICATION" if approve else "PUBLICATION_REJECTED",
        approved=bool(approve),
        reviewer=reviewer,
        reason=reason,
        fld_sha256=str(fld["fld_sha256"]),
        oda_sha256=str(oda["oda_sha256"]),
        version_sha256=version_sha256,
    )
'@
    $Files["src\sgoda\integration\spt0235\manifest.py"] = @'
from __future__ import annotations

import hashlib
import json
from typing import Any


def _canonical(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def build_publication_manifest(
    *,
    decision: dict[str, Any],
    registry_validation: dict[str, Any],
) -> dict[str, Any]:
    if not bool(decision.get("approved")):
        raise ValueError("Publication manifest requires an approved decision.")
    if str(decision.get("status")) != "APPROVED_FOR_PUBLICATION":
        raise ValueError("Publication decision status is invalid.")
    if not bool(registry_validation.get("references_valid")):
        raise ValueError("Registry references must be valid.")

    payload = {
        "schema_version": "1.0.0",
        "component": "SPT-023.5",
        "layer": "3",
        "lexical_id": str(decision["lexical_id"]),
        "version": int(decision["version"]),
        "fld_sha256": str(decision["fld_sha256"]),
        "oda_sha256": str(decision["oda_sha256"]),
        "version_sha256": str(decision["version_sha256"]),
        "reviewer": str(decision["reviewer"]),
        "reason": str(decision["reason"]),
        "publication_status": "READY_FOR_INSTITUTIONAL_REGISTRY",
        "references_valid": True,
        "paid_api_used": False,
    }
    payload["publication_manifest_sha256"] = hashlib.sha256(
        _canonical(payload)
    ).hexdigest().upper()
    return payload
'@
    $Files["src\sgoda\integration\spt0235\catalog.py"] = @'
from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any


class PublishedObjectCatalog:
    """Catálogo institucional local de objetos FLD/ODA publicados."""

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)

    def load(self) -> dict[str, Any]:
        if not self.path.exists():
            return {
                "schema_version": "1.0.0",
                "component": "SPT-023.5",
                "catalog_type": "PUBLISHED_FLD_ODA",
                "entries": {},
            }

        data = json.loads(self.path.read_text(encoding="utf-8"))
        if str(data.get("schema_version")) != "1.0.0":
            raise ValueError("Unsupported published catalog schema_version.")
        if data.get("catalog_type") != "PUBLISHED_FLD_ODA":
            raise ValueError("Invalid published catalog type.")
        if not isinstance(data.get("entries"), dict):
            raise ValueError("Published catalog entries must be an object.")
        return data

    def publish(self, manifest: dict[str, Any]) -> dict[str, Any]:
        if manifest.get("publication_status") != "READY_FOR_INSTITUTIONAL_REGISTRY":
            raise ValueError("Manifest is not ready for institutional registry.")

        lexical_id = str(manifest.get("lexical_id") or "").strip()
        version = int(manifest.get("version", 0))
        manifest_sha = str(manifest.get("publication_manifest_sha256") or "").strip()

        if not lexical_id or version < 1 or not manifest_sha:
            raise ValueError("Publication manifest identity is incomplete.")

        data = self.load()
        entries = dict(data["entries"])
        existing = list(entries.get(lexical_id) or [])

        duplicate = [
            item
            for item in existing
            if int(item.get("version", 0)) == version
        ]
        if duplicate:
            if str(duplicate[0].get("publication_manifest_sha256")) == manifest_sha:
                result = dict(duplicate[0])
                result["reused"] = True
                return result
            raise ValueError("Conflicting publication already exists for lexical version.")

        record = dict(manifest)
        record["reused"] = False
        existing.append(record)
        existing.sort(key=lambda item: int(item["version"]))
        entries[lexical_id] = existing
        data["entries"] = entries

        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_name(self.path.name + ".tmp")
        tmp.write_text(
            json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
            newline="\n",
        )
        os.replace(tmp, self.path)
        return record

    def get(self, lexical_id: str, version: int | None = None) -> dict[str, Any] | None:
        entries = self.load()["entries"].get(str(lexical_id))
        if not entries:
            return None

        if version is None:
            return dict(entries[-1])

        for item in entries:
            if int(item["version"]) == int(version):
                return dict(item)
        return None
'@
    $Files["src\sgoda\integration\spt0235\layer3.py"] = @'
from __future__ import annotations

from pathlib import Path
from typing import Any

from .catalog import PublishedObjectCatalog
from .manifest import build_publication_manifest
from .publication import review_for_publication
from .references import validate_object_references
from .registry import FldOdaRegistry


class Spt0235Layer3GovernanceService:
    """Gobernanza de publicación y cierre institucional de SPT-023.5."""

    def __init__(
        self,
        *,
        registry_path: str | Path,
        published_catalog_path: str | Path,
    ) -> None:
        self.registry = FldOdaRegistry(registry_path)
        self.catalog = PublishedObjectCatalog(published_catalog_path)

    def review_and_publish(
        self,
        *,
        lexical_id: str,
        reviewer: str,
        reason: str,
        approve: bool,
        version: int | None = None,
        require_multimedia_files: bool = False,
    ) -> dict[str, Any]:
        stored = self.registry.get(lexical_id, version=version)
        if stored is None:
            raise ValueError("Requested FLD/ODA object version was not found.")

        fld = dict(stored["fld"])
        oda = dict(stored["oda"])
        reference_validation = validate_object_references(
            fld,
            oda,
            require_files=require_multimedia_files,
        )

        decision = review_for_publication(
            stored,
            lexical_id=lexical_id,
            approve=approve,
            reviewer=reviewer,
            reason=reason,
        ).to_dict()

        if not decision["approved"]:
            return {
                "component": "SPT-023.5",
                "layer": "3",
                "status": "PUBLICATION_REJECTED",
                "lexical_id": lexical_id,
                "decision": decision,
                "reference_validation": reference_validation,
                "publication_manifest": None,
                "published_record": None,
                "spt0235_scope_complete": False,
                "next_component": "SPT-023.5-CAPA-3",
            }

        manifest = build_publication_manifest(
            decision=decision,
            registry_validation=reference_validation,
        )
        published = self.catalog.publish(manifest)

        return {
            "component": "SPT-023.5",
            "layer": "3",
            "status": "PUBLISHED_FLD_ODA",
            "lexical_id": lexical_id,
            "decision": decision,
            "reference_validation": reference_validation,
            "publication_manifest": manifest,
            "published_record": published,
            "spt0235_scope_complete": True,
            "paid_api_used": False,
            "next_component": "SPT-023.6",
        }
'@
    $Files["tests\integration\test_spt0235_publication_governance_layer3.py"] = @'
import pytest

from sgoda.integration.spt0235.catalog import PublishedObjectCatalog
from sgoda.integration.spt0235.layer3 import Spt0235Layer3GovernanceService
from sgoda.integration.spt0235.manifest import build_publication_manifest
from sgoda.integration.spt0235.publication import review_for_publication
from sgoda.integration.spt0235.registry import FldOdaRegistry


def objects():
    resources = {
        resource_type: {
            "resource_id": f"MM-{resource_type}",
            "resource_type": resource_type,
            "output_path": f"media/LEX-001/{resource_type}.bin",
            "sha256": "A" * 64,
        }
        for resource_type in (
            "image",
            "audio_puinave",
            "audio_es",
            "audio_en",
            "audio_it",
        )
    }
    fld = {
        "object_type": "FLD",
        "lexical_id": "LEX-001",
        "puinave": "AMDA",
        "multimedia_manifest_sha256": "M" * 64,
        "resources": resources,
        "fld_sha256": "F" * 64,
    }
    oda = {
        "object_type": "ODA",
        "lexical_id": "LEX-001",
        "source_fld_sha256": fld["fld_sha256"],
        "multimedia_manifest_sha256": fld["multimedia_manifest_sha256"],
        "oda_sha256": "O" * 64,
    }
    return fld, oda


def stored_version():
    fld, oda = objects()
    return {
        "version": 1,
        "fld": fld,
        "oda": oda,
        "version_sha256": "V" * 64,
    }


def test_publication_requires_reviewer():
    with pytest.raises(ValueError):
        review_for_publication(
            stored_version(),
            lexical_id="LEX-001",
            approve=True,
            reviewer="",
            reason="ok",
        )


def test_publication_requires_reason():
    with pytest.raises(ValueError):
        review_for_publication(
            stored_version(),
            lexical_id="LEX-001",
            approve=True,
            reviewer="r1",
            reason="",
        )


def test_publication_approval_status():
    decision = review_for_publication(
        stored_version(),
        lexical_id="LEX-001",
        approve=True,
        reviewer="r1",
        reason="approved",
    )
    assert decision.status == "APPROVED_FOR_PUBLICATION"
    assert decision.approved is True


def test_publication_rejection_status():
    decision = review_for_publication(
        stored_version(),
        lexical_id="LEX-001",
        approve=False,
        reviewer="r1",
        reason="rejected",
    )
    assert decision.status == "PUBLICATION_REJECTED"
    assert decision.approved is False


def test_publication_detects_lexical_mismatch():
    with pytest.raises(ValueError):
        review_for_publication(
            stored_version(),
            lexical_id="OTHER",
            approve=True,
            reviewer="r1",
            reason="approved",
        )


def test_manifest_requires_approved_decision():
    decision = review_for_publication(
        stored_version(),
        lexical_id="LEX-001",
        approve=False,
        reviewer="r1",
        reason="rejected",
    ).to_dict()
    with pytest.raises(ValueError):
        build_publication_manifest(
            decision=decision,
            registry_validation={"references_valid": True},
        )


def test_manifest_requires_valid_references():
    decision = review_for_publication(
        stored_version(),
        lexical_id="LEX-001",
        approve=True,
        reviewer="r1",
        reason="approved",
    ).to_dict()
    with pytest.raises(ValueError):
        build_publication_manifest(
            decision=decision,
            registry_validation={"references_valid": False},
        )


def test_manifest_sha_is_deterministic():
    decision = review_for_publication(
        stored_version(),
        lexical_id="LEX-001",
        approve=True,
        reviewer="r1",
        reason="approved",
    ).to_dict()
    validation = {"references_valid": True}
    one = build_publication_manifest(
        decision=decision,
        registry_validation=validation,
    )
    two = build_publication_manifest(
        decision=decision,
        registry_validation=validation,
    )
    assert one["publication_manifest_sha256"] == two["publication_manifest_sha256"]


def test_catalog_publishes_manifest(tmp_path):
    decision = review_for_publication(
        stored_version(),
        lexical_id="LEX-001",
        approve=True,
        reviewer="r1",
        reason="approved",
    ).to_dict()
    manifest = build_publication_manifest(
        decision=decision,
        registry_validation={"references_valid": True},
    )
    catalog = PublishedObjectCatalog(tmp_path / "published.json")
    result = catalog.publish(manifest)
    assert result["lexical_id"] == "LEX-001"
    assert result["version"] == 1


def test_catalog_reuses_identical_publication(tmp_path):
    decision = review_for_publication(
        stored_version(),
        lexical_id="LEX-001",
        approve=True,
        reviewer="r1",
        reason="approved",
    ).to_dict()
    manifest = build_publication_manifest(
        decision=decision,
        registry_validation={"references_valid": True},
    )
    catalog = PublishedObjectCatalog(tmp_path / "published.json")
    catalog.publish(manifest)
    second = catalog.publish(manifest)
    assert second["reused"] is True


def test_catalog_query_latest(tmp_path):
    decision = review_for_publication(
        stored_version(),
        lexical_id="LEX-001",
        approve=True,
        reviewer="r1",
        reason="approved",
    ).to_dict()
    manifest = build_publication_manifest(
        decision=decision,
        registry_validation={"references_valid": True},
    )
    catalog = PublishedObjectCatalog(tmp_path / "published.json")
    catalog.publish(manifest)
    assert catalog.get("LEX-001")["version"] == 1


def test_catalog_query_unknown_returns_none(tmp_path):
    catalog = PublishedObjectCatalog(tmp_path / "published.json")
    assert catalog.get("UNKNOWN") is None


def seed_registry(path):
    fld, oda = objects()
    registry = FldOdaRegistry(path)
    registry.save_entry(
        lexical_id="LEX-001",
        fld=fld,
        oda=oda,
    )
    return registry


def test_layer3_approved_flow_publishes(tmp_path):
    registry_path = tmp_path / "registry.json"
    seed_registry(registry_path)
    service = Spt0235Layer3GovernanceService(
        registry_path=registry_path,
        published_catalog_path=tmp_path / "published.json",
    )
    result = service.review_and_publish(
        lexical_id="LEX-001",
        reviewer="reviewer-01",
        reason="complete and validated",
        approve=True,
    )
    assert result["status"] == "PUBLISHED_FLD_ODA"
    assert result["spt0235_scope_complete"] is True


def test_layer3_rejection_does_not_publish(tmp_path):
    registry_path = tmp_path / "registry.json"
    seed_registry(registry_path)
    service = Spt0235Layer3GovernanceService(
        registry_path=registry_path,
        published_catalog_path=tmp_path / "published.json",
    )
    result = service.review_and_publish(
        lexical_id="LEX-001",
        reviewer="reviewer-01",
        reason="not ready",
        approve=False,
    )
    assert result["status"] == "PUBLICATION_REJECTED"
    assert result["published_record"] is None


def test_layer3_requires_existing_object(tmp_path):
    service = Spt0235Layer3GovernanceService(
        registry_path=tmp_path / "registry.json",
        published_catalog_path=tmp_path / "published.json",
    )
    with pytest.raises(ValueError):
        service.review_and_publish(
            lexical_id="LEX-404",
            reviewer="reviewer-01",
            reason="x",
            approve=True,
        )


def test_layer3_preserves_reference_validation(tmp_path):
    registry_path = tmp_path / "registry.json"
    seed_registry(registry_path)
    service = Spt0235Layer3GovernanceService(
        registry_path=registry_path,
        published_catalog_path=tmp_path / "published.json",
    )
    result = service.review_and_publish(
        lexical_id="LEX-001",
        reviewer="reviewer-01",
        reason="complete",
        approve=True,
    )
    assert result["reference_validation"]["references_valid"] is True


def test_layer3_disables_paid_api(tmp_path):
    registry_path = tmp_path / "registry.json"
    seed_registry(registry_path)
    service = Spt0235Layer3GovernanceService(
        registry_path=registry_path,
        published_catalog_path=tmp_path / "published.json",
    )
    result = service.review_and_publish(
        lexical_id="LEX-001",
        reviewer="reviewer-01",
        reason="complete",
        approve=True,
    )
    assert result["paid_api_used"] is False


def test_layer3_points_to_spt0236(tmp_path):
    registry_path = tmp_path / "registry.json"
    seed_registry(registry_path)
    service = Spt0235Layer3GovernanceService(
        registry_path=registry_path,
        published_catalog_path=tmp_path / "published.json",
    )
    result = service.review_and_publish(
        lexical_id="LEX-001",
        reviewer="reviewer-01",
        reason="complete",
        approve=True,
    )
    assert result["next_component"] == "SPT-023.6"
'@
    $Files["docs\06_Tecnologia\SPT-023.5\SGD-SPT023.5-Capa3-Gobernanza-Publicacion-Cierre.md"] = @'
# SPT-023.5 — Constructor FLD / ODA — Capa 3

## Objetivo

Cerrar funcional e institucionalmente SPT-023.5 mediante gobernanza de
publicación, manifiesto de publicación, catálogo institucional de objetos FLD/ODA
publicados e integración de salida hacia SPT-023.6.

## Gobernanza

La publicación exige decisión humana explícita con `reviewer` y `reason`.
Un rechazo conserva los objetos versionados pero no los incorpora al catálogo
de publicados.

## Validaciones previas

Antes de publicar se valida:

- existencia de la versión solicitada;
- coherencia de identificador léxico;
- enlace ODA -> hash FLD;
- igualdad del manifiesto multimedia;
- cinco referencias multimedia válidas;
- hash de versión disponible.

## Manifiesto de publicación

La aprobación produce un manifiesto SHA-256 determinístico con:

- identificador léxico;
- versión;
- hash FLD;
- hash ODA;
- hash de versión;
- revisor;
- razón;
- estado `READY_FOR_INSTITUTIONAL_REGISTRY`.

## Catálogo publicado

El catálogo publicado es local, JSON y atómico. Reutiliza de forma idempotente
una publicación idéntica y bloquea conflictos para la misma versión.

## Cierre

Con Capa 1, Capa 2 y Capa 3 aprobadas, SPT-023.5 queda completamente cerrado.
El siguiente paquete autorizado es **SPT-023.6 — Orquestador Inteligente**.
'@
    $Files["config\integration\spt0235\publication-governance.json"] = @'
{
  "schema_version": "1.0.0",
  "component": "SPT-023.5",
  "layer": "3",
  "human_publication_review_required": true,
  "reviewer_required": true,
  "reason_required": true,
  "validate_registry_version": true,
  "validate_fld_oda_link": true,
  "validate_multimedia_references": true,
  "publication_manifest_sha256": true,
  "published_catalog": "LOCAL_JSON_ATOMIC",
  "idempotent_publication": true,
  "paid_api_allowed": false,
  "spt0235_scope_complete_on_approval": true,
  "next_component": "SPT-023.6"
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
        "src\sgoda\integration\spt0235\publication.py",
        "src\sgoda\integration\spt0235\manifest.py",
        "src\sgoda\integration\spt0235\catalog.py",
        "src\sgoda\integration\spt0235\layer3.py",
        "tests\integration\test_spt0235_publication_governance_layer3.py"
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
                "tests/integration/test_spt0235_publication_governance_layer3.py" `
                -q 2>&1
        )
        $TargetCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $Previous
    }

    $TargetOutput | ForEach-Object { Write-Host $_ }
    if ($TargetCode -ne 0) {
        throw "Targeted SPT-023.5 Capa 3 tests failed."
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
    Write-Host "[8/12] EVIDENCE + SGD-002 FINAL SPT-023.5 CLOSURE" -ForegroundColor Yellow

    $EvidencePath = Join-Path $Root "artifacts\development\SPT-023.5-Capa3-v1.0.0\implementation-evidence.json"
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
        component = "SPT-023.5"
        layer = "3"
        title = "Gobernanza Publicacion y Cierre FLD ODA"
        generated_utc = [DateTime]::UtcNow.ToString("o")
        certified_baseline = $ExpectedBaseline
        targeted_tests_passed = $TargetPassed
        institutional_tests_passed = $SuitePassed
        protected_files = $ProtectedBefore.Count
        protected_files_changed = $ChangedProtected.Count
        human_publication_review = $true
        publication_manifest_sha256 = $true
        published_catalog = $true
        idempotent_publication = $true
        reference_validation = $true
        spt0235_scope_complete = $true
        paid_api_allowed = $false
        next_component = "SPT-023.6"
        generated_files = $Generated
    }

    Write-Utf8Lf -Path $EvidencePath -Content ($Evidence | ConvertTo-Json -Depth 8) -TrackCreated

    $MasterAppend = @"

$Marker
## SPT-023.5 — Constructor FLD / ODA — CIERRE

- Estado institucional: CLOSED.
- Capa 1: constructor FLD/ODA cerrado y preservado.
- Capa 2: registro, versionado, validación y consulta cerrados y preservados.
- Capa 3: gobernanza de publicación y catálogo institucional implementados.
- Línea base de entrada: `$ExpectedBaseline`.
- Pruebas específicas Capa 3: `$TargetPassed` aprobadas.
- Suite institucional: `$SuitePassed` aprobadas.
- Revisión humana de publicación: obligatoria.
- Validación FLD/ODA y referencias multimedia: obligatoria.
- Manifiesto de publicación: SHA-256 determinístico.
- Catálogo de objetos publicados: local, atómico e idempotente.
- APIs de pago: deshabilitadas.
- Componentes cerrados anteriores: preservados por SHA-256.
- SPT-023.5: alcance completo cerrado.
- Siguiente paquete autorizado: SPT-023.6 — Orquestador Inteligente.
"@

    $UpdatedMaster = $MasterBookOriginal.TrimEnd([char[]]@("`r","`n")) + "`n" + $MasterAppend.Replace("`r`n","`n").Replace("`r","`n").TrimStart([char[]]@("`r","`n"))

    [System.IO.File]::WriteAllText(
        $MasterBookPath,
        $UpdatedMaster,
        (New-Object System.Text.UTF8Encoding($false))
    )
    $MasterBookTouched = $true

    Write-Host "EVIDENCE : CREATED" -ForegroundColor Green
    Write-Host "SGD-002  : SPT-023.5 CLOSED" -ForegroundColor Green

    Write-Host ""
    Write-Host "[9/12] EXACT CONTROLLED STAGING" -ForegroundColor Yellow

    $Allowed = @(
        $Files.Keys | ForEach-Object { $_.Replace("\","/") }
    )
    $Allowed += "artifacts/development/SPT-023.5-Capa3-v1.0.0/implementation-evidence.json"
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
        throw "Repository moved during SPT-023.5 Capa 3 transaction."
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
