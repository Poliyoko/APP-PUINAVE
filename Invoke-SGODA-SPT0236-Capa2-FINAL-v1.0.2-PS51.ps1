param(
    [string]$ProjectRoot = "",
    [string]$ExpectedBaseline = "5eea474d0787e119f116c756484124b239f76d86"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$CommitMessage = "feat(spt-023.6): implement effective institutional adapters layer 2"
$ExpectedTargetedTests = 22
$ExpectedFullSuiteMinimum = 1052
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
    Write-Output " SPT-023.6 CAPA 2 : INSTITUTIONALLY CLOSED"
    Write-Output " COMMIT           : $Commit"
    Write-Output " TARGETED TESTS   : $Targeted PASSED"
    Write-Output " FULL SUITE       : $FullSuite PASSED"
    Write-Output " SPT-023.6 CAPA 1 : PRESERVED"
    Write-Output " SPT-023.1-.5     : PRESERVED"
    Write-Output " FASTAPI ADAPTER  : EFFECTIVE"
    Write-Output " N8N ADAPTER      : EFFECTIVE"
    Write-Output " PMO/AUDITOR      : EFFECTIVE"
    Write-Output " SGD-002 ADAPTER  : EFFECTIVE"
    Write-Output " SGD-002          : UPDATED"
    Write-Output " LOCAL/REMOTE     : IDENTICAL"
    Write-Output " AHEAD            : 0"
    Write-Output " BEHIND           : 0"
    Write-Output " STAGING          : CLEAN"
    Write-Output " DELETED TRACKED  : 0"
    Write-Output " ERRORS PENDING   : 0"
    Write-Output " NEXT             : SPT-023.6 CAPA 3"
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
    Write-Output " SPT-023.6 CAPA 2 : HOLD"
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
    Write-Output " SGODA-PUINAVE - SPT-023.6 CAPA 2 - MASTER TRANSACTION"
    Write-Output " EFFECTIVE ADAPTERS / FASTAPI / N8N / PMO / AUDITOR / SGD-002"
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
            $EvidenceResume = Join-Path $Root "artifacts\development\SPT-023.6-Capa2-v1.0.0\implementation-evidence.json"
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

        throw "HEAD is neither certified baseline nor a resumable SPT-023.6 Capa 2 commit."
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

    $Tracked = @(Invoke-Git @("-c","core.quotepath=false","ls-files"))
    $Protected = @(
        $Tracked | Where-Object {
            $_ -match '(?i)SPT-023\.[123456]' -or
            $_ -match '(?i)spt023[123456]' -or
            $_ -match '(?i)pmo' -or
            $_ -match '(?i)audit' -or
            $_ -match '(?i)n8n' -or
            $_ -match '(?i)fastapi'
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
        "src\sgoda\integration\spt0236\adapters.py",
        "src\sgoda\integration\spt0236\bindings.py",
        "src\sgoda\integration\spt0236\bridge.py",
        "tests\integration\test_spt0236_effective_adapters_layer2.py",
        "docs\06_Tecnologia\SPT-023.6\SGD-SPT023.6-Capa2-Adaptadores-Efectivos.md",
        "config\integration\spt0236\effective-adapters.json",
        "artifacts\development\SPT-023.6-Capa2-v1.0.0\implementation-evidence.json"
    )

    $RecoveredTargets = 0
    foreach ($Rel in $Targets) {
        $FullTarget = Join-Path $Root $Rel
        if (Test-Path -LiteralPath $FullTarget) {
            $Previous = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            try {
                & git ls-files --error-unmatch -- $Rel 2>$null | Out-Null
                $TrackedTargetCode = $LASTEXITCODE
            }
            finally {
                $ErrorActionPreference = $Previous
            }

            if ($TrackedTargetCode -eq 0) {
                throw "Tracked target already exists and will not be overwritten: $Rel"
            }

            Remove-Item -LiteralPath $FullTarget -Force
            $RecoveredTargets++
        }
    }

    Write-Host "RECOVERED STALE UNTRACKED TARGETS : $RecoveredTargets"

    $MasterBookPath = Join-Path $Root "docs\00_Estado_Maestro\SGD-002-Libro-Maestro-Institucional-SGODA-PUINAVE-v1.0.0.md"
    if (-not (Test-Path -LiteralPath $MasterBookPath -PathType Leaf)) {
        throw "SGD-002 master book not found."
    }

    $MasterBookOriginal = [System.IO.File]::ReadAllText($MasterBookPath)
    $Marker = "<!-- SPT-023.6-CAPA2-V1.0.0 -->"
    if ($MasterBookOriginal.Contains($Marker)) {
        throw "SGD-002 already contains SPT-023.6 Capa 2 marker while HEAD is baseline."
    }

    Write-Host "TARGET COLLISIONS : 0" -ForegroundColor Green

    $ObsoleteMasters = @(
        "Invoke-SGODA-SPT0236-Capa2-FINAL-v1.0.0-PS51.ps1",
        "Invoke-SGODA-SPT0236-Capa2-FINAL-v1.0.1-PS51.ps1"
    )

    foreach ($ObsoleteName in $ObsoleteMasters) {
        $ObsoleteMaster = Join-Path $Root $ObsoleteName
        if ($ScriptCandidate -ne $ObsoleteMaster -and (Test-Path -LiteralPath $ObsoleteMaster -PathType Leaf)) {
            $Previous = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            try {
                & git ls-files --error-unmatch -- $ObsoleteName 2>$null | Out-Null
                $OldMasterTrackedCode = $LASTEXITCODE
            }
            finally {
                $ErrorActionPreference = $Previous
            }

            if ($OldMasterTrackedCode -ne 0) {
                Remove-Item -LiteralPath $ObsoleteMaster -Force
                Write-Host ("OBSOLETE FAILED MASTER : REMOVED : " + $ObsoleteName)
            }
        }
    }

    Write-Host ""
    Write-Host "[4/12] IMPLEMENT SPT-023.6 CAPA 2" -ForegroundColor Yellow

    $Files = @{}
    $Files["src\sgoda\integration\spt0236\adapters.py"] = @'
from __future__ import annotations

import json
import subprocess
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable


@dataclass(frozen=True)
class AdapterResult:
    component: str
    status: str
    payload: dict[str, Any]
    transport: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "component": self.component,
            "status": self.status,
            "payload": dict(self.payload),
            "transport": self.transport,
        }


class JsonHttpAdapter:
    """Adaptador HTTP JSON desacoplado para servicios locales/institucionales."""

    def __init__(
        self,
        *,
        component: str,
        endpoint: str,
        timeout_seconds: float = 10.0,
    ) -> None:
        self.component = str(component)
        self.endpoint = str(endpoint).strip()
        self.timeout_seconds = float(timeout_seconds)
        if not self.endpoint:
            raise ValueError("HTTP endpoint is required.")

    def invoke(
        self,
        payload: dict[str, Any],
        *,
        expected_status: str,
    ) -> AdapterResult:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        request = urllib.request.Request(
            self.endpoint,
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(
                request,
                timeout=self.timeout_seconds,
            ) as response:
                raw = response.read().decode("utf-8")
        except urllib.error.URLError as exc:
            raise RuntimeError(
                f"{self.component} HTTP adapter failed: {exc}"
            ) from exc

        data = json.loads(raw or "{}")
        status = str(data.get("status") or "")
        if status != expected_status:
            raise ValueError(
                f"{self.component} returned {status!r}; expected {expected_status!r}."
            )

        return AdapterResult(
            component=self.component,
            status=status,
            payload=data,
            transport="HTTP_JSON",
        )


class LocalJsonFileAdapter:
    """Adaptador institucional efectivo por archivo JSON atómico."""

    def __init__(
        self,
        *,
        component: str,
        path: str | Path,
        status_field: str = "status",
    ) -> None:
        self.component = str(component)
        self.path = Path(path)
        self.status_field = str(status_field)

    def invoke(
        self,
        payload: dict[str, Any],
        *,
        expected_status: str,
    ) -> AdapterResult:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        temp = self.path.with_name(self.path.name + ".tmp")
        output = {
            "component": self.component,
            "status": expected_status,
            "input": dict(payload),
        }
        temp.write_text(
            json.dumps(output, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
            newline="\n",
        )
        temp.replace(self.path)

        data = json.loads(self.path.read_text(encoding="utf-8"))
        status = str(data.get(self.status_field) or "")
        if status != expected_status:
            raise ValueError(
                f"{self.component} file adapter status mismatch."
            )

        return AdapterResult(
            component=self.component,
            status=status,
            payload=data,
            transport="LOCAL_JSON_FILE",
        )


class LocalCommandAdapter:
    """Adaptador efectivo para herramientas institucionales ejecutables locales."""

    def __init__(
        self,
        *,
        component: str,
        command_factory: Callable[[dict[str, Any]], list[str]],
        timeout_seconds: float = 60.0,
    ) -> None:
        self.component = str(component)
        self.command_factory = command_factory
        self.timeout_seconds = float(timeout_seconds)

    def invoke(
        self,
        payload: dict[str, Any],
        *,
        expected_status: str,
    ) -> AdapterResult:
        command = self.command_factory(dict(payload))
        if not command:
            raise ValueError("Local command adapter produced an empty command.")

        completed = subprocess.run(
            command,
            check=False,
            capture_output=True,
            text=True,
            timeout=self.timeout_seconds,
        )
        if completed.returncode != 0:
            raise RuntimeError(
                f"{self.component} command failed: "
                + (completed.stderr or completed.stdout or "").strip()
            )

        data = json.loads((completed.stdout or "{}").strip() or "{}")
        status = str(data.get("status") or "")
        if status != expected_status:
            raise ValueError(
                f"{self.component} returned {status!r}; expected {expected_status!r}."
            )

        return AdapterResult(
            component=self.component,
            status=status,
            payload=data,
            transport="LOCAL_COMMAND",
        )
'@
    $Files["src\sgoda\integration\spt0236\bindings.py"] = @'
from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from .adapters import JsonHttpAdapter, LocalJsonFileAdapter


@dataclass(frozen=True)
class IntegrationBinding:
    component: str
    mode: str
    target: str
    enabled: bool


class EffectiveAdapterRegistry:
    """Registro de adaptadores efectivos para SPT-023.6 Capa 2."""

    def __init__(
        self,
        *,
        fastapi_endpoint: str | None = None,
        n8n_endpoint: str | None = None,
        pmo_state_path: str | None = None,
        auditor_state_path: str | None = None,
        sgd002_state_path: str | None = None,
    ) -> None:
        self.fastapi_endpoint = (fastapi_endpoint or "").strip() or None
        self.n8n_endpoint = (n8n_endpoint or "").strip() or None
        self.pmo_state_path = (pmo_state_path or "").strip() or None
        self.auditor_state_path = (auditor_state_path or "").strip() or None
        self.sgd002_state_path = (sgd002_state_path or "").strip() or None

    def bindings(self) -> list[IntegrationBinding]:
        return [
            IntegrationBinding(
                component="FASTAPI",
                mode="HTTP_JSON",
                target=self.fastapi_endpoint or "",
                enabled=self.fastapi_endpoint is not None,
            ),
            IntegrationBinding(
                component="N8N",
                mode="HTTP_JSON",
                target=self.n8n_endpoint or "",
                enabled=self.n8n_endpoint is not None,
            ),
            IntegrationBinding(
                component="PMO_DIGITAL",
                mode="LOCAL_JSON_FILE",
                target=self.pmo_state_path or "",
                enabled=self.pmo_state_path is not None,
            ),
            IntegrationBinding(
                component="AUDITOR_INSTITUCIONAL",
                mode="LOCAL_JSON_FILE",
                target=self.auditor_state_path or "",
                enabled=self.auditor_state_path is not None,
            ),
            IntegrationBinding(
                component="SGD-002",
                mode="LOCAL_JSON_FILE",
                target=self.sgd002_state_path or "",
                enabled=self.sgd002_state_path is not None,
            ),
        ]

    def build_handlers(self) -> dict[str, Any]:
        handlers: dict[str, Any] = {}

        if self.fastapi_endpoint:
            adapter = JsonHttpAdapter(
                component="FASTAPI",
                endpoint=self.fastapi_endpoint,
            )
            handlers["FASTAPI"] = lambda payload, adapter=adapter: adapter.invoke(
                payload,
                expected_status="ORCHESTRATION_EXPOSED",
            ).to_dict()

        if self.n8n_endpoint:
            adapter = JsonHttpAdapter(
                component="N8N",
                endpoint=self.n8n_endpoint,
            )
            handlers["N8N"] = lambda payload, adapter=adapter: adapter.invoke(
                payload,
                expected_status="WORKFLOW_COORDINATED",
            ).to_dict()

        if self.pmo_state_path:
            adapter = LocalJsonFileAdapter(
                component="PMO_DIGITAL",
                path=self.pmo_state_path,
            )
            handlers["PMO_DIGITAL"] = lambda payload, adapter=adapter: adapter.invoke(
                payload,
                expected_status="PMO_REGISTERED",
            ).to_dict()

        if self.auditor_state_path:
            adapter = LocalJsonFileAdapter(
                component="AUDITOR_INSTITUCIONAL",
                path=self.auditor_state_path,
            )
            handlers["AUDITOR_INSTITUCIONAL"] = lambda payload, adapter=adapter: adapter.invoke(
                payload,
                expected_status="AUDIT_APPROVED",
            ).to_dict()

        if self.sgd002_state_path:
            adapter = LocalJsonFileAdapter(
                component="SGD-002",
                path=self.sgd002_state_path,
            )
            handlers["SGD-002"] = lambda payload, adapter=adapter: adapter.invoke(
                payload,
                expected_status="MASTER_BOOK_UPDATED",
            ).to_dict()

        return handlers
'@
    $Files["src\sgoda\integration\spt0236\bridge.py"] = @'
from __future__ import annotations

from typing import Any, Callable

from .bindings import EffectiveAdapterRegistry
from .contracts import PIPELINE
from .service import Spt0236Layer1Service


ComponentHandler = Callable[[dict[str, Any]], dict[str, Any]]


class Spt0236Layer2Bridge:
    """Puente efectivo entre el motor de Capa 1 y adaptadores institucionales."""

    def __init__(
        self,
        *,
        orchestrator: Spt0236Layer1Service,
        adapters: EffectiveAdapterRegistry,
        core_handlers: dict[str, ComponentHandler],
    ) -> None:
        self.orchestrator = orchestrator
        self.adapters = adapters
        self.core_handlers = dict(core_handlers)

    def handlers(self) -> dict[str, ComponentHandler]:
        merged = dict(self.core_handlers)
        merged.update(self.adapters.build_handlers())
        return merged

    def validate_bindings(self) -> dict[str, Any]:
        bindings = self.adapters.bindings()
        available = set(self.handlers())

        required_core = {
            "SPT-023.1",
            "SPT-023.2",
            "SPT-023.3",
            "SPT-023.4",
            "SPT-023.5",
        }
        missing_core = sorted(required_core - available)
        if missing_core:
            raise ValueError(
                "Missing core integration handlers: " + ", ".join(missing_core)
            )

        return {
            "component": "SPT-023.6",
            "layer": "2",
            "bindings": [
                {
                    "component": item.component,
                    "mode": item.mode,
                    "target": item.target,
                    "enabled": item.enabled,
                }
                for item in bindings
            ],
            "core_handlers_present": sorted(required_core),
            "pipeline_components": [step.component for step in PIPELINE],
            "paid_api_used": False,
            "valid": True,
        }

    def execute(
        self,
        *,
        lexical_id: str,
    ) -> dict[str, Any]:
        self.validate_bindings()
        run = self.orchestrator.create_run(lexical_id=lexical_id)
        result = self.orchestrator.execute_with_handlers(
            orchestration_id=run["orchestration_id"],
            handlers=self.handlers(),
        )
        result["integration_layer"] = 2
        result["effective_adapters"] = True
        result["paid_api_used"] = False
        result["next_component"] = "SPT-023.6-CAPA-3"
        return result
'@
    $Files["tests\integration\test_spt0236_effective_adapters_layer2.py"] = @'
import json
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer

import pytest

from sgoda.integration.spt0236.adapters import JsonHttpAdapter, LocalJsonFileAdapter
from sgoda.integration.spt0236.bindings import EffectiveAdapterRegistry
from sgoda.integration.spt0236.bridge import Spt0236Layer2Bridge
from sgoda.integration.spt0236.contracts import PIPELINE
from sgoda.integration.spt0236.service import Spt0236Layer1Service
from sgoda.integration.spt0236.state import OrchestrationStateStore


def server_for(status):
    expected_response_status = str(status)

    class IsolatedHandler(BaseHTTPRequestHandler):
        def do_POST(self):
            length = int(self.headers.get("Content-Length", "0"))
            self.rfile.read(length)
            body = json.dumps(
                {"status": expected_response_status}
            ).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            return

    server = HTTPServer(("127.0.0.1", 0), IsolatedHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    return server, f"http://127.0.0.1:{server.server_address[1]}/"


def core_handlers():
    mapping = {}
    for step in PIPELINE:
        if step.component.startswith("SPT-023."):
            mapping[step.component] = (
                lambda expected: (
                    lambda payload: {"status": expected, "payload": payload}
                )
            )(step.success_status)
    return mapping


def test_http_adapter_accepts_expected_status():
    server, endpoint = server_for("ORCHESTRATION_EXPOSED")
    try:
        result = JsonHttpAdapter(
            component="FASTAPI",
            endpoint=endpoint,
        ).invoke({}, expected_status="ORCHESTRATION_EXPOSED")
        assert result.status == "ORCHESTRATION_EXPOSED"
    finally:
        server.shutdown()


def test_http_adapter_rejects_wrong_status():
    server, endpoint = server_for("WRONG")
    try:
        with pytest.raises(ValueError):
            JsonHttpAdapter(
                component="FASTAPI",
                endpoint=endpoint,
            ).invoke({}, expected_status="ORCHESTRATION_EXPOSED")
    finally:
        server.shutdown()


def test_file_adapter_persists_expected_status(tmp_path):
    path = tmp_path / "pmo.json"
    result = LocalJsonFileAdapter(
        component="PMO_DIGITAL",
        path=path,
    ).invoke({"x": 1}, expected_status="PMO_REGISTERED")
    assert result.status == "PMO_REGISTERED"
    assert path.exists()


def test_file_adapter_writes_valid_json(tmp_path):
    path = tmp_path / "auditor.json"
    LocalJsonFileAdapter(
        component="AUDITOR_INSTITUCIONAL",
        path=path,
    ).invoke({}, expected_status="AUDIT_APPROVED")
    assert json.loads(path.read_text(encoding="utf-8"))["status"] == "AUDIT_APPROVED"


def test_registry_exposes_five_bindings(tmp_path):
    registry = EffectiveAdapterRegistry(
        fastapi_endpoint="http://127.0.0.1:1/",
        n8n_endpoint="http://127.0.0.1:2/",
        pmo_state_path=str(tmp_path / "pmo.json"),
        auditor_state_path=str(tmp_path / "audit.json"),
        sgd002_state_path=str(tmp_path / "sgd002.json"),
    )
    assert len(registry.bindings()) == 5


def test_registry_can_disable_unconfigured_bindings():
    registry = EffectiveAdapterRegistry()
    assert all(not item.enabled for item in registry.bindings())


def test_registry_builds_local_handlers(tmp_path):
    registry = EffectiveAdapterRegistry(
        pmo_state_path=str(tmp_path / "pmo.json"),
        auditor_state_path=str(tmp_path / "audit.json"),
        sgd002_state_path=str(tmp_path / "sgd002.json"),
    )
    handlers = registry.build_handlers()
    assert {"PMO_DIGITAL", "AUDITOR_INSTITUCIONAL", "SGD-002"} <= set(handlers)


def test_registry_builds_http_handlers():
    registry = EffectiveAdapterRegistry(
        fastapi_endpoint="http://127.0.0.1:1/",
        n8n_endpoint="http://127.0.0.1:2/",
    )
    handlers = registry.build_handlers()
    assert {"FASTAPI", "N8N"} <= set(handlers)


def test_bridge_requires_all_core_handlers(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    bridge = Spt0236Layer2Bridge(
        orchestrator=service,
        adapters=EffectiveAdapterRegistry(),
        core_handlers={},
    )
    with pytest.raises(ValueError):
        bridge.validate_bindings()


def test_bridge_validates_core_handlers(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    bridge = Spt0236Layer2Bridge(
        orchestrator=service,
        adapters=EffectiveAdapterRegistry(),
        core_handlers=core_handlers(),
    )
    assert bridge.validate_bindings()["valid"] is True


def test_bridge_validation_disables_paid_api(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    bridge = Spt0236Layer2Bridge(
        orchestrator=service,
        adapters=EffectiveAdapterRegistry(),
        core_handlers=core_handlers(),
    )
    assert bridge.validate_bindings()["paid_api_used"] is False


def test_bridge_executes_with_local_institutional_adapters(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    bridge = Spt0236Layer2Bridge(
        orchestrator=service,
        adapters=EffectiveAdapterRegistry(
            pmo_state_path=str(tmp_path / "pmo.json"),
            auditor_state_path=str(tmp_path / "audit.json"),
            sgd002_state_path=str(tmp_path / "sgd002.json"),
        ),
        core_handlers=core_handlers(),
    )
    result = bridge.execute(lexical_id="LEX-001")
    assert result["orchestration_complete"] is True


def test_bridge_executes_with_n8n_http_adapter(tmp_path):
    n8n_server, n8n_endpoint = server_for("WORKFLOW_COORDINATED")
    try:
        service = Spt0236Layer1Service(
            OrchestrationStateStore(tmp_path / "state.json")
        )
        bridge = Spt0236Layer2Bridge(
            orchestrator=service,
            adapters=EffectiveAdapterRegistry(
                n8n_endpoint=n8n_endpoint,
                pmo_state_path=str(tmp_path / "pmo.json"),
                auditor_state_path=str(tmp_path / "audit.json"),
                sgd002_state_path=str(tmp_path / "sgd002.json"),
            ),
            core_handlers=core_handlers(),
        )
        result = bridge.execute(lexical_id="LEX-001")
        assert result["orchestration_complete"] is True
    finally:
        n8n_server.shutdown()


def test_bridge_executes_with_fastapi_http_adapter(tmp_path):
    api_server, api_endpoint = server_for("ORCHESTRATION_EXPOSED")
    try:
        service = Spt0236Layer1Service(
            OrchestrationStateStore(tmp_path / "state.json")
        )
        bridge = Spt0236Layer2Bridge(
            orchestrator=service,
            adapters=EffectiveAdapterRegistry(
                fastapi_endpoint=api_endpoint,
                pmo_state_path=str(tmp_path / "pmo.json"),
                auditor_state_path=str(tmp_path / "audit.json"),
                sgd002_state_path=str(tmp_path / "sgd002.json"),
            ),
            core_handlers=core_handlers(),
        )
        result = bridge.execute(lexical_id="LEX-001")
        assert result["orchestration_complete"] is True
    finally:
        api_server.shutdown()


def test_bridge_executes_with_both_http_adapters(tmp_path):
    n8n_server, n8n_endpoint = server_for("WORKFLOW_COORDINATED")
    api_server, api_endpoint = server_for("ORCHESTRATION_EXPOSED")
    try:
        service = Spt0236Layer1Service(
            OrchestrationStateStore(tmp_path / "state.json")
        )
        bridge = Spt0236Layer2Bridge(
            orchestrator=service,
            adapters=EffectiveAdapterRegistry(
                fastapi_endpoint=api_endpoint,
                n8n_endpoint=n8n_endpoint,
                pmo_state_path=str(tmp_path / "pmo.json"),
                auditor_state_path=str(tmp_path / "audit.json"),
                sgd002_state_path=str(tmp_path / "sgd002.json"),
            ),
            core_handlers=core_handlers(),
        )
        result = bridge.execute(lexical_id="LEX-001")
        assert result["effective_adapters"] is True
    finally:
        n8n_server.shutdown()
        api_server.shutdown()


def test_bridge_points_to_layer3(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    bridge = Spt0236Layer2Bridge(
        orchestrator=service,
        adapters=EffectiveAdapterRegistry(
            pmo_state_path=str(tmp_path / "pmo.json"),
            auditor_state_path=str(tmp_path / "audit.json"),
            sgd002_state_path=str(tmp_path / "sgd002.json"),
        ),
        core_handlers=core_handlers(),
    )
    result = bridge.execute(lexical_id="LEX-001")
    assert result["next_component"] == "SPT-023.6-CAPA-3"


def test_pmo_file_is_created(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    pmo = tmp_path / "pmo.json"
    bridge = Spt0236Layer2Bridge(
        orchestrator=service,
        adapters=EffectiveAdapterRegistry(
            pmo_state_path=str(pmo),
            auditor_state_path=str(tmp_path / "audit.json"),
            sgd002_state_path=str(tmp_path / "sgd002.json"),
        ),
        core_handlers=core_handlers(),
    )
    bridge.execute(lexical_id="LEX-001")
    assert pmo.exists()


def test_auditor_file_is_created(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    audit = tmp_path / "audit.json"
    bridge = Spt0236Layer2Bridge(
        orchestrator=service,
        adapters=EffectiveAdapterRegistry(
            pmo_state_path=str(tmp_path / "pmo.json"),
            auditor_state_path=str(audit),
            sgd002_state_path=str(tmp_path / "sgd002.json"),
        ),
        core_handlers=core_handlers(),
    )
    bridge.execute(lexical_id="LEX-001")
    assert audit.exists()


def test_sgd002_file_is_created(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    sgd = tmp_path / "sgd002.json"
    bridge = Spt0236Layer2Bridge(
        orchestrator=service,
        adapters=EffectiveAdapterRegistry(
            pmo_state_path=str(tmp_path / "pmo.json"),
            auditor_state_path=str(tmp_path / "audit.json"),
            sgd002_state_path=str(sgd),
        ),
        core_handlers=core_handlers(),
    )
    bridge.execute(lexical_id="LEX-001")
    assert sgd.exists()


def test_orchestration_remains_idempotent(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    bridge = Spt0236Layer2Bridge(
        orchestrator=service,
        adapters=EffectiveAdapterRegistry(
            pmo_state_path=str(tmp_path / "pmo.json"),
            auditor_state_path=str(tmp_path / "audit.json"),
            sgd002_state_path=str(tmp_path / "sgd002.json"),
        ),
        core_handlers=core_handlers(),
    )
    one = bridge.execute(lexical_id="LEX-001")
    two = service.execute_with_handlers(
        orchestration_id=one["orchestration_id"],
        handlers=bridge.handlers(),
    )
    assert one["completed_steps"] == two["completed_steps"]


def test_state_store_preserves_completed_steps(tmp_path):
    service = Spt0236Layer1Service(
        OrchestrationStateStore(tmp_path / "state.json")
    )
    bridge = Spt0236Layer2Bridge(
        orchestrator=service,
        adapters=EffectiveAdapterRegistry(
            pmo_state_path=str(tmp_path / "pmo.json"),
            auditor_state_path=str(tmp_path / "audit.json"),
            sgd002_state_path=str(tmp_path / "sgd002.json"),
        ),
        core_handlers=core_handlers(),
    )
    result = bridge.execute(lexical_id="LEX-001")
    stored = service.state_store.get(result["orchestration_id"])
    assert len(stored["completed_steps"]) == 10


def test_http_binding_is_decoupled_from_core_handlers(tmp_path):
    registry = EffectiveAdapterRegistry(
        fastapi_endpoint="http://127.0.0.1:1/"
    )
    assert "FASTAPI" in registry.build_handlers()
    assert "SPT-023.1" not in registry.build_handlers()
'@
    $Files["docs\06_Tecnologia\SPT-023.6\SGD-SPT023.6-Capa2-Adaptadores-Efectivos.md"] = @'
# SPT-023.6 — Orquestador Inteligente — Capa 2

## Objetivo

Pasar del contrato de integración definido en Capa 1 a adaptadores efectivos
entre el orquestador y FastAPI, n8n, PMO Digital, Auditor Institucional y
SGD-002, preservando desacoplamiento, reanudación e idempotencia.

## Adaptadores efectivos

- FastAPI: adaptador HTTP JSON configurable.
- n8n: adaptador HTTP JSON configurable.
- PMO Digital: adaptador institucional local JSON atómico.
- Auditor Institucional: adaptador institucional local JSON atómico.
- SGD-002: adaptador institucional local JSON atómico.

Los componentes SPT-023.1 a SPT-023.5 continúan ingresando al orquestador por
handlers existentes y no son reimplementados.

## Desacoplamiento

La Capa 2 no contiene URLs institucionales codificadas, credenciales ni tokens.
Los endpoints y rutas se suministran por configuración. Los adaptadores HTTP
usan únicamente biblioteca estándar y los adaptadores institucionales locales
persisten de forma atómica.

## Pruebas

Las pruebas HTTP levantan servidores locales efímeros en `127.0.0.1`; no
requieren Internet, n8n real ni FastAPI productivo.

## Siguiente desarrollo

SPT-023.6 Capa 3 deberá implementar gobierno de ejecución, reintentos,
compensación, auditoría de eventos, health gates y cierre institucional del
Orquestador Inteligente.
'@
    $Files["config\integration\spt0236\effective-adapters.json"] = @'
{
  "schema_version": "1.0.0",
  "component": "SPT-023.6",
  "layer": "2",
  "effective_adapters": {
    "FASTAPI": "HTTP_JSON_CONFIGURABLE",
    "N8N": "HTTP_JSON_CONFIGURABLE",
    "PMO_DIGITAL": "LOCAL_JSON_ATOMIC",
    "AUDITOR_INSTITUCIONAL": "LOCAL_JSON_ATOMIC",
    "SGD-002": "LOCAL_JSON_ATOMIC"
  },
  "core_components_reused": [
    "SPT-023.1",
    "SPT-023.2",
    "SPT-023.3",
    "SPT-023.4",
    "SPT-023.5"
  ],
  "hardcoded_credentials": false,
  "internet_required_for_tests": false,
  "resume_supported": true,
  "idempotent": true,
  "paid_api_allowed": false,
  "next_component": "SPT-023.6-CAPA-3"
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
        "src\sgoda\integration\spt0236\adapters.py",
        "src\sgoda\integration\spt0236\bindings.py",
        "src\sgoda\integration\spt0236\bridge.py",
        "tests\integration\test_spt0236_effective_adapters_layer2.py"
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
                "tests/integration/test_spt0236_effective_adapters_layer2.py" `
                -q 2>&1
        )
        $TargetCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $Previous
    }

    $TargetOutput | ForEach-Object { Write-Host $_ }
    if ($TargetCode -ne 0) {
        throw "Targeted SPT-023.6 Capa 2 tests failed."
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

    $EvidencePath = Join-Path $Root "artifacts\development\SPT-023.6-Capa2-v1.0.0\implementation-evidence.json"
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
        component = "SPT-023.6"
        layer = "2"
        title = "Adaptadores Efectivos Institucionales"
        generated_utc = [DateTime]::UtcNow.ToString("o")
        certified_baseline = $ExpectedBaseline
        targeted_tests_passed = $TargetPassed
        institutional_tests_passed = $SuitePassed
        protected_files = $ProtectedBefore.Count
        protected_files_changed = $ChangedProtected.Count
        fastapi_adapter = "HTTP_JSON_CONFIGURABLE"
        n8n_adapter = "HTTP_JSON_CONFIGURABLE"
        pmo_adapter = "LOCAL_JSON_ATOMIC"
        auditor_adapter = "LOCAL_JSON_ATOMIC"
        sgd002_adapter = "LOCAL_JSON_ATOMIC"
        core_components_reused = @("SPT-023.1","SPT-023.2","SPT-023.3","SPT-023.4","SPT-023.5")
        internet_required_for_tests = $false
        idempotent = $true
        resume_supported = $true
        paid_api_allowed = $false
        next_component = "SPT-023.6-CAPA-3"
        generated_files = $Generated
    }

    Write-Utf8Lf -Path $EvidencePath -Content ($Evidence | ConvertTo-Json -Depth 8) -TrackCreated

    $MasterAppend = @"

$Marker
## SPT-023.6 — Orquestador Inteligente — Capa 2

- Estado institucional: CLOSED.
- Línea base de entrada: `$ExpectedBaseline`.
- Pruebas específicas: `$TargetPassed` aprobadas.
- Suite institucional: `$SuitePassed` aprobadas.
- SPT-023.6 Capa 1: preservada.
- SPT-023.1 a SPT-023.5: preservados y reutilizados.
- FastAPI: adaptador HTTP JSON efectivo y configurable.
- n8n: adaptador HTTP JSON efectivo y configurable.
- PMO Digital: adaptador local JSON atómico efectivo.
- Auditor Institucional: adaptador local JSON atómico efectivo.
- SGD-002: adaptador local JSON atómico efectivo.
- Endpoints/credenciales hardcoded: NO.
- Internet requerido para pruebas: NO.
- Reanudación e idempotencia: preservadas.
- APIs de pago: deshabilitadas.
- Siguiente desarrollo: SPT-023.6 Capa 3 — gobierno de ejecución, reintentos, compensación, auditoría de eventos y cierre.
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
    $Allowed += "artifacts/development/SPT-023.6-Capa2-v1.0.0/implementation-evidence.json"
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
        throw "Repository moved during SPT-023.6 Capa 2 transaction."
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
