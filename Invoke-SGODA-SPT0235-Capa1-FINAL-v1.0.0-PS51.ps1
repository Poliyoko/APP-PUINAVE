param(
    [string]$ProjectRoot = "",
    [string]$ExpectedBaseline = "72ad012c4ffa690fbde5db06eed9fbefb2615500"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$CommitMessage = "feat(spt-023.5): implement FLD ODA builder layer 1"
$ExpectedTargetedTests = 20
$ExpectedFullSuiteMinimum = 972
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
    Write-Output " SPT-023.5 CAPA 1 : INSTITUTIONALLY CLOSED"
    Write-Output " COMMIT           : $Commit"
    Write-Output " TARGETED TESTS   : $Targeted PASSED"
    Write-Output " FULL SUITE       : $FullSuite PASSED"
    Write-Output " SPT-023.4        : PRESERVED"
    Write-Output " SPT-023.1-.3     : PRESERVED"
    Write-Output " SGD-002          : UPDATED"
    Write-Output " LOCAL/REMOTE     : IDENTICAL"
    Write-Output " AHEAD            : 0"
    Write-Output " BEHIND           : 0"
    Write-Output " STAGING          : CLEAN"
    Write-Output " DELETED TRACKED  : 0"
    Write-Output " ERRORS PENDING   : 0"
    Write-Output " NEXT             : SPT-023.5 CAPA 2"
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
    Write-Output " SPT-023.5 CAPA 1 : HOLD"
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
    Write-Output " SGODA-PUINAVE - SPT-023.5 CAPA 1 - MASTER TRANSACTION"
    Write-Output " FLD / ODA BUILDER / TRACEABILITY / INSTITUTIONAL HASHING"
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
            $EvidenceResume = Join-Path $Root "artifacts\development\SPT-023.5-Capa1-v1.0.0\implementation-evidence.json"
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

        throw "HEAD is neither certified baseline nor a resumable SPT-023.5 Capa 1 commit."
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
            $_ -match '(?i)SPT-023\.[1234]' -or
            $_ -match '(?i)spt023[1234]'
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
        "src\sgoda\integration\spt0235\__init__.py",
        "src\sgoda\integration\spt0235\models.py",
        "src\sgoda\integration\spt0235\fld.py",
        "src\sgoda\integration\spt0235\oda.py",
        "src\sgoda\integration\spt0235\service.py",
        "tests\integration\test_spt0235_fld_oda_builder_layer1.py",
        "docs\06_Tecnologia\SPT-023.5\SGD-SPT023.5-Capa1-Constructor-FLD-ODA.md",
        "config\integration\spt0235\fld-oda-builder.json",
        "artifacts\development\SPT-023.5-Capa1-v1.0.0\implementation-evidence.json"
    )

    foreach ($Rel in $Targets) {
        if (Test-Path -LiteralPath (Join-Path $Root $Rel)) {
            throw "Target already exists before fresh SPT-023.5 Capa 1 transaction: $Rel"
        }
    }

    $MasterBookPath = Join-Path $Root "docs\00_Estado_Maestro\SGD-002-Libro-Maestro-Institucional-SGODA-PUINAVE-v1.0.0.md"
    if (-not (Test-Path -LiteralPath $MasterBookPath -PathType Leaf)) {
        throw "SGD-002 master book not found."
    }

    $MasterBookOriginal = [System.IO.File]::ReadAllText($MasterBookPath)
    $Marker = "<!-- SPT-023.5-CAPA1-V1.0.0 -->"
    if ($MasterBookOriginal.Contains($Marker)) {
        throw "SGD-002 already contains SPT-023.5 Capa 1 marker while HEAD is baseline."
    }

    Write-Host "TARGET COLLISIONS : 0" -ForegroundColor Green

    Write-Host ""
    Write-Host "[4/12] IMPLEMENT SPT-023.5 CAPA 1" -ForegroundColor Yellow

    $Files = @{}
    $Files["src\sgoda\integration\spt0235\__init__.py"] = @'
"""SPT-023.5 — Constructor FLD / ODA — Capa 1."""

