<#
.SYNOPSIS
    SPT-020.4 - Institutional Event Bus - One File Installer.

.DESCRIPTION
    Instala y valida el bus institucional de eventos de SGODA-PUINAVE.

    Incluye:
      - contratos de eventos;
      - publicacion y suscripcion;
      - filtros por tipo de evento;
      - prioridades;
      - suscriptores multiples;
      - reintentos controlados;
      - historial de entregas;
      - dead-letter queue;
      - health report;
      - pruebas especificas;
      - compilacion Python;
      - suite completa;
      - evidencia SHA-256;
      - documentacion, acta y release candidato.

    Compatible con Windows PowerShell 5.1.
    No instala n8n.
    No requiere broker externo.
    No usa servicios de pago.
    No publica en Git.

.PARAMETER ProjectRoot
    Raiz del repositorio. Por defecto usa la carpeta actual.

.PARAMETER SkipFullSuite
    Omite la suite completa y bloquea el cierre.

.EXAMPLE
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
    .\Install-SPT020.4-v1.0.0-OneFile-PS51.ps1
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipFullSuite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Component = "SPT-020.4"
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
    param([string]$Path, [object]$Data)
    $Json = $Data | ConvertTo-Json -Depth 40
    Write-TextFile -Path $Path -Content ($Json + "`r`n")
}

function Get-RelativePathSafe {
    param([string]$Root, [string]$Path)

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

$PackageRoot = Join-Path $ProjectRoot "src\sgoda\platform\event_bus"
$TestsRoot = Join-Path $ProjectRoot "tests\platform\event_bus"
$DocsRoot = Join-Path $ProjectRoot "docs\06_Tecnologia\SPT-020.4"
$RunRoot = Join-Path $ProjectRoot "artifacts\development\SPT-020.4-v1.0.0\runs\$RunId"
$ReleaseRoot = Join-Path $ProjectRoot "releases\SPT-020.4-v1.0.0"
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

Write-Step "Instalando Institutional Event Bus"

$ModelsPy = @'
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import IntEnum
from typing import Any, Dict
from uuid import uuid4


class EventPriority(IntEnum):
    LOW = 10
    NORMAL = 20
    HIGH = 30
    CRITICAL = 40


@dataclass(frozen=True)
class InstitutionalEvent:
    event_type: str
    payload: Dict[str, Any]
    source: str
    priority: EventPriority = EventPriority.NORMAL
    event_id: str = field(default_factory=lambda: str(uuid4()))
    occurred_at_utc: str = field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )

    def __post_init__(self) -> None:
        if not self.event_type or not self.event_type.strip():
            raise ValueError("event_type is required")
        if not self.source or not self.source.strip():
            raise ValueError("source is required")

        object.__setattr__(self, "event_type", self.event_type.strip())
        object.__setattr__(self, "source", self.source.strip())
        object.__setattr__(self, "payload", dict(self.payload))


@dataclass(frozen=True)
class EventDelivery:
    event_id: str
    subscriber_name: str
    delivered: bool
    attempts: int
    error: str = ""


@dataclass(frozen=True)
class DeadLetter:
    event: InstitutionalEvent
    subscriber_name: str
    attempts: int
    error: str
'@

$RegistryPy = @'
from dataclasses import dataclass
from typing import Callable, Dict, Iterable, Tuple


class SubscriptionError(RuntimeError):
    pass


@dataclass(frozen=True)
class Subscription:
    name: str
    handler: Callable
    event_types: Tuple[str, ...]


class EventSubscriptionRegistry:
    def __init__(self) -> None:
        self._subscriptions: Dict[str, Subscription] = {}

    def subscribe(self, name: str, handler: Callable, event_types=()) -> Subscription:
        if not name or not name.strip():
            raise ValueError("subscriber name is required")
        if not callable(handler):
            raise ValueError("handler must be callable")
        if name in self._subscriptions:
            raise SubscriptionError(
                "subscriber already registered: {0}".format(name)
            )

        subscription = Subscription(
            name=name.strip(),
            handler=handler,
            event_types=tuple(sorted(set(event_types))),
        )
        self._subscriptions[subscription.name] = subscription
        return subscription

    def unsubscribe(self, name: str) -> None:
        self._subscriptions.pop(name, None)

    def matching(self, event_type: str) -> Iterable[Subscription]:
        return tuple(
            subscription
            for subscription in self._subscriptions.values()
            if not subscription.event_types
            or event_type in subscription.event_types
        )

    def subscriptions(self) -> Iterable[Subscription]:
        return tuple(self._subscriptions.values())
