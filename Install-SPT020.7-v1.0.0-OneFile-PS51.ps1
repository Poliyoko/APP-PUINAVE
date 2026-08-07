<#
.SYNOPSIS
    SPT-020.7 - Institutional Health Monitor - One File Installer.

.DESCRIPTION
    Instala, valida y cierra institucionalmente el monitor integral de salud
    de la Plataforma Tecnologica SGODA-PUINAVE.

    Incluye:
      - contratos de controles de salud;
      - severidades y estados institucionales;
      - registro de proveedores de salud;
      - ejecucion agregada de controles;
      - umbrales y degradacion;
      - alertas institucionales;
      - snapshots e historial;
      - deteccion de controles duplicados;
      - tolerancia controlada a fallos;
      - resumen ejecutivo de salud;
      - pruebas especificas;
      - compilacion Python;
      - suite completa;
      - evidencia SHA-256;
      - acta definitiva;
      - release institucional;
      - cierre automatico cuando todos los gates son aprobados.

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
    .\Install-SPT020.7-v1.0.0-OneFile-PS51.ps1
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipFullSuite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Component = "SPT-020.7"
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

    $Json = $Data | ConvertTo-Json -Depth 50
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

$PackageRoot = Join-Path $ProjectRoot "src\sgoda\platform\health_monitor"
$TestsRoot = Join-Path $ProjectRoot "tests\platform\health_monitor"
$DocsRoot = Join-Path $ProjectRoot "docs\06_Tecnologia\SPT-020.7"
$RunRoot = Join-Path $ProjectRoot "artifacts\development\SPT-020.7-v1.0.0\runs\$RunId"
$ReleaseRoot = Join-Path $ProjectRoot "releases\SPT-020.7-v1.0.0"
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

Write-Step "Instalando Institutional Health Monitor"

$ModelsPy = @'
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import IntEnum, Enum
from typing import Any, Dict, Tuple


class HealthSeverity(IntEnum):
    INFO = 10
    WARNING = 20
    ERROR = 30
    CRITICAL = 40


class HealthStatus(str, Enum):
    HEALTHY = "HEALTHY"
    DEGRADED = "DEGRADED"
    UNHEALTHY = "UNHEALTHY"
    UNKNOWN = "UNKNOWN"


@dataclass(frozen=True)
class HealthCheckResult:
    check_id: str
    component_id: str
    healthy: bool
    severity: HealthSeverity = HealthSeverity.ERROR
    detail: str = ""
    metrics: Dict[str, Any] = field(default_factory=dict)
    checked_at_utc: str = field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )

    def __post_init__(self) -> None:
        if not self.check_id or not self.check_id.strip():
            raise ValueError("check_id is required")
        if not self.component_id or not self.component_id.strip():
            raise ValueError("component_id is required")

        object.__setattr__(self, "check_id", self.check_id.strip())
        object.__setattr__(self, "component_id", self.component_id.strip())
        object.__setattr__(self, "metrics", dict(self.metrics))


@dataclass(frozen=True)
class HealthAlert:
    check_id: str
    component_id: str
    severity: HealthSeverity
    detail: str


@dataclass(frozen=True)
class HealthSnapshot:
    status: HealthStatus
    healthy_checks: int
    degraded_checks: int
    failed_checks: int
    results: Tuple[HealthCheckResult, ...]
    alerts: Tuple[HealthAlert, ...]
    generated_at_utc: str = field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )
'@

$RegistryPy = @'
from dataclasses import dataclass
from typing import Callable, Dict, Iterable, Tuple


class HealthRegistryError(RuntimeError):
    pass


class DuplicateHealthCheckError(HealthRegistryError):
    pass


@dataclass(frozen=True)
class RegisteredHealthCheck:
    check_id: str
    component_id: str
    provider: Callable


