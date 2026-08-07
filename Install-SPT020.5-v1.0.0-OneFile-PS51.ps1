<#
.SYNOPSIS
    SPT-020.5 - Institutional Service Discovery and Registry - One File Installer.

.DESCRIPTION
    Instala y valida el registro y descubrimiento institucional de servicios
    de SGODA-PUINAVE.

    Incluye:
      - contratos de servicios;
      - registro y desregistro;
      - descubrimiento por nombre y capacidad;
      - endpoints institucionales;
      - compatibilidad de versiones;
      - heartbeat y estado de disponibilidad;
      - expiracion controlada;
      - deteccion de duplicados;
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
    .\Install-SPT020.5-v1.0.0-OneFile-PS51.ps1
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipFullSuite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Component = "SPT-020.5"
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

$PackageRoot = Join-Path $ProjectRoot "src\sgoda\platform\service_discovery"
$TestsRoot = Join-Path $ProjectRoot "tests\platform\service_discovery"
$DocsRoot = Join-Path $ProjectRoot "docs\06_Tecnologia\SPT-020.5"
$RunRoot = Join-Path $ProjectRoot "artifacts\development\SPT-020.5-v1.0.0\runs\$RunId"
$ReleaseRoot = Join-Path $ProjectRoot "releases\SPT-020.5-v1.0.0"
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

Write-Step "Instalando Institutional Service Discovery and Registry"

$ModelsPy = @'
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Dict, Tuple


class ServiceStatus(str, Enum):
    AVAILABLE = "AVAILABLE"
    DEGRADED = "DEGRADED"
    UNAVAILABLE = "UNAVAILABLE"
    RETIRED = "RETIRED"


@dataclass(frozen=True)
class ServiceEndpoint:
    protocol: str
    address: str

    def __post_init__(self) -> None:
        if not self.protocol or not self.protocol.strip():
            raise ValueError("protocol is required")
        if not self.address or not self.address.strip():
            raise ValueError("address is required")


@dataclass(frozen=True)
class ServiceDefinition:
    service_id: str
    name: str
    version: str
    capabilities: Tuple[str, ...]
    endpoints: Tuple[ServiceEndpoint, ...]
    metadata: Dict[str, str] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if not self.service_id or not self.service_id.strip():
            raise ValueError("service_id is required")
        if not self.name or not self.name.strip():
            raise ValueError("name is required")
        if not self.version or not self.version.strip():
            raise ValueError("version is required")
        if not self.endpoints:
            raise ValueError("at least one endpoint is required")

        object.__setattr__(self, "service_id", self.service_id.strip())
        object.__setattr__(self, "name", self.name.strip())
        object.__setattr__(
            self,
            "capabilities",
            tuple(sorted(set(self.capabilities))),
        )
        object.__setattr__(self, "endpoints", tuple(self.endpoints))
        object.__setattr__(self, "metadata", dict(self.metadata))


@dataclass
class ServiceRecord:
    definition: ServiceDefinition
    status: ServiceStatus = ServiceStatus.AVAILABLE
    last_heartbeat_utc: str = field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )
'@

$VersioningPy = @'
from typing import Tuple


class InvalidServiceVersionError(ValueError):
    pass


def parse_version(value: str) -> Tuple[int, int, int]:
    parts = value.strip().split(".")
    if len(parts) != 3 or not all(part.isdigit() for part in parts):
        raise InvalidServiceVersionError(
            "version must use semantic numeric format X.Y.Z"
        )
    return tuple(int(part) for part in parts)


def is_compatible(
    current: str,
    minimum: str = "0.0.0",
    maximum: str = "",
) -> bool:
    current_value = parse_version(current)
    minimum_value = parse_version(minimum)

    if current_value < minimum_value:
        return False

    if maximum and current_value > parse_version(maximum):
        return False

    return True
'@

$RegistryPy = @'
from datetime import datetime, timezone
from typing import Dict, Iterable, Tuple

from .models import ServiceDefinition, ServiceRecord, ServiceStatus
from .versioning import is_compatible


class ServiceRegistryError(RuntimeError):
    pass


class DuplicateServiceError(ServiceRegistryError):
    pass


class ServiceNotFoundError(ServiceRegistryError):
    pass


