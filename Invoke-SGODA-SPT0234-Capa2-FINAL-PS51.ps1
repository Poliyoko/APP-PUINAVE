param(
    [string]$ProjectRoot = "",
    [string]$ExpectedBaseline = "7eff8c2519b9a4922282331ca9f8cbe7dd042828"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$CommitMessage = "feat(spt-023.4): implement local multimedia execution layer 2"
$ExpectedTargetedTests = 21
$ExpectedFullSuiteMinimum = 934
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
    Write-Output " SPT-023.4 CAPA 2 : INSTITUTIONALLY CLOSED"
    Write-Output " COMMIT           : $Commit"
    Write-Output " TARGETED TESTS   : $Targeted PASSED"
    Write-Output " FULL SUITE       : $FullSuite PASSED"
    Write-Output " SPT-023.4 CAPA 1 : PRESERVED"
    Write-Output " SPT-023.1-.3     : PRESERVED"
    Write-Output " LEGACY MULTIMEDIA: PRESERVED / REUSED"
    Write-Output " SGD-002          : UPDATED"
    Write-Output " LOCAL/REMOTE     : IDENTICAL"
    Write-Output " AHEAD            : 0"
    Write-Output " BEHIND           : 0"
    Write-Output " STAGING          : CLEAN"
    Write-Output " DELETED TRACKED  : 0"
    Write-Output " ERRORS PENDING   : 0"
    Write-Output " NEXT             : SPT-023.4 CAPA 3"
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
    Write-Output " SPT-023.4 CAPA 2 : HOLD"
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
    Write-Output " SGODA-PUINAVE - SPT-023.4 CAPA 2 - MASTER TRANSACTION"
    Write-Output " LOCAL EXECUTION / FILE VALIDATION / ADR-010 RMR PERSISTENCE"
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
            $EvidenceResume = Join-Path $Root "artifacts\development\SPT-023.4-Capa2-v1.0.0\implementation-evidence.json"
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

        throw "HEAD is neither certified baseline nor a resumable SPT-023.4 Capa 2 commit."
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
    Write-Host "[2/12] SHA-256 FREEZE OF CLOSED + REUSED COMPONENTS" -ForegroundColor Yellow

    $RequiredLayer1 = @(
        "src\sgoda\integration\spt0234\models.py",
        "src\sgoda\integration\spt0234\policy.py",
        "src\sgoda\integration\spt0234\planner.py",
        "src\sgoda\integration\spt0234\service.py",
        "config\integration\spt0234\multimedia-policy.json"
    )

    foreach ($Rel in $RequiredLayer1) {
        if (-not (Test-Path -LiteralPath (Join-Path $Root $Rel) -PathType Leaf)) {
            throw "Required SPT-023.4 Capa 1 component missing: $Rel"
        }
    }

    $Tracked = @(Invoke-Git @("-c","core.quotepath=false","ls-files"))
    $Protected = @(
        $Tracked | Where-Object {
            $_ -match '(?i)SPT-023\.[123]' -or
            $_ -match '(?i)spt023[123]' -or
            $_ -match '(?i)SPT-023\.4' -or
            $_ -match '(?i)spt0234' -or
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

    Write-Host "PROTECTED FILES : $($ProtectedBefore.Count)"
    Write-Host "SHA-256 FREEZE  : PASS" -ForegroundColor Green

    Write-Host ""
    Write-Host "[3/12] TARGET COLLISION GATE" -ForegroundColor Yellow

    $Targets = @(
        "src\sgoda\integration\spt0234\validators.py",
        "src\sgoda\integration\spt0234\executor.py",
        "src\sgoda\integration\spt0234\rmr.py",
        "src\sgoda\integration\spt0234\layer2.py",
        "tests\integration\test_spt0234_multimedia_execution_layer2.py",
        "docs\06_Tecnologia\SPT-023.4\SGD-SPT023.4-Capa2-Ejecucion-Local-RMR.md",
        "config\integration\spt0234\local-execution.json",
        "artifacts\development\SPT-023.4-Capa2-v1.0.0\implementation-evidence.json"
    )

    foreach ($Rel in $Targets) {
        if (Test-Path -LiteralPath (Join-Path $Root $Rel)) {
            throw "Target already exists before fresh SPT-023.4 Capa 2 transaction: $Rel"
        }
    }

    $MasterBookPath = Join-Path $Root "docs\00_Estado_Maestro\SGD-002-Libro-Maestro-Institucional-SGODA-PUINAVE-v1.0.0.md"
    if (-not (Test-Path -LiteralPath $MasterBookPath -PathType Leaf)) {
        throw "SGD-002 master book not found."
    }

    $MasterBookOriginal = [System.IO.File]::ReadAllText($MasterBookPath)
    $Marker = "<!-- SPT-023.4-CAPA2-V1.0.0 -->"
    if ($MasterBookOriginal.Contains($Marker)) {
        throw "SGD-002 already contains SPT-023.4 Capa 2 marker while HEAD is baseline."
    }

    Write-Host "TARGET COLLISIONS : 0" -ForegroundColor Green

    Write-Host ""
    Write-Host "[4/12] IMPLEMENT SPT-023.4 CAPA 2" -ForegroundColor Yellow

    $Files = @{}
    $Files["src\sgoda\integration\spt0234\validators.py"] = @'
from __future__ import annotations

import wave
from pathlib import Path


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
JPEG_SIGNATURES = (b"\xff\xd8\xff",)


def validate_image_file(path: str | Path) -> dict[str, object]:
    target = Path(path)
    if not target.is_file():
        raise ValueError(f"Image file does not exist: {target}")

    data = target.read_bytes()
    if len(data) < 8:
        raise ValueError("Image file is too small.")

    if data.startswith(PNG_SIGNATURE):
        media_type = "image/png"
    elif any(data.startswith(sig) for sig in JPEG_SIGNATURES):
        media_type = "image/jpeg"
    else:
        raise ValueError("Unsupported or invalid image signature.")

    return {
        "path": str(target),
        "media_type": media_type,
        "size_bytes": len(data),
        "valid": True,
    }


def validate_wav_file(path: str | Path) -> dict[str, object]:
    target = Path(path)
    if not target.is_file():
        raise ValueError(f"Audio file does not exist: {target}")

    try:
        with wave.open(str(target), "rb") as handle:
            channels = handle.getnchannels()
            sample_width = handle.getsampwidth()
            frame_rate = handle.getframerate()
            frame_count = handle.getnframes()
            duration = frame_count / frame_rate if frame_rate else 0.0
    except (wave.Error, EOFError) as exc:
        raise ValueError(f"Invalid WAV file: {target}") from exc

    if channels < 1:
        raise ValueError("WAV must have at least one channel.")
    if sample_width < 1:
        raise ValueError("WAV sample width is invalid.")
    if frame_rate < 1:
        raise ValueError("WAV frame rate is invalid.")

    return {
        "path": str(target),
        "media_type": "audio/wav",
        "channels": channels,
        "sample_width": sample_width,
        "frame_rate": frame_rate,
        "frame_count": frame_count,
        "duration_seconds": round(duration, 6),
        "size_bytes": target.stat().st_size,
        "valid": True,
    }
'@
    $Files["src\sgoda\integration\spt0234\executor.py"] = @'
from __future__ import annotations

import hashlib
import shlex
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from .validators import validate_image_file, validate_wav_file


@dataclass(frozen=True)
class ExecutionResult:
    resource_id: str
    resource_type: str
    status: str
    output_path: str
    sha256: str
    validation: dict[str, object]
    provider: str
    reused: bool = False

    def to_dict(self) -> dict[str, Any]:
        return {
            "resource_id": self.resource_id,
            "resource_type": self.resource_type,
            "status": self.status,
            "output_path": self.output_path,
            "sha256": self.sha256,
            "validation": dict(self.validation),
            "provider": self.provider,
            "reused": self.reused,
        }


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def _render_command(template: str, values: dict[str, str]) -> list[str]:
    rendered = template
    for key, value in values.items():
        rendered = rendered.replace("{" + key + "}", value)
    return shlex.split(rendered, posix=False)


class LocalMultimediaExecutor:
    """Ejecutor gobernado exclusivamente por comandos locales configurados.

    No contiene URLs, SDKs remotos ni credenciales. La ejecución externa queda
    limitada a comandos locales definidos por la configuración institucional.
    """

    def __init__(
        self,
        *,
        image_command: str | None = None,
        tts_command: str | None = None,
    ) -> None:
        self.image_command = (image_command or "").strip() or None
        self.tts_command = (tts_command or "").strip() or None

    def _run_local(
        self,
        *,
        command_template: str,
        values: dict[str, str],
        output: Path,
    ) -> None:
        command = _render_command(command_template, values)
        if not command:
            raise ValueError("Local provider command is empty.")

        output.parent.mkdir(parents=True, exist_ok=True)

        completed = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            timeout=120,
        )
        if completed.returncode != 0:
            raise RuntimeError(
                "Local provider failed: "
                + (completed.stderr or completed.stdout or "").strip()
            )
        if not output.is_file():
            raise RuntimeError("Local provider did not create the expected output.")

    def execute_image(
        self,
        *,
        resource_id: str,
        lexical_id: str,
        puinave: str,
        prompt: str,
        output_path: str | Path,
    ) -> ExecutionResult:
        if self.image_command is None:
            raise RuntimeError("No local image provider is configured.")

        output = Path(output_path)
        self._run_local(
            command_template=self.image_command,
            values={
                "resource_id": resource_id,
                "lexical_id": lexical_id,
                "puinave": puinave,
                "prompt": prompt,
                "output": str(output),
            },
            output=output,
        )
        validation = validate_image_file(output)
        return ExecutionResult(
            resource_id=resource_id,
            resource_type="image",
            status="GENERATED_LOCAL",
            output_path=str(output),
            sha256=_sha256(output),
            validation=validation,
            provider="LOCAL_IMAGE_COMMAND",
        )

    def execute_tts(
        self,
        *,
        resource_id: str,
        lexical_id: str,
        resource_type: str,
        language: str,
        text: str,
        output_path: str | Path,
    ) -> ExecutionResult:
        if self.tts_command is None:
            raise RuntimeError("No local TTS provider is configured.")

        output = Path(output_path)
        self._run_local(
            command_template=self.tts_command,
            values={
                "resource_id": resource_id,
                "lexical_id": lexical_id,
                "resource_type": resource_type,
                "language": language,
                "text": text,
                "output": str(output),
            },
            output=output,
        )
        validation = validate_wav_file(output)
        return ExecutionResult(
            resource_id=resource_id,
            resource_type=resource_type,
            status="GENERATED_LOCAL",
            output_path=str(output),
            sha256=_sha256(output),
            validation=validation,
            provider="FREE_LOCAL_TTS_COMMAND",
        )

    def import_native_audio(
        self,
        *,
        resource_id: str,
        lexical_id: str,
        source_path: str | Path,
        output_path: str | Path,
    ) -> ExecutionResult:
        source = Path(source_path)
        validation_source = validate_wav_file(source)

        output = Path(output_path)
        output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, output)

        validation = validate_wav_file(output)
        if validation["size_bytes"] != validation_source["size_bytes"]:
            raise RuntimeError("Native audio copy size mismatch.")

        return ExecutionResult(
            resource_id=resource_id,
            resource_type="audio_puinave",
            status="IMPORTED_NATIVE",
            output_path=str(output),
            sha256=_sha256(output),
            validation=validation,
            provider="NATIVE_HUMAN_RECORDING",
        )
'@
    $Files["src\sgoda\integration\spt0234\rmr.py"] = @'
from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any


class RmrRegistry:
    """Registro Multimedia Reutilizable local, atómico y determinístico."""

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)

    def load(self) -> dict[str, Any]:
        if not self.path.exists():
            return {
                "schema_version": "1.0.0",
                "component": "ADR-010/RMR",
                "resources": {},
            }

        data = json.loads(self.path.read_text(encoding="utf-8"))
        if str(data.get("schema_version")) != "1.0.0":
            raise ValueError("Unsupported RMR schema_version.")
        if not isinstance(data.get("resources"), dict):
            raise ValueError("RMR resources must be an object.")
        return data

    def upsert(self, record: dict[str, Any]) -> dict[str, Any]:
        resource_id = str(record.get("resource_id") or "").strip()
        if not resource_id:
            raise ValueError("RMR record requires resource_id.")

        data = self.load()
        resources = dict(data["resources"])
        resources[resource_id] = dict(record)
        data["resources"] = resources

        self.path.parent.mkdir(parents=True, exist_ok=True)
        temp = self.path.with_name(self.path.name + ".tmp")
        temp.write_text(
            json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
            newline="\n",
        )
        os.replace(temp, self.path)
        return dict(resources[resource_id])

    def get(self, resource_id: str) -> dict[str, Any] | None:
        return self.load()["resources"].get(resource_id)