from .fld import build_fld
from .models import LexicalInput, MultimediaReference, parse_ready_for_fld_oda
from .oda import build_oda
from .service import Spt0235Layer1Service

__all__ = [
    "LexicalInput",
    "MultimediaReference",
    "Spt0235Layer1Service",
    "build_fld",
    "build_oda",
    "parse_ready_for_fld_oda",
]
'@
    $Files["src\sgoda\integration\spt0235\models.py"] = @'
from __future__ import annotations

from dataclasses import dataclass, asdict
from typing import Any


@dataclass(frozen=True)
class MultimediaReference:
    resource_id: str
    resource_type: str
    output_path: str
    sha256: str
    media_type: str | None
    language: str | None
    reviewer: str | None

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


@dataclass(frozen=True)
class LexicalInput:
    lexical_id: str
    puinave: str
    category_id: str | None
    translations: dict[str, str]
    multimedia_manifest_sha256: str
    resources: tuple[MultimediaReference, ...]

    def to_dict(self) -> dict[str, Any]:
        return {
            "lexical_id": self.lexical_id,
            "puinave": self.puinave,
            "category_id": self.category_id,
            "translations": dict(self.translations),
            "multimedia_manifest_sha256": self.multimedia_manifest_sha256,
            "resources": [item.to_dict() for item in self.resources],
        }


def parse_ready_for_fld_oda(payload: dict[str, Any]) -> LexicalInput:
    if str(payload.get("status") or "").strip() != "READY_FOR_FLD_ODA":
        raise ValueError("SPT-023.5 requires READY_FOR_FLD_ODA input.")

    lexical_id = str(payload.get("lexical_id") or "").strip()
    puinave = str(payload.get("puinave") or "").strip()
    category_id = str(payload.get("category_id") or "").strip() or None
    manifest_sha = str(payload.get("multimedia_manifest_sha256") or "").strip()

    if not lexical_id:
        raise ValueError("lexical_id is required.")
    if not puinave:
        raise ValueError("Puinave text is required.")
    if not manifest_sha:
        raise ValueError("multimedia_manifest_sha256 is required.")

    translations = dict(payload.get("translations") or {})
    resources_raw = list(payload.get("resources") or [])

    if len(resources_raw) != 5:
        raise ValueError("Exactly five multimedia resources are required.")

    resources: list[MultimediaReference] = []
    resource_types: set[str] = set()

    for raw in resources_raw:
        resource_type = str(raw.get("resource_type") or "").strip()
        resource_id = str(raw.get("resource_id") or "").strip()
        output_path = str(raw.get("output_path") or "").strip()
        sha256 = str(raw.get("sha256") or "").strip()

        if not resource_type or not resource_id or not output_path or not sha256:
            raise ValueError("Multimedia resource is incomplete.")
        if resource_type in resource_types:
            raise ValueError(f"Duplicate multimedia resource_type: {resource_type}")

        resource_types.add(resource_type)
        validation = dict(raw.get("validation") or {})
        resources.append(
            MultimediaReference(
                resource_id=resource_id,
                resource_type=resource_type,
                output_path=output_path,
                sha256=sha256,
                media_type=str(validation.get("media_type") or "").strip() or None,
                language=str(raw.get("language") or "").strip() or None,
                reviewer=str(raw.get("reviewer") or "").strip() or None,
            )
        )

    expected = {
        "image",
        "audio_puinave",
        "audio_es",
        "audio_en",
        "audio_it",
    }
    if resource_types != expected:
        raise ValueError("Multimedia resource set is incomplete or invalid.")

    return LexicalInput(
        lexical_id=lexical_id,
        puinave=puinave,
        category_id=category_id,
        translations=translations,
        multimedia_manifest_sha256=manifest_sha,
        resources=tuple(resources),
    )
'@
    $Files["src\sgoda\integration\spt0235\fld.py"] = @'
from __future__ import annotations

import hashlib
import json
from typing import Any

from .models import LexicalInput


def _sha256(value: object) -> str:
    data = json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(data).hexdigest().upper()