class InstitutionalHealthRegistry:
    def __init__(self) -> None:
        self._checks: Dict[str, RegisteredHealthCheck] = {}

    def register(
        self,
        check_id: str,
        component_id: str,
        provider: Callable,
    ) -> RegisteredHealthCheck:
        if not check_id or not check_id.strip():
            raise ValueError("check_id is required")
        if not component_id or not component_id.strip():
            raise ValueError("component_id is required")
        if not callable(provider):
            raise ValueError("provider must be callable")
        if check_id in self._checks:
            raise DuplicateHealthCheckError(
                "health check already registered: {0}".format(check_id)
            )

        registered = RegisteredHealthCheck(
            check_id=check_id.strip(),
            component_id=component_id.strip(),
            provider=provider,
        )
        self._checks[registered.check_id] = registered
        return registered

    def unregister(self, check_id: str) -> None:
        self._checks.pop(check_id, None)

    def checks(self) -> Iterable[RegisteredHealthCheck]:
        return tuple(self._checks.values())

    def by_component(
        self,
        component_id: str,
    ) -> Tuple[RegisteredHealthCheck, ...]:
        return tuple(
            check
            for check in self._checks.values()
            if check.component_id == component_id
        )
'@

$MonitorPy = @'
from typing import Dict, List, Optional, Tuple

from .models import (
    HealthAlert,
    HealthCheckResult,
    HealthSeverity,
    HealthSnapshot,
    HealthStatus,
)
from .registry import InstitutionalHealthRegistry


class InstitutionalHealthMonitor:
    def __init__(
        self,
        registry: Optional[InstitutionalHealthRegistry] = None,
        degraded_threshold: int = 1,
        unhealthy_threshold: int = 1,
    ) -> None:
        if degraded_threshold < 1:
            raise ValueError("degraded_threshold must be at least 1")
        if unhealthy_threshold < 1:
            raise ValueError("unhealthy_threshold must be at least 1")

        self.registry = registry or InstitutionalHealthRegistry()
        self.degraded_threshold = degraded_threshold
        self.unhealthy_threshold = unhealthy_threshold
        self.history: List[HealthSnapshot] = []

    def register(
        self,
        check_id: str,
        component_id: str,
        provider,
    ):
        return self.registry.register(check_id, component_id, provider)

    def run(
        self,
        component_id: str = "",
    ) -> HealthSnapshot:
        checks = (
            self.registry.by_component(component_id)
            if component_id
            else tuple(self.registry.checks())
        )

        results = []
        alerts = []

        for check in checks:
            try:
                raw = check.provider()

                if isinstance(raw, HealthCheckResult):
                    result = raw
                elif isinstance(raw, bool):
                    result = HealthCheckResult(
                        check_id=check.check_id,
                        component_id=check.component_id,
                        healthy=raw,
                        detail="HEALTHY" if raw else "FAILED",
                    )
                elif isinstance(raw, dict):
                    result = HealthCheckResult(
                        check_id=check.check_id,
                        component_id=check.component_id,
                        healthy=bool(raw.get("healthy", False)),
                        severity=raw.get(
                            "severity",
                            HealthSeverity.ERROR,
                        ),
                        detail=str(raw.get("detail", "")),
                        metrics=dict(raw.get("metrics", {})),
                    )
                else:
                    raise TypeError(
                        "health provider returned unsupported value"
                    )
            except Exception as exc:
                result = HealthCheckResult(
                    check_id=check.check_id,
                    component_id=check.component_id,
                    healthy=False,
                    severity=HealthSeverity.CRITICAL,
                    detail=str(exc),
                )

            results.append(result)

            if not result.healthy:
                alerts.append(
                    HealthAlert(
                        check_id=result.check_id,
                        component_id=result.component_id,
                        severity=result.severity,
                        detail=result.detail,
                    )
                )

        failed = sum(1 for result in results if not result.healthy)
        degraded = sum(
            1
            for result in results
            if (
                not result.healthy
                and result.severity <= HealthSeverity.WARNING
            )
        )
        critical_failures = sum(
            1
            for result in results
            if (
                not result.healthy
                and result.severity >= HealthSeverity.ERROR
            )
        )
        healthy = sum(1 for result in results if result.healthy)

        if not results:
            status = HealthStatus.UNKNOWN
        elif critical_failures >= self.unhealthy_threshold:
            status = HealthStatus.UNHEALTHY
        elif degraded >= self.degraded_threshold or failed > 0:
            status = HealthStatus.DEGRADED
        else:
            status = HealthStatus.HEALTHY

        snapshot = HealthSnapshot(
            status=status,
            healthy_checks=healthy,
            degraded_checks=degraded,
            failed_checks=failed,
            results=tuple(results),
            alerts=tuple(alerts),
        )
        self.history.append(snapshot)
        return snapshot

    def latest(self) -> HealthSnapshot:
        if not self.history:
            raise RuntimeError("no health snapshot available")
        return self.history[-1]

    def component_summary(self) -> Dict[str, HealthStatus]:
        if not self.history:
            return {}

        latest = self.history[-1]
        grouped = {}

        for result in latest.results:
            current = grouped.get(
                result.component_id,
                HealthStatus.HEALTHY,
            )

            if not result.healthy:
                if result.severity >= HealthSeverity.ERROR:
                    grouped[result.component_id] = HealthStatus.UNHEALTHY
                elif current != HealthStatus.UNHEALTHY:
                    grouped[result.component_id] = HealthStatus.DEGRADED
            else:
                grouped.setdefault(
                    result.component_id,
                    HealthStatus.HEALTHY,
                )

        return grouped