'@
    $Files["src\sgoda\integration\spt0234\layer2.py"] = @'
from __future__ import annotations

from pathlib import Path
from typing import Any

from .executor import LocalMultimediaExecutor
from .rmr import RmrRegistry


class Spt0234Layer2Service:
    """Ejecución local y persistencia efectiva de los planes de Capa 1."""

    def __init__(
        self,
        *,
        executor: LocalMultimediaExecutor,
        rmr: RmrRegistry,
        media_root: str | Path,
    ) -> None:
        self.executor = executor
        self.rmr = rmr
        self.media_root = Path(media_root)

    def _output_path(
        self,
        *,
        lexical_id: str,
        resource_type: str,
        extension: str,
    ) -> Path:
        safe_lexical = "".join(
            ch if ch.isalnum() or ch in "-_." else "_"
            for ch in lexical_id
        )
        return self.media_root / safe_lexical / f"{resource_type}{extension}"

    def execute_resource(
        self,
        plan: dict[str, Any],
        *,
        puinave: str,
        localized_text: str | None = None,
        image_prompt: str | None = None,
        native_audio_source: str | Path | None = None,
    ) -> dict[str, Any]:
        resource_id = str(plan["resource_id"])
        lexical_id = str(plan["lexical_id"])
        resource_type = str(plan["resource_type"])
        language = plan.get("language")

        existing = self.rmr.get(resource_id)
        if existing and str(existing.get("status")) in {
            "GENERATED_LOCAL",
            "IMPORTED_NATIVE",
            "APPROVED",
            "PUBLISHED",
        }:
            reused = dict(existing)
            reused["reused"] = True
            reused["status"] = "REUSE_EXISTING"
            return reused

        if resource_type == "image":
            prompt = str(image_prompt or "").strip()
            if not prompt:
                raise ValueError("Image execution requires image_prompt.")
            result = self.executor.execute_image(
                resource_id=resource_id,
                lexical_id=lexical_id,
                puinave=puinave,
                prompt=prompt,
                output_path=self._output_path(
                    lexical_id=lexical_id,
                    resource_type="image",
                    extension=".png",
                ),
            )
        elif resource_type == "audio_puinave":
            if native_audio_source is None:
                raise ValueError("Puinave audio requires native_audio_source.")
            result = self.executor.import_native_audio(
                resource_id=resource_id,
                lexical_id=lexical_id,
                source_path=native_audio_source,
                output_path=self._output_path(
                    lexical_id=lexical_id,
                    resource_type="audio_puinave",
                    extension=".wav",
                ),
            )
        elif resource_type in {"audio_es", "audio_en", "audio_it"}:
            text = str(localized_text or "").strip()
            if not text:
                raise ValueError(f"{resource_type} requires localized_text.")
            result = self.executor.execute_tts(
                resource_id=resource_id,
                lexical_id=lexical_id,
                resource_type=resource_type,
                language=str(language),
                text=text,
                output_path=self._output_path(
                    lexical_id=lexical_id,
                    resource_type=resource_type,
                    extension=".wav",
                ),
            )
        else:
            raise ValueError(f"Unsupported multimedia resource_type: {resource_type}")

        record = result.to_dict()
        record.update(
            {
                "lexical_id": lexical_id,
                "language": language,
                "source_component": "SPT-023.4-CAPA-1",
                "target_component": "ADR-010/RMR",
                "paid_api_used": False,
                "external_network_required": False,
            }
        )
        return self.rmr.upsert(record)

    def execute_plan(
        self,
        multimedia_plan: dict[str, Any],
        *,
        localized_texts: dict[str, str],
        image_prompt: str,
        native_audio_source: str | Path,
    ) -> dict[str, Any]:
        lexical_id = str(multimedia_plan["lexical_id"])
        puinave = str(multimedia_plan["puinave"])
        results: list[dict[str, Any]] = []

        for plan in multimedia_plan["plans"]:
            resource_type = str(plan["resource_type"])
            results.append(
                self.execute_resource(
                    plan,
                    puinave=puinave,
                    localized_text=localized_texts.get(resource_type),
                    image_prompt=image_prompt,
                    native_audio_source=native_audio_source,
                )
            )

        status_counts: dict[str, int] = {}
        for item in results:
            status = str(item["status"])
            status_counts[status] = status_counts.get(status, 0) + 1

        return {
            "component": "SPT-023.4",
            "layer": "2",
            "lexical_id": lexical_id,
            "resources_processed": len(results),
            "status_counts": status_counts,
            "paid_api_used": False,
            "external_network_required": False,
            "rmr_persisted": True,
            "results": results,
            "next_component": "SPT-023.4-CAPA-3",
        }