def build_fld(source: LexicalInput) -> dict[str, Any]:
    resources = {
        item.resource_type: item.to_dict()
        for item in source.resources
    }

    payload: dict[str, Any] = {
        "schema_version": "1.0.0",
        "object_type": "FLD",
        "component": "SPT-023.5",
        "lexical_id": source.lexical_id,
        "puinave": source.puinave,
        "category_id": source.category_id,
        "translations": {
            "es": str(source.translations.get("es") or ""),
            "en": str(source.translations.get("en") or ""),
            "it": str(source.translations.get("it") or ""),
        },
        "multimedia_manifest_sha256": source.multimedia_manifest_sha256,
        "resources": resources,
        "institutional_metadata": {
            "source_component": "SPT-023.4",
            "builder_component": "SPT-023.5",
            "traceability_required": True,
        },
    }
    payload["fld_sha256"] = _sha256(payload)
    return payload
'@
    $Files["src\sgoda\integration\spt0235\oda.py"] = @'
from __future__ import annotations

import hashlib
import json
from typing import Any


def _sha256(value: object) -> str:
    data = json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(data).hexdigest().upper()


def build_oda(fld: dict[str, Any]) -> dict[str, Any]:
    if fld.get("object_type") != "FLD":
        raise ValueError("ODA construction requires FLD input.")

    lexical_id = str(fld.get("lexical_id") or "").strip()
    puinave = str(fld.get("puinave") or "").strip()
    resources = dict(fld.get("resources") or {})

    if not lexical_id or not puinave:
        raise ValueError("FLD lexical identity is incomplete.")
    if len(resources) != 5:
        raise ValueError("FLD must reference exactly five multimedia resources.")

    payload: dict[str, Any] = {
        "schema_version": "1.0.0",
        "object_type": "ODA",
        "component": "SPT-023.5",
        "lexical_id": lexical_id,
        "title": puinave,
        "learning_object": {
            "term": puinave,
            "category_id": fld.get("category_id"),
            "translations": dict(fld.get("translations") or {}),
            "multimedia": resources,
        },
        "source_fld_sha256": fld["fld_sha256"],
        "multimedia_manifest_sha256": fld["multimedia_manifest_sha256"],
        "institutional_metadata": {
            "source_component": "SPT-023.5-FLD",
            "target_component": "SPT-023.5-ODA",
            "ready_for_registry": True,
        },
    }
    payload["oda_sha256"] = _sha256(payload)
    return payload
'@
    $Files["src\sgoda\integration\spt0235\service.py"] = @'
from __future__ import annotations

from typing import Any

from .fld import build_fld
from .models import parse_ready_for_fld_oda
from .oda import build_oda


class Spt0235Layer1Service:
    """Constructor determinístico FLD/ODA desde el handoff de SPT-023.4."""

    def build_one(
        self,
        handoff: dict[str, Any],
        *,
        translations: dict[str, str] | None = None,
    ) -> dict[str, Any]:
        payload = dict(handoff)
        payload["translations"] = dict(translations or payload.get("translations") or {})

        source = parse_ready_for_fld_oda(payload)
        fld = build_fld(source)
        oda = build_oda(fld)

        return {
            "component": "SPT-023.5",
            "layer": "1",
            "status": "FLD_ODA_BUILT",
            "lexical_id": source.lexical_id,
            "fld": fld,
            "oda": oda,
            "traceability": {
                "source_multimedia_manifest_sha256": source.multimedia_manifest_sha256,
                "fld_sha256": fld["fld_sha256"],
                "oda_sha256": oda["oda_sha256"],
            },
            "next_component": "SPT-023.5-CAPA-2",
        }

    def build_batch(
        self,
        handoffs: list[dict[str, Any]],
        *,
        translations_by_lexical_id: dict[str, dict[str, str]] | None = None,
    ) -> dict[str, Any]:
        translations_by_lexical_id = translations_by_lexical_id or {}
        results = []

        for handoff in handoffs:
            lexical_id = str(handoff.get("lexical_id") or "").strip()
            results.append(
                self.build_one(
                    handoff,
                    translations=translations_by_lexical_id.get(lexical_id, {}),
                )
            )

        return {
            "component": "SPT-023.5",
            "layer": "1",
            "records_processed": len(results),
            "fld_built": len(results),
            "oda_built": len(results),
            "results": results,
            "next_component": "SPT-023.5-CAPA-2",
        }