class InstitutionalServiceRegistry:
    def __init__(self) -> None:
        self._records: Dict[str, ServiceRecord] = {}

    def register(self, definition: ServiceDefinition) -> ServiceRecord:
        if definition.service_id in self._records:
            raise DuplicateServiceError(
                "service already registered: {0}".format(
                    definition.service_id
                )
            )

        record = ServiceRecord(definition=definition)
        self._records[definition.service_id] = record
        return record

    def unregister(self, service_id: str) -> None:
        self._records.pop(service_id, None)

    def get(self, service_id: str) -> ServiceRecord:
        try:
            return self._records[service_id]
        except KeyError as exc:
            raise ServiceNotFoundError(
                "service not registered: {0}".format(service_id)
            ) from exc

    def heartbeat(
        self,
        service_id: str,
        status: ServiceStatus = ServiceStatus.AVAILABLE,
    ) -> ServiceRecord:
        record = self.get(service_id)
        record.status = status
        record.last_heartbeat_utc = datetime.now(timezone.utc).isoformat()
        return record

    def set_status(
        self,
        service_id: str,
        status: ServiceStatus,
    ) -> ServiceRecord:
        record = self.get(service_id)
        record.status = status
        return record

    def discover(
        self,
        name: str = "",
        capability: str = "",
        minimum_version: str = "0.0.0",
        maximum_version: str = "",
        available_only: bool = True,
    ) -> Tuple[ServiceRecord, ...]:
        matches = []

        for record in self._records.values():
            definition = record.definition

            if name and definition.name != name:
                continue
            if capability and capability not in definition.capabilities:
                continue
            if available_only and record.status != ServiceStatus.AVAILABLE:
                continue
            if not is_compatible(
                definition.version,
                minimum_version,
                maximum_version,
            ):
                continue

            matches.append(record)

        return tuple(
            sorted(
                matches,
                key=lambda item: (
                    item.definition.name,
                    item.definition.version,
                    item.definition.service_id,
                ),
            )
        )

    def records(self) -> Iterable[ServiceRecord]:
        return tuple(self._records.values())
'@

$DiscoveryPy = @'
from datetime import datetime, timezone
from typing import Tuple

from .models import ServiceRecord, ServiceStatus
from .registry import InstitutionalServiceRegistry


class NoServiceAvailableError(RuntimeError):
    pass


class InstitutionalServiceDiscovery:
    def __init__(self, registry: InstitutionalServiceRegistry) -> None:
        self.registry = registry

    def resolve(
        self,
        capability: str,
        minimum_version: str = "0.0.0",
        maximum_version: str = "",
    ) -> ServiceRecord:
        matches = self.registry.discover(
            capability=capability,
            minimum_version=minimum_version,
            maximum_version=maximum_version,
            available_only=True,
        )

        if not matches:
            raise NoServiceAvailableError(
                "no service available for capability: {0}".format(
                    capability
                )
            )

        return matches[-1]

    def expire_stale(
        self,
        max_age_seconds: int,
        now_utc: datetime = None,
    ) -> Tuple[str, ...]:
        if max_age_seconds < 0:
            raise ValueError("max_age_seconds cannot be negative")

        now = now_utc or datetime.now(timezone.utc)
        expired = []

        for record in self.registry.records():
            heartbeat = datetime.fromisoformat(record.last_heartbeat_utc)
            age = (now - heartbeat).total_seconds()

            if (
                age > max_age_seconds
                and record.status != ServiceStatus.RETIRED
            ):
                record.status = ServiceStatus.UNAVAILABLE
                expired.append(record.definition.service_id)

        return tuple(sorted(expired))
'@

$HealthPy = @'
from dataclasses import dataclass
from typing import Tuple

from .models import ServiceStatus
from .registry import InstitutionalServiceRegistry


@dataclass(frozen=True)
class RegisteredServiceHealth:
    service_id: str
    status: str
    capabilities: Tuple[str, ...]


@dataclass(frozen=True)
class ServiceRegistryHealthReport:
    healthy: bool
    total_services: int
    available_services: int
    services: Tuple[RegisteredServiceHealth, ...]


class ServiceRegistryHealthMonitor:
    def evaluate(
        self,
        registry: InstitutionalServiceRegistry,
    ) -> ServiceRegistryHealthReport:
        items = tuple(
            RegisteredServiceHealth(
                service_id=record.definition.service_id,
                status=record.status.value,
                capabilities=record.definition.capabilities,
            )
            for record in registry.records()
        )

        available = sum(
            1
            for record in registry.records()
            if record.status == ServiceStatus.AVAILABLE
        )

        return ServiceRegistryHealthReport(
            healthy=(len(items) == 0 or available > 0),
            total_services=len(items),
            available_services=available,
            services=items,
        )
'@

$InitPy = @'
from .discovery import (
    InstitutionalServiceDiscovery,
    NoServiceAvailableError,
)
from .health import (
    RegisteredServiceHealth,
    ServiceRegistryHealthMonitor,
    ServiceRegistryHealthReport,
)
from .models import (
    ServiceDefinition,
    ServiceEndpoint,
    ServiceRecord,
    ServiceStatus,
)
from .registry import (
    DuplicateServiceError,
    InstitutionalServiceRegistry,
    ServiceNotFoundError,
    ServiceRegistryError,
)
from .versioning import (
    InvalidServiceVersionError,
    is_compatible,
    parse_version,
)