'@
    $Files["tests\integration\test_spt0234_multimedia_execution_layer2.py"] = @'
import base64
import json
import sys
import wave

import pytest

from sgoda.integration.spt0234.executor import LocalMultimediaExecutor
from sgoda.integration.spt0234.layer2 import Spt0234Layer2Service
from sgoda.integration.spt0234.rmr import RmrRegistry
from sgoda.integration.spt0234.validators import validate_image_file, validate_wav_file


PNG_1X1 = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
)


def write_wav(path):
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(8000)
        handle.writeframes(b"\x00\x00" * 80)


def make_commands():
    image_code = (
        "import base64,pathlib;"
        "pathlib.Path(r'{output}').write_bytes("
        "base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII='))"
    )
    wav_code = (
        "import wave,pathlib;"
        "p=pathlib.Path(r'{output}');"
        "p.parent.mkdir(parents=True,exist_ok=True);"
        "w=wave.open(str(p),'wb');"
        "w.setnchannels(1);w.setsampwidth(2);w.setframerate(8000);"
        "w.writeframes(b'\\x00\\x00'*80);w.close()"
    )
    image = f'"{sys.executable}" -c "{image_code}"'
    tts = f'"{sys.executable}" -c "{wav_code}"'
    return image, tts


def plan(resource_type, language=None):
    return {
        "resource_id": f"MM-{resource_type}",
        "lexical_id": "LEX-001",
        "resource_type": resource_type,
        "language": language,
    }