'@

$BusPy = @'
from typing import List, Optional, Tuple

from .models import DeadLetter, EventDelivery, InstitutionalEvent
from .registry import EventSubscriptionRegistry


class NoSubscriberError(RuntimeError):
    pass


class InstitutionalEventBus:
    def __init__(
        self,
        registry: Optional[EventSubscriptionRegistry] = None,
        max_attempts: int = 2,
    ) -> None:
        if max_attempts < 1:
            raise ValueError("max_attempts must be at least 1")

        self.registry = registry or EventSubscriptionRegistry()
        self.max_attempts = max_attempts
        self.history: List[EventDelivery] = []
        self.dead_letters: List[DeadLetter] = []

    def subscribe(self, name, handler, event_types=()):
        return self.registry.subscribe(name, handler, event_types)

    def publish(self, event: InstitutionalEvent) -> Tuple[EventDelivery, ...]:
        subscriptions = tuple(self.registry.matching(event.event_type))

        if not subscriptions:
            raise NoSubscriberError(
                "no subscriber available for event: {0}".format(
                    event.event_type
                )
            )

        deliveries = []

        for subscription in subscriptions:
            attempts = 0
            delivered = False
            error = ""

            while attempts < self.max_attempts and not delivered:
                attempts += 1

                try:
                    subscription.handler(event)
                    delivered = True
                except Exception as exc:
                    error = str(exc)

            delivery = EventDelivery(
                event_id=event.event_id,
                subscriber_name=subscription.name,
                delivered=delivered,
                attempts=attempts,
                error=error,
            )
            deliveries.append(delivery)
            self.history.append(delivery)

            if not delivered:
                self.dead_letters.append(
                    DeadLetter(
                        event=event,
                        subscriber_name=subscription.name,
                        attempts=attempts,
                        error=error,
                    )
                )

        return tuple(deliveries)

    def replay_dead_letters(self) -> Tuple[EventDelivery, ...]:
        pending = tuple(self.dead_letters)
        self.dead_letters.clear()
        results = []

        for dead_letter in pending:
            subscription = next(
                (
                    item
                    for item in self.registry.subscriptions()
                    if item.name == dead_letter.subscriber_name
                ),
                None,
            )

            if subscription is None:
                self.dead_letters.append(dead_letter)
                continue

            attempts = 0
            delivered = False
            error = ""

            while attempts < self.max_attempts and not delivered:
                attempts += 1

                try:
                    subscription.handler(dead_letter.event)
                    delivered = True
                except Exception as exc:
                    error = str(exc)

            delivery = EventDelivery(
                event_id=dead_letter.event.event_id,
                subscriber_name=dead_letter.subscriber_name,
                delivered=delivered,
                attempts=attempts,
                error=error,
            )
            results.append(delivery)
            self.history.append(delivery)

            if not delivered:
                self.dead_letters.append(
                    DeadLetter(
                        event=dead_letter.event,
                        subscriber_name=dead_letter.subscriber_name,
                        attempts=attempts,
                        error=error,
                    )
                )

        return tuple(results)
'@

$HealthPy = @'
from dataclasses import dataclass

from .service_bus import InstitutionalEventBus


@dataclass(frozen=True)
class EventBusHealthReport:
    healthy: bool
    subscribers: int
    deliveries: int
    dead_letters: int


class EventBusHealthMonitor:
    def evaluate(self, bus: InstitutionalEventBus) -> EventBusHealthReport:
        subscribers = len(tuple(bus.registry.subscriptions()))
        dead_letters = len(bus.dead_letters)

        return EventBusHealthReport(
            healthy=(dead_letters == 0),
            subscribers=subscribers,
            deliveries=len(bus.history),
            dead_letters=dead_letters,
        )
'@

$InitPy = @'
from .health import EventBusHealthMonitor, EventBusHealthReport
from .models import (
    DeadLetter,
    EventDelivery,
    EventPriority,
    InstitutionalEvent,
)
from .registry import (
    EventSubscriptionRegistry,
    Subscription,
    SubscriptionError,
)
from .service_bus import InstitutionalEventBus, NoSubscriberError

__all__ = [
    "DeadLetter",
    "EventBusHealthMonitor",
    "EventBusHealthReport",
    "EventDelivery",
    "EventPriority",
    "EventSubscriptionRegistry",
    "InstitutionalEvent",
    "InstitutionalEventBus",
    "NoSubscriberError",
    "Subscription",
    "SubscriptionError",
]
'@

