<#
.SYNOPSIS
    SPT-020.6 - Institutional Runtime Orchestrator - One File Installer.

.DESCRIPTION
    Instala y valida el orquestador institucional de ejecucion de
    SGODA-PUINAVE.

    Incluye:
      - contratos de unidades de runtime;
      - estados de ejecucion;
      - registro de componentes ejecutables;
      - plan de arranque y apagado;
      - ordenamiento por dependencias;
      - hooks institucionales;
      - rollback ante fallos;
      - historial de ejecucion;
      - health report;
      - pruebas especificas;
      - compilacion Python;
      - suite completa;
      - evidencia SHA-256;
      - documentacion, acta y release candidato.

    Compatible con Windows PowerShell 5.1.
    No instala n8n.
    No requiere infraestructura externa.
    No usa servicios de pago.
    No publica en Git.

.PARAMETER ProjectRoot
    Raiz del repositorio. Por defecto usa la carpeta actual.

.PARAMETER SkipFullSuite
    Omite la suite completa y bloquea el cierre.

.EXAMPLE
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
    .\Install-SPT020.6-v1.0.0-OneFile-PS51.ps1
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipFullSuite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Component = "SPT-020.6"
$Version = "1.0.0"
$RunId = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
$GeneratedUtc = (Get-Date).ToUniversalTime().ToString("o")
$SelfPath = [System.IO.Path]::GetFullPath($MyInvocation.MyCommand.Path)