def service(tmp_path):
    image, tts = make_commands()
    return Spt0234Layer2Service(
        executor=LocalMultimediaExecutor(
            image_command=image,
            tts_command=tts,
        ),
        rmr=RmrRegistry(tmp_path / "rmr.json"),
        media_root=tmp_path / "media",
    )


def test_valid_png_is_accepted(tmp_path):
    path = tmp_path / "x.png"
    path.write_bytes(PNG_1X1)
    assert validate_image_file(path)["media_type"] == "image/png"


def test_invalid_image_is_rejected(tmp_path):
    path = tmp_path / "x.png"
    path.write_bytes(b"not-image")
    with pytest.raises(ValueError):
        validate_image_file(path)


def test_valid_wav_is_accepted(tmp_path):
    path = tmp_path / "x.wav"
    write_wav(path)
    assert validate_wav_file(path)["media_type"] == "audio/wav"


def test_invalid_wav_is_rejected(tmp_path):
    path = tmp_path / "x.wav"
    path.write_bytes(b"bad")
    with pytest.raises(ValueError):
        validate_wav_file(path)


def test_image_executes_local_provider(tmp_path):
    result = service(tmp_path).execute_resource(
        plan("image"),
        puinave="AMDA",
        image_prompt="single lexical illustration",
    )
    assert result["status"] == "GENERATED_LOCAL"
    assert result["paid_api_used"] is False