$TestsPy = @'
import pytest

from sgoda.platform.event_bus import (
    EventBusHealthMonitor,
    EventPriority,
    EventSubscriptionRegistry,
    InstitutionalEvent,
    InstitutionalEventBus,
    NoSubscriberError,
    SubscriptionError,
)


def test_event_requires_type():
    with pytest.raises(ValueError):
        InstitutionalEvent("", {}, "test")


def test_event_copies_payload():
    payload = {"value": 1}
    event = InstitutionalEvent("component.active", payload, "SPT-020.2")
    payload["value"] = 2
    assert event.payload["value"] == 1


def test_priority_values_are_ordered():
    assert EventPriority.CRITICAL > EventPriority.HIGH
    assert EventPriority.HIGH > EventPriority.NORMAL


def test_registry_rejects_duplicate_subscriber():
    registry = EventSubscriptionRegistry()
    registry.subscribe("audit", lambda event: None)

    with pytest.raises(SubscriptionError):
        registry.subscribe("audit", lambda event: None)


def test_publish_delivers_to_matching_subscriber():
    bus = InstitutionalEventBus()
    received = []
    bus.subscribe("audit", received.append, ("component.active",))

    event = InstitutionalEvent(
        "component.active",
        {"component": "SPT-020.3"},
        "SPT-020.2",
    )
    deliveries = bus.publish(event)

    assert deliveries[0].delivered is True
    assert received[0].payload["component"] == "SPT-020.3"


def test_publish_delivers_to_multiple_subscribers():
    bus = InstitutionalEventBus()
    first = []
    second = []
    bus.subscribe("first", first.append, ("event",))
    bus.subscribe("second", second.append, ("event",))
    deliveries = bus.publish(InstitutionalEvent("event", {}, "test"))
    assert len(deliveries) == 2
    assert len(first) == 1
    assert len(second) == 1


def test_event_type_filter_is_respected():
    bus = InstitutionalEventBus()
    received = []
    bus.subscribe("audit", received.append, ("allowed",))

    with pytest.raises(NoSubscriberError):
        bus.publish(InstitutionalEvent("other", {}, "test"))


def test_handler_is_retried_until_success():
    bus = InstitutionalEventBus(max_attempts=3)
    calls = {"count": 0}

    def handler(event):
        calls["count"] += 1
        if calls["count"] < 2:
            raise RuntimeError("temporary")

    bus.subscribe("retry", handler, ("event",))
    delivery = bus.publish(InstitutionalEvent("event", {}, "test"))[0]

    assert delivery.delivered is True
    assert delivery.attempts == 2
    assert len(bus.dead_letters) == 0


def test_failed_handler_goes_to_dead_letter_queue():
    bus = InstitutionalEventBus(max_attempts=2)

    def handler(event):
        raise RuntimeError("permanent")

    bus.subscribe("failed", handler, ("event",))
    delivery = bus.publish(InstitutionalEvent("event", {}, "test"))[0]

    assert delivery.delivered is False
    assert delivery.attempts == 2
    assert len(bus.dead_letters) == 1


def test_dead_letter_can_be_replayed():
    bus = InstitutionalEventBus(max_attempts=1)
    state = {"working": False}

    def handler(event):
        if not state["working"]:
            raise RuntimeError("not ready")

    bus.subscribe("recoverable", handler, ("event",))
    bus.publish(InstitutionalEvent("event", {}, "test"))
    assert len(bus.dead_letters) == 1

    state["working"] = True
    replayed = bus.replay_dead_letters()

    assert replayed[0].delivered is True
    assert len(bus.dead_letters) == 0


def test_history_preserves_deliveries():
    bus = InstitutionalEventBus()
    bus.subscribe("audit", lambda event: None, ("event",))
    bus.publish(InstitutionalEvent("event", {}, "test"))
    assert len(bus.history) == 1


def test_health_report_is_healthy_without_dead_letters():
    bus = InstitutionalEventBus()
    bus.subscribe("audit", lambda event: None, ("event",))
    bus.publish(InstitutionalEvent("event", {}, "test"))
    report = EventBusHealthMonitor().evaluate(bus)
    assert report.healthy is True
    assert report.subscribers == 1
    assert report.dead_letters == 0


def test_health_report_detects_dead_letters():
    bus = InstitutionalEventBus(max_attempts=1)

    def handler(event):
        raise RuntimeError("failure")

    bus.subscribe("failed", handler, ("event",))
    bus.publish(InstitutionalEvent("event", {}, "test"))
    report = EventBusHealthMonitor().evaluate(bus)
    assert report.healthy is False
    assert report.dead_letters == 1