'@

$AdaptersPy = @'
from typing import Any, Callable, Dict

from .models import HealthCheckResult, HealthSeverity


def boolean_health_adapter(
    check_id: str,
    component_id: str,
    provider: Callable[[], bool],
    failure_detail: str = "health check failed",
):
    def check() -> HealthCheckResult:
        healthy = bool(provider())
        return HealthCheckResult(
            check_id=check_id,
            component_id=component_id,
            healthy=healthy,
            severity=HealthSeverity.ERROR,
            detail="HEALTHY" if healthy else failure_detail,
        )

    return check


def metric_threshold_adapter(
    check_id: str,
    component_id: str,
    provider: Callable[[], float],
    maximum: float,
    metric_name: str,
):
    def check() -> HealthCheckResult:
        value = float(provider())
        healthy = value <= maximum
        return HealthCheckResult(
            check_id=check_id,
            component_id=component_id,
            healthy=healthy,
            severity=HealthSeverity.WARNING,
            detail=(
                "WITHIN_THRESHOLD"
                if healthy
                else "THRESHOLD_EXCEEDED"
            ),
            metrics={
                metric_name: value,
                "maximum": maximum,
            },
        )

    return check
'@

$ReporterPy = @'
from dataclasses import asdict
from typing import Dict

from .models import HealthSnapshot


class InstitutionalHealthReporter:
    def to_dict(self, snapshot: HealthSnapshot) -> Dict:
        return {
            "status": snapshot.status.value,
            "healthy_checks": snapshot.healthy_checks,
            "degraded_checks": snapshot.degraded_checks,
            "failed_checks": snapshot.failed_checks,
            "results": [
                {
                    **asdict(result),
                    "severity": result.severity.name,
                }
                for result in snapshot.results
            ],
            "alerts": [
                {
                    **asdict(alert),
                    "severity": alert.severity.name,
                }
                for alert in snapshot.alerts
            ],
            "generated_at_utc": snapshot.generated_at_utc,
        }
'@

$InitPy = @'
from .adapters import boolean_health_adapter, metric_threshold_adapter
from .models import (
    HealthAlert,
    HealthCheckResult,
    HealthSeverity,
    HealthSnapshot,
    HealthStatus,
)
from .monitor import InstitutionalHealthMonitor
from .registry import (
    DuplicateHealthCheckError,
    HealthRegistryError,
    InstitutionalHealthRegistry,
    RegisteredHealthCheck,
)
from .reporter import InstitutionalHealthReporter

__all__ = [
    "DuplicateHealthCheckError",
    "HealthAlert",
    "HealthCheckResult",
    "HealthRegistryError",
    "HealthSeverity",
    "HealthSnapshot",
    "HealthStatus",
    "InstitutionalHealthMonitor",
    "InstitutionalHealthRegistry",
    "InstitutionalHealthReporter",
    "RegisteredHealthCheck",
    "boolean_health_adapter",
    "metric_threshold_adapter",
]
'@