'@
    $Files["tests\integration\test_spt0235_fld_oda_builder_layer1.py"] = @'
import copy

import pytest

from sgoda.integration.spt0235.fld import build_fld
from sgoda.integration.spt0235.models import parse_ready_for_fld_oda
from sgoda.integration.spt0235.oda import build_oda
from sgoda.integration.spt0235.service import Spt0235Layer1Service


RESOURCE_TYPES = (
    ("image", None, "image/png"),
    ("audio_puinave", "pui", "audio/wav"),
    ("audio_es", "es-CO", "audio/wav"),
    ("audio_en", "en-US", "audio/wav"),
    ("audio_it", "it-IT", "audio/wav"),
)


def handoff():
    resources = []
    for index, (resource_type, language, media_type) in enumerate(RESOURCE_TYPES, start=1):
        resources.append(
            {
                "resource_id": f"MM-{index}",
                "resource_type": resource_type,
                "output_path": f"media/LEX-001/{resource_type}.bin",
                "sha256": f"{index}" * 64,
                "language": language,
                "reviewer": "reviewer-01",
                "validation": {
                    "valid": True,
                    "media_type": media_type,
                },
            }
        )

    return {
        "component": "SPT-023.4",
        "layer": "3",
        "status": "READY_FOR_FLD_ODA",
        "lexical_id": "LEX-001",
        "puinave": "AMDA",
        "category_id": "CAT-NATURE",
        "multimedia_manifest_sha256": "A" * 64,
        "resources": resources,
        "paid_api_used": False,
        "next_component": "SPT-023.5",
    }


def translations():
    return {
        "es": "palabra ejemplo",
        "en": "example word",
        "it": "parola esempio",
    }


def test_ready_input_is_parsed():
    source = parse_ready_for_fld_oda({**handoff(), "translations": translations()})
    assert source.lexical_id == "LEX-001"
    assert len(source.resources) == 5


def test_non_ready_input_is_rejected():
    payload = handoff()
    payload["status"] = "MULTIMEDIA_REVIEW_REQUIRED"
    with pytest.raises(ValueError):
        parse_ready_for_fld_oda(payload)


def test_missing_lexical_id_is_rejected():
    payload = handoff()
    payload["lexical_id"] = ""
    with pytest.raises(ValueError):
        parse_ready_for_fld_oda(payload)


def test_missing_puinave_is_rejected():
    payload = handoff()
    payload["puinave"] = ""
    with pytest.raises(ValueError):
        parse_ready_for_fld_oda(payload)


def test_missing_manifest_sha_is_rejected():
    payload = handoff()
    payload["multimedia_manifest_sha256"] = ""
    with pytest.raises(ValueError):
        parse_ready_for_fld_oda(payload)


def test_exactly_five_resources_are_required():
    payload = handoff()
    payload["resources"] = payload["resources"][:-1]
    with pytest.raises(ValueError):
        parse_ready_for_fld_oda(payload)


def test_duplicate_resource_type_is_rejected():
    payload = handoff()
    payload["resources"][4]["resource_type"] = "image"
    with pytest.raises(ValueError):
        parse_ready_for_fld_oda(payload)


def test_fld_contains_lexical_identity():
    source = parse_ready_for_fld_oda({**handoff(), "translations": translations()})
    fld = build_fld(source)
    assert fld["object_type"] == "FLD"
    assert fld["lexical_id"] == "LEX-001"
    assert fld["puinave"] == "AMDA"


def test_fld_contains_all_translations():
    source = parse_ready_for_fld_oda({**handoff(), "translations": translations()})
    fld = build_fld(source)
    assert fld["translations"]["es"] == "palabra ejemplo"
    assert fld["translations"]["en"] == "example word"
    assert fld["translations"]["it"] == "parola esempio"


