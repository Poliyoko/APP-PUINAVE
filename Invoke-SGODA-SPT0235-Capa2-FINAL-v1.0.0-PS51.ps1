param(
    [string]$ProjectRoot = "",
    [string]$ExpectedBaseline = "e337686a1132c8dda2ba511e176c2c98ab8d9fd8"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$CommitMessage = "feat(spt-023.5): implement FLD ODA registry layer 2"
$ExpectedTargetedTests = 20
$ExpectedFullSuiteMinimum = 992
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
    Write-Output " SPT-023.5 CAPA 2 : INSTITUTIONALLY CLOSED"
    Write-Output " COMMIT           : $Commit"
    Write-Output " TARGETED TESTS   : $Targeted PASSED"
    Write-Output " FULL SUITE       : $FullSuite PASSED"
    Write-Output " SPT-023.5 CAPA 1 : PRESERVED"
    Write-Output " SPT-023.1-.4     : PRESERVED"
    Write-Output " SGD-002          : UPDATED"
    Write-Output " LOCAL/REMOTE     : IDENTICAL"
    Write-Output " AHEAD            : 0"
    Write-Output " BEHIND           : 0"
    Write-Output " STAGING          : CLEAN"
    Write-Output " DELETED TRACKED  : 0"
    Write-Output " ERRORS PENDING   : 0"
    Write-Output " NEXT             : SPT-023.5 CAPA 3"
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
    Write-Output " SPT-023.5 CAPA 2 : HOLD"
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
    Write-Output " SGODA-PUINAVE - SPT-023.5 CAPA 2 - MASTER TRANSACTION"
    Write-Output " FLD/ODA REGISTRY / VERSIONING / REFERENCE VALIDATION / QUERY"
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
            $EvidenceResume = Join-Path $Root "artifacts\development\SPT-023.5-Capa2-v1.0.0\implementation-evidence.json"
            if (-not (Test-Path -LiteralPath $EvidenceResume -PathType Leaf)) {
                throw "Resumable Capa 2 commit detected but evidence file is missing."
            }

            $DataResume = Get-Content -LiteralPath $EvidenceResume -Raw -Encoding UTF8 | ConvertFrom-Json

            if ($Local -eq $Remote) {
                $FinalStaged = @(Invoke-Git @("diff","--cached","--name-only")).Count
                $FinalDeleted = @(Invoke-Git @("ls-files","--deleted")).Count
                if ($FinalStaged -ne 0 -or $FinalDeleted -ne 0) {
                    throw "Published Capa 2 commit exists but repository safety is not clean."
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

        throw "HEAD is neither certified baseline nor a resumable SPT-023.5 Capa 2 commit."
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
        "src\sgoda\integration\spt0235\registry.py",
        "src\sgoda\integration\spt0235\references.py",
        "src\sgoda\integration\spt0235\query.py",
        "src\sgoda\integration\spt0235\layer2.py",
        "tests\integration\test_spt0235_fld_oda_registry_layer2.py",
        "docs\06_Tecnologia\SPT-023.5\SGD-SPT023.5-Capa2-Registro-Versionado-FLD-ODA.md",
        "config\integration\spt0235\registry-policy.json",
        "artifacts\development\SPT-023.5-Capa2-v1.0.0\implementation-evidence.json"
    )

    foreach ($Rel in $Targets) {
        if (Test-Path -LiteralPath (Join-Path $Root $Rel)) {
            throw "Target already exists before fresh SPT-023.5 Capa 2 transaction: $Rel"
        }
    }

    $MasterBookPath = Join-Path $Root "docs\00_Estado_Maestro\SGD-002-Libro-Maestro-Institucional-SGODA-PUINAVE-v1.0.0.md"
    if (-not (Test-Path -LiteralPath $MasterBookPath -PathType Leaf)) {
        throw "SGD-002 master book not found."
    }

    $MasterBookOriginal = [System.IO.File]::ReadAllText($MasterBookPath)
    $Marker = "<!-- SPT-023.5-CAPA2-V1.0.0 -->"
    if ($MasterBookOriginal.Contains($Marker)) {
        throw "SGD-002 already contains SPT-023.5 Capa 2 marker while HEAD is baseline."
    }

    Write-Host "TARGET COLLISIONS : 0" -ForegroundColor Green

    Write-Host ""
    Write-Host "[4/12] IMPLEMENT SPT-023.5 CAPA 2" -ForegroundColor Yellow

    $Files = @{}
    $Files["src\sgoda\integration\spt0235\registry.py"] = @'
from __future__ import annotations

import hashlib
import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any


def _canonical(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def _sha256(value: object) -> str:
    return hashlib.sha256(_canonical(value)).hexdigest().upper()


@dataclass(frozen=True)
class StoredObject:
    lexical_id: str
    object_type: str
    version: int
    object_sha256: str
    content: dict[str, Any]

    def to_dict(self) -> dict[str, Any]:
        return {
            "lexical_id": self.lexical_id,
            "object_type": self.object_type,
            "version": self.version,
            "object_sha256": self.object_sha256,
            "content": dict(self.content),
        }


class FldOdaRegistry:
    """Registro institucional local, versionado y atómico para FLD/ODA."""

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)

    def _empty(self) -> dict[str, Any]:
        return {
            "schema_version": "1.0.0",
            "component": "SPT-023.5",
            "registry_type": "FLD_ODA_MASTER",
            "entries": {},
        }

    def load(self) -> dict[str, Any]:
        if not self.path.exists():
            return self._empty()

        data = json.loads(self.path.read_text(encoding="utf-8"))
        if str(data.get("schema_version")) != "1.0.0":
            raise ValueError("Unsupported FLD/ODA registry schema_version.")
        if data.get("registry_type") != "FLD_ODA_MASTER":
            raise ValueError("Invalid FLD/ODA registry_type.")
        if not isinstance(data.get("entries"), dict):
            raise ValueError("Registry entries must be an object.")

        self.verify(data)
        return data

    @staticmethod
    def verify(data: dict[str, Any]) -> bool:
        entries = data.get("entries")
        if not isinstance(entries, dict):
            raise ValueError("Registry entries must be an object.")

        for lexical_id, record in entries.items():
            if str(record.get("lexical_id") or "") != lexical_id:
                raise ValueError("Registry lexical_id mismatch.")

            versions = record.get("versions")
            if not isinstance(versions, list) or not versions:
                raise ValueError("Registry record requires versions.")

            expected_version = 1
            for item in versions:
                if int(item.get("version", 0)) != expected_version:
                    raise ValueError("Registry versions must be contiguous.")

                fld = dict(item.get("fld") or {})
                oda = dict(item.get("oda") or {})
                if fld.get("object_type") != "FLD":
                    raise ValueError("Stored FLD object_type is invalid.")
                if oda.get("object_type") != "ODA":
                    raise ValueError("Stored ODA object_type is invalid.")

                fld_sha = str(fld.get("fld_sha256") or "")
                oda_sha = str(oda.get("oda_sha256") or "")
                if not fld_sha or not oda_sha:
                    raise ValueError("Stored FLD/ODA hashes are required.")

                body = {
                    "version": expected_version,
                    "fld_sha256": fld_sha,
                    "oda_sha256": oda_sha,
                    "source_multimedia_manifest_sha256": str(
                        item.get("source_multimedia_manifest_sha256") or ""
                    ),
                }
                if str(item.get("version_sha256") or "") != _sha256(body):
                    raise ValueError("Registry version SHA-256 mismatch.")

                expected_version += 1

            if int(record.get("latest_version", 0)) != len(versions):
                raise ValueError("Registry latest_version mismatch.")

        return True

    def save_entry(
        self,
        *,
        lexical_id: str,
        fld: dict[str, Any],
        oda: dict[str, Any],
    ) -> dict[str, Any]:
        lexical_id = str(lexical_id or "").strip()
        if not lexical_id:
            raise ValueError("lexical_id is required.")

        if fld.get("object_type") != "FLD":
            raise ValueError("FLD object is required.")
        if oda.get("object_type") != "ODA":
            raise ValueError("ODA object is required.")
        if str(fld.get("lexical_id") or "") != lexical_id:
            raise ValueError("FLD lexical_id mismatch.")
        if str(oda.get("lexical_id") or "") != lexical_id:
            raise ValueError("ODA lexical_id mismatch.")
        if str(oda.get("source_fld_sha256") or "") != str(fld.get("fld_sha256") or ""):
            raise ValueError("ODA must reference the stored FLD hash.")

        data = self.load()
        entries = dict(data["entries"])
        existing = dict(entries.get(lexical_id) or {})
        versions = list(existing.get("versions") or [])

        next_version = len(versions) + 1
        body = {
            "version": next_version,
            "fld_sha256": str(fld["fld_sha256"]),
            "oda_sha256": str(oda["oda_sha256"]),
            "source_multimedia_manifest_sha256": str(
                fld.get("multimedia_manifest_sha256") or ""
            ),
        }

        version_record = {
            "version": next_version,
            "fld": dict(fld),
            "oda": dict(oda),
            "source_multimedia_manifest_sha256": body[
                "source_multimedia_manifest_sha256"
            ],
            "version_sha256": _sha256(body),
        }
        versions.append(version_record)

        entries[lexical_id] = {
            "lexical_id": lexical_id,
            "latest_version": next_version,
            "versions": versions,
        }
        data["entries"] = entries

        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_name(self.path.name + ".tmp")
        tmp.write_text(
            json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
            newline="\n",
        )
        os.replace(tmp, self.path)

        self.verify(data)
        return dict(version_record)

    def get(self, lexical_id: str, version: int | None = None) -> dict[str, Any] | None:
        data = self.load()
        record = data["entries"].get(str(lexical_id))
        if record is None:
            return None

        versions = record["versions"]
        if version is None:
            return dict(versions[-1])

        version = int(version)
        for item in versions:
            if int(item["version"]) == version:
                return dict(item)
        return None
'@
    $Files["src\sgoda\integration\spt0235\references.py"] = @'
from __future__ import annotations

from pathlib import Path
from typing import Any


def validate_object_references(
    fld: dict[str, Any],
    oda: dict[str, Any],
    *,
    require_files: bool = False,
) -> dict[str, Any]:
    if fld.get("object_type") != "FLD":
        raise ValueError("FLD object is required.")
    if oda.get("object_type") != "ODA":
        raise ValueError("ODA object is required.")

    if fld.get("lexical_id") != oda.get("lexical_id"):
        raise ValueError("FLD/ODA lexical_id mismatch.")
    if oda.get("source_fld_sha256") != fld.get("fld_sha256"):
        raise ValueError("ODA source_fld_sha256 mismatch.")
    if oda.get("multimedia_manifest_sha256") != fld.get("multimedia_manifest_sha256"):
        raise ValueError("FLD/ODA multimedia manifest mismatch.")

    resources = dict(fld.get("resources") or {})
    if len(resources) != 5:
        raise ValueError("FLD must contain exactly five multimedia references.")

    required = {
        "image",
        "audio_puinave",
        "audio_es",
        "audio_en",
        "audio_it",
    }
    if set(resources) != required:
        raise ValueError("FLD multimedia resource set is invalid.")

    missing_files: list[str] = []
    for resource_type, item in resources.items():
        output_path = str((item or {}).get("output_path") or "").strip()
        sha256 = str((item or {}).get("sha256") or "").strip()

        if not output_path or not sha256:
            raise ValueError(f"Incomplete multimedia reference: {resource_type}")

        if require_files and not Path(output_path).is_file():
            missing_files.append(output_path)

    if missing_files:
        raise ValueError(
            "Missing referenced multimedia files: " + ", ".join(missing_files)
        )

    return {
        "lexical_id": str(fld["lexical_id"]),
        "resource_count": len(resources),
        "references_valid": True,
        "files_required": bool(require_files),
        "missing_files": missing_files,
    }
'@
    $Files["src\sgoda\integration\spt0235\query.py"] = @'
from __future__ import annotations

from typing import Any

from .registry import FldOdaRegistry


class FldOdaQueryService:
    def __init__(self, registry: FldOdaRegistry) -> None:
        self.registry = registry

    def by_lexical_id(
        self,
        lexical_id: str,
        *,
        version: int | None = None,
    ) -> dict[str, Any] | None:
        result = self.registry.get(lexical_id, version=version)
        if result is None:
            return None

        return {
            "component": "SPT-023.5",
            "layer": "2",
            "lexical_id": lexical_id,
            "version": result["version"],
            "fld": result["fld"],
            "oda": result["oda"],
            "version_sha256": result["version_sha256"],
        }
'@
    $Files["src\sgoda\integration\spt0235\layer2.py"] = @'
from __future__ import annotations

from pathlib import Path
from typing import Any

from .query import FldOdaQueryService
from .references import validate_object_references
from .registry import FldOdaRegistry


class Spt0235Layer2Service:
    """Persistencia, versionado, validación y consulta de FLD/ODA."""

    def __init__(self, registry_path: str | Path) -> None:
        self.registry = FldOdaRegistry(registry_path)
        self.query = FldOdaQueryService(self.registry)

    def persist(
        self,
        build_result: dict[str, Any],
        *,
        require_multimedia_files: bool = False,
    ) -> dict[str, Any]:
        if str(build_result.get("status") or "") != "FLD_ODA_BUILT":
            raise ValueError("SPT-023.5 Capa 2 requires FLD_ODA_BUILT input.")

        lexical_id = str(build_result.get("lexical_id") or "").strip()
        fld = dict(build_result.get("fld") or {})
        oda = dict(build_result.get("oda") or {})

        validation = validate_object_references(
            fld,
            oda,
            require_files=require_multimedia_files,
        )

        stored = self.registry.save_entry(
            lexical_id=lexical_id,
            fld=fld,
            oda=oda,
        )

        return {
            "component": "SPT-023.5",
            "layer": "2",
            "status": "FLD_ODA_PERSISTED",
            "lexical_id": lexical_id,
            "version": stored["version"],
            "version_sha256": stored["version_sha256"],
            "reference_validation": validation,
            "registry_verified": True,
            "next_component": "SPT-023.5-CAPA-3",
        }

    def retrieve(
        self,
        lexical_id: str,
        *,
        version: int | None = None,
    ) -> dict[str, Any] | None:
        return self.query.by_lexical_id(
            lexical_id,
            version=version,
        )
'@
    $Files["tests\integration\test_spt0235_fld_oda_registry_layer2.py"] = @'
import copy
import json

import pytest

from sgoda.integration.spt0235.layer2 import Spt0235Layer2Service
from sgoda.integration.spt0235.query import FldOdaQueryService
from sgoda.integration.spt0235.references import validate_object_references
from sgoda.integration.spt0235.registry import FldOdaRegistry


def build_result():
    resources = {}
    for index, resource_type in enumerate(
        ("image", "audio_puinave", "audio_es", "audio_en", "audio_it"),
        start=1,
    ):
        resources[resource_type] = {
            "resource_id": f"MM-{index}",
            "resource_type": resource_type,
            "output_path": f"media/LEX-001/{resource_type}.bin",
            "sha256": f"{index}" * 64,
        }

    fld = {
        "schema_version": "1.0.0",
        "object_type": "FLD",
        "component": "SPT-023.5",
        "lexical_id": "LEX-001",
        "puinave": "AMDA",
        "category_id": "CAT-NATURE",
        "translations": {
            "es": "palabra ejemplo",
            "en": "example word",
            "it": "parola esempio",
        },
        "multimedia_manifest_sha256": "A" * 64,
        "resources": resources,
        "fld_sha256": "F" * 64,
    }
    oda = {
        "schema_version": "1.0.0",
        "object_type": "ODA",
        "component": "SPT-023.5",
        "lexical_id": "LEX-001",
        "title": "AMDA",
        "learning_object": {
            "term": "AMDA",
            "category_id": "CAT-NATURE",
            "translations": dict(fld["translations"]),
            "multimedia": dict(resources),
        },
        "source_fld_sha256": fld["fld_sha256"],
        "multimedia_manifest_sha256": fld["multimedia_manifest_sha256"],
        "oda_sha256": "O" * 64,
    }
    return {
        "component": "SPT-023.5",
        "layer": "1",
        "status": "FLD_ODA_BUILT",
        "lexical_id": "LEX-001",
        "fld": fld,
        "oda": oda,
    }


def test_reference_validation_accepts_valid_pair():
    result = build_result()
    validation = validate_object_references(result["fld"], result["oda"])
    assert validation["references_valid"] is True
    assert validation["resource_count"] == 5


def test_reference_validation_rejects_lexical_mismatch():
    result = build_result()
    result["oda"]["lexical_id"] = "LEX-X"
    with pytest.raises(ValueError):
        validate_object_references(result["fld"], result["oda"])


def test_reference_validation_rejects_fld_hash_mismatch():
    result = build_result()
    result["oda"]["source_fld_sha256"] = "X"
    with pytest.raises(ValueError):
        validate_object_references(result["fld"], result["oda"])


def test_reference_validation_rejects_manifest_mismatch():
    result = build_result()
    result["oda"]["multimedia_manifest_sha256"] = "X"
    with pytest.raises(ValueError):
        validate_object_references(result["fld"], result["oda"])


def test_reference_validation_requires_five_resources():
    result = build_result()
    result["fld"]["resources"].pop("audio_it")
    with pytest.raises(ValueError):
        validate_object_references(result["fld"], result["oda"])


def test_registry_persists_first_version(tmp_path):
    result = build_result()
    registry = FldOdaRegistry(tmp_path / "registry.json")
    stored = registry.save_entry(
        lexical_id="LEX-001",
        fld=result["fld"],
        oda=result["oda"],
    )
    assert stored["version"] == 1
    assert registry.get("LEX-001")["version"] == 1


def test_registry_increments_version(tmp_path):
    result = build_result()
    registry = FldOdaRegistry(tmp_path / "registry.json")
    registry.save_entry(
        lexical_id="LEX-001",
        fld=result["fld"],
        oda=result["oda"],
    )
    second = copy.deepcopy(result)
    second["fld"]["fld_sha256"] = "G" * 64
    second["oda"]["source_fld_sha256"] = "G" * 64
    second["oda"]["oda_sha256"] = "P" * 64
    stored = registry.save_entry(
        lexical_id="LEX-001",
        fld=second["fld"],
        oda=second["oda"],
    )
    assert stored["version"] == 2


def test_registry_can_retrieve_specific_version(tmp_path):
    result = build_result()
    registry = FldOdaRegistry(tmp_path / "registry.json")
    registry.save_entry(lexical_id="LEX-001", fld=result["fld"], oda=result["oda"])
    second = copy.deepcopy(result)
    second["fld"]["fld_sha256"] = "G" * 64
    second["oda"]["source_fld_sha256"] = "G" * 64
    second["oda"]["oda_sha256"] = "P" * 64
    registry.save_entry(lexical_id="LEX-001", fld=second["fld"], oda=second["oda"])
    assert registry.get("LEX-001", version=1)["version"] == 1
    assert registry.get("LEX-001", version=2)["version"] == 2


def test_registry_returns_none_for_unknown_lexical_id(tmp_path):
    registry = FldOdaRegistry(tmp_path / "registry.json")
    assert registry.get("UNKNOWN") is None


def test_registry_detects_tampering(tmp_path):
    result = build_result()
    path = tmp_path / "registry.json"
    registry = FldOdaRegistry(path)
    registry.save_entry(
        lexical_id="LEX-001",
        fld=result["fld"],
        oda=result["oda"],
    )
    data = json.loads(path.read_text(encoding="utf-8"))
    data["entries"]["LEX-001"]["versions"][0]["version_sha256"] = "BAD"
    path.write_text(json.dumps(data), encoding="utf-8")
    with pytest.raises(ValueError):
        registry.load()


def test_query_returns_latest_version(tmp_path):
    result = build_result()
    registry = FldOdaRegistry(tmp_path / "registry.json")
    registry.save_entry(lexical_id="LEX-001", fld=result["fld"], oda=result["oda"])
    query = FldOdaQueryService(registry)
    found = query.by_lexical_id("LEX-001")
    assert found["version"] == 1
    assert found["fld"]["object_type"] == "FLD"
    assert found["oda"]["object_type"] == "ODA"


def test_query_returns_none_when_missing(tmp_path):
    query = FldOdaQueryService(FldOdaRegistry(tmp_path / "registry.json"))
    assert query.by_lexical_id("LEX-404") is None


def test_layer2_persists_valid_build_result(tmp_path):
    service = Spt0235Layer2Service(tmp_path / "registry.json")
    result = service.persist(build_result())
    assert result["status"] == "FLD_ODA_PERSISTED"
    assert result["version"] == 1


def test_layer2_rejects_wrong_status(tmp_path):
    payload = build_result()
    payload["status"] = "OTHER"
    service = Spt0235Layer2Service(tmp_path / "registry.json")
    with pytest.raises(ValueError):
        service.persist(payload)


def test_layer2_can_retrieve_after_persist(tmp_path):
    service = Spt0235Layer2Service(tmp_path / "registry.json")
    service.persist(build_result())
    found = service.retrieve("LEX-001")
    assert found["lexical_id"] == "LEX-001"


def test_version_sha_is_deterministic_for_same_version_body(tmp_path):
    result = build_result()
    one = FldOdaRegistry(tmp_path / "one.json").save_entry(
        lexical_id="LEX-001",
        fld=result["fld"],
        oda=result["oda"],
    )
    two = FldOdaRegistry(tmp_path / "two.json").save_entry(
        lexical_id="LEX-001",
        fld=result["fld"],
        oda=result["oda"],
    )
    assert one["version_sha256"] == two["version_sha256"]


def test_registry_rejects_oda_not_referencing_fld(tmp_path):
    result = build_result()
    result["oda"]["source_fld_sha256"] = "X"
    registry = FldOdaRegistry(tmp_path / "registry.json")
    with pytest.raises(ValueError):
        registry.save_entry(
            lexical_id="LEX-001",
            fld=result["fld"],
            oda=result["oda"],
        )


def test_require_files_detects_missing_multimedia(tmp_path):
    result = build_result()
    with pytest.raises(ValueError):
        validate_object_references(
            result["fld"],
            result["oda"],
            require_files=True,
        )


def test_layer2_points_to_layer3(tmp_path):
    service = Spt0235Layer2Service(tmp_path / "registry.json")
    result = service.persist(build_result())
    assert result["next_component"] == "SPT-023.5-CAPA-3"


def test_registry_file_is_valid_json(tmp_path):
    result = build_result()
    path = tmp_path / "registry.json"
    registry = FldOdaRegistry(path)
    registry.save_entry(lexical_id="LEX-001", fld=result["fld"], oda=result["oda"])
    data = json.loads(path.read_text(encoding="utf-8"))
    assert data["registry_type"] == "FLD_ODA_MASTER"
'@
    $Files["docs\06_Tecnologia\SPT-023.5\SGD-SPT023.5-Capa2-Registro-Versionado-FLD-ODA.md"] = @'
# SPT-023.5 — Constructor FLD / ODA — Capa 2

## Objetivo

Implementar la persistencia institucional, versionado, validación de referencias
y consulta de las Fichas Léxicas Digitales (FLD) y Objetos Digitales de
Aprendizaje (ODA) construidos por SPT-023.5 Capa 1.

## Capacidades

- registro maestro local FLD/ODA;
- versiones contiguas por identificador léxico;
- conservación de todas las versiones;
- hash SHA-256 determinístico por versión;
- validación cruzada FLD -> ODA;
- validación del manifiesto multimedia;
- validación de exactamente cinco recursos;
- consulta de última versión;
- consulta por versión específica;
- detección de manipulación del registro;
- persistencia atómica JSON.

## Integridad

El ODA debe referenciar el hash exacto de la FLD almacenada y ambos objetos deben
referenciar el mismo manifiesto multimedia de SPT-023.4.

La validación física de archivos multimedia puede activarse con
`require_multimedia_files=True` cuando se ejecute sobre recursos reales.

## Siguiente desarrollo

SPT-023.5 Capa 3 deberá implementar gobernanza de publicación de FLD/ODA,
manifiesto de completitud, integración con el registro institucional y cierre
del paquete SPT-023.5.
'@
    $Files["config\integration\spt0235\registry-policy.json"] = @'
{
  "schema_version": "1.0.0",
  "component": "SPT-023.5",
  "layer": "2",
  "registry_type": "FLD_ODA_MASTER",
  "storage": "LOCAL_JSON_ATOMIC",
  "versioning": true,
  "preserve_all_versions": true,
  "version_hash_algorithm": "SHA-256",
  "validate_fld_oda_link": true,
  "validate_multimedia_manifest": true,
  "required_multimedia_resources": 5,
  "query_by_lexical_id": true,
  "query_by_version": true,
  "paid_api_allowed": false,
  "next_component": "SPT-023.5-CAPA-3"
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
        "src\sgoda\integration\spt0235\registry.py",
        "src\sgoda\integration\spt0235\references.py",
        "src\sgoda\integration\spt0235\query.py",
        "src\sgoda\integration\spt0235\layer2.py",
        "tests\integration\test_spt0235_fld_oda_registry_layer2.py"
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
                "tests/integration/test_spt0235_fld_oda_registry_layer2.py" `
                -q 2>&1
        )
        $TargetCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $Previous
    }

    $TargetOutput | ForEach-Object { Write-Host $_ }
    if ($TargetCode -ne 0) {
        throw "Targeted SPT-023.5 Capa 2 tests failed."
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

    $EvidencePath = Join-Path $Root "artifacts\development\SPT-023.5-Capa2-v1.0.0\implementation-evidence.json"
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
        layer = "2"
        title = "Registro Versionado FLD ODA"
        generated_utc = [DateTime]::UtcNow.ToString("o")
        certified_baseline = $ExpectedBaseline
        targeted_tests_passed = $TargetPassed
        institutional_tests_passed = $SuitePassed
        protected_files = $ProtectedBefore.Count
        protected_files_changed = $ChangedProtected.Count
        registry_master = $true
        versioning = $true
        preserve_all_versions = $true
        reference_validation = $true
        version_sha256 = $true
        query_by_lexical_id = $true
        query_by_version = $true
        paid_api_allowed = $false
        next_component = "SPT-023.5-CAPA-3"
        generated_files = $Generated
    }

    Write-Utf8Lf -Path $EvidencePath -Content ($Evidence | ConvertTo-Json -Depth 8) -TrackCreated

    $MasterAppend = @"

$Marker
## SPT-023.5 — Constructor FLD / ODA — Capa 2

- Estado institucional: CLOSED.
- Línea base de entrada: `$ExpectedBaseline`.
- Pruebas específicas: `$TargetPassed` aprobadas.
- Suite institucional: `$SuitePassed` aprobadas.
- Registro maestro FLD/ODA: implementado.
- Versionado por identificador léxico: implementado.
- Conservación de versiones históricas: habilitada.
- Validación FLD -> ODA: implementada.
- Validación de manifiesto multimedia: implementada.
- Hash por versión: SHA-256 determinístico.
- Consulta por identificador léxico: implementada.
- Consulta por versión: implementada.
- APIs de pago: deshabilitadas.
- Componentes cerrados anteriores: preservados por SHA-256.
- Siguiente desarrollo: SPT-023.5 Capa 3 — gobernanza de publicación y cierre FLD/ODA.
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
    $Allowed += "artifacts/development/SPT-023.5-Capa2-v1.0.0/implementation-evidence.json"
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
        throw "Repository moved during SPT-023.5 Capa 2 transaction."
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