$TestsPy = @'
import pytest

from sgoda.platform.health_monitor import (
    DuplicateHealthCheckError,
    HealthCheckResult,
    HealthSeverity,
    HealthStatus,
    InstitutionalHealthMonitor,
    InstitutionalHealthReporter,
    boolean_health_adapter,
    metric_threshold_adapter,
)


def test_health_check_requires_identity():
    with pytest.raises(ValueError):
        HealthCheckResult("", "SPT-020.1", True)


def test_monitor_registers_and_runs_boolean_check():
    monitor = InstitutionalHealthMonitor()
    monitor.register("service-bus", "SPT-020.1", lambda: True)
    snapshot = monitor.run()
    assert snapshot.status == HealthStatus.HEALTHY
    assert snapshot.healthy_checks == 1


def test_duplicate_check_is_rejected():
    monitor = InstitutionalHealthMonitor()
    monitor.register("check", "component", lambda: True)

    with pytest.raises(DuplicateHealthCheckError):
        monitor.register("check", "component", lambda: True)


def test_warning_failure_degrades_platform():
    monitor = InstitutionalHealthMonitor()
    monitor.register(
        "latency",
        "SPT-020.1",
        lambda: {
            "healthy": False,
            "severity": HealthSeverity.WARNING,
            "detail": "slow",
        },
    )
    snapshot = monitor.run()
    assert snapshot.status == HealthStatus.DEGRADED
    assert snapshot.degraded_checks == 1


def test_error_failure_marks_platform_unhealthy():
    monitor = InstitutionalHealthMonitor()
    monitor.register(
        "runtime",
        "SPT-020.6",
        lambda: {
            "healthy": False,
            "severity": HealthSeverity.ERROR,
            "detail": "failed",
        },
    )
    snapshot = monitor.run()
    assert snapshot.status == HealthStatus.UNHEALTHY
    assert snapshot.failed_checks == 1


def test_provider_exception_becomes_critical_alert():
    monitor = InstitutionalHealthMonitor()

    def failing():
        raise RuntimeError("provider failure")

    monitor.register("provider", "SPT-020.5", failing)
    snapshot = monitor.run()
    assert snapshot.status == HealthStatus.UNHEALTHY
    assert snapshot.alerts[0].severity == HealthSeverity.CRITICAL
    assert snapshot.alerts[0].detail == "provider failure"


def test_monitor_accepts_health_result():
    monitor = InstitutionalHealthMonitor()
    monitor.register(
        "custom",
        "SPT-020.4",
        lambda: HealthCheckResult(
            "custom",
            "SPT-020.4",
            True,
            metrics={"events": 10},
        ),
    )
    snapshot = monitor.run()
    assert snapshot.results[0].metrics["events"] == 10


def test_component_filter_runs_only_requested_checks():
    monitor = InstitutionalHealthMonitor()
    monitor.register("a", "SPT-A", lambda: True)
    monitor.register("b", "SPT-B", lambda: True)
    snapshot = monitor.run(component_id="SPT-B")
    assert len(snapshot.results) == 1
    assert snapshot.results[0].component_id == "SPT-B"


def test_empty_monitor_reports_unknown():
    snapshot = InstitutionalHealthMonitor().run()
    assert snapshot.status == HealthStatus.UNKNOWN


def test_latest_returns_last_snapshot():
    monitor = InstitutionalHealthMonitor()
    monitor.register("check", "SPT-020.1", lambda: True)
    first = monitor.run()
    second = monitor.run()
    assert monitor.latest() is second
    assert monitor.latest() is not first


def test_latest_without_history_is_blocked():
    with pytest.raises(RuntimeError):
        InstitutionalHealthMonitor().latest()


