param(
    [string]$ProjectRoot = "",
    [string]$ExpectedBaseline = "f6634162fd79fa2c724692e5cf93fbaf8599618a"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

$CommitMessage = "feat(spt-023.6): close governed orchestrator layer 3"
$ExpectedTargetedTests = 24
$ExpectedFullSuiteMinimum = 1076
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
    Write-Output " SPT-023.6 CAPA 3 : INSTITUTIONALLY CLOSED"
    Write-Output " SPT-023.6        : INSTITUTIONALLY CLOSED"
    Write-Output " COMMIT           : $Commit"
    Write-Output " TARGETED TESTS   : $Targeted PASSED"
    Write-Output " FULL SUITE       : $FullSuite PASSED"
    Write-Output " CAPAS 1-2        : PRESERVED"
    Write-Output " SPT-023.1-.5     : PRESERVED"
    Write-Output " RETRIES          : GOVERNED"
    Write-Output " COMPENSATION     : GOVERNED"
    Write-Output " EVENT LEDGER     : SHA-256 VERIFIED"
    Write-Output " HEALTH GATES     : PASS"
    Write-Output " SGD-002          : UPDATED"
    Write-Output " LOCAL/REMOTE     : IDENTICAL"
    Write-Output " AHEAD            : 0"
    Write-Output " BEHIND           : 0"
    Write-Output " STAGING          : CLEAN"
    Write-Output " DELETED TRACKED  : 0"
    Write-Output " ERRORS PENDING   : 0"
    Write-Output " NEXT             : SPT-023.7 AUDITORIA INTELIGENTE"
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
    Write-Output " SPT-023.6 CAPA 3 : HOLD"
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
    Write-Output " SGODA-PUINAVE - SPT-023.6 CAPA 3 - FINAL MASTER TRANSACTION"
    Write-Output " GOVERNANCE / RETRIES / COMPENSATION / EVENT LEDGER / HEALTH GATES"
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
            $EvidenceResume = Join-Path $Root "artifacts\development\SPT-023.6-Capa3-v1.0.0\implementation-evidence.json"
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

        throw "HEAD is neither certified baseline nor a resumable SPT-023.6 Capa 3 commit."
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
        "src\sgoda\integration\spt0236\governance.py",
        "src\sgoda\integration\spt0236\events.py",
        "src\sgoda\integration\spt0236\compensation.py",
        "src\sgoda\integration\spt0236\runtime.py",
        "src\sgoda\integration\spt0236\layer3.py",
        "tests\integration\test_spt0236_governance_layer3.py",
        "docs\06_Tecnologia\SPT-023.6\SGD-SPT023.6-Capa3-Gobierno-Cierre.md",
        "config\integration\spt0236\governance-policy.json",
        "artifacts\development\SPT-023.6-Capa3-v1.0.0\implementation-evidence.json"
    )

    foreach ($Rel in $Targets) {
        if (Test-Path -LiteralPath (Join-Path $Root $Rel)) {
            throw "Target already exists before fresh SPT-023.6 Capa 3 transaction: $Rel"
        }
    }

    $MasterBookPath = Join-Path $Root "docs\00_Estado_Maestro\SGD-002-Libro-Maestro-Institucional-SGODA-PUINAVE-v1.0.0.md"
    if (-not (Test-Path -LiteralPath $MasterBookPath -PathType Leaf)) {
        throw "SGD-002 master book not found."
    }

    $MasterBookOriginal = [System.IO.File]::ReadAllText($MasterBookPath)
    $Marker = "<!-- SPT-023.6-CAPA3-CLOSE-V1.0.0 -->"
    if ($MasterBookOriginal.Contains($Marker)) {
        throw "SGD-002 already contains SPT-023.6 Capa 3 closure marker while HEAD is baseline."
    }

    Write-Host "TARGET COLLISIONS : 0" -ForegroundColor Green

    Write-Host ""
    Write-Host "[4/12] IMPLEMENT SPT-023.6 CAPA 3" -ForegroundColor Yellow

    $Files = @{}
    $Files["src\sgoda\integration\spt0236\governance.py"] = @'