__all__ = [
    "DuplicateServiceError",
    "InstitutionalServiceDiscovery",
    "InstitutionalServiceRegistry",
    "InvalidServiceVersionError",
    "NoServiceAvailableError",
    "RegisteredServiceHealth",
    "ServiceDefinition",
    "ServiceEndpoint",
    "ServiceNotFoundError",
    "ServiceRecord",
    "ServiceRegistryError",
    "ServiceRegistryHealthMonitor",
    "ServiceRegistryHealthReport",
    "ServiceStatus",
    "is_compatible",
    "parse_version",
]
'@

$TestsPy = @'
from datetime import datetime, timedelta, timezone

import pytest

from sgoda.platform.service_discovery import (
    DuplicateServiceError,
    InstitutionalServiceDiscovery,
    InstitutionalServiceRegistry,
    InvalidServiceVersionError,
    NoServiceAvailableError,
    ServiceDefinition,
    ServiceEndpoint,
    ServiceRegistryHealthMonitor,
    ServiceStatus,
    is_compatible,
    parse_version,
)


def build_service(
    service_id="service-1",
    name="lexical",
    version="1.0.0",
    capabilities=("search",),
):
    return ServiceDefinition(
        service_id=service_id,
        name=name,
        version=version,
        capabilities=capabilities,
        endpoints=(ServiceEndpoint("inproc", "sgoda://lexical"),),
    )


def test_service_requires_endpoint():
    with pytest.raises(ValueError):
        ServiceDefinition("service", "name", "1.0.0", (), ())


def test_parse_semantic_version():
    assert parse_version("1.2.3") == (1, 2, 3)


def test_invalid_version_is_rejected():
    with pytest.raises(InvalidServiceVersionError):
        parse_version("1.2")


def test_version_compatibility():
    assert is_compatible("1.5.0", "1.0.0", "2.0.0") is True
    assert is_compatible("2.1.0", "1.0.0", "2.0.0") is False


def test_registry_registers_service():
    registry = InstitutionalServiceRegistry()
    record = registry.register(build_service())
    assert record.status == ServiceStatus.AVAILABLE


def test_registry_rejects_duplicate_service():
    registry = InstitutionalServiceRegistry()
    service = build_service()
    registry.register(service)

    with pytest.raises(DuplicateServiceError):
        registry.register(service)


def test_discover_by_capability():
    registry = InstitutionalServiceRegistry()
    registry.register(build_service())
    matches = registry.discover(capability="search")
    assert matches[0].definition.service_id == "service-1"


def test_discover_filters_unavailable_services():
    registry = InstitutionalServiceRegistry()
    registry.register(build_service())
    registry.set_status("service-1", ServiceStatus.UNAVAILABLE)
    assert registry.discover(capability="search") == ()


def test_discovery_resolves_highest_compatible_service():
    registry = InstitutionalServiceRegistry()
    registry.register(build_service("service-1", version="1.0.0"))
    registry.register(build_service("service-2", version="1.5.0"))
    discovery = InstitutionalServiceDiscovery(registry)
    result = discovery.resolve("search", "1.0.0", "2.0.0")
    assert result.definition.service_id == "service-2"


def test_discovery_raises_when_service_is_missing():
    discovery = InstitutionalServiceDiscovery(
        InstitutionalServiceRegistry()
    )

    with pytest.raises(NoServiceAvailableError):
        discovery.resolve("missing")


def test_heartbeat_updates_status():
    registry = InstitutionalServiceRegistry()
    registry.register(build_service())
    registry.heartbeat("service-1", ServiceStatus.DEGRADED)
    assert registry.get("service-1").status == ServiceStatus.DEGRADED


def test_stale_service_is_expired():
    registry = InstitutionalServiceRegistry()
    record = registry.register(build_service())
    record.last_heartbeat_utc = (
        datetime.now(timezone.utc) - timedelta(minutes=10)
    ).isoformat()

    discovery = InstitutionalServiceDiscovery(registry)
    expired = discovery.expire_stale(
        max_age_seconds=60,
        now_utc=datetime.now(timezone.utc),
    )

    assert expired == ("service-1",)
    assert record.status == ServiceStatus.UNAVAILABLE


def test_registry_can_unregister_service():
    registry = InstitutionalServiceRegistry()
    registry.register(build_service())
    registry.unregister("service-1")
    assert tuple(registry.records()) == ()