def test_component_summary_reports_states():
    monitor = InstitutionalHealthMonitor()
    monitor.register("healthy", "SPT-A", lambda: True)
    monitor.register(
        "warning",
        "SPT-B",
        lambda: {
            "healthy": False,
            "severity": HealthSeverity.WARNING,
        },
    )
    monitor.run()
    summary = monitor.component_summary()
    assert summary["SPT-A"] == HealthStatus.HEALTHY
    assert summary["SPT-B"] == HealthStatus.DEGRADED


def test_boolean_adapter_creates_health_result():
    check = boolean_health_adapter(
        "bus",
        "SPT-020.1",
        lambda: True,
    )
    result = check()
    assert result.healthy is True
    assert result.check_id == "bus"


def test_metric_threshold_adapter_approves_value():
    check = metric_threshold_adapter(
        "latency",
        "SPT-020.4",
        lambda: 10,
        maximum=20,
        metric_name="latency_ms",
    )
    result = check()
    assert result.healthy is True
    assert result.metrics["latency_ms"] == 10.0


def test_metric_threshold_adapter_detects_excess():
    check = metric_threshold_adapter(
        "latency",
        "SPT-020.4",
        lambda: 30,
        maximum=20,
        metric_name="latency_ms",
    )
    result = check()
    assert result.healthy is False
    assert result.severity == HealthSeverity.WARNING


def test_reporter_serializes_snapshot():
    monitor = InstitutionalHealthMonitor()
    monitor.register("check", "SPT-020.1", lambda: True)
    snapshot = monitor.run()
    report = InstitutionalHealthReporter().to_dict(snapshot)
    assert report["status"] == "HEALTHY"
    assert report["healthy_checks"] == 1


def test_history_preserves_snapshots():
    monitor = InstitutionalHealthMonitor()
    monitor.register("check", "SPT-020.1", lambda: True)
    monitor.run()
    monitor.run()
    assert len(monitor.history) == 2


def test_unregister_removes_check():
    monitor = InstitutionalHealthMonitor()
    monitor.register("check", "SPT-020.1", lambda: True)
    monitor.registry.unregister("check")
    assert monitor.run().status == HealthStatus.UNKNOWN
'@

Write-TextFile -Path (Join-Path $PackageRoot "models.py") -Content $ModelsPy
Write-TextFile -Path (Join-Path $PackageRoot "registry.py") -Content $RegistryPy
Write-TextFile -Path (Join-Path $PackageRoot "monitor.py") -Content $MonitorPy
Write-TextFile -Path (Join-Path $PackageRoot "adapters.py") -Content $AdaptersPy
Write-TextFile -Path (Join-Path $PackageRoot "reporter.py") -Content $ReporterPy
Write-TextFile -Path (Join-Path $PackageRoot "__init__.py") -Content $InitPy
Write-TextFile -Path (Join-Path $TestsRoot "test_spt0207.py") -Content $TestsPy

$Config = [ordered]@{
    component = $Component
    version = $Version
    name = "Institutional Health Monitor"
    parent_component = "SPT-020"
    aggregate_monitoring = $true
    severity_model = $true
    alerts = $true
    snapshots = $true
    threshold_adapters = $true
    automatic_closure = $true
    repository_is_source_of_truth = $true
    external_infrastructure_required = $false
    n8n_required = $false
    paid_services_required = $false
}

$ConfigPath = Join-Path $ConfigRoot "SPT-020.7-component.json"
Write-JsonFile -Path $ConfigPath -Data $Config

$Document = @"
# SGD-436 - Institutional Health Monitor

| Field | Value |
|---|---|
| Component | SPT-020.7 |
| Version | $Version |
| Parent | SPT-020 |
| Aggregate monitoring | YES |
| Severity model | YES |
| Institutional alerts | YES |
| Snapshots and history | YES |
| Threshold adapters | YES |
| Automatic closure | YES |
| External infrastructure | NO |
| n8n | Not installed |
| Paid services | Not required |

SPT-020.7 consolidates health checks from the technological platform,
classifies HEALTHY, DEGRADED, UNHEALTHY and UNKNOWN states, generates alerts,
preserves snapshots and provides institutional health summaries.
"@

