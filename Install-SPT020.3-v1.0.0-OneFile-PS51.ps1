<#
.SYNOPSIS
    SPT-020.3 - Institutional Component Dependency Manager - One File Installer.

.DESCRIPTION
    Instala y valida el administrador institucional de dependencias de
    componentes de SGODA-PUINAVE.

    Incluye:
      - contratos de dependencias;
      - restricciones de versiones;
      - registro de componentes;
      - deteccion de dependencias faltantes;
      - deteccion de ciclos;
      - orden topologico de instalacion;
      - validacion de compatibilidad;
      - impacto de dependientes;
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
    .\Install-SPT020.3-v1.0.0-OneFile-PS51.ps1
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipFullSuite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Component = "SPT-020.3"
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

$PackageRoot = Join-Path $ProjectRoot "src\sgoda\platform\dependencies"
$TestsRoot = Join-Path $ProjectRoot "tests\platform\dependencies"
$DocsRoot = Join-Path $ProjectRoot "docs\06_Tecnologia\SPT-020.3"
$RunRoot = Join-Path $ProjectRoot "artifacts\development\SPT-020.3-v1.0.0\runs\$RunId"
$ReleaseRoot = Join-Path $ProjectRoot "releases\SPT-020.3-v1.0.0"
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

Write-Step "Instalando Institutional Component Dependency Manager"

$ModelsPy = @'
from dataclasses import dataclass, field
from typing import Dict, Tuple


@dataclass(frozen=True)
class DependencyRequirement:
    component_id: str
    minimum_version: str = "0.0.0"
    maximum_version: str = ""

    def __post_init__(self) -> None:
        if not self.component_id or not self.component_id.strip():
            raise ValueError("component_id is required")
        object.__setattr__(self, "component_id", self.component_id.strip())


@dataclass(frozen=True)
class DependencyComponent:
    component_id: str
    version: str
    dependencies: Tuple[DependencyRequirement, ...] = ()
    metadata: Dict[str, str] = field(default_factory=dict)

    def __post_init__(self) -> None:
        if not self.component_id or not self.component_id.strip():
            raise ValueError("component_id is required")
        if not self.version or not self.version.strip():
            raise ValueError("version is required")
        object.__setattr__(self, "component_id", self.component_id.strip())
        object.__setattr__(self, "version", self.version.strip())
        object.__setattr__(self, "dependencies", tuple(self.dependencies))
        object.__setattr__(self, "metadata", dict(self.metadata))
'@

$VersioningPy = @'
from typing import Tuple


class InvalidVersionError(ValueError):
    pass