'@

Write-TextFile -Path (Join-Path $PackageRoot "models.py") -Content $ModelsPy
Write-TextFile -Path (Join-Path $PackageRoot "registry.py") -Content $RegistryPy
Write-TextFile -Path (Join-Path $PackageRoot "service_bus.py") -Content $BusPy
Write-TextFile -Path (Join-Path $PackageRoot "health.py") -Content $HealthPy
Write-TextFile -Path (Join-Path $PackageRoot "__init__.py") -Content $InitPy
Write-TextFile -Path (Join-Path $TestsRoot "test_spt0204.py") -Content $TestsPy

$Config = [ordered]@{
    component = $Component
    version = $Version
    name = "Institutional Event Bus"
    parent_component = "SPT-020"
    transport = "in_process"
    priority_support = $true
    retry_support = $true
    dead_letter_queue = $true
    repository_is_source_of_truth = $true
    external_broker_required = $false
    n8n_required = $false
    paid_services_required = $false
}

$ConfigPath = Join-Path $ConfigRoot "SPT-020.4-component.json"
Write-JsonFile -Path $ConfigPath -Data $Config

$Document = @"
# SGD-433 - Institutional Event Bus

| Field | Value |
|---|---|
| Component | SPT-020.4 |
| Version | $Version |
| Parent | SPT-020 |
| Transport | In process |
| Event priorities | YES |
| Controlled retries | YES |
| Dead-letter queue | YES |
| External broker | NO |
| n8n | Not installed |
| Paid services | Not required |

SPT-020.4 provides institutional event contracts, filtered subscriptions,
multiple delivery, controlled retries, delivery history, dead-letter handling
and health monitoring without external infrastructure.
"@

$DocumentPath = Join-Path $DocsRoot "SGD-433-Institutional-Event-Bus.md"
Write-TextFile -Path $DocumentPath -Content $Document

$env:PYTHONPATH = Join-Path $ProjectRoot "src"

Write-Step "Ejecutando pruebas especificas SPT-020.4"

$ComponentResult = Invoke-Pytest `
    -Targets @("tests/platform/event_bus/test_spt0204.py") `
    -LogPath (Join-Path $RunRoot "pytest-spt0204.txt")

if (-not $ComponentResult.Passed) {
    throw "Las pruebas especificas de SPT-020.4 fallaron."
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
    external_broker_required = $false
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
# ACT-020.4 - Institutional Event Bus

| Field | Value |
|---|---|
| Component | SPT-020.4 |
| Version | $Version |
| Status | $ActStatus |
| Component tests | $($ComponentResult.Passed) |
| Python compile exit code | $CompileExitCode |
| Full suite passed | $FullSuitePassed |
| External broker required | NO |
| n8n installed | NO |
| Paid services | NO |
"@

$ActPath = Join-Path $DocsRoot "ACT-020.4-Institutional-Event-Bus.md"
Write-TextFile -Path $ActPath -Content $Act

$Manifest = [ordered]@{
    component = $Component
    version = $Version
    status = $Status
    evidence = Get-RelativePathSafe -Root $ProjectRoot -Path $EvidencePath
    act = Get-RelativePathSafe -Root $ProjectRoot -Path $ActPath
    external_broker_required = $false
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
    -Destination (Join-Path $ReleaseRoot "SGD-433-Institutional-Event-Bus.md") `
    -Force

Copy-Item `
    -LiteralPath $ActPath `
    -Destination (Join-Path $ReleaseRoot "ACT-020.4-Institutional-Event-Bus.md") `
    -Force

Write-Step "Resultado final"

Write-Host "SPT-020.4 tests passed: $($ComponentResult.Passed)"
Write-Host "Python compile exit code: $CompileExitCode"
Write-Host "Full suite passed: $FullSuitePassed"
Write-Host "External broker required: NO"
Write-Host "n8n installed: NO"
Write-Host "Paid services: NO"
Write-Host "Evidence: $EvidencePath" -ForegroundColor Cyan
Write-Host "Release: $ReleaseRoot" -ForegroundColor Cyan
Write-Host "Status: $Status" -ForegroundColor Cyan

if ($Approved) {
    Write-Host "SPT-020.4: CANDIDATE FOR INSTITUTIONAL CLOSURE." -ForegroundColor Green
}
else {
    Write-Host "SPT-020.4: CLOSURE BLOCKED." -ForegroundColor Red
    exit 1
}