@pytest.mark.parametrize(
    ("resource_type", "locale"),
    [
        ("audio_es", "es-CO"),
        ("audio_en", "en-US"),
        ("audio_it", "it-IT"),
    ],
)
def test_tts_executes_local_provider(tmp_path, resource_type, locale):
    result = service(tmp_path).execute_resource(
        plan(resource_type, locale),
        puinave="AMDA",
        localized_text="texto",
    )
    assert result["status"] == "GENERATED_LOCAL"
    assert result["validation"]["media_type"] == "audio/wav"


def test_puinave_native_audio_is_imported(tmp_path):
    source = tmp_path / "native.wav"
    write_wav(source)
    result = service(tmp_path).execute_resource(
        plan("audio_puinave", "pui"),
        puinave="AMDA",
        native_audio_source=source,
    )
    assert result["status"] == "IMPORTED_NATIVE"
    assert result["provider"] == "NATIVE_HUMAN_RECORDING"


def test_native_audio_missing_source_is_rejected(tmp_path):
    with pytest.raises(ValueError):
        service(tmp_path).execute_resource(
            plan("audio_puinave", "pui"),
            puinave="AMDA",
        )


def test_image_requires_prompt(tmp_path):
    with pytest.raises(ValueError):
        service(tmp_path).execute_resource(
            plan("image"),
            puinave="AMDA",
        )