function Write-Step {
    param([string]$Text)
    Write-Host ""
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Write-TextFile {
    param(
        [string]$Path,
        [AllowEmptyString()][string]$Content
    )

    $Parent = Split-Path -Parent $Path

    if ($Parent -and -not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Data
    )

    $Json = $Data | ConvertTo-Json -Depth 40
    Write-TextFile -Path $Path -Content ($Json + "`r`n")
}

function Get-RelativePathSafe {
    param(
        [string]$Root,
        [string]$Path
    )

    $RootFull = [System.IO.Path]::GetFullPath($Root)
    $PathFull = [System.IO.Path]::GetFullPath($Path)

    if (-not $RootFull.EndsWith("\")) {
        $RootFull = $RootFull + "\"
    }

    $RootUri = New-Object System.Uri($RootFull)
    $PathUri = New-Object System.Uri($PathFull)
    $Relative = $RootUri.MakeRelativeUri($PathUri).ToString()

    return [System.Uri]::UnescapeDataString($Relative).Replace("\", "/")
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

    return @($Errors)
}

function Invoke-Pytest {
    param(
        [string[]]$Targets,
        [string]$LogPath
    )

    $Arguments = @("-m", "pytest", "-q")

    foreach ($Target in $Targets) {
        $Arguments += $Target
    }

    $Output = @(& python @Arguments 2>&1)
    $ExitCode = $LASTEXITCODE

    Write-TextFile `
        -Path $LogPath `
        -Content (($Output -join "`r`n") + "`r`n")

    $Output | ForEach-Object { Write-Host $_ }

    return [PSCustomObject]@{
        ExitCode = $ExitCode
        Passed = ($ExitCode -eq 0)
    }
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot

foreach ($Required in @("src", "tests", "docs", "artifacts", "releases")) {
    $RequiredPath = Join-Path $ProjectRoot $Required

    if (-not (Test-Path -LiteralPath $RequiredPath -PathType Container)) {
        throw "Falta la carpeta obligatoria: $Required"
    }
}

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    throw "Python no esta disponible."
}

$SelfErrors = @(Test-PowerShellSyntax -Path $SelfPath)

if ($SelfErrors.Count -ne 0) {
    throw "El ejecutable contiene errores de sintaxis PowerShell."
}

$PackageRoot = Join-Path $ProjectRoot "src\sgoda\platform\runtime_orchestrator"
$TestsRoot = Join-Path $ProjectRoot "tests\platform\runtime_orchestrator"
$DocsRoot = Join-Path $ProjectRoot "docs\06_Tecnologia\SPT-020.6"
$RunRoot = Join-Path $ProjectRoot "artifacts\development\SPT-020.6-v1.0.0\runs\$RunId"
$ReleaseRoot = Join-Path $ProjectRoot "releases\SPT-020.6-v1.0.0"
$ConfigRoot = Join-Path $ProjectRoot "config\platform"

foreach ($Directory in @(
    $PackageRoot,
    $TestsRoot,
    $DocsRoot,
    $RunRoot,
    $ReleaseRoot,
    $ConfigRoot
)) {
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
}

$PlatformRoot = Split-Path -Parent $PackageRoot
$PlatformInit = Join-Path $PlatformRoot "__init__.py"

if (-not (Test-Path -LiteralPath $PlatformInit)) {
    Write-TextFile -Path $PlatformInit -Content ""
}

Write-Step "Instalando Institutional Runtime Orchestrator"

$ModelsPy = @'
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Any, Callable, Dict, Tuple


class RuntimeState(str, Enum):
    REGISTERED = "REGISTERED"
    STARTING = "STARTING"
    RUNNING = "RUNNING"
    STOPPING = "STOPPING"
    STOPPED = "STOPPED"
    FAILED = "FAILED"


@dataclass(frozen=True)
class RuntimeUnitDefinition:
    unit_id: str
    version: str
    start: Callable[[], Any]
    stop: Callable[[], Any]
    dependencies: Tuple[str, ...] = ()
    metadata: Dict[str, str] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if not self.unit_id or not self.unit_id.strip():
            raise ValueError("unit_id is required")
        if not self.version or not self.version.strip():
            raise ValueError("version is required")
        if not callable(self.start):
            raise ValueError("start must be callable")
        if not callable(self.stop):
            raise ValueError("stop must be callable")

        object.__setattr__(self, "unit_id", self.unit_id.strip())
        object.__setattr__(self, "version", self.version.strip())
        object.__setattr__(
            self,
            "dependencies",
            tuple(sorted(set(self.dependencies))),
        )
        object.__setattr__(self, "metadata", dict(self.metadata))


@dataclass
class RuntimeUnitRecord:
    definition: RuntimeUnitDefinition
    state: RuntimeState = RuntimeState.REGISTERED
    last_error: str = ""


@dataclass(frozen=True)
class RuntimeEvent:
    unit_id: str
    previous_state: RuntimeState
    current_state: RuntimeState
    action: str
    detail: str = ""
    occurred_at_utc: str = field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )
'@

$RegistryPy = @'
from typing import Dict, Iterable

from .models import RuntimeUnitDefinition, RuntimeUnitRecord


class RuntimeRegistryError(RuntimeError):
    pass


class DuplicateRuntimeUnitError(RuntimeRegistryError):
    pass


class RuntimeUnitNotFoundError(RuntimeRegistryError):
    pass


class RuntimeUnitRegistry:
    def __init__(self) -> None:
        self._records: Dict[str, RuntimeUnitRecord] = {}

    def register(
        self,
        definition: RuntimeUnitDefinition,
    ) -> RuntimeUnitRecord:
        if definition.unit_id in self._records:
            raise DuplicateRuntimeUnitError(
                "runtime unit already registered: {0}".format(
                    definition.unit_id
                )
            )

        record = RuntimeUnitRecord(definition=definition)
        self._records[definition.unit_id] = record
        return record

    def get(self, unit_id: str) -> RuntimeUnitRecord:
        try:
            return self._records[unit_id]
        except KeyError as exc:
            raise RuntimeUnitNotFoundError(
                "runtime unit not registered: {0}".format(unit_id)
            ) from exc

    def exists(self, unit_id: str) -> bool:
        return unit_id in self._records

    def records(self) -> Iterable[RuntimeUnitRecord]:
        return tuple(self._records.values())
'@

$PlannerPy = @'
from typing import List, Set, Tuple

from .registry import RuntimeUnitRegistry


class RuntimeDependencyError(RuntimeError):
    pass


class RuntimeDependencyCycleError(RuntimeDependencyError):
    pass


class RuntimePlanner:
    def __init__(self, registry: RuntimeUnitRegistry) -> None:
        self.registry = registry

    def startup_order(self) -> Tuple[str, ...]:
        visiting: Set[str] = set()
        visited: Set[str] = set()
        ordered: List[str] = []

        def visit(unit_id: str) -> None:
            if unit_id in visited:
                return

            if unit_id in visiting:
                raise RuntimeDependencyCycleError(
                    "runtime dependency cycle detected at {0}".format(
                        unit_id
                    )
                )

            visiting.add(unit_id)
            record = self.registry.get(unit_id)

            for dependency in record.definition.dependencies:
                if not self.registry.exists(dependency):
                    raise RuntimeDependencyError(
                        "missing runtime dependency: {0}".format(
                            dependency
                        )
                    )
                visit(dependency)

            visiting.remove(unit_id)
            visited.add(unit_id)
            ordered.append(unit_id)

        for record in self.registry.records():
            visit(record.definition.unit_id)

        return tuple(ordered)

    def shutdown_order(self) -> Tuple[str, ...]:
        return tuple(reversed(self.startup_order()))
'@

$OrchestratorPy = @'
from typing import Callable, Dict, List, Optional, Tuple

from .models import RuntimeEvent, RuntimeState, RuntimeUnitDefinition
from .planner import RuntimePlanner
from .registry import RuntimeUnitRegistry


class RuntimeTransitionError(RuntimeError):
    pass


class RuntimeStartError(RuntimeError):
    pass


class InstitutionalRuntimeOrchestrator:
    def __init__(
        self,
        registry: Optional[RuntimeUnitRegistry] = None,
    ) -> None:
        self.registry = registry or RuntimeUnitRegistry()
        self.planner = RuntimePlanner(self.registry)
        self.history: List[RuntimeEvent] = []
        self._hooks: Dict[str, List[Callable]] = {}

    def register(self, definition: RuntimeUnitDefinition):
        return self.registry.register(definition)

    def add_hook(self, action: str, hook: Callable) -> None:
        if not callable(hook):
            raise ValueError("hook must be callable")
        self._hooks.setdefault(action, []).append(hook)

    def _emit(
        self,
        unit_id: str,
        previous_state: RuntimeState,
        current_state: RuntimeState,
        action: str,
        detail: str = "",
    ) -> RuntimeEvent:
        event = RuntimeEvent(
            unit_id=unit_id,
            previous_state=previous_state,
            current_state=current_state,
            action=action,
            detail=detail,
        )
        self.history.append(event)

        for hook in self._hooks.get(action, ()):
            hook(event)

        return event

    def start_unit(self, unit_id: str) -> RuntimeEvent:
        record = self.registry.get(unit_id)

        if record.state == RuntimeState.RUNNING:
            raise RuntimeTransitionError(
                "runtime unit already running: {0}".format(unit_id)
            )

        for dependency in record.definition.dependencies:
            dependency_record = self.registry.get(dependency)
            if dependency_record.state != RuntimeState.RUNNING:
                raise RuntimeTransitionError(
                    "runtime dependency is not running: {0}".format(
                        dependency
                    )
                )

        previous = record.state
        record.state = RuntimeState.STARTING
        self._emit(
            unit_id,
            previous,
            RuntimeState.STARTING,
            "STARTING",
        )

        try:
            record.definition.start()
        except Exception as exc:
            record.last_error = str(exc)
            record.state = RuntimeState.FAILED
            self._emit(
                unit_id,
                RuntimeState.STARTING,
                RuntimeState.FAILED,
                "START_FAILED",
                str(exc),
            )
            raise RuntimeStartError(
                "runtime start failed: {0}".format(unit_id)
            ) from exc

        record.last_error = ""
        record.state = RuntimeState.RUNNING
        return self._emit(
            unit_id,
            RuntimeState.STARTING,
            RuntimeState.RUNNING,
            "STARTED",
        )

    def stop_unit(self, unit_id: str) -> RuntimeEvent:
        record = self.registry.get(unit_id)

        if record.state not in (
            RuntimeState.RUNNING,
            RuntimeState.FAILED,
        ):
            raise RuntimeTransitionError(
                "runtime unit cannot be stopped from state: {0}".format(
                    record.state.value
                )
            )

        previous = record.state
        record.state = RuntimeState.STOPPING
        self._emit(
            unit_id,
            previous,
            RuntimeState.STOPPING,
            "STOPPING",
        )

        record.definition.stop()
        record.state = RuntimeState.STOPPED

        return self._emit(
            unit_id,
            RuntimeState.STOPPING,
            RuntimeState.STOPPED,
            "STOPPED",
        )

    def start_all(self) -> Tuple[RuntimeEvent, ...]:
        started = []
        events = []

        try:
            for unit_id in self.planner.startup_order():
                event = self.start_unit(unit_id)
                started.append(unit_id)
                events.append(event)
        except Exception:
            for started_id in reversed(started):
                record = self.registry.get(started_id)
                if record.state == RuntimeState.RUNNING:
                    self.stop_unit(started_id)
            raise

        return tuple(events)

    def stop_all(self) -> Tuple[RuntimeEvent, ...]:
        events = []

        for unit_id in self.planner.shutdown_order():
            record = self.registry.get(unit_id)

            if record.state in (
                RuntimeState.RUNNING,
                RuntimeState.FAILED,
            ):
                events.append(self.stop_unit(unit_id))

        return tuple(events)
'@

$HealthPy = @'
from dataclasses import dataclass
from typing import Tuple

from .models import RuntimeState
from .registry import RuntimeUnitRegistry


@dataclass(frozen=True)
class RuntimeUnitHealth:
    unit_id: str
    state: str
    healthy: bool
    last_error: str


@dataclass(frozen=True)
class RuntimeHealthReport:
    healthy: bool
    running_units: int
    failed_units: int
    units: Tuple[RuntimeUnitHealth, ...]


class RuntimeHealthMonitor:
    def evaluate(
        self,
        registry: RuntimeUnitRegistry,
    ) -> RuntimeHealthReport:
        units = tuple(
            RuntimeUnitHealth(
                unit_id=record.definition.unit_id,
                state=record.state.value,
                healthy=(record.state != RuntimeState.FAILED),
                last_error=record.last_error,
            )
            for record in registry.records()
        )

        running = sum(
            1
            for record in registry.records()
            if record.state == RuntimeState.RUNNING
        )
        failed = sum(
            1
            for record in registry.records()
            if record.state == RuntimeState.FAILED
        )

        return RuntimeHealthReport(
            healthy=(failed == 0),
            running_units=running,
            failed_units=failed,
            units=units,
        )
'@

$InitPy = @'
from .health import (
    RuntimeHealthMonitor,
    RuntimeHealthReport,
    RuntimeUnitHealth,
)
from .models import (
    RuntimeEvent,
    RuntimeState,
    RuntimeUnitDefinition,
    RuntimeUnitRecord,
)
from .orchestrator import (
    InstitutionalRuntimeOrchestrator,
    RuntimeStartError,
    RuntimeTransitionError,
)
from .planner import (
    RuntimeDependencyCycleError,
    RuntimeDependencyError,
    RuntimePlanner,
)
from .registry import (
    DuplicateRuntimeUnitError,
    RuntimeRegistryError,
    RuntimeUnitNotFoundError,
    RuntimeUnitRegistry,
)

__all__ = [
    "DuplicateRuntimeUnitError",
    "InstitutionalRuntimeOrchestrator",
    "RuntimeDependencyCycleError",
    "RuntimeDependencyError",
    "RuntimeEvent",
    "RuntimeHealthMonitor",
    "RuntimeHealthReport",
    "RuntimePlanner",
    "RuntimeRegistryError",
    "RuntimeStartError",
    "RuntimeState",
    "RuntimeTransitionError",
    "RuntimeUnitDefinition",
    "RuntimeUnitHealth",
    "RuntimeUnitNotFoundError",
    "RuntimeUnitRecord",
    "RuntimeUnitRegistry",
]
'@

$TestsPy = @'
import pytest

from sgoda.platform.runtime_orchestrator import (
    DuplicateRuntimeUnitError,
    InstitutionalRuntimeOrchestrator,
    RuntimeDependencyCycleError,
    RuntimeDependencyError,
    RuntimeHealthMonitor,
    RuntimeStartError,
    RuntimeState,
    RuntimeTransitionError,
    RuntimeUnitDefinition,
)


def unit(unit_id, started, stopped, dependencies=(), fail=False):
    def start():
        if fail:
            raise RuntimeError("start failure")
        started.append(unit_id)

    def stop():
        stopped.append(unit_id)

    return RuntimeUnitDefinition(
        unit_id=unit_id,
        version="1.0.0",
        start=start,
        stop=stop,
        dependencies=dependencies,
    )


def test_runtime_unit_requires_identity():
    with pytest.raises(ValueError):
        RuntimeUnitDefinition("", "1.0.0", lambda: None, lambda: None)


def test_duplicate_runtime_unit_is_rejected():
    orchestrator = InstitutionalRuntimeOrchestrator()
    definition = unit("A", [], [])
    orchestrator.register(definition)

    with pytest.raises(DuplicateRuntimeUnitError):
        orchestrator.register(definition)


def test_startup_order_places_dependencies_first():
    orchestrator = InstitutionalRuntimeOrchestrator()
    orchestrator.register(unit("A", [], []))
    orchestrator.register(unit("B", [], [], dependencies=("A",)))
    assert orchestrator.planner.startup_order() == ("A", "B")


def test_shutdown_order_is_reversed():
    orchestrator = InstitutionalRuntimeOrchestrator()
    orchestrator.register(unit("A", [], []))
    orchestrator.register(unit("B", [], [], dependencies=("A",)))
    assert orchestrator.planner.shutdown_order() == ("B", "A")


def test_missing_dependency_is_detected():
    orchestrator = InstitutionalRuntimeOrchestrator()
    orchestrator.register(unit("B", [], [], dependencies=("A",)))

    with pytest.raises(RuntimeDependencyError):
        orchestrator.planner.startup_order()


def test_dependency_cycle_is_detected():
    orchestrator = InstitutionalRuntimeOrchestrator()
    orchestrator.register(unit("A", [], [], dependencies=("B",)))
    orchestrator.register(unit("B", [], [], dependencies=("A",)))

    with pytest.raises(RuntimeDependencyCycleError):
        orchestrator.planner.startup_order()


def test_start_all_follows_dependency_order():
    started = []
    stopped = []
    orchestrator = InstitutionalRuntimeOrchestrator()
    orchestrator.register(unit("A", started, stopped))
    orchestrator.register(
        unit("B", started, stopped, dependencies=("A",))
    )

    orchestrator.start_all()

    assert started == ["A", "B"]
    assert orchestrator.registry.get("B").state == RuntimeState.RUNNING


def test_stop_all_uses_reverse_order():
    started = []
    stopped = []
    orchestrator = InstitutionalRuntimeOrchestrator()
    orchestrator.register(unit("A", started, stopped))
    orchestrator.register(
        unit("B", started, stopped, dependencies=("A",))
    )

    orchestrator.start_all()
    orchestrator.stop_all()

    assert stopped == ["B", "A"]


def test_start_unit_requires_running_dependencies():
    orchestrator = InstitutionalRuntimeOrchestrator()
    orchestrator.register(unit("A", [], []))
    orchestrator.register(unit("B", [], [], dependencies=("A",)))

    with pytest.raises(RuntimeTransitionError):
        orchestrator.start_unit("B")


def test_runtime_start_failure_sets_failed_state():
    orchestrator = InstitutionalRuntimeOrchestrator()
    orchestrator.register(unit("A", [], [], fail=True))

    with pytest.raises(RuntimeStartError):
        orchestrator.start_unit("A")

    record = orchestrator.registry.get("A")
    assert record.state == RuntimeState.FAILED
    assert record.last_error == "start failure"


def test_start_all_rolls_back_started_units():
    started = []
    stopped = []
    orchestrator = InstitutionalRuntimeOrchestrator()
    orchestrator.register(unit("A", started, stopped))
    orchestrator.register(
        unit("B", started, stopped, dependencies=("A",), fail=True)
    )

    with pytest.raises(RuntimeStartError):
        orchestrator.start_all()

    assert stopped == ["A"]
    assert orchestrator.registry.get("A").state == RuntimeState.STOPPED


def test_hooks_receive_runtime_events():
    received = []
    orchestrator = InstitutionalRuntimeOrchestrator()
    orchestrator.register(unit("A", [], []))
    orchestrator.add_hook("STARTED", received.append)
    orchestrator.start_unit("A")
    assert received[0].unit_id == "A"


def test_history_preserves_state_transitions():
    orchestrator = InstitutionalRuntimeOrchestrator()
    orchestrator.register(unit("A", [], []))
    orchestrator.start_unit("A")
    actions = [event.action for event in orchestrator.history]
    assert actions == ["STARTING", "STARTED"]


def test_running_unit_cannot_start_twice():
    orchestrator = InstitutionalRuntimeOrchestrator()
    orchestrator.register(unit("A", [], []))
    orchestrator.start_unit("A")

    with pytest.raises(RuntimeTransitionError):
        orchestrator.start_unit("A")


def test_health_report_counts_running_units():
    orchestrator = InstitutionalRuntimeOrchestrator()
    orchestrator.register(unit("A", [], []))
    orchestrator.start_unit("A")
    report = RuntimeHealthMonitor().evaluate(orchestrator.registry)
    assert report.healthy is True
    assert report.running_units == 1
    assert report.failed_units == 0


def test_health_report_detects_failed_units():
    orchestrator = InstitutionalRuntimeOrchestrator()
    orchestrator.register(unit("A", [], [], fail=True))

    with pytest.raises(RuntimeStartError):
        orchestrator.start_unit("A")

    report = RuntimeHealthMonitor().evaluate(orchestrator.registry)
    assert report.healthy is False
    assert report.failed_units == 1
'@

Write-TextFile -Path (Join-Path $PackageRoot "models.py") -Content $ModelsPy
Write-TextFile -Path (Join-Path $PackageRoot "registry.py") -Content $RegistryPy
Write-TextFile -Path (Join-Path $PackageRoot "planner.py") -Content $PlannerPy
Write-TextFile -Path (Join-Path $PackageRoot "orchestrator.py") -Content $OrchestratorPy
Write-TextFile -Path (Join-Path $PackageRoot "health.py") -Content $HealthPy
Write-TextFile -Path (Join-Path $PackageRoot "__init__.py") -Content $InitPy
Write-TextFile -Path (Join-Path $TestsRoot "test_spt0206.py") -Content $TestsPy

$Config = [ordered]@{
    component = $Component
    version = $Version
    name = "Institutional Runtime Orchestrator"
    parent_component = "SPT-020"
    dependency_ordering = $true
    rollback_support = $true
    lifecycle_hooks = $true
    health_monitoring = $true
    repository_is_source_of_truth = $true
    external_infrastructure_required = $false
    n8n_required = $false
    paid_services_required = $false
}

$ConfigPath = Join-Path $ConfigRoot "SPT-020.6-component.json"
Write-JsonFile -Path $ConfigPath -Data $Config

$Document = @"
# SGD-435 - Institutional Runtime Orchestrator

| Field | Value |
|---|---|
| Component | SPT-020.6 |
| Version | $Version |
| Parent | SPT-020 |
| Dependency ordering | YES |
| Controlled startup | YES |
| Controlled shutdown | YES |
| Rollback | YES |
| Runtime hooks | YES |
| External infrastructure | NO |
| n8n | Not installed |
| Paid services | Not required |

SPT-020.6 coordinates runtime registration, dependency-aware startup,
reverse-order shutdown, controlled rollback, execution history and health
monitoring without external infrastructure.
"@

$DocumentPath = Join-Path $DocsRoot "SGD-435-Institutional-Runtime-Orchestrator.md"
Write-TextFile -Path $DocumentPath -Content $Document

$env:PYTHONPATH = Join-Path $ProjectRoot "src"

Write-Step "Ejecutando pruebas especificas SPT-020.6"

$ComponentResult = Invoke-Pytest `
    -Targets @("tests/platform/runtime_orchestrator/test_spt0206.py") `
    -LogPath (Join-Path $RunRoot "pytest-spt0206.txt")

if (-not $ComponentResult.Passed) {
    throw "Las pruebas especificas de SPT-020.6 fallaron."
}

Write-Step "Compilando Python"

$CompileOutput = @(& python -m compileall -q src tests 2>&1)
$CompileExitCode = $LASTEXITCODE

Write-TextFile `
    -Path (Join-Path $RunRoot "python-compileall.txt") `
    -Content (($CompileOutput -join "`r`n") + "`r`n")

if ($CompileExitCode -ne 0) {
    throw "La compilacion Python fallo."
}

$FullSuiteRequested = -not $SkipFullSuite.IsPresent
$FullSuitePassed = $false
$FullSuiteExitCode = $null

if ($FullSuiteRequested) {
    Write-Step "Ejecutando suite completa"

    $FullSuiteResult = Invoke-Pytest `
        -Targets @() `
        -LogPath (Join-Path $RunRoot "pytest-full-suite.txt")

    $FullSuiteExitCode = $FullSuiteResult.ExitCode
    $FullSuitePassed = $FullSuiteResult.Passed

    if (-not $FullSuitePassed) {
        throw "La suite completa fallo."
    }
}
else {
    Write-Host "Suite completa omitida. Cierre bloqueado." -ForegroundColor Yellow
}

$Files = @(
    Get-ChildItem -LiteralPath $PackageRoot -File
    Get-ChildItem -LiteralPath $TestsRoot -File
    Get-Item -LiteralPath $DocumentPath
    Get-Item -LiteralPath $ConfigPath
)

$FileRecords = @()

foreach ($File in $Files) {
    $FileRecords += [ordered]@{
        path = Get-RelativePathSafe -Root $ProjectRoot -Path $File.FullName
        sha256 = (
            Get-FileHash -LiteralPath $File.FullName -Algorithm SHA256
        ).Hash.ToLowerInvariant()
    }
}

$Approved = (
    $ComponentResult.Passed -and
    $CompileExitCode -eq 0 -and
    $FullSuiteRequested -and
    $FullSuitePassed
)

$Status = if ($Approved) {
    "CANDIDATE_FOR_INSTITUTIONAL_CLOSURE"
}
else {
    "CLOSURE_BLOCKED"
}

$Evidence = [ordered]@{
    component = $Component
    version = $Version
    run_id = $RunId
    generated_at_utc = $GeneratedUtc
    status = $Status
    approved = $Approved
    component_tests_passed = $ComponentResult.Passed
    python_compile_exit_code = $CompileExitCode
    full_suite_requested = $FullSuiteRequested
    full_suite_passed = $FullSuitePassed
    full_suite_exit_code = $FullSuiteExitCode
    repository_is_source_of_truth = $true
    external_infrastructure_required = $false
    n8n_installed = $false
    paid_services_required = $false
    files = $FileRecords
}

$EvidencePath = Join-Path $RunRoot "implementation-evidence.json"
Write-JsonFile -Path $EvidencePath -Data $Evidence

$ActStatus = if ($Approved) {
    "CANDIDATE FOR INSTITUTIONAL CLOSURE"
}
else {
    "NOT APPROVED"
}

$Act = @"
# ACT-020.6 - Institutional Runtime Orchestrator

| Field | Value |
|---|---|
| Component | SPT-020.6 |
| Version | $Version |
| Status | $ActStatus |
| Component tests | $($ComponentResult.Passed) |
| Python compile exit code | $CompileExitCode |
| Full suite passed | $FullSuitePassed |
| External infrastructure required | NO |
| n8n installed | NO |
| Paid services | NO |
"@

$ActPath = Join-Path $DocsRoot "ACT-020.6-Institutional-Runtime-Orchestrator.md"
Write-TextFile -Path $ActPath -Content $Act

$Manifest = [ordered]@{
    component = $Component
    version = $Version
    status = $Status
    evidence = Get-RelativePathSafe -Root $ProjectRoot -Path $EvidencePath
    act = Get-RelativePathSafe -Root $ProjectRoot -Path $ActPath
    external_infrastructure_required = $false
    n8n_required = $false
    paid_services_required = $false
}

Write-JsonFile `
    -Path (Join-Path $ReleaseRoot "manifest.json") `
    -Data $Manifest

Copy-Item `
    -LiteralPath $EvidencePath `
    -Destination (Join-Path $ReleaseRoot "implementation-evidence.json") `
    -Force

Copy-Item `
    -LiteralPath $DocumentPath `
    -Destination (Join-Path $ReleaseRoot "SGD-435-Institutional-Runtime-Orchestrator.md") `
    -Force

Copy-Item `
    -LiteralPath $ActPath `
    -Destination (Join-Path $ReleaseRoot "ACT-020.6-Institutional-Runtime-Orchestrator.md") `
    -Force

Write-Step "Resultado final"

Write-Host "SPT-020.6 tests passed: $($ComponentResult.Passed)"
Write-Host "Python compile exit code: $CompileExitCode"
Write-Host "Full suite passed: $FullSuitePassed"
Write-Host "External infrastructure required: NO"
Write-Host "n8n installed: NO"
Write-Host "Paid services: NO"
Write-Host "Evidence: $EvidencePath" -ForegroundColor Cyan
Write-Host "Release: $ReleaseRoot" -ForegroundColor Cyan
Write-Host "Status: $Status" -ForegroundColor Cyan

if ($Approved) {
    Write-Host "SPT-020.6: CANDIDATE FOR INSTITUTIONAL CLOSURE." -ForegroundColor Green
}
else {
    Write-Host "SPT-020.6: CLOSURE BLOCKED." -ForegroundColor Red
    exit 1
}
