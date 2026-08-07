<#
.SYNOPSIS
    SPT-020.2 - Component Lifecycle Manager - One File Installer.

.DESCRIPTION
    Instala y valida el administrador institucional del ciclo de vida de
    componentes de SGODA-PUINAVE.

    Estados soportados:
      REGISTERED -> INSTALLED -> ACTIVE -> SUSPENDED -> ACTIVE -> RETIRED

    Incluye:
      - contratos y estados;
      - registro de componentes;
      - transiciones controladas;
      - hooks institucionales;
      - historial y trazabilidad;
      - validacion de dependencias;
      - health snapshot;
      - pruebas especificas;
      - compilacion Python;
      - suite completa;
      - evidencia SHA-256;
      - documentacion, acta y release candidato.

    Compatible con Windows PowerShell 5.1.
    No instala n8n.
    No usa servicios de pago.
    No publica en Git.

.PARAMETER ProjectRoot
    Raiz del repositorio. Por defecto usa la carpeta actual.

.PARAMETER SkipFullSuite
    Omite la suite completa y bloquea el cierre.

.EXAMPLE
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
    .\Install-SPT020.2-v1.0.0-OneFile-PS51.ps1
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipFullSuite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Component = "SPT-020.2"
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

    $Json = $Data | ConvertTo-Json -Depth 30
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

$PackageRoot = Join-Path $ProjectRoot "src\sgoda\platform\lifecycle"
$TestsRoot = Join-Path $ProjectRoot "tests\platform\lifecycle"
$DocsRoot = Join-Path $ProjectRoot "docs\06_Tecnologia\SPT-020.2"
$RunRoot = Join-Path $ProjectRoot "artifacts\development\SPT-020.2-v1.0.0\runs\$RunId"
$ReleaseRoot = Join-Path $ProjectRoot "releases\SPT-020.2-v1.0.0"
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

Write-Step "Instalando Component Lifecycle Manager"

$StatesPy = @'
from enum import Enum


class ComponentState(str, Enum):
    REGISTERED = "REGISTERED"
    INSTALLED = "INSTALLED"
    ACTIVE = "ACTIVE"
    SUSPENDED = "SUSPENDED"
    RETIRED = "RETIRED"


ALLOWED_TRANSITIONS = {
    ComponentState.REGISTERED: {ComponentState.INSTALLED},
    ComponentState.INSTALLED: {ComponentState.ACTIVE, ComponentState.RETIRED},
    ComponentState.ACTIVE: {ComponentState.SUSPENDED, ComponentState.RETIRED},
    ComponentState.SUSPENDED: {ComponentState.ACTIVE, ComponentState.RETIRED},
    ComponentState.RETIRED: set(),
}
'@

$ModelsPy = @'
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Dict, Tuple

from .states import ComponentState


@dataclass(frozen=True)
class ComponentDefinition:
    component_id: str
    version: str
    dependencies: Tuple[str, ...] = ()
    metadata: Dict[str, Any] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if not self.component_id or not self.component_id.strip():
            raise ValueError("component_id is required")
        if not self.version or not self.version.strip():
            raise ValueError("version is required")

        object.__setattr__(self, "component_id", self.component_id.strip())
        object.__setattr__(self, "version", self.version.strip())
        object.__setattr__(self, "dependencies", tuple(self.dependencies))
        object.__setattr__(self, "metadata", dict(self.metadata))


@dataclass(frozen=True)
class LifecycleEvent:
    component_id: str
    previous_state: ComponentState
    current_state: ComponentState
    reason: str
    occurred_at_utc: str = field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )


@dataclass
class ComponentRecord:
    definition: ComponentDefinition
    state: ComponentState = ComponentState.REGISTERED
'@

$RegistryPy = @'
from typing import Dict, Iterable

from .models import ComponentDefinition, ComponentRecord


class ComponentRegistryError(RuntimeError):
    pass


class ComponentLifecycleRegistry:
    def __init__(self) -> None:
        self._records: Dict[str, ComponentRecord] = {}

    def register(self, definition: ComponentDefinition) -> ComponentRecord:
        component_id = definition.component_id

        if component_id in self._records:
            raise ComponentRegistryError(
                "component already registered: {0}".format(component_id)
            )

        record = ComponentRecord(definition=definition)
        self._records[component_id] = record
        return record

    def get(self, component_id: str) -> ComponentRecord:
        try:
            return self._records[component_id]
        except KeyError as exc:
            raise ComponentRegistryError(
                "component not registered: {0}".format(component_id)
            ) from exc

    def exists(self, component_id: str) -> bool:
        return component_id in self._records

    def records(self) -> Iterable[ComponentRecord]:
        return tuple(self._records.values())