def test_tts_requires_text(tmp_path):
    with pytest.raises(ValueError):
        service(tmp_path).execute_resource(
            plan("audio_es", "es-CO"),
            puinave="AMDA",
        )


def test_rmr_upsert_and_get(tmp_path):
    registry = RmrRegistry(tmp_path / "rmr.json")
    registry.upsert({"resource_id": "R1", "status": "APPROVED"})
    assert registry.get("R1")["status"] == "APPROVED"


def test_rmr_write_is_valid_json(tmp_path):
    path = tmp_path / "rmr.json"
    registry = RmrRegistry(path)
    registry.upsert({"resource_id": "R1", "status": "APPROVED"})
    assert json.loads(path.read_text(encoding="utf-8"))["resources"]["R1"]["status"] == "APPROVED"


def test_existing_rmr_resource_is_reused(tmp_path):
    svc = service(tmp_path)
    svc.rmr.upsert(
        {
            "resource_id": "MM-image",
            "status": "APPROVED",
            "resource_type": "image",
        }
    )
    result = svc.execute_resource(
        plan("image"),
        puinave="AMDA",
        image_prompt="unused",
    )
    assert result["status"] == "REUSE_EXISTING"
    assert result["reused"] is True


def test_executor_without_image_provider_is_blocked(tmp_path):
    executor = LocalMultimediaExecutor(tts_command="x")
    with pytest.raises(RuntimeError):
        executor.execute_image(
            resource_id="R1",
            lexical_id="L1",
            puinave="A",
            prompt="p",
            output_path=tmp_path / "x.png",
        )


def test_executor_without_tts_provider_is_blocked(tmp_path):
    executor = LocalMultimediaExecutor(image_command="x")
    with pytest.raises(RuntimeError):
        executor.execute_tts(
            resource_id="R1",
            lexical_id="L1",
            resource_type="audio_es",
            language="es-CO",
            text="hola",
            output_path=tmp_path / "x.wav",
        )


