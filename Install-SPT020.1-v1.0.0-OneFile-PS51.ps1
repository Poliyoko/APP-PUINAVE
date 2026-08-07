<#
.SYNOPSIS
    SPT-020.1 - Institutional Service Bus - One File Installer.

.DESCRIPTION
    Archivo unico PowerShell 5.1 para instalar, validar y preparar el cierre
    tecnico de SPT-020.1.

    Realiza:
      - instalacion del codigo Python;
      - instalacion de pruebas;
      - configuracion institucional;
      - pruebas especificas;
      - compilacion Python;
      - suite completa;
      - evidencias SHA-256;
      - documento, acta y release candidato.

    No instala n8n.
    No requiere broker externo.
    No usa servicios de pago.
    No publica en Git.

.PARAMETER ProjectRoot
    Raiz del repositorio. Por defecto usa la carpeta actual.

.PARAMETER SkipFullSuite
    Omite la suite completa. Si se usa, no autoriza cierre.

.EXAMPLE
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
    .\Install-SPT020.1-v1.0.0-OneFile-PS51.ps1
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipFullSuite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Component = "SPT-020.1"
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

    Write-TextFile -Path $LogPath -Content (($Output -join "`r`n") + "`r`n")
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
    throw "El instalador contiene errores de sintaxis PowerShell."
}

$PackageRoot = Join-Path $ProjectRoot "src\sgoda\platform\service_bus"
$TestsRoot = Join-Path $ProjectRoot "tests\platform\service_bus"
$DocsRoot = Join-Path $ProjectRoot "docs\06_Tecnologia\SPT-020.1"
$RunRoot = Join-Path $ProjectRoot "artifacts\development\SPT-020.1-v1.0.0\runs\$RunId"
$ReleaseRoot = Join-Path $ProjectRoot "releases\SPT-020.1-v1.0.0"
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

Write-Step "Instalando Institutional Service Bus"

$Contracts = @'
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Dict
from uuid import uuid4


@dataclass(frozen=True)
class InstitutionalMessage:
    topic: str
    payload: Dict[str, Any]
    source: str
    message_id: str = field(default_factory=lambda: str(uuid4()))
    created_at_utc: str = field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )

    def __post_init__(self) -> None:
        if not self.topic or not self.topic.strip():
            raise ValueError("topic is required")
        if not self.source or not self.source.strip():
            raise ValueError("source is required")

        object.__setattr__(self, "topic", self.topic.strip())
        object.__setattr__(self, "source", self.source.strip())
        object.__setattr__(self, "payload", dict(self.payload))
'@

$Registry = @'
from dataclasses import dataclass
from typing import Any, Dict, Iterable, Tuple


class ServiceRegistrationError(RuntimeError):
    pass


@dataclass(frozen=True)
class ServiceDescriptor:
    name: str
    service: Any
    topics: Tuple[str, ...]


class InstitutionalServiceRegistry:
    def __init__(self) -> None:
        self._services: Dict[str, ServiceDescriptor] = {}

    def register(self, name: str, service: Any, topics=()) -> ServiceDescriptor:
        if not name or not name.strip():
            raise ValueError("service name is required")
        if service is None:
            raise ValueError("service instance is required")
        if not callable(getattr(service, "handle", None)):
            raise ServiceRegistrationError("service must implement handle(message)")

        descriptor = ServiceDescriptor(
            name=name.strip(),
            service=service,
            topics=tuple(sorted(set(topics))),
        )
        self._services[descriptor.name] = descriptor
        return descriptor

    def get(self, name: str) -> Any:
        try:
            return self._services[name].service
        except KeyError as exc:
            raise ServiceRegistrationError(
                "service not registered: {0}".format(name)
            ) from exc

    def find_by_topic(self, topic: str):
        return tuple(
            item
            for item in self._services.values()
            if not item.topics or topic in item.topics
        )

    def descriptors(self) -> Iterable[ServiceDescriptor]:
        return tuple(self._services.values())
'@

$Bus = @'
from dataclasses import dataclass
from typing import Any, Dict, List, Tuple

from .contracts import InstitutionalMessage
from .registry import InstitutionalServiceRegistry


class RoutingError(RuntimeError):
    pass


@dataclass(frozen=True)
class DeliveryResult:
    service_name: str
    output: Any


@dataclass(frozen=True)
class BusReceipt:
    message_id: str
    topic: str
    deliveries: Tuple[DeliveryResult, ...]