def parse_version(value: str) -> Tuple[int, int, int]:
    parts = value.strip().split(".")
    if len(parts) != 3 or not all(part.isdigit() for part in parts):
        raise InvalidVersionError(
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

    if maximum:
        maximum_value = parse_version(maximum)
        if current_value > maximum_value:
            return False

    return True
'@

$RegistryPy = @'
from typing import Dict, Iterable

from .models import DependencyComponent


class DependencyRegistryError(RuntimeError):
    pass


class ComponentDependencyRegistry:
    def __init__(self) -> None:
        self._components: Dict[str, DependencyComponent] = {}

    def register(self, component: DependencyComponent) -> None:
        if component.component_id in self._components:
            raise DependencyRegistryError(
                "component already registered: {0}".format(
                    component.component_id
                )
            )
        self._components[component.component_id] = component

    def get(self, component_id: str) -> DependencyComponent:
        try:
            return self._components[component_id]
        except KeyError as exc:
            raise DependencyRegistryError(
                "component not registered: {0}".format(component_id)
            ) from exc

    def exists(self, component_id: str) -> bool:
        return component_id in self._components

    def components(self) -> Iterable[DependencyComponent]:
        return tuple(self._components.values())
'@

$ManagerPy = @'
from typing import Dict, List, Set, Tuple

from .models import DependencyComponent
from .registry import ComponentDependencyRegistry
from .versioning import is_compatible


class MissingDependencyError(RuntimeError):
    pass


class DependencyCycleError(RuntimeError):
    pass


class DependencyCompatibilityError(RuntimeError):
    pass


class InstitutionalComponentDependencyManager:
    def __init__(
        self,
        registry: ComponentDependencyRegistry = None,
    ) -> None:
        self.registry = registry or ComponentDependencyRegistry()

    def register(self, component: DependencyComponent) -> None:
        self.registry.register(component)

    def validate_component(self, component_id: str) -> None:
        component = self.registry.get(component_id)

        for requirement in component.dependencies:
            if not self.registry.exists(requirement.component_id):
                raise MissingDependencyError(
                    "missing dependency: {0}".format(
                        requirement.component_id
                    )
                )

            installed = self.registry.get(requirement.component_id)
            if not is_compatible(
                installed.version,
                requirement.minimum_version,
                requirement.maximum_version,
            ):
                raise DependencyCompatibilityError(
                    "incompatible dependency {0}: {1}".format(
                        installed.component_id,
                        installed.version,
                    )
                )

        self._assert_no_cycles()

    def validate_all(self) -> None:
        for component in self.registry.components():
            self.validate_component(component.component_id)

    def installation_order(self) -> Tuple[str, ...]:
        self.validate_all()

        visiting: Set[str] = set()
        visited: Set[str] = set()
        ordered: List[str] = []

        def visit(component_id: str) -> None:
            if component_id in visited:
                return
            if component_id in visiting:
                raise DependencyCycleError(
                    "dependency cycle detected at {0}".format(component_id)
                )

            visiting.add(component_id)
            component = self.registry.get(component_id)

            for requirement in component.dependencies:
                visit(requirement.component_id)

            visiting.remove(component_id)
            visited.add(component_id)
            ordered.append(component_id)

        for component in self.registry.components():
            visit(component.component_id)

        return tuple(ordered)

    def dependents_of(self, component_id: str) -> Tuple[str, ...]:
        dependents = []

        for component in self.registry.components():
            if any(
                dependency.component_id == component_id
                for dependency in component.dependencies
            ):
                dependents.append(component.component_id)

        return tuple(sorted(dependents))

    def _assert_no_cycles(self) -> None:
        visiting: Set[str] = set()
        visited: Set[str] = set()

        def visit(component_id: str) -> None:
            if component_id in visited:
                return
            if component_id in visiting:
                raise DependencyCycleError(
                    "dependency cycle detected at {0}".format(component_id)
                )

            visiting.add(component_id)
            component = self.registry.get(component_id)

            for requirement in component.dependencies:
                if self.registry.exists(requirement.component_id):
                    visit(requirement.component_id)

            visiting.remove(component_id)
            visited.add(component_id)

        for component in self.registry.components():
            visit(component.component_id)
'@

$HealthPy = @'
from dataclasses import dataclass
from typing import Tuple

from .manager import InstitutionalComponentDependencyManager


@dataclass(frozen=True)
class DependencyHealthItem:
    component_id: str
    valid: bool


@dataclass(frozen=True)
class DependencyHealthReport:
    healthy: bool
    components: Tuple[DependencyHealthItem, ...]


class DependencyHealthMonitor:
    def evaluate(
        self,
        manager: InstitutionalComponentDependencyManager,
    ) -> DependencyHealthReport:
        items = []

        for component in manager.registry.components():
            valid = True
            try:
                manager.validate_component(component.component_id)
            except RuntimeError:
                valid = False

            items.append(
                DependencyHealthItem(
                    component_id=component.component_id,
                    valid=valid,
                )
            )

        return DependencyHealthReport(
            healthy=all(item.valid for item in items),
            components=tuple(items),
        )
'@

$InitPy = @'
from .health import (
    DependencyHealthItem,
    DependencyHealthMonitor,
    DependencyHealthReport,
)
from .manager import (
    DependencyCompatibilityError,
    DependencyCycleError,
    InstitutionalComponentDependencyManager,
    MissingDependencyError,
)
from .models import DependencyComponent, DependencyRequirement
from .registry import ComponentDependencyRegistry, DependencyRegistryError
from .versioning import InvalidVersionError, is_compatible, parse_version

__all__ = [
    "ComponentDependencyRegistry",
    "DependencyCompatibilityError",
    "DependencyComponent",
    "DependencyCycleError",
    "DependencyHealthItem",
    "DependencyHealthMonitor",
    "DependencyHealthReport",
    "DependencyRegistryError",
    "DependencyRequirement",
    "InstitutionalComponentDependencyManager",
    "InvalidVersionError",
    "MissingDependencyError",
    "is_compatible",
    "parse_version",
]
'@

$TestsPy = @'
import pytest

from sgoda.platform.dependencies import (
    ComponentDependencyRegistry,
    DependencyCompatibilityError,
    DependencyComponent,
    DependencyCycleError,
    DependencyHealthMonitor,
    DependencyRegistryError,
    DependencyRequirement,
    InstitutionalComponentDependencyManager,
    InvalidVersionError,
    MissingDependencyError,
    is_compatible,
    parse_version,
)


def test_parse_semantic_version():
    assert parse_version("1.2.3") == (1, 2, 3)


def test_invalid_version_is_rejected():
    with pytest.raises(InvalidVersionError):
        parse_version("1.2")


def test_version_compatibility_range():
    assert is_compatible("1.5.0", "1.0.0", "2.0.0") is True
    assert is_compatible("2.1.0", "1.0.0", "2.0.0") is False


def test_registry_rejects_duplicate():
    registry = ComponentDependencyRegistry()
    component = DependencyComponent("SPT-A", "1.0.0")
    registry.register(component)

    with pytest.raises(DependencyRegistryError):
        registry.register(component)


def test_missing_dependency_is_detected():
    manager = InstitutionalComponentDependencyManager()
    manager.register(
        DependencyComponent(
            "SPT-B",
            "1.0.0",
            dependencies=(DependencyRequirement("SPT-A"),),
        )
    )

    with pytest.raises(MissingDependencyError):
        manager.validate_component("SPT-B")


def test_incompatible_dependency_is_detected():
    manager = InstitutionalComponentDependencyManager()
    manager.register(DependencyComponent("SPT-A", "1.0.0"))
    manager.register(
        DependencyComponent(
            "SPT-B",
            "1.0.0",
            dependencies=(
                DependencyRequirement(
                    "SPT-A",
                    minimum_version="2.0.0",
                ),
            ),
        )
    )

    with pytest.raises(DependencyCompatibilityError):
        manager.validate_component("SPT-B")


def test_valid_dependency_is_approved():
    manager = InstitutionalComponentDependencyManager()
    manager.register(DependencyComponent("SPT-A", "1.2.0"))
    manager.register(
        DependencyComponent(
            "SPT-B",
            "1.0.0",
            dependencies=(
                DependencyRequirement(
                    "SPT-A",
                    minimum_version="1.0.0",
                    maximum_version="2.0.0",
                ),
            ),
        )
    )
    manager.validate_component("SPT-B")


def test_installation_order_places_dependencies_first():
    manager = InstitutionalComponentDependencyManager()
    manager.register(DependencyComponent("SPT-A", "1.0.0"))
    manager.register(
        DependencyComponent(
            "SPT-B",
            "1.0.0",
            dependencies=(DependencyRequirement("SPT-A"),),
        )
    )
    assert manager.installation_order() == ("SPT-A", "SPT-B")


def test_cycle_is_detected():
    manager = InstitutionalComponentDependencyManager()
    manager.register(
        DependencyComponent(
            "SPT-A",
            "1.0.0",
            dependencies=(DependencyRequirement("SPT-B"),),
        )
    )
    manager.register(
        DependencyComponent(
            "SPT-B",
            "1.0.0",
            dependencies=(DependencyRequirement("SPT-A"),),
        )
    )

    with pytest.raises(DependencyCycleError):
        manager.validate_all()


def test_dependents_are_reported():
    manager = InstitutionalComponentDependencyManager()
    manager.register(DependencyComponent("SPT-A", "1.0.0"))
    manager.register(
        DependencyComponent(
            "SPT-B",
            "1.0.0",
            dependencies=(DependencyRequirement("SPT-A"),),
        )
    )
    manager.register(
        DependencyComponent(
            "SPT-C",
            "1.0.0",
            dependencies=(DependencyRequirement("SPT-A"),),
        )
    )
    assert manager.dependents_of("SPT-A") == ("SPT-B", "SPT-C")


def test_validate_all_approves_valid_graph():
    manager = InstitutionalComponentDependencyManager()
    manager.register(DependencyComponent("SPT-A", "1.0.0"))
    manager.register(
        DependencyComponent(
            "SPT-B",
            "1.0.0",
            dependencies=(DependencyRequirement("SPT-A"),),
        )
    )
    manager.validate_all()


def test_health_monitor_reports_valid_graph():
    manager = InstitutionalComponentDependencyManager()
    manager.register(DependencyComponent("SPT-A", "1.0.0"))
    report = DependencyHealthMonitor().evaluate(manager)
    assert report.healthy is True
    assert report.components[0].component_id == "SPT-A"
'@

Write-TextFile -Path (Join-Path $PackageRoot "models.py") -Content $ModelsPy
Write-TextFile -Path (Join-Path $PackageRoot "versioning.py") -Content $VersioningPy
Write-TextFile -Path (Join-Path $PackageRoot "registry.py") -Content $RegistryPy
Write-TextFile -Path (Join-Path $PackageRoot "manager.py") -Content $ManagerPy
Write-TextFile -Path (Join-Path $PackageRoot "health.py") -Content $HealthPy
Write-TextFile -Path (Join-Path $PackageRoot "__init__.py") -Content $InitPy
Write-TextFile -Path (Join-Path $TestsRoot "test_spt0203.py") -Content $TestsPy

$Config = [ordered]@{
    component = $Component
    version = $Version
    name = "Institutional Component Dependency Manager"
    parent_component = "SPT-020"
    semantic_versioning = $true
    cycle_detection = $true
    topological_order = $true
    repository_is_source_of_truth = $true
    external_service_required = $false
    n8n_required = $false
    paid_services_required = $false
}

$ConfigPath = Join-Path $ConfigRoot "SPT-020.3-component.json"
Write-JsonFile -Path $ConfigPath -Data $Config

$Document = @"
# SGD-432 - Institutional Component Dependency Manager

| Field | Value |
|---|---|
| Component | SPT-020.3 |
| Version | $Version |
| Parent | SPT-020 |
| Semantic versions | YES |
| Cycle detection | YES |
| Topological order | YES |
| External service | NO |
| n8n | Not installed |
| Paid services | Not required |

SPT-020.3 validates component dependency graphs, version compatibility,
missing dependencies, cycles, installation order and dependent impact.
"@

$DocumentPath = Join-Path $DocsRoot "SGD-432-Component-Dependency-Manager.md"
Write-TextFile -Path $DocumentPath -Content $Document

$env:PYTHONPATH = Join-Path $ProjectRoot "src"

Write-Step "Ejecutando pruebas especificas SPT-020.3"

$ComponentResult = Invoke-Pytest `
    -Targets @("tests/platform/dependencies/test_spt0203.py") `
    -LogPath (Join-Path $RunRoot "pytest-spt0203.txt")

if (-not $ComponentResult.Passed) {
    throw "Las pruebas especificas de SPT-020.3 fallaron."
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
# ACT-020.3 - Institutional Component Dependency Manager

| Field | Value |
|---|---|
| Component | SPT-020.3 |
| Version | $Version |
| Status | $ActStatus |
| Component tests | $($ComponentResult.Passed) |
| Python compile exit code | $CompileExitCode |
| Full suite passed | $FullSuitePassed |
| External service required | NO |
| n8n installed | NO |
| Paid services | NO |
"@

$ActPath = Join-Path $DocsRoot "ACT-020.3-Component-Dependency-Manager.md"
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
    -Destination (Join-Path $ReleaseRoot "SGD-432-Component-Dependency-Manager.md") `
    -Force

Copy-Item `
    -LiteralPath $ActPath `
    -Destination (Join-Path $ReleaseRoot "ACT-020.3-Component-Dependency-Manager.md") `
    -Force

Write-Step "Resultado final"

Write-Host "SPT-020.3 tests passed: $($ComponentResult.Passed)"
Write-Host "Python compile exit code: $CompileExitCode"
Write-Host "Full suite passed: $FullSuitePassed"
Write-Host "External service required: NO"
Write-Host "n8n installed: NO"
Write-Host "Paid services: NO"
Write-Host "Evidence: $EvidencePath" -ForegroundColor Cyan
Write-Host "Release: $ReleaseRoot" -ForegroundColor Cyan
Write-Host "Status: $Status" -ForegroundColor Cyan

if ($Approved) {
    Write-Host "SPT-020.3: CANDIDATE FOR INSTITUTIONAL CLOSURE." -ForegroundColor Green
}
else {
    Write-Host "SPT-020.3: CLOSURE BLOCKED." -ForegroundColor Red
    exit 1
}