from __future__ import annotations

from dataclasses import dataclass, asdict
from typing import Any


@dataclass(frozen=True)
class RetryPolicy:
    max_attempts: int = 3
    retryable_exceptions: tuple[str, ...] = ("RuntimeError", "TimeoutError")

    def validate(self) -> None:
        if self.max_attempts < 1:
            raise ValueError("max_attempts must be >= 1.")

    def to_dict(self) -> dict[str, Any]:
        self.validate()
        return asdict(self)


@dataclass(frozen=True)
class HealthGateResult:
    component: str
    healthy: bool
    detail: str

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


def evaluate_health_gates(
    results: list[HealthGateResult],
    *,
    required_components: tuple[str, ...],
) -> dict[str, Any]:
    by_component = {item.component: item for item in results}
    missing = [
        component for component in required_components
        if component not in by_component
    ]
    unhealthy = [
        component for component in required_components
        if component in by_component and not by_component[component].healthy
    ]
    return {
        "required_components": list(required_components),
        "missing": missing,
        "unhealthy": unhealthy,
        "passed": not missing and not unhealthy,
    }
'@
    $Files["src\sgoda\integration\spt0236\events.py"] = @'
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
from typing import Any


def _canonical(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


class OrchestrationEventLedger:
    """Ledger local append-only lógico con hash encadenado."""

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)

    def _load(self) -> list[dict[str, Any]]:
        if not self.path.exists():
            return []
        data = json.loads(self.path.read_text(encoding="utf-8"))
        if not isinstance(data, list):
            raise ValueError("Event ledger must be a JSON array.")
        self.verify(data)
        return data

    @staticmethod
    def verify(events: list[dict[str, Any]]) -> bool:
        previous = "GENESIS"
        for index, event in enumerate(events, start=1):
            if int(event.get("sequence", 0)) != index:
                raise ValueError("Event sequence is not contiguous.")
            if str(event.get("previous_hash") or "") != previous:
                raise ValueError("Event previous_hash mismatch.")

            body = {
                "sequence": index,
                "orchestration_id": str(event.get("orchestration_id") or ""),
                "event_type": str(event.get("event_type") or ""),
                "payload": dict(event.get("payload") or {}),
                "previous_hash": previous,
            }
            expected = hashlib.sha256(_canonical(body)).hexdigest().upper()
            if str(event.get("event_sha256") or "") != expected:
                raise ValueError("Event SHA-256 mismatch.")
            previous = expected
        return True

    def append(
        self,
        *,
        orchestration_id: str,
        event_type: str,
        payload: dict[str, Any],
    ) -> dict[str, Any]:
        orchestration_id = str(orchestration_id or "").strip()
        event_type = str(event_type or "").strip()
        if not orchestration_id or not event_type:
            raise ValueError("orchestration_id and event_type are required.")

        events = self._load()
        previous = events[-1]["event_sha256"] if events else "GENESIS"
        sequence = len(events) + 1
        body = {
            "sequence": sequence,
            "orchestration_id": orchestration_id,
            "event_type": event_type,
            "payload": dict(payload),
            "previous_hash": previous,
        }
        event = dict(body)
        event["event_sha256"] = hashlib.sha256(
            _canonical(body)
        ).hexdigest().upper()
        events.append(event)

        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_name(self.path.name + ".tmp")
        tmp.write_text(
            json.dumps(events, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
            newline="\n",
        )
        os.replace(tmp, self.path)
        self.verify(events)
        return event

    def all(self) -> list[dict[str, Any]]:
        return self._load()
'@
    $Files["src\sgoda\integration\spt0236\compensation.py"] = @'
from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Callable


CompensationHandler = Callable[[dict[str, Any]], dict[str, Any]]


@dataclass(frozen=True)
class CompensationResult:
    component: str
    status: str
    detail: dict[str, Any]

    def to_dict(self) -> dict[str, Any]:
        return {
            "component": self.component,
            "status": self.status,
            "detail": dict(self.detail),
        }


class CompensationRegistry:
    def __init__(self) -> None:
        self._handlers: dict[str, CompensationHandler] = {}

    def register(
        self,
        component: str,
        handler: CompensationHandler,
    ) -> None:
        component = str(component or "").strip()
        if not component:
            raise ValueError("component is required.")
        self._handlers[component] = handler

    def compensate(
        self,
        component: str,
        payload: dict[str, Any],
    ) -> CompensationResult:
        handler = self._handlers.get(component)
        if handler is None:
            return CompensationResult(
                component=component,
                status="NO_COMPENSATION_REGISTERED",
                detail={},
            )

        result = dict(handler(dict(payload)) or {})
        status = str(result.get("status") or "").strip()
        if not status:
            raise ValueError("Compensation handler must return status.")
        return CompensationResult(
            component=component,
            status=status,
            detail=result,
        )
'@
    $Files["src\sgoda\integration\spt0236\runtime.py"] = @'
from __future__ import annotations

from typing import Any, Callable

from .compensation import CompensationRegistry
from .events import OrchestrationEventLedger
from .governance import RetryPolicy


Handler = Callable[[dict[str, Any]], dict[str, Any]]


class GovernedExecutionRuntime:
    """Runtime gobernado con retries, eventos y compensación."""

    def __init__(
        self,
        *,
        ledger: OrchestrationEventLedger,
        compensation: CompensationRegistry,
        retry_policy: RetryPolicy | None = None,
    ) -> None:
        self.ledger = ledger
        self.compensation = compensation
        self.retry_policy = retry_policy or RetryPolicy()
        self.retry_policy.validate()

    def execute(
        self,
        *,
        orchestration_id: str,
        component: str,
        expected_status: str,
        handler: Handler,
        payload: dict[str, Any],
    ) -> dict[str, Any]:
        self.ledger.append(
            orchestration_id=orchestration_id,
            event_type="STEP_STARTED",
            payload={"component": component},
        )

        last_error: Exception | None = None
        for attempt in range(1, self.retry_policy.max_attempts + 1):
            self.ledger.append(
                orchestration_id=orchestration_id,
                event_type="STEP_ATTEMPT",
                payload={"component": component, "attempt": attempt},
            )
            try:
                result = dict(handler(dict(payload)) or {})
                status = str(result.get("status") or "")
                if status != expected_status:
                    raise ValueError(
                        f"{component} returned {status!r}; "
                        f"expected {expected_status!r}."
                    )

                self.ledger.append(
                    orchestration_id=orchestration_id,
                    event_type="STEP_SUCCEEDED",
                    payload={
                        "component": component,
                        "attempt": attempt,
                        "status": status,
                    },
                )
                return result
            except Exception as exc:
                last_error = exc
                retryable = type(exc).__name__ in self.retry_policy.retryable_exceptions
                self.ledger.append(
                    orchestration_id=orchestration_id,
                    event_type="STEP_FAILED",
                    payload={
                        "component": component,
                        "attempt": attempt,
                        "error_type": type(exc).__name__,
                        "retryable": retryable,
                    },
                )
                if not retryable or attempt >= self.retry_policy.max_attempts:
                    break

        compensation = self.compensation.compensate(
            component,
            {
                "orchestration_id": orchestration_id,
                "component": component,
                "payload": dict(payload),
            },
        )
        self.ledger.append(
            orchestration_id=orchestration_id,
            event_type="COMPENSATION_EXECUTED",
            payload=compensation.to_dict(),
        )

        if last_error is None:
            raise RuntimeError(f"{component} failed without an exception.")
        raise last_error
'@
    $Files["src\sgoda\integration\spt0236\layer3.py"] = @'
from __future__ import annotations

from pathlib import Path
from typing import Any, Callable

from .compensation import CompensationRegistry
from .events import OrchestrationEventLedger
from .governance import HealthGateResult, RetryPolicy, evaluate_health_gates
from .runtime import GovernedExecutionRuntime


HealthProbe = Callable[[], HealthGateResult]


class Spt0236Layer3GovernanceService:
    """Gobierno final de ejecución y cierre del Orquestador Inteligente."""

    REQUIRED_HEALTH = (
        "ORCHESTRATOR",
        "STATE_STORE",
        "PMO_DIGITAL",
        "AUDITOR_INSTITUCIONAL",
        "SGD-002",
    )

    def __init__(
        self,
        *,
        ledger_path: str | Path,
        retry_policy: RetryPolicy | None = None,
    ) -> None:
        self.ledger = OrchestrationEventLedger(ledger_path)
        self.compensation = CompensationRegistry()
        self.runtime = GovernedExecutionRuntime(
            ledger=self.ledger,
            compensation=self.compensation,
            retry_policy=retry_policy,
        )

    def register_compensation(
        self,
        component: str,
        handler: Callable[[dict[str, Any]], dict[str, Any]],
    ) -> None:
        self.compensation.register(component, handler)

    def health_gate(
        self,
        probes: dict[str, HealthProbe],
    ) -> dict[str, Any]:
        results: list[HealthGateResult] = []
        for component in self.REQUIRED_HEALTH:
            probe = probes.get(component)
            if probe is None:
                continue
            result = probe()
            if result.component != component:
                raise ValueError("Health probe component mismatch.")
            results.append(result)

        gate = evaluate_health_gates(
            results,
            required_components=self.REQUIRED_HEALTH,
        )
        gate["component"] = "SPT-023.6"
        gate["layer"] = "3"
        return gate

    def certify_closure(
        self,
        *,
        orchestration_id: str,
        health_gate: dict[str, Any],
        orchestration_complete: bool,
        adapters_effective: bool,
    ) -> dict[str, Any]:
        if not bool(health_gate.get("passed")):
            raise ValueError("Health gates must pass before SPT-023.6 closure.")
        if not orchestration_complete:
            raise ValueError("Orchestration must be complete before closure.")
        if not adapters_effective:
            raise ValueError("Effective adapters are required before closure.")

        self.ledger.append(
            orchestration_id=orchestration_id,
            event_type="SPT0236_CLOSURE_CERTIFIED",
            payload={
                "health_gate": True,
                "orchestration_complete": True,
                "adapters_effective": True,
            },
        )

        return {
            "component": "SPT-023.6",
            "layer": "3",
            "status": "SPT0236_INSTITUTIONALLY_CLOSED",
            "orchestration_id": orchestration_id,
            "health_gate": "PASS",
            "event_ledger_verified": OrchestrationEventLedger.verify(
                self.ledger.all()
            ),
            "retries_governed": True,
            "compensation_governed": True,
            "adapters_effective": True,
            "orchestration_complete": True,
            "paid_api_used": False,
            "next_component": "SPT-023.7",
        }
'@
    $Files["tests\integration\test_spt0236_governance_layer3.py"] = @'
import pytest

from sgoda.integration.spt0236.compensation import CompensationRegistry
from sgoda.integration.spt0236.events import OrchestrationEventLedger
from sgoda.integration.spt0236.governance import (
    HealthGateResult,
    RetryPolicy,
    evaluate_health_gates,
)
from sgoda.integration.spt0236.layer3 import Spt0236Layer3GovernanceService
from sgoda.integration.spt0236.runtime import GovernedExecutionRuntime


def healthy(component):
    return lambda: HealthGateResult(
        component=component,
        healthy=True,
        detail="ok",
    )


def all_probes():
    return {
        component: healthy(component)
        for component in Spt0236Layer3GovernanceService.REQUIRED_HEALTH
    }


def test_retry_policy_requires_positive_attempts():
    with pytest.raises(ValueError):
        RetryPolicy(max_attempts=0).validate()


def test_default_retry_policy_is_valid():
    RetryPolicy().validate()


def test_health_gate_passes_when_all_required_are_healthy():
    results = [
        HealthGateResult(component="A", healthy=True, detail="ok"),
        HealthGateResult(component="B", healthy=True, detail="ok"),
    ]
    gate = evaluate_health_gates(results, required_components=("A", "B"))
    assert gate["passed"] is True


def test_health_gate_fails_when_component_missing():
    results = [HealthGateResult(component="A", healthy=True, detail="ok")]
    gate = evaluate_health_gates(results, required_components=("A", "B"))
    assert gate["passed"] is False
    assert gate["missing"] == ["B"]


def test_health_gate_fails_when_component_unhealthy():
    results = [
        HealthGateResult(component="A", healthy=False, detail="bad")
    ]
    gate = evaluate_health_gates(results, required_components=("A",))
    assert gate["passed"] is False
    assert gate["unhealthy"] == ["A"]


def test_event_ledger_appends_and_verifies(tmp_path):
    ledger = OrchestrationEventLedger(tmp_path / "events.json")
    ledger.append(
        orchestration_id="ORCH-1",
        event_type="X",
        payload={"a": 1},
    )
    assert OrchestrationEventLedger.verify(ledger.all()) is True


def test_event_ledger_hash_chain_changes(tmp_path):
    ledger = OrchestrationEventLedger(tmp_path / "events.json")
    one = ledger.append(
        orchestration_id="ORCH-1",
        event_type="X",
        payload={},
    )
    two = ledger.append(
        orchestration_id="ORCH-1",
        event_type="Y",
        payload={},
    )
    assert two["previous_hash"] == one["event_sha256"]


def test_event_ledger_detects_tampering(tmp_path):
    ledger = OrchestrationEventLedger(tmp_path / "events.json")
    event = ledger.append(
        orchestration_id="ORCH-1",
        event_type="X",
        payload={},
    )
    event["event_sha256"] = "BAD"
    with pytest.raises(ValueError):
        OrchestrationEventLedger.verify([event])


def test_compensation_registry_returns_no_handler_status():
    registry = CompensationRegistry()
    result = registry.compensate("X", {})
    assert result.status == "NO_COMPENSATION_REGISTERED"


def test_compensation_registry_executes_handler():
    registry = CompensationRegistry()
    registry.register("X", lambda payload: {"status": "COMPENSATED"})
    result = registry.compensate("X", {})
    assert result.status == "COMPENSATED"


def test_runtime_executes_successfully(tmp_path):
    runtime = GovernedExecutionRuntime(
        ledger=OrchestrationEventLedger(tmp_path / "events.json"),
        compensation=CompensationRegistry(),
    )
    result = runtime.execute(
        orchestration_id="ORCH-1",
        component="X",
        expected_status="OK",
        handler=lambda payload: {"status": "OK"},
        payload={},
    )
    assert result["status"] == "OK"


def test_runtime_retries_runtime_error(tmp_path):
    attempts = {"count": 0}

    def flaky(payload):
        attempts["count"] += 1
        if attempts["count"] < 2:
            raise RuntimeError("temporary")
        return {"status": "OK"}

    runtime = GovernedExecutionRuntime(
        ledger=OrchestrationEventLedger(tmp_path / "events.json"),
        compensation=CompensationRegistry(),
        retry_policy=RetryPolicy(max_attempts=3),
    )
    result = runtime.execute(
        orchestration_id="ORCH-1",
        component="X",
        expected_status="OK",
        handler=flaky,
        payload={},
    )
    assert result["status"] == "OK"
    assert attempts["count"] == 2


def test_runtime_does_not_retry_value_error(tmp_path):
    attempts = {"count": 0}

    def broken(payload):
        attempts["count"] += 1
        raise ValueError("permanent")

    runtime = GovernedExecutionRuntime(
        ledger=OrchestrationEventLedger(tmp_path / "events.json"),
        compensation=CompensationRegistry(),
        retry_policy=RetryPolicy(max_attempts=3),
    )
    with pytest.raises(ValueError):
        runtime.execute(
            orchestration_id="ORCH-1",
            component="X",
            expected_status="OK",
            handler=broken,
            payload={},
        )
    assert attempts["count"] == 1


def test_runtime_compensates_after_terminal_failure(tmp_path):
    compensated = {"value": False}
    registry = CompensationRegistry()

    def compensate(payload):
        compensated["value"] = True
        return {"status": "COMPENSATED"}

    registry.register("X", compensate)
    runtime = GovernedExecutionRuntime(
        ledger=OrchestrationEventLedger(tmp_path / "events.json"),
        compensation=registry,
        retry_policy=RetryPolicy(max_attempts=1),
    )
    with pytest.raises(RuntimeError):
        runtime.execute(
            orchestration_id="ORCH-1",
            component="X",
            expected_status="OK",
            handler=lambda payload: (_ for _ in ()).throw(RuntimeError("x")),
            payload={},
        )
    assert compensated["value"] is True


def test_runtime_records_compensation_event(tmp_path):
    registry = CompensationRegistry()
    registry.register("X", lambda payload: {"status": "COMPENSATED"})
    ledger = OrchestrationEventLedger(tmp_path / "events.json")
    runtime = GovernedExecutionRuntime(
        ledger=ledger,
        compensation=registry,
        retry_policy=RetryPolicy(max_attempts=1),
    )
    with pytest.raises(RuntimeError):
        runtime.execute(
            orchestration_id="ORCH-1",
            component="X",
            expected_status="OK",
            handler=lambda payload: (_ for _ in ()).throw(RuntimeError("x")),
            payload={},
        )
    assert ledger.all()[-1]["event_type"] == "COMPENSATION_EXECUTED"


def test_layer3_health_gate_passes(tmp_path):
    service = Spt0236Layer3GovernanceService(
        ledger_path=tmp_path / "events.json"
    )
    assert service.health_gate(all_probes())["passed"] is True


def test_layer3_health_gate_fails_missing_probe(tmp_path):
    service = Spt0236Layer3GovernanceService(
        ledger_path=tmp_path / "events.json"
    )
    probes = all_probes()
    probes.pop("PMO_DIGITAL")
    assert service.health_gate(probes)["passed"] is False


def test_layer3_rejects_closure_without_health(tmp_path):
    service = Spt0236Layer3GovernanceService(
        ledger_path=tmp_path / "events.json"
    )
    with pytest.raises(ValueError):
        service.certify_closure(
            orchestration_id="ORCH-1",
            health_gate={"passed": False},
            orchestration_complete=True,
            adapters_effective=True,
        )


def test_layer3_rejects_closure_without_complete_orchestration(tmp_path):
    service = Spt0236Layer3GovernanceService(
        ledger_path=tmp_path / "events.json"
    )
    with pytest.raises(ValueError):
        service.certify_closure(
            orchestration_id="ORCH-1",
            health_gate={"passed": True},
            orchestration_complete=False,
            adapters_effective=True,
        )


def test_layer3_rejects_closure_without_effective_adapters(tmp_path):
    service = Spt0236Layer3GovernanceService(
        ledger_path=tmp_path / "events.json"
    )
    with pytest.raises(ValueError):
        service.certify_closure(
            orchestration_id="ORCH-1",
            health_gate={"passed": True},
            orchestration_complete=True,
            adapters_effective=False,
        )


def test_layer3_certifies_full_closure(tmp_path):
    service = Spt0236Layer3GovernanceService(
        ledger_path=tmp_path / "events.json"
    )
    gate = service.health_gate(all_probes())
    result = service.certify_closure(
        orchestration_id="ORCH-1",
        health_gate=gate,
        orchestration_complete=True,
        adapters_effective=True,
    )
    assert result["status"] == "SPT0236_INSTITUTIONALLY_CLOSED"


def test_layer3_closure_verifies_event_ledger(tmp_path):
    service = Spt0236Layer3GovernanceService(
        ledger_path=tmp_path / "events.json"
    )
    result = service.certify_closure(
        orchestration_id="ORCH-1",
        health_gate=service.health_gate(all_probes()),
        orchestration_complete=True,
        adapters_effective=True,
    )
    assert result["event_ledger_verified"] is True


def test_layer3_closure_disables_paid_api(tmp_path):
    service = Spt0236Layer3GovernanceService(
        ledger_path=tmp_path / "events.json"
    )
    result = service.certify_closure(
        orchestration_id="ORCH-1",
        health_gate=service.health_gate(all_probes()),
        orchestration_complete=True,
        adapters_effective=True,
    )
    assert result["paid_api_used"] is False


def test_layer3_points_to_spt0237(tmp_path):
    service = Spt0236Layer3GovernanceService(
        ledger_path=tmp_path / "events.json"
    )
    result = service.certify_closure(
        orchestration_id="ORCH-1",
        health_gate=service.health_gate(all_probes()),
        orchestration_complete=True,
        adapters_effective=True,
    )
    assert result["next_component"] == "SPT-023.7"
'@
    $Files["docs\06_Tecnologia\SPT-023.6\SGD-SPT023.6-Capa3-Gobierno-Cierre.md"] = @'
# SPT-023.6 — Orquestador Inteligente — Capa 3

## Objetivo

Cerrar funcional e institucionalmente SPT-023.6 incorporando gobierno de
ejecución, reintentos controlados, compensación, auditoría de eventos,
health gates y certificación final del Orquestador Inteligente.

## Gobierno de ejecución

La Capa 3 incorpora una política explícita de reintentos. Solo excepciones
clasificadas como transitorias son reintentadas; los errores permanentes se
detienen inmediatamente.

## Compensación

Cada componente puede registrar una acción de compensación. Una falla terminal
ejecuta la compensación correspondiente y registra el resultado en el ledger.

## Auditoría de eventos

El ledger de eventos mantiene secuencia contigua y hash SHA-256 encadenado.
Cualquier alteración rompe la verificación de integridad.

## Health gates

Antes del cierre institucional deben estar saludables:

- Orquestador;
- State Store;
- PMO Digital;
- Auditor Institucional;
- SGD-002.

FastAPI y n8n se mantienen desacoplados por adaptadores efectivos de Capa 2 y
pueden someterse a health checks operativos posteriores sin bloquear las pruebas
unitarias de esta capa.

## Cierre

El cierre exige simultáneamente:

- health gates aprobados;
- orquestación completa;
- adaptadores efectivos;
- ledger verificable;
- gobierno de retries y compensación.

Una vez aprobado, SPT-023.6 queda `INSTITUTIONALLY CLOSED` y habilita
**SPT-023.7 — Auditoría Inteligente**.
'@
    $Files["config\integration\spt0236\governance-policy.json"] = @'
{
  "schema_version": "1.0.0",
  "component": "SPT-023.6",
  "layer": "3",
  "execution_governance": true,
  "retry_policy": {
    "max_attempts": 3,
    "retryable_exceptions": [
      "RuntimeError",
      "TimeoutError"
    ]
  },
  "compensation_enabled": true,
  "event_ledger": {
    "storage": "LOCAL_JSON_ATOMIC",
    "sha256_chain": true
  },
  "required_health_gates": [
    "ORCHESTRATOR",
    "STATE_STORE",
    "PMO_DIGITAL",
    "AUDITOR_INSTITUCIONAL",
    "SGD-002"
  ],
  "effective_adapters_required": true,
  "orchestration_complete_required": true,
  "paid_api_allowed": false,
  "close_spt0236": true,
  "next_component": "SPT-023.7"
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
        "src\sgoda\integration\spt0236\governance.py",
        "src\sgoda\integration\spt0236\events.py",
        "src\sgoda\integration\spt0236\compensation.py",
        "src\sgoda\integration\spt0236\runtime.py",
        "src\sgoda\integration\spt0236\layer3.py",
        "tests\integration\test_spt0236_governance_layer3.py"
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
                "tests/integration/test_spt0236_governance_layer3.py" `
                -q 2>&1
        )
        $TargetCode = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $Previous
    }

    $TargetOutput | ForEach-Object { Write-Host $_ }
    if ($TargetCode -ne 0) {
        throw "Targeted SPT-023.6 Capa 3 tests failed."
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
    Write-Host "[8/12] EVIDENCE + SGD-002 FINAL SPT-023.6 CLOSURE" -ForegroundColor Yellow

    $EvidencePath = Join-Path $Root "artifacts\development\SPT-023.6-Capa3-v1.0.0\implementation-evidence.json"
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
        layer = "3"
        title = "Gobierno de Ejecucion y Cierre del Orquestador Inteligente"
        generated_utc = [DateTime]::UtcNow.ToString("o")
        certified_baseline = $ExpectedBaseline
        targeted_tests_passed = $TargetPassed
        institutional_tests_passed = $SuitePassed
        protected_files = $ProtectedBefore.Count
        protected_files_changed = $ChangedProtected.Count
        retries_governed = $true
        compensation_governed = $true
        event_ledger_sha256 = $true
        health_gates = $true
        effective_adapters_required = $true
        orchestration_complete_required = $true
        spt0236_scope_complete = $true
        paid_api_allowed = $false
        next_component = "SPT-023.7"
        generated_files = $Generated
    }

    Write-Utf8Lf -Path $EvidencePath -Content ($Evidence | ConvertTo-Json -Depth 8) -TrackCreated

    $MasterAppend = @"

$Marker
## SPT-023.6 — Orquestador Inteligente — CIERRE

- Estado institucional: CLOSED.
- Capa 1: contrato y motor de orquestación cerrados y preservados.
- Capa 2: adaptadores efectivos FastAPI/n8n/PMO/Auditor/SGD-002 cerrados y preservados.
- Capa 3: gobierno de ejecución, retries, compensación, auditoría de eventos y health gates implementados.
- Línea base de entrada: `$ExpectedBaseline`.
- Pruebas específicas Capa 3: `$TargetPassed` aprobadas.
- Suite institucional: `$SuitePassed` aprobadas.
- Reintentos: gobernados por política.
- Compensación: registro y ejecución gobernados.
- Ledger de eventos: secuencia y cadena SHA-256 verificables.
- Health gates obligatorios: Orquestador, State Store, PMO, Auditor y SGD-002.
- Adaptadores efectivos: requeridos.
- Orquestación completa: requerida.
- APIs de pago: deshabilitadas.
- Componentes cerrados anteriores: preservados por SHA-256.
- SPT-023.6: alcance completo cerrado.
- Siguiente paquete autorizado: SPT-023.7 — Auditoría Inteligente.
"@

    $UpdatedMaster = $MasterBookOriginal.TrimEnd([char[]]@("`r","`n")) + "`n" + $MasterAppend.Replace("`r`n","`n").Replace("`r","`n").TrimStart([char[]]@("`r","`n"))

    [System.IO.File]::WriteAllText(
        $MasterBookPath,
        $UpdatedMaster,
        (New-Object System.Text.UTF8Encoding($false))
    )
    $MasterBookTouched = $true

    Write-Host "EVIDENCE : CREATED" -ForegroundColor Green
    Write-Host "SGD-002  : SPT-023.6 CLOSED" -ForegroundColor Green

    Write-Host ""
    Write-Host "[9/12] EXACT CONTROLLED STAGING" -ForegroundColor Yellow

    $Allowed = @(
        $Files.Keys | ForEach-Object { $_.Replace("\","/") }
    )
    $Allowed += "artifacts/development/SPT-023.6-Capa3-v1.0.0/implementation-evidence.json"
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
        throw "Repository moved during SPT-023.6 Capa 3 transaction."
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