def test_fld_references_five_multimedia_resources():
    source = parse_ready_for_fld_oda({**handoff(), "translations": translations()})
    fld = build_fld(source)
    assert len(fld["resources"]) == 5


def test_fld_hash_is_deterministic():
    source = parse_ready_for_fld_oda({**handoff(), "translations": translations()})
    one = build_fld(source)
    two = build_fld(source)
    assert one["fld_sha256"] == two["fld_sha256"]


def test_oda_requires_fld():
    with pytest.raises(ValueError):
        build_oda({"object_type": "OTHER"})


def test_oda_contains_source_fld_hash():
    source = parse_ready_for_fld_oda({**handoff(), "translations": translations()})
    fld = build_fld(source)
    oda = build_oda(fld)
    assert oda["source_fld_sha256"] == fld["fld_sha256"]


def test_oda_contains_learning_object():
    source = parse_ready_for_fld_oda({**handoff(), "translations": translations()})
    oda = build_oda(build_fld(source))
    assert oda["object_type"] == "ODA"
    assert oda["learning_object"]["term"] == "AMDA"


def test_oda_hash_is_deterministic():
    source = parse_ready_for_fld_oda({**handoff(), "translations": translations()})
    fld = build_fld(source)
    one = build_oda(fld)
    two = build_oda(fld)
    assert one["oda_sha256"] == two["oda_sha256"]


def test_service_builds_fld_and_oda():
    result = Spt0235Layer1Service().build_one(
        handoff(),
        translations=translations(),
    )
    assert result["status"] == "FLD_ODA_BUILT"
    assert result["fld"]["object_type"] == "FLD"
    assert result["oda"]["object_type"] == "ODA"


def test_service_preserves_multimedia_manifest_traceability():
    result = Spt0235Layer1Service().build_one(
        handoff(),
        translations=translations(),
    )
    assert result["traceability"]["source_multimedia_manifest_sha256"] == "A" * 64


def test_service_points_to_layer2():
    result = Spt0235Layer1Service().build_one(
        handoff(),
        translations=translations(),
    )
    assert result["next_component"] == "SPT-023.5-CAPA-2"


def test_batch_builds_two_records():
    second = copy.deepcopy(handoff())
    second["lexical_id"] = "LEX-002"
    second["puinave"] = "WAI"
    for item in second["resources"]:
        item["resource_id"] = "SECOND-" + item["resource_id"]

    result = Spt0235Layer1Service().build_batch(
        [handoff(), second],
        translations_by_lexical_id={
            "LEX-001": translations(),
            "LEX-002": {"es": "dos", "en": "two", "it": "due"},
        },
    )
    assert result["records_processed"] == 2
    assert result["fld_built"] == 2
    assert result["oda_built"] == 2


def test_fld_and_oda_hashes_are_different():
    result = Spt0235Layer1Service().build_one(
        handoff(),
        translations=translations(),
    )
    assert result["fld"]["fld_sha256"] != result["oda"]["oda_sha256"]
'@
    $Files["docs\06_Tecnologia\SPT-023.5\SGD-SPT023.5-Capa1-Constructor-FLD-ODA.md"] = @'
# SPT-023.5 — Constructor FLD / ODA — Capa 1

## Objetivo

Iniciar SPT-023.5 construyendo de forma determinística la Ficha Léxica Digital
(FLD) y el Objeto Digital de Aprendizaje (ODA) a partir del contrato
`READY_FOR_FLD_ODA` producido por SPT-023.4.

## Entrada

La capa exige:

- identificador léxico estable;
- palabra Puinave;
- categoría institucional;
- traducciones disponibles;
- manifiesto multimedia SHA-256;
- exactamente cinco recursos multimedia aprobados:
  imagen, audio Puinave, audio español, audio inglés y audio italiano.

## Ficha Léxica Digital

La FLD consolida identidad léxica, traducciones, categoría, referencias
multimedia, trazabilidad del manifiesto y metadatos institucionales.