'@

$ManagerPy = @'
from typing import Callable, Dict, List, Optional, Tuple

from .models import ComponentDefinition, LifecycleEvent
from .registry import ComponentLifecycleRegistry
from .states import ALLOWED_TRANSITIONS, ComponentState


class LifecycleTransitionError(RuntimeError):
    pass


class DependencyValidationError(RuntimeError):
    pass


class ComponentLifecycleManager:
    def __init__(
        self,
        registry: Optional[ComponentLifecycleRegistry] = None,
    ) -> None:
        self.registry = registry or ComponentLifecycleRegistry()
        self.history: List[LifecycleEvent] = []
        self._hooks: Dict[ComponentState, List[Callable]] = {}

    def register(self, definition: ComponentDefinition):
        return self.registry.register(definition)

    def add_hook(self, state: ComponentState, hook: Callable) -> None:
        if not callable(hook):
            raise ValueError("hook must be callable")
        self._hooks.setdefault(state, []).append(hook)

    def validate_dependencies(self, component_id: str) -> Tuple[str, ...]:
        record = self.registry.get(component_id)
        missing = tuple(
            dependency
            for dependency in record.definition.dependencies
            if not self.registry.exists(dependency)
        )

        if missing:
            raise DependencyValidationError(
                "missing dependencies: {0}".format(", ".join(missing))
            )

        return missing

    def transition(
        self,
        component_id: str,
        target_state: ComponentState,
        reason: str = "",
    ) -> LifecycleEvent:
        record = self.registry.get(component_id)
        previous_state = record.state

        if target_state not in ALLOWED_TRANSITIONS[previous_state]:
            raise LifecycleTransitionError(
                "invalid transition: {0} -> {1}".format(
                    previous_state.value,
                    target_state.value,
                )
            )

        if target_state in (ComponentState.INSTALLED, ComponentState.ACTIVE):
            self.validate_dependencies(component_id)

        record.state = target_state
        event = LifecycleEvent(
            component_id=component_id,
            previous_state=previous_state,
            current_state=target_state,
            reason=reason,
        )
        self.history.append(event)

        for hook in self._hooks.get(target_state, ()):
            hook(event)

        return event

    def install(self, component_id: str, reason: str = "") -> LifecycleEvent:
        return self.transition(component_id, ComponentState.INSTALLED, reason)

    def activate(self, component_id: str, reason: str = "") -> LifecycleEvent:
        return self.transition(component_id, ComponentState.ACTIVE, reason)

    def suspend(self, component_id: str, reason: str = "") -> LifecycleEvent:
        return self.transition(component_id, ComponentState.SUSPENDED, reason)

    def retire(self, component_id: str, reason: str = "") -> LifecycleEvent:
        return self.transition(component_id, ComponentState.RETIRED, reason)
'@

$HealthPy = @'
from dataclasses import dataclass
from typing import Tuple

from .registry import ComponentLifecycleRegistry


@dataclass(frozen=True)
class ComponentHealth:
    component_id: str
    version: str
    state: str


@dataclass(frozen=True)
class LifecycleHealthSnapshot:
    healthy: bool
    components: Tuple[ComponentHealth, ...]


class LifecycleHealthMonitor:
    def snapshot(
        self,
        registry: ComponentLifecycleRegistry,
    ) -> LifecycleHealthSnapshot:
        components = tuple(
            ComponentHealth(
                component_id=record.definition.component_id,
                version=record.definition.version,
                state=record.state.value,
            )
            for record in registry.records()
        )

        return LifecycleHealthSnapshot(
            healthy=True,
            components=components,
        )
'@

$InitPy = @'
from .health import (
    ComponentHealth,
    LifecycleHealthMonitor,
    LifecycleHealthSnapshot,
)
from .manager import (
    ComponentLifecycleManager,
    DependencyValidationError,
    LifecycleTransitionError,
)
from .models import ComponentDefinition, ComponentRecord, LifecycleEvent
from .registry import ComponentLifecycleRegistry, ComponentRegistryError
from .states import ALLOWED_TRANSITIONS, ComponentState