def test_unknown_resource_type_is_rejected(tmp_path):
    with pytest.raises(ValueError):
        service(tmp_path).execute_resource(
            plan("video"),
            puinave="AMDA",
        )


def test_execute_full_plan_persists_five_resources(tmp_path):
    svc = service(tmp_path)
    native = tmp_path / "native.wav"
    write_wav(native)

    multimedia_plan = {
        "lexical_id": "LEX-001",
        "puinave": "AMDA",
        "plans": [
            plan("image"),
            plan("audio_puinave", "pui"),
            plan("audio_es", "es-CO"),
            plan("audio_en", "en-US"),
            plan("audio_it", "it-IT"),
        ],
    }
    result = svc.execute_plan(
        multimedia_plan,
        localized_texts={
            "audio_es": "hola",
            "audio_en": "hello",
            "audio_it": "ciao",
        },
        image_prompt="single lexical illustration",
        native_audio_source=native,
    )
    assert result["resources_processed"] == 5
    assert result["rmr_persisted"] is True
    assert len(svc.rmr.load()["resources"]) == 5


def test_full_plan_never_uses_paid_api(tmp_path):
    svc = service(tmp_path)
    native = tmp_path / "native.wav"
    write_wav(native)

    result = svc.execute_plan(
        {
            "lexical_id": "LEX-001",
            "puinave": "AMDA",
            "plans": [
                plan("image"),
                plan("audio_puinave", "pui"),
                plan("audio_es", "es-CO"),
                plan("audio_en", "en-US"),
                plan("audio_it", "it-IT"),
            ],
        },
        localized_texts={
            "audio_es": "hola",
            "audio_en": "hello",
            "audio_it": "ciao",
        },
        image_prompt="single lexical illustration",
        native_audio_source=native,
    )
    assert result["paid_api_used"] is False
    assert result["external_network_required"] is False


def test_layer2_points_to_layer3(tmp_path):
    svc = service(tmp_path)
    native = tmp_path / "native.wav"
    write_wav(native)
    result = svc.execute_plan(
        {
            "lexical_id": "LEX-001",
            "puinave": "AMDA",
            "plans": [
                plan("image"),
                plan("audio_puinave", "pui"),
                plan("audio_es", "es-CO"),
                plan("audio_en", "en-US"),
                plan("audio_it", "it-IT"),
            ],
        },
        localized_texts={
            "audio_es": "hola",
            "audio_en": "hello",
            "audio_it": "ciao",
        },
        image_prompt="single lexical illustration",
        native_audio_source=native,
    )
    assert result["next_component"] == "SPT-023.4-CAPA-3"
'@
    $Files["docs\06_Tecnologia\SPT-023.4\SGD-SPT023.4-Capa2-Ejecucion-Local-RMR.md"] = @'
# SPT-023.4 — Generador Multimedia — Capa 2

## Objetivo

Implementar la ejecución local gobernada de los planes producidos por
SPT-023.4 Capa 1 y persistir los resultados en el Registro Multimedia
Reutilizable (ADR-010/RMR).

## Capacidades

- ejecución de proveedor local de imagen mediante comando configurable;
- ejecución de TTS local para español, inglés e italiano;
- incorporación de grabación humana nativa Puinave;
- validación binaria de imágenes PNG/JPEG;
- validación estructural de audio WAV;
- SHA-256 de cada recurso;
- persistencia atómica en RMR;
- reutilización de recursos ya aprobados;
- bloqueo cuando falta proveedor local o entrada humana requerida;
- prohibición explícita de APIs de pago y dependencia de red.

## Seguridad

La capa no contiene URLs, tokens, credenciales ni SDKs remotos. Los proveedores
son comandos locales declarados por configuración institucional.

Las pruebas usan proveedores locales sintéticos únicamente para validar el
contrato de ejecución y persistencia; no sustituyen la grabación Puinave ni
constituyen contenido multimedia institucional final.

## Siguiente desarrollo