## Objeto Digital de Aprendizaje

El ODA se construye exclusivamente desde una FLD válida y conserva su hash como
referencia de origen. Incluye el término, traducciones, categoría y los cinco
recursos multimedia.

## Integridad

FLD y ODA generan SHA-256 determinísticos sobre representación JSON canónica.

## Siguiente desarrollo

SPT-023.5 Capa 2 deberá implementar persistencia/versionado institucional de FLD
y ODA, registro maestro de objetos, validación de referencias y consulta por
identificador léxico.
'@
    $Files["config\integration\spt0235\fld-oda-builder.json"] = @'
{
  "schema_version": "1.0.0",
  "component": "SPT-023.5",
  "layer": "1",
  "input_status_required": "READY_FOR_FLD_ODA",
  "required_multimedia_resources": 5,
  "constructs": [
    "FLD",
    "ODA"
  ],
  "canonical_hash_algorithm": "SHA-256",
  "traceability_required": true,
  "paid_api_allowed": false,
  "next_component": "SPT-023.5-CAPA-2"
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
        "src\sgoda\integration\spt0235\__init__.py",
        "src\sgoda\integration\spt0235\models.py",
        "src\sgoda\integration\spt0235\fld.py",
        "src\sgoda\integration\spt0235\oda.py",
        "src\sgoda\integration\spt0235\service.py",
        "tests\integration\test_spt0235_fld_oda_builder_layer1.py"
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
                "tests/integration/test_spt0235_fld_oda_builder_layer1.py" `
                -q 2>&1
        )
        $TargetCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $Previous
    }

    $TargetOutput | ForEach-Object { Write-Host $_ }
    if ($TargetCode -ne 0) {
        throw "Targeted SPT-023.5 Capa 1 tests failed."
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
    Write-Host "[8/12] EVIDENCE + SGD-002 UPDATE" -ForegroundColor Yellow

    $EvidencePath = Join-Path $Root "artifacts\development\SPT-023.5-Capa1-v1.0.0\implementation-evidence.json"
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
        layer = "1"
        title = "Constructor FLD ODA"
        generated_utc = [DateTime]::UtcNow.ToString("o")
        certified_baseline = $ExpectedBaseline
        targeted_tests_passed = $TargetPassed
        institutional_tests_passed = $SuitePassed
        protected_files = $ProtectedBefore.Count
        protected_files_changed = $ChangedProtected.Count
        fld_builder = $true
        oda_builder = $true
        multimedia_references = 5
        deterministic_sha256 = $true
        source_status = "READY_FOR_FLD_ODA"
        paid_api_allowed = $false
        next_component = "SPT-023.5-CAPA-2"
        generated_files = $Generated
    }

    Write-Utf8Lf -Path $EvidencePath -Content ($Evidence | ConvertTo-Json -Depth 8) -TrackCreated

    $MasterAppend = @"

$Marker
## SPT-023.5 — Constructor FLD / ODA — Capa 1

- Estado institucional: CLOSED.
- Línea base de entrada: `$ExpectedBaseline`.
- Entrada requerida: READY_FOR_FLD_ODA desde SPT-023.4.
- Pruebas específicas: `$TargetPassed` aprobadas.
- Suite institucional: `$SuitePassed` aprobadas.
- Ficha Léxica Digital: construcción determinística implementada.
- Objeto Digital de Aprendizaje: construcción determinística implementada.
- Recursos multimedia referenciados: cinco por palabra.
- Integridad: SHA-256 determinístico para FLD y ODA.
- Trazabilidad: manifiesto multimedia -> FLD -> ODA.
- APIs de pago: deshabilitadas.
- Componentes cerrados anteriores: preservados por SHA-256.
- Siguiente desarrollo: SPT-023.5 Capa 2 — persistencia, versionado y registro institucional FLD/ODA.
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
    $Allowed += "artifacts/development/SPT-023.5-Capa1-v1.0.0/implementation-evidence.json"
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
        throw "Repository moved during SPT-023.5 Capa 1 transaction."
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