class InstitutionalServiceBus:
    def __init__(self) -> None:
        self.registry = InstitutionalServiceRegistry()
        self.history: List[BusReceipt] = []
        self._middleware = []

    def register_service(self, name: str, service: Any, topics=()):
        return self.registry.register(name, service, topics)

    def add_middleware(self, middleware) -> None:
        if not callable(middleware):
            raise ValueError("middleware must be callable")
        self._middleware.append(middleware)

    def publish(
        self,
        topic: str,
        payload: Dict[str, Any],
        source: str,
    ) -> BusReceipt:
        message = InstitutionalMessage(topic, payload, source)

        for middleware in self._middleware:
            message = middleware(message)
            if message is None:
                raise RuntimeError("middleware cannot return None")

        descriptors = self.registry.find_by_topic(message.topic)

        if not descriptors:
            raise RoutingError(
                "no service available for topic: {0}".format(message.topic)
            )

        deliveries = tuple(
            DeliveryResult(
                service_name=descriptor.name,
                output=descriptor.service.handle(message),
            )
            for descriptor in descriptors
        )

        receipt = BusReceipt(
            message_id=message.message_id,
            topic=message.topic,
            deliveries=deliveries,
        )
        self.history.append(receipt)
        return receipt
'@

$Health = @'
from dataclasses import dataclass
from typing import Tuple

from .registry import InstitutionalServiceRegistry


@dataclass(frozen=True)
class ServiceHealth:
    name: str
    healthy: bool


@dataclass(frozen=True)
class BusHealthReport:
    healthy: bool
    services: Tuple[ServiceHealth, ...]


class InstitutionalBusHealthMonitor:
    def evaluate(self, registry: InstitutionalServiceRegistry) -> BusHealthReport:
        results = []

        for descriptor in registry.descriptors():
            health_method = getattr(descriptor.service, "health", None)

            if callable(health_method):
                healthy = bool(health_method())
            else:
                healthy = callable(getattr(descriptor.service, "handle", None))

            results.append(ServiceHealth(descriptor.name, healthy))

        return BusHealthReport(
            healthy=all(item.healthy for item in results),
            services=tuple(results),
        )
'@

$Init = @'
from .contracts import InstitutionalMessage
from .health import BusHealthReport, InstitutionalBusHealthMonitor, ServiceHealth
from .registry import (
    InstitutionalServiceRegistry,
    ServiceDescriptor,
    ServiceRegistrationError,
)
from .service_bus import (
    BusReceipt,
    DeliveryResult,
    InstitutionalServiceBus,
    RoutingError,
)

__all__ = [
    "BusHealthReport",
    "BusReceipt",
    "DeliveryResult",
    "InstitutionalBusHealthMonitor",
    "InstitutionalMessage",
    "InstitutionalServiceBus",
    "InstitutionalServiceRegistry",
    "RoutingError",
    "ServiceDescriptor",
    "ServiceHealth",
    "ServiceRegistrationError",
]
'@

$Tests = @'
import pytest

from sgoda.platform.service_bus import (
    InstitutionalBusHealthMonitor,
    InstitutionalMessage,
    InstitutionalServiceBus,
    InstitutionalServiceRegistry,
    RoutingError,
    ServiceRegistrationError,
)


class Service:
    def __init__(self):
        self.received = []

    def handle(self, message):
        self.received.append(message)
        return message.payload.get("value", "OK")

    def health(self):
        return True


def test_message_requires_topic():
    with pytest.raises(ValueError):
        InstitutionalMessage("", {}, "test")


def test_message_copies_payload():
    payload = {"value": 1}
    message = InstitutionalMessage("topic", payload, "test")
    payload["value"] = 2
    assert message.payload["value"] == 1


def test_registry_requires_handle_contract():
    registry = InstitutionalServiceRegistry()
    with pytest.raises(ServiceRegistrationError):
        registry.register("invalid", object())


def test_registry_registers_and_gets_service():
    registry = InstitutionalServiceRegistry()
    service = Service()
    registry.register("service", service, ("topic",))
    assert registry.get("service") is service


def test_bus_routes_message():
    bus = InstitutionalServiceBus()
    service = Service()
    bus.register_service("service", service, ("topic",))
    receipt = bus.publish("topic", {"value": 7}, "test")
    assert receipt.deliveries[0].output == 7
    assert len(bus.history) == 1


def test_bus_rejects_unknown_topic():
    bus = InstitutionalServiceBus()
    with pytest.raises(RoutingError):
        bus.publish("missing", {}, "test")