__all__ = [
    "ALLOWED_TRANSITIONS",
    "ComponentDefinition",
    "ComponentHealth",
    "ComponentLifecycleManager",
    "ComponentLifecycleRegistry",
    "ComponentRecord",
    "ComponentRegistryError",
    "ComponentState",
    "DependencyValidationError",
    "LifecycleEvent",
    "LifecycleHealthMonitor",
    "LifecycleHealthSnapshot",
    "LifecycleTransitionError",
]
'@

$TestsPy = @'
import pytest

from sgoda.platform.lifecycle import (
    ComponentDefinition,
    ComponentLifecycleManager,
    ComponentLifecycleRegistry,
    ComponentRegistryError,
    ComponentState,
    DependencyValidationError,
    LifecycleHealthMonitor,
    LifecycleTransitionError,
)


def test_definition_requires_identity():
    with pytest.raises(ValueError):
        ComponentDefinition("", "1.0.0")


def test_registry_rejects_duplicate_component():
    registry = ComponentLifecycleRegistry()
    definition = ComponentDefinition("SPT-TEST", "1.0.0")
    registry.register(definition)

    with pytest.raises(ComponentRegistryError):
        registry.register(definition)


def test_manager_registers_component():
    manager = ComponentLifecycleManager()
    record = manager.register(ComponentDefinition("SPT-TEST", "1.0.0"))
    assert record.state == ComponentState.REGISTERED


def test_install_and_activate_component():
    manager = ComponentLifecycleManager()
    manager.register(ComponentDefinition("SPT-TEST", "1.0.0"))
    manager.install("SPT-TEST")
    manager.activate("SPT-TEST")
    assert manager.registry.get("SPT-TEST").state == ComponentState.ACTIVE


def test_suspend_and_reactivate_component():
    manager = ComponentLifecycleManager()
    manager.register(ComponentDefinition("SPT-TEST", "1.0.0"))
    manager.install("SPT-TEST")
    manager.activate("SPT-TEST")
    manager.suspend("SPT-TEST")
    manager.activate("SPT-TEST")
    assert manager.registry.get("SPT-TEST").state == ComponentState.ACTIVE


def test_invalid_transition_is_blocked():
    manager = ComponentLifecycleManager()
    manager.register(ComponentDefinition("SPT-TEST", "1.0.0"))

    with pytest.raises(LifecycleTransitionError):
        manager.activate("SPT-TEST")


def test_missing_dependency_is_blocked():
    manager = ComponentLifecycleManager()
    manager.register(
        ComponentDefinition(
            "SPT-CHILD",
            "1.0.0",
            dependencies=("SPT-PARENT",),
        )
    )

    with pytest.raises(DependencyValidationError):
        manager.install("SPT-CHILD")


def test_dependency_allows_installation():
    manager = ComponentLifecycleManager()
    manager.register(ComponentDefinition("SPT-PARENT", "1.0.0"))
    manager.register(
        ComponentDefinition(
            "SPT-CHILD",
            "1.0.0",
            dependencies=("SPT-PARENT",),
        )
    )
    event = manager.install("SPT-CHILD")
    assert event.current_state == ComponentState.INSTALLED


def test_hook_receives_transition_event():
    manager = ComponentLifecycleManager()
    received = []
    manager.register(ComponentDefinition("SPT-TEST", "1.0.0"))
    manager.add_hook(ComponentState.INSTALLED, received.append)
    manager.install("SPT-TEST", "installation")
    assert received[0].reason == "installation"


def test_history_preserves_transition_order():
    manager = ComponentLifecycleManager()
    manager.register(ComponentDefinition("SPT-TEST", "1.0.0"))
    manager.install("SPT-TEST")
    manager.activate("SPT-TEST")
    assert [event.current_state for event in manager.history] == [
        ComponentState.INSTALLED,
        ComponentState.ACTIVE,
    ]


def test_retired_component_cannot_reactivate():
    manager = ComponentLifecycleManager()
    manager.register(ComponentDefinition("SPT-TEST", "1.0.0"))
    manager.install("SPT-TEST")
    manager.retire("SPT-TEST")

    with pytest.raises(LifecycleTransitionError):
        manager.activate("SPT-TEST")


def test_health_snapshot_contains_registered_components():
    manager = ComponentLifecycleManager()
    manager.register(ComponentDefinition("SPT-TEST", "1.0.0"))
    snapshot = LifecycleHealthMonitor().snapshot(manager.registry)
    assert snapshot.healthy is True
    assert snapshot.components[0].component_id == "SPT-TEST"
'@