def test_health_report_counts_services():
    registry = InstitutionalServiceRegistry()
    registry.register(build_service())
    report = ServiceRegistryHealthMonitor().evaluate(registry)
    assert report.healthy is True
    assert report.total_services == 1
    assert report.available_services == 1


def test_health_report_detects_no_available_services():
    registry = InstitutionalServiceRegistry()
    registry.register(build_service())
    registry.set_status("service-1", ServiceStatus.UNAVAILABLE)
    report = ServiceRegistryHealthMonitor().evaluate(registry)
    assert report.healthy is False
'@

Write-TextFile -Path (Join-Path $PackageRoot "models.py") -Content $ModelsPy
Write-TextFile -Path (Join-Path $PackageRoot "versioning.py") -Content $VersioningPy
Write-TextFile -Path (Join-Path $PackageRoot "registry.py") -Content $RegistryPy
Write-TextFile -Path (Join-Path $PackageRoot "discovery.py") -Content $DiscoveryPy
Write-TextFile -Path (Join-Path $PackageRoot "health.py") -Content $HealthPy
Write-TextFile -Path (Join-Path $PackageRoot "__init__.py") -Content $InitPy
Write-TextFile -Path (Join-Path $TestsRoot "test_spt0205.py") -Content $TestsPy

$Config = [ordered]@{
    component = $Component
    version = $Version
    name = "Institutional Service Discovery and Registry"
    parent_component = "SPT-020"
    semantic_versioning = $true
    capability_discovery = $true
    heartbeat_support = $true
    stale_service_expiration = $true
    repository_is_source_of_truth = $true
    external_infrastructure_required = $false
    n8n_required = $false
    paid_services_required = $false
}

$ConfigPath = Join-Path $ConfigRoot "SPT-020.5-component.json"
Write-JsonFile -Path $ConfigPath -Data $Config

$Document = @"
# SGD-434 - Institutional Service Discovery and Registry

| Field | Value |
|---|---|
| Component | SPT-020.5 |
| Version | $Version |
| Parent | SPT-020 |
| Capability discovery | YES |
| Semantic versions | YES |
| Heartbeat | YES |
| Stale service expiration | YES |
| External infrastructure | NO |
| n8n | Not installed |
| Paid services | Not required |

SPT-020.5 provides institutional service registration, capability discovery,
version compatibility, endpoint cataloguing, heartbeat management, controlled
expiration and registry health monitoring.
"@

$DocumentPath = Join-Path $DocsRoot "SGD-434-Service-Discovery-Registry.md"
Write-TextFile -Path $DocumentPath -Content $Document

$env:PYTHONPATH = Join-Path $ProjectRoot "src"

Write-Step "Ejecutando pruebas especificas SPT-020.5"

$ComponentResult = Invoke-Pytest `
    -Targets @("tests/platform/service_discovery/test_spt0205.py") `
    -LogPath (Join-Path $RunRoot "pytest-spt0205.txt")

if (-not $ComponentResult.Passed) {
    throw "Las pruebas especificas de SPT-020.5 fallaron."
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
# ACT-020.5 - Institutional Service Discovery and Registry

| Field | Value |
|---|---|
| Component | SPT-020.5 |
| Version | $Version |
| Status | $ActStatus |
| Component tests | $($ComponentResult.Passed) |
| Python compile exit code | $CompileExitCode |
| Full suite passed | $FullSuitePassed |
| External infrastructure required | NO |
| n8n installed | NO |
| Paid services | NO |
"@

$ActPath = Join-Path $DocsRoot "ACT-020.5-Service-Discovery-Registry.md"
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
    -Destination (Join-Path $ReleaseRoot "SGD-434-Service-Discovery-Registry.md") `
    -Force

Copy-Item `
    -LiteralPath $ActPath `
    -Destination (Join-Path $ReleaseRoot "ACT-020.5-Service-Discovery-Registry.md") `
    -Force

Write-Step "Resultado final"

Write-Host "SPT-020.5 tests passed: $($ComponentResult.Passed)"
Write-Host "Python compile exit code: $CompileExitCode"
Write-Host "Full suite passed: $FullSuitePassed"
Write-Host "External infrastructure required: NO"
Write-Host "n8n installed: NO"
Write-Host "Paid services: NO"
Write-Host "Evidence: $EvidencePath" -ForegroundColor Cyan
Write-Host "Release: $ReleaseRoot" -ForegroundColor Cyan
Write-Host "Status: $Status" -ForegroundColor Cyan

if ($Approved) {
    Write-Host "SPT-020.5: CANDIDATE FOR INSTITUTIONAL CLOSURE." -ForegroundColor Green
}
else {
    Write-Host "SPT-020.5: CLOSURE BLOCKED." -ForegroundColor Red
    exit 1
}