SPT-023.4 Capa 3 deberá cerrar la gobernanza de calidad multimedia, aprobación
humana, manifestación de completitud por palabra y preparación del contrato de
salida hacia SPT-023.5 Constructor FLD/ODA.
'@
    $Files["config\integration\spt0234\local-execution.json"] = @'
{
  "schema_version": "1.0.0",
  "component": "SPT-023.4",
  "layer": "2",
  "execution_mode": "LOCAL_ONLY",
  "external_network_required": false,
  "paid_api_allowed": false,
  "image_provider": {
    "mode": "LOCAL_COMMAND",
    "command": null,
    "required_output": "PNG_OR_JPEG"
  },
  "tts_provider": {
    "mode": "LOCAL_COMMAND",
    "command": null,
    "languages": ["es-CO", "en-US", "it-IT"],
    "required_output": "WAV"
  },
  "puinave_audio": {
    "mode": "NATIVE_HUMAN_RECORDING",
    "required_output": "WAV",
    "human_validation_required": true
  },
  "registry": "ADR-010/RMR",
  "reuse_existing_approved_resources": true,
  "next_component": "SPT-023.4-CAPA-3"
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
        "src\sgoda\integration\spt0234\validators.py",
        "src\sgoda\integration\spt0234\executor.py",
        "src\sgoda\integration\spt0234\rmr.py",
        "src\sgoda\integration\spt0234\layer2.py",
        "tests\integration\test_spt0234_multimedia_execution_layer2.py"
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
                "tests/integration/test_spt0234_multimedia_execution_layer2.py" `
                -q 2>&1
        )
        $TargetCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $Previous
    }

    $TargetOutput | ForEach-Object { Write-Host $_ }
    if ($TargetCode -ne 0) {
        throw "Targeted SPT-023.4 Capa 2 tests failed."
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

    $EvidencePath = Join-Path $Root "artifacts\development\SPT-023.4-Capa2-v1.0.0\implementation-evidence.json"
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
        layer = "2"
        title = "Ejecucion Local y Persistencia Multimedia RMR"
        generated_utc = [DateTime]::UtcNow.ToString("o")
        certified_baseline = $ExpectedBaseline
        targeted_tests_passed = $TargetPassed
        institutional_tests_passed = $SuitePassed
        protected_files = $ProtectedBefore.Count
        protected_files_changed = $ChangedProtected.Count
        local_image_execution_contract = $true
        local_tts_execution_contract = $true
        puinave_native_import = $true
        png_jpeg_validation = $true
        wav_validation = $true
        sha256_per_resource = $true
        rmr_persistence = $true
        reuse_existing_resources = $true
        external_network_required = $false
        paid_api_allowed = $false
        next_component = "SPT-023.4-CAPA-3"
        generated_files = $Generated
    }

    Write-Utf8Lf -Path $EvidencePath -Content ($Evidence | ConvertTo-Json -Depth 8) -TrackCreated

    $MasterAppend = @"

$Marker
## SPT-023.4 — Generador Multimedia — Capa 2

- Estado institucional: CLOSED.
- Línea base de entrada: `$ExpectedBaseline`.
- Pruebas específicas: `$TargetPassed` aprobadas.
- Suite institucional: `$SuitePassed` aprobadas.
- Ejecución de imagen: contrato de proveedor local gobernado.
- TTS ES/EN/IT: ejecución mediante proveedor local gratuito configurable.
- Audio Puinave: importación de grabación humana nativa WAV.
- Validación: PNG/JPEG y WAV.
- Integridad: SHA-256 por recurso.
- Persistencia: ADR-010/RMR local y atómico.
- Reutilización: recursos existentes aprobados no se regeneran.
- Red externa obligatoria: NO.
- APIs de pago: NO.
- Componentes cerrados/reutilizados: preservados por SHA-256.
- Siguiente desarrollo: SPT-023.4 Capa 3 — gobernanza de calidad y cierre multimedia.
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
    $Allowed += "artifacts/development/SPT-023.4-Capa2-v1.0.0/implementation-evidence.json"
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
        throw "Repository moved during SPT-023.4 Capa 2 transaction."
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