def test_bus_applies_middleware():
    bus = InstitutionalServiceBus()
    service = Service()
    bus.register_service("service", service, ("topic",))

    def enrich(message):
        message.payload["validated"] = True
        return message

    bus.add_middleware(enrich)
    bus.publish("topic", {}, "test")
    assert service.received[0].payload["validated"] is True


def test_health_monitor_reports_healthy_service():
    registry = InstitutionalServiceRegistry()
    registry.register("service", Service(), ("topic",))
    report = InstitutionalBusHealthMonitor().evaluate(registry)
    assert report.healthy is True
    assert report.services[0].name == "service"
'@

Write-TextFile -Path (Join-Path $PackageRoot "contracts.py") -Content $Contracts
Write-TextFile -Path (Join-Path $PackageRoot "registry.py") -Content $Registry
Write-TextFile -Path (Join-Path $PackageRoot "service_bus.py") -Content $Bus
Write-TextFile -Path (Join-Path $PackageRoot "health.py") -Content $Health
Write-TextFile -Path (Join-Path $PackageRoot "__init__.py") -Content $Init
Write-TextFile -Path (Join-Path $TestsRoot "test_spt0201.py") -Content $Tests

$Config = [ordered]@{
    component = $Component
    version = $Version
    name = "Institutional Service Bus"
    parent_component = "SPT-020"
    transport = "in_process"
    repository_is_source_of_truth = $true
    external_broker_required = $false
    n8n_required = $false
    paid_services_required = $false
}

Write-JsonFile `
    -Path (Join-Path $ConfigRoot "SPT-020.1-component.json") `
    -Data $Config

$Document = @"
# SGD-430 - Institutional Service Bus

| Field | Value |
|---|---|
| Component | SPT-020.1 |
| Version | $Version |
| Transport | In process |
| External broker | Not required |
| n8n | Not installed |
| Paid services | Not required |

SPT-020.1 provides institutional message contracts, service registration,
topic routing, middleware, delivery receipts and health monitoring.
"@

$DocumentPath = Join-Path $DocsRoot "SGD-430-Institutional-Service-Bus.md"
Write-TextFile -Path $DocumentPath -Content $Document

$env:PYTHONPATH = Join-Path $ProjectRoot "src"

Write-Step "Ejecutando pruebas especificas"

$ComponentResult = Invoke-Pytest `
    -Targets @("tests/platform/service_bus/test_spt0201.py") `
    -LogPath (Join-Path $RunRoot "pytest-spt0201.txt")

if (-not $ComponentResult.Passed) {
    throw "Las pruebas especificas de SPT-020.1 fallaron."
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
    Get-Item -LiteralPath (Join-Path $ConfigRoot "SPT-020.1-component.json")
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
# ACT-020.1 - Institutional Service Bus

| Field | Value |
|---|---|
| Component | SPT-020.1 |
| Version | $Version |
| Status | $ActStatus |
| Component tests | $($ComponentResult.Passed) |
| Python compile exit code | $CompileExitCode |
| Full suite passed | $FullSuitePassed |
| External broker required | NO |
| n8n installed | NO |
| Paid services | NO |
"@

$ActPath = Join-Path $DocsRoot "ACT-020.1-Institutional-Service-Bus.md"
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
    -Destination (Join-Path $ReleaseRoot "SGD-430-Institutional-Service-Bus.md") `
    -Force

Copy-Item `
    -LiteralPath $ActPath `
    -Destination (Join-Path $ReleaseRoot "ACT-020.1-Institutional-Service-Bus.md") `
    -Force

Write-Step "Resultado final"

Write-Host "SPT-020.1 tests passed: $($ComponentResult.Passed)"
Write-Host "Python compile exit code: $CompileExitCode"
Write-Host "Full suite passed: $FullSuitePassed"
Write-Host "External broker required: NO"
Write-Host "n8n installed: NO"
Write-Host "Paid services: NO"
Write-Host "Evidence: $EvidencePath" -ForegroundColor Cyan
Write-Host "Release: $ReleaseRoot" -ForegroundColor Cyan
Write-Host "Status: $Status" -ForegroundColor Cyan

if ($Approved) {
    Write-Host "SPT-020.1: CANDIDATE FOR INSTITUTIONAL CLOSURE." -ForegroundColor Green
}
else {
    Write-Host "SPT-020.1: CLOSURE BLOCKED." -ForegroundColor Red
    exit 1
}