$DocumentPath = Join-Path $DocsRoot "SGD-436-Institutional-Health-Monitor.md"
Write-TextFile -Path $DocumentPath -Content $Document

$env:PYTHONPATH = Join-Path $ProjectRoot "src"

Write-Step "Ejecutando pruebas especificas SPT-020.7"

$ComponentResult = Invoke-Pytest `
    -Targets @("tests/platform/health_monitor/test_spt0207.py") `
    -LogPath (Join-Path $RunRoot "pytest-spt0207.txt")

if (-not $ComponentResult.Passed) {
    throw "Las pruebas especificas de SPT-020.7 fallaron."
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

$TechnicalErrors = 0

if (-not $ComponentResult.Passed) {
    $TechnicalErrors++
}

if ($CompileExitCode -ne 0) {
    $TechnicalErrors++
}

if (-not $FullSuiteRequested -or -not $FullSuitePassed) {
    $TechnicalErrors++
}

$Closed = ($TechnicalErrors -eq 0)

$Status = if ($Closed) {
    "CLOSED"
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
    closed = $Closed
    component_tests_passed = $ComponentResult.Passed
    python_compile_exit_code = $CompileExitCode
    full_suite_requested = $FullSuiteRequested
    full_suite_passed = $FullSuitePassed
    full_suite_exit_code = $FullSuiteExitCode
    technical_errors = $TechnicalErrors
    repository_is_source_of_truth = $true
    external_infrastructure_required = $false
    n8n_installed = $false
    paid_services_required = $false
    files = $FileRecords
}

$EvidencePath = Join-Path $RunRoot "implementation-evidence.json"
Write-JsonFile -Path $EvidencePath -Data $Evidence

$ActStatus = if ($Closed) {
    "CLOSED - INSTITUTIONAL IMPLEMENTATION APPROVED"
}
else {
    "NOT CLOSED"
}

$Act = @"
# ACT-020.7 - Institutional Health Monitor Closure Act

| Field | Value |
|---|---|
| Component | SPT-020.7 |
| Version | $Version |
| Status | $ActStatus |
| Component tests | $($ComponentResult.Passed) |
| Python compile exit code | $CompileExitCode |
| Full suite passed | $FullSuitePassed |
| Technical errors | $TechnicalErrors |
| External infrastructure required | NO |
| n8n installed | NO |
| Paid services | NO |

SPT-020.7 is institutionally closed only when all technical gates pass and
the technical error count is zero.
"@

$ActPath = Join-Path $DocsRoot "ACT-020.7-Cierre-Institutional-Health-Monitor.md"
Write-TextFile -Path $ActPath -Content $Act

$Manifest = [ordered]@{
    component = $Component
    version = $Version
    status = $Status
    closed = $Closed
    technical_errors = $TechnicalErrors
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
    -Destination (Join-Path $ReleaseRoot "SGD-436-Institutional-Health-Monitor.md") `
    -Force

Copy-Item `
    -LiteralPath $ActPath `
    -Destination (Join-Path $ReleaseRoot "ACT-020.7-Cierre-Institutional-Health-Monitor.md") `
    -Force

Write-Step "Resultado final"

Write-Host "SPT-020.7 tests passed: $($ComponentResult.Passed)"
Write-Host "Python compile exit code: $CompileExitCode"
Write-Host "Full suite passed: $FullSuitePassed"
Write-Host "Technical errors: $TechnicalErrors"
Write-Host "External infrastructure required: NO"
Write-Host "n8n installed: NO"
Write-Host "Paid services: NO"
Write-Host "Evidence: $EvidencePath" -ForegroundColor Cyan
Write-Host "Act: $ActPath" -ForegroundColor Cyan
Write-Host "Release: $ReleaseRoot" -ForegroundColor Cyan
Write-Host "Institutional status: $Status" -ForegroundColor Cyan

if ($Closed) {
    Write-Host "SPT-020.7: CLOSED WITH ZERO TECHNICAL ERRORS." -ForegroundColor Green
}
else {
    Write-Host "SPT-020.7: CLOSURE BLOCKED." -ForegroundColor Red
    exit 1
}