Write-TextFile -Path (Join-Path $PackageRoot "states.py") -Content $StatesPy
Write-TextFile -Path (Join-Path $PackageRoot "models.py") -Content $ModelsPy
Write-TextFile -Path (Join-Path $PackageRoot "registry.py") -Content $RegistryPy
Write-TextFile -Path (Join-Path $PackageRoot "manager.py") -Content $ManagerPy
Write-TextFile -Path (Join-Path $PackageRoot "health.py") -Content $HealthPy
Write-TextFile -Path (Join-Path $PackageRoot "__init__.py") -Content $InitPy
Write-TextFile -Path (Join-Path $TestsRoot "test_spt0202.py") -Content $TestsPy

$Config = [ordered]@{
    component = $Component
    version = $Version
    name = "Component Lifecycle Manager"
    parent_component = "SPT-020"
    lifecycle_states = @(
        "REGISTERED",
        "INSTALLED",
        "ACTIVE",
        "SUSPENDED",
        "RETIRED"
    )
    repository_is_source_of_truth = $true
    external_service_required = $false
    n8n_required = $false
    paid_services_required = $false
}

$ConfigPath = Join-Path $ConfigRoot "SPT-020.2-component.json"
Write-JsonFile -Path $ConfigPath -Data $Config

$Document = @"
# SGD-431 - Component Lifecycle Manager

| Field | Value |
|---|---|
| Component | SPT-020.2 |
| Version | $Version |
| Parent | SPT-020 |
| Repository source of truth | YES |
| External service required | NO |
| n8n | Not installed |
| Paid services | Not required |

## Lifecycle

REGISTERED -> INSTALLED -> ACTIVE -> SUSPENDED -> ACTIVE -> RETIRED

SPT-020.2 manages registration, dependency validation, controlled state
transitions, institutional hooks, event history and lifecycle health snapshots.
"@

$DocumentPath = Join-Path $DocsRoot "SGD-431-Component-Lifecycle-Manager.md"
Write-TextFile -Path $DocumentPath -Content $Document

$env:PYTHONPATH = Join-Path $ProjectRoot "src"

Write-Step "Ejecutando pruebas especificas SPT-020.2"

$ComponentResult = Invoke-Pytest `
    -Targets @("tests/platform/lifecycle/test_spt0202.py") `
    -LogPath (Join-Path $RunRoot "pytest-spt0202.txt")

if (-not $ComponentResult.Passed) {
    throw "Las pruebas especificas de SPT-020.2 fallaron."
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
    external_service_required = $false
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
# ACT-020.2 - Component Lifecycle Manager

| Field | Value |
|---|---|
| Component | SPT-020.2 |
| Version | $Version |
| Status | $ActStatus |
| Component tests | $($ComponentResult.Passed) |
| Python compile exit code | $CompileExitCode |
| Full suite passed | $FullSuitePassed |
| External service required | NO |
| n8n installed | NO |
| Paid services | NO |
"@

$ActPath = Join-Path $DocsRoot "ACT-020.2-Component-Lifecycle-Manager.md"
Write-TextFile -Path $ActPath -Content $Act

$Manifest = [ordered]@{
    component = $Component
    version = $Version
    status = $Status
    evidence = Get-RelativePathSafe -Root $ProjectRoot -Path $EvidencePath
    act = Get-RelativePathSafe -Root $ProjectRoot -Path $ActPath
    external_service_required = $false
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
    -Destination (Join-Path $ReleaseRoot "SGD-431-Component-Lifecycle-Manager.md") `
    -Force

Copy-Item `
    -LiteralPath $ActPath `
    -Destination (Join-Path $ReleaseRoot "ACT-020.2-Component-Lifecycle-Manager.md") `
    -Force

Write-Step "Resultado final"

Write-Host "SPT-020.2 tests passed: $($ComponentResult.Passed)"
Write-Host "Python compile exit code: $CompileExitCode"
Write-Host "Full suite passed: $FullSuitePassed"
Write-Host "External service required: NO"
Write-Host "n8n installed: NO"
Write-Host "Paid services: NO"
Write-Host "Evidence: $EvidencePath" -ForegroundColor Cyan
Write-Host "Release: $ReleaseRoot" -ForegroundColor Cyan
Write-Host "Status: $Status" -ForegroundColor Cyan

if ($Approved) {
    Write-Host "SPT-020.2: CANDIDATE FOR INSTITUTIONAL CLOSURE." -ForegroundColor Green
}
else {
    Write-Host "SPT-020.2: CLOSURE BLOCKED." -ForegroundColor Red
    exit 1
}
