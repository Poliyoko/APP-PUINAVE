<#
.SYNOPSIS
    Instala y valida SPT-019.3 A-D para SGODA-PUINAVE.

.DESCRIPTION
    Implementa secuencialmente:
      SPT-019.3A - Orquestador institucional y carga de componentes.
      SPT-019.3B - Integracion con PMO Digital y Auditor Institucional.
      SPT-019.3C - Eventos, trazabilidad y evidencias.
      SPT-019.3D - Quality Gates, pruebas finales y paquete de cierre.

    Compatible con Windows PowerShell 5.1.
    Solo usa PowerShell, Python y pytest.
    No instala n8n y no usa servicios de pago.

.PARAMETER ProjectRoot
    Raiz del repositorio. Por defecto: carpeta actual.

.PARAMETER SkipFullSuite
    Omite la suite completa del repositorio. Las pruebas A-D siempre se ejecutan.

.EXAMPLE
    Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
    .\Install-SPT019.3-v1.0.1-PS51.ps1
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipFullSuite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Component = "SPT-019.3"
$Version = "1.0.1"
$RunId = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
$GeneratedUtc = (Get-Date).ToUniversalTime().ToString("o")

function Write-Step {
    param([string]$Text)
    Write-Host ""
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Write-AsciiFile {
    param(
        [string]$Path,
        [string]$Content
    )

    $Parent = Split-Path -Parent $Path
    if ($Parent -and -not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.Encoding]::ASCII
    )
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Data
    )

    $Json = $Data | ConvertTo-Json -Depth 20
    Write-AsciiFile -Path $Path -Content ($Json + "`r`n")
}

function Backup-Target {
    param(
        [string]$Target,
        [string]$BackupRoot,
        [string]$Root
    )

    if (Test-Path -LiteralPath $Target -PathType Leaf) {
        $Relative = $Target.Substring($Root.Length).TrimStart("\")
        $Destination = Join-Path $BackupRoot $Relative
        $DestinationParent = Split-Path -Parent $Destination

        if (-not (Test-Path -LiteralPath $DestinationParent)) {
            New-Item -ItemType Directory -Path $DestinationParent -Force | Out-Null
        }

        Copy-Item -LiteralPath $Target -Destination $Destination -Force
    }
}

function Invoke-PytestGate {
    param(
        [string]$GateName,
        [string[]]$Targets,
        [string]$LogPath
    )

    Write-Step "Ejecutando quality gate $GateName"

    $Arguments = @("-m", "pytest", "-q")
    foreach ($Target in $Targets) {
        $Arguments += $Target
    }

    $Output = & python @Arguments 2>&1
    $ExitCode = $LASTEXITCODE

    Write-AsciiFile -Path $LogPath -Content (($Output -join "`r`n") + "`r`n")
    $Output | ForEach-Object { Write-Host $_ }

    if ($ExitCode -ne 0) {
        throw "Quality gate $GateName fallo. Revise: $LogPath"
    }

    Write-Host "Quality gate ${GateName}: APROBADO." -ForegroundColor Green
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot

foreach ($Required in @("src", "tests", "docs", "artifacts", "releases")) {
    if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot $Required) -PathType Container)) {
        throw "Falta la carpeta obligatoria: $Required"
    }
}

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    throw "Python no esta disponible."
}

$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$PackageRoot = Join-Path $ProjectRoot "src\sgoda\workflows\spt0193"
$TestsRoot = Join-Path $ProjectRoot "tests\workflows\spt0193"
$DocsRoot = Join-Path $ProjectRoot "docs\06_Tecnologia\SPT-019.3"
$ArtifactsRoot = Join-Path $ProjectRoot "artifacts\development\SPT-019.3-v1.0.1"
$RunRoot = Join-Path $ArtifactsRoot "runs\$RunId"
$BackupRoot = Join-Path $RunRoot "backup"
$ReleaseRoot = Join-Path $ProjectRoot "releases\SPT-019.3-v1.0.1"

foreach ($Directory in @($PackageRoot, $TestsRoot, $DocsRoot, $RunRoot, $BackupRoot, $ReleaseRoot)) {
    New-Item -ItemType Directory -Path $Directory -Force | Out-Null
}

$ParentPackage = Split-Path -Parent $PackageRoot
$ParentInit = Join-Path $ParentPackage "__init__.py"
if (-not (Test-Path -LiteralPath $ParentInit)) {
    Write-AsciiFile -Path $ParentInit -Content ""
}

$TargetFiles = @(
    (Join-Path $PackageRoot "__init__.py"),
    (Join-Path $PackageRoot "components.py"),
    (Join-Path $PackageRoot "orchestrator.py"),
    (Join-Path $PackageRoot "institutional_integration.py"),
    (Join-Path $PackageRoot "events.py"),
    (Join-Path $PackageRoot "traceability.py"),
    (Join-Path $PackageRoot "evidence.py"),
    (Join-Path $PackageRoot "quality.py"),
    (Join-Path $TestsRoot "test_spt0193a.py"),
    (Join-Path $TestsRoot "test_spt0193b.py"),
    (Join-Path $TestsRoot "test_spt0193c.py"),
    (Join-Path $TestsRoot "test_spt0193d.py")
)

foreach ($TargetFile in $TargetFiles) {
    Backup-Target -Target $TargetFile -BackupRoot $BackupRoot -Root $ProjectRoot
}

Write-Host "SPT-019.3 v$Version" -ForegroundColor White
Write-Host "Run: $RunId" -ForegroundColor Gray

# ---------------------------------------------------------------------------
# SPT-019.3A
# ---------------------------------------------------------------------------
Write-Step "Instalando SPT-019.3A"

$ComponentsPy = @'
from dataclasses import dataclass
from importlib import import_module
from typing import Any, Dict, Iterable, Optional, Sequence, Tuple


class ComponentLoadError(RuntimeError):
    pass


@dataclass(frozen=True)
class ComponentDescriptor:
    name: str
    component: Any
    required_methods: Tuple[str, ...] = ()


class InstitutionalComponentLoader:
    def __init__(self) -> None:
        self._components: Dict[str, ComponentDescriptor] = {}

    def register(
        self,
        name: str,
        component: Any,
        required_methods: Sequence[str] = (),
    ) -> ComponentDescriptor:
        if not name or not name.strip():
            raise ValueError("component name is required")
        if component is None:
            raise ValueError("component instance is required")

        descriptor = ComponentDescriptor(
            name=name.strip(),
            component=component,
            required_methods=tuple(required_methods),
        )
        self._validate_descriptor(descriptor)
        self._components[descriptor.name] = descriptor
        return descriptor

    def load_from_module(
        self,
        name: str,
        module_name: str,
        attribute: str,
        required_methods: Sequence[str] = (),
    ) -> ComponentDescriptor:
        try:
            module = import_module(module_name)
            component = getattr(module, attribute)
        except (ImportError, AttributeError) as exc:
            raise ComponentLoadError(
                "cannot load {0} from {1}".format(attribute, module_name)
            ) from exc

        return self.register(name, component, required_methods)

    def get(self, name: str) -> Any:
        try:
            return self._components[name].component
        except KeyError as exc:
            raise ComponentLoadError("component not registered: {0}".format(name)) from exc

    def descriptors(self) -> Iterable[ComponentDescriptor]:
        return tuple(self._components.values())

    def validate_all(self) -> None:
        for descriptor in self._components.values():
            self._validate_descriptor(descriptor)

    @staticmethod
    def _validate_descriptor(descriptor: ComponentDescriptor) -> None:
        missing = [
            method
            for method in descriptor.required_methods
            if not callable(getattr(descriptor.component, method, None))
        ]
        if missing:
            raise ComponentLoadError(
                "component {0} misses methods: {1}".format(
                    descriptor.name, ", ".join(missing)
                )
            )
'@

$OrchestratorPy = @'
from dataclasses import dataclass
from typing import Any, Dict, Optional, Sequence, Tuple


class OrchestrationError(RuntimeError):
    pass


@dataclass(frozen=True)
class OrchestrationResult:
    workflow_id: str
    status: str
    output: Any
    metadata: Dict[str, Any]


def _call_first(
    target: Any,
    names: Sequence[str],
    *args: Any,
    required: bool = True,
    **kwargs: Any
) -> Any:
    for name in names:
        method = getattr(target, name, None)
        if callable(method):
            return method(*args, **kwargs)

    if required:
        raise OrchestrationError(
            "no compatible method found: {0}".format(", ".join(names))
        )
    return None


class InstitutionalWorkflowOrchestrator:
    def __init__(
        self,
        engine: Any,
        registry: Any,
        ipsm: Optional[Any] = None,
        event_bus: Optional[Any] = None,
        integration: Optional[Any] = None,
        evidence: Optional[Any] = None,
    ) -> None:
        if engine is None:
            raise ValueError("engine is required")
        if registry is None:
            raise ValueError("registry is required")

        self.engine = engine
        self.registry = registry
        self.ipsm = ipsm
        self.event_bus = event_bus
        self.integration = integration
        self.evidence = evidence

    def execute(
        self,
        workflow_id: str,
        payload: Optional[Dict[str, Any]] = None,
    ) -> OrchestrationResult:
        if not workflow_id or not workflow_id.strip():
            raise ValueError("workflow_id is required")

        workflow_id = workflow_id.strip()
        payload = dict(payload or {})

        self._publish("workflow.requested", {"workflow_id": workflow_id})

        validation = _call_first(
            self.registry,
            ("validate", "validate_workflow"),
            workflow_id,
            required=False,
        )
        if validation is False:
            raise OrchestrationError("registry rejected workflow: {0}".format(workflow_id))

        workflow = _call_first(
            self.registry,
            ("get", "find", "resolve", "get_workflow"),
            workflow_id,
        )

        output = _call_first(
            self.engine,
            ("execute", "run", "dispatch", "execute_workflow"),
            workflow,
            payload,
        )

        result = OrchestrationResult(
            workflow_id=workflow_id,
            status="COMPLETED",
            output=output,
            metadata={"registered": True},
        )

        if self.integration is not None:
            method = getattr(self.integration, "record_execution", None)
            if callable(method):
                method(result)

        if self.evidence is not None:
            method = getattr(self.evidence, "record", None)
            if callable(method):
                method("workflow.completed", result.__dict__)

        if self.ipsm is not None:
            _call_first(
                self.ipsm,
                ("refresh", "consolidate", "update_project_state"),
                required=False,
            )

        self._publish(
            "workflow.completed",
            {"workflow_id": workflow_id, "status": result.status},
        )
        return result

    def _publish(self, name: str, payload: Dict[str, Any]) -> None:
        if self.event_bus is None:
            return
        method = getattr(self.event_bus, "publish", None)
        if callable(method):
            method(name, payload)
'@

$InitA = @'
from .components import ComponentDescriptor, ComponentLoadError, InstitutionalComponentLoader
from .orchestrator import InstitutionalWorkflowOrchestrator, OrchestrationError, OrchestrationResult

__all__ = [
    "ComponentDescriptor",
    "ComponentLoadError",
    "InstitutionalComponentLoader",
    "InstitutionalWorkflowOrchestrator",
    "OrchestrationError",
    "OrchestrationResult",
]
'@

$TestA = @'
import pytest

from sgoda.workflows.spt0193.components import (
    ComponentLoadError,
    InstitutionalComponentLoader,
)
from sgoda.workflows.spt0193.orchestrator import (
    InstitutionalWorkflowOrchestrator,
    OrchestrationError,
)


class Registry:
    def validate(self, workflow_id):
        return workflow_id != "blocked"

    def get(self, workflow_id):
        return {"id": workflow_id}


class Engine:
    def execute(self, workflow, payload):
        return {"workflow": workflow["id"], "payload": payload}


def test_loader_registers_and_gets_component():
    loader = InstitutionalComponentLoader()
    engine = Engine()
    loader.register("engine", engine, ("execute",))
    assert loader.get("engine") is engine


def test_loader_rejects_missing_contract():
    loader = InstitutionalComponentLoader()
    with pytest.raises(ComponentLoadError):
        loader.register("invalid", object(), ("execute",))


def test_orchestrator_executes_registered_workflow():
    orchestrator = InstitutionalWorkflowOrchestrator(Engine(), Registry())
    result = orchestrator.execute("WF-001", {"value": 7})
    assert result.status == "COMPLETED"
    assert result.output["workflow"] == "WF-001"
    assert result.output["payload"]["value"] == 7


def test_orchestrator_rejects_registry_block():
    orchestrator = InstitutionalWorkflowOrchestrator(Engine(), Registry())
    with pytest.raises(OrchestrationError):
        orchestrator.execute("blocked")
'@

Write-AsciiFile -Path (Join-Path $PackageRoot "components.py") -Content $ComponentsPy
Write-AsciiFile -Path (Join-Path $PackageRoot "orchestrator.py") -Content $OrchestratorPy
Write-AsciiFile -Path (Join-Path $PackageRoot "__init__.py") -Content $InitA
Write-AsciiFile -Path (Join-Path $TestsRoot "test_spt0193a.py") -Content $TestA

$DocA = @'
# SGD-420 - Arquitectura del Orquestador Institucional

## Componente

SPT-019.3A

## Objetivo

Integrar SPT-019.0, SPT-019.1 y SPT-019.2 mediante contratos adaptables,
sin copiar sus datos ni reemplazar su logica.

## Flujo

Registro -> validacion -> carga -> ejecucion -> resultado -> actualizacion IPSM.

## Restricciones

- El repositorio permanece como fuente de verdad.
- No se instala n8n.
- No se requieren servicios de pago.
- Cada capa debe aprobar sus pruebas antes de continuar.
'@
Write-AsciiFile -Path (Join-Path $DocsRoot "SGD-420-Arquitectura-Orquestador.md") -Content $DocA

Invoke-PytestGate `
    -GateName "SPT-019.3A" `
    -Targets @("tests/workflows/spt0193/test_spt0193a.py") `
    -LogPath (Join-Path $RunRoot "gate-a-pytest.txt")

# ---------------------------------------------------------------------------
# SPT-019.3B
# ---------------------------------------------------------------------------
Write-Step "Instalando SPT-019.3B"

$IntegrationPy = @'
from dataclasses import asdict
from typing import Any, Dict


class IntegrationError(RuntimeError):
    pass


def _invoke(target: Any, names, *args, required=True, **kwargs):
    for name in names:
        method = getattr(target, name, None)
        if callable(method):
            return method(*args, **kwargs)
    if required:
        raise IntegrationError("compatible integration method not found")
    return None


class PMODigitalGateway:
    def __init__(self, pmo: Any) -> None:
        if pmo is None:
            raise ValueError("pmo is required")
        self.pmo = pmo

    def record(self, payload: Dict[str, Any]) -> Any:
        return _invoke(
            self.pmo,
            ("record_execution", "register_event", "record_metric", "update"),
            payload,
        )


class InstitutionalAuditorGateway:
    def __init__(self, auditor: Any) -> None:
        if auditor is None:
            raise ValueError("auditor is required")
        self.auditor = auditor

    def audit(self, payload: Dict[str, Any]) -> Any:
        return _invoke(
            self.auditor,
            ("audit_execution", "audit", "verify", "record"),
            payload,
        )


class InstitutionalIntegrationService:
    def __init__(
        self,
        pmo_gateway: PMODigitalGateway,
        auditor_gateway: InstitutionalAuditorGateway,
    ) -> None:
        self.pmo_gateway = pmo_gateway
        self.auditor_gateway = auditor_gateway

    def record_execution(self, result: Any) -> Dict[str, Any]:
        payload = asdict(result) if hasattr(result, "__dataclass_fields__") else dict(result)
        pmo_result = self.pmo_gateway.record(payload)
        audit_result = self.auditor_gateway.audit(payload)
        return {
            "pmo": pmo_result,
            "audit": audit_result,
            "workflow_id": payload.get("workflow_id"),
        }
'@

$TestB = @'
from sgoda.workflows.spt0193.institutional_integration import (
    InstitutionalAuditorGateway,
    InstitutionalIntegrationService,
    PMODigitalGateway,
)
from sgoda.workflows.spt0193.orchestrator import OrchestrationResult


class PMO:
    def __init__(self):
        self.events = []

    def record_execution(self, payload):
        self.events.append(payload)
        return "PMO_OK"


class Auditor:
    def __init__(self):
        self.events = []

    def audit_execution(self, payload):
        self.events.append(payload)
        return "AUDIT_OK"


def test_pmo_gateway_records_execution():
    pmo = PMO()
    gateway = PMODigitalGateway(pmo)
    assert gateway.record({"workflow_id": "WF-1"}) == "PMO_OK"
    assert pmo.events[0]["workflow_id"] == "WF-1"


def test_auditor_gateway_records_audit():
    auditor = Auditor()
    gateway = InstitutionalAuditorGateway(auditor)
    assert gateway.audit({"workflow_id": "WF-2"}) == "AUDIT_OK"


def test_integration_service_coordinates_both_components():
    pmo = PMO()
    auditor = Auditor()
    service = InstitutionalIntegrationService(
        PMODigitalGateway(pmo),
        InstitutionalAuditorGateway(auditor),
    )
    result = OrchestrationResult("WF-3", "COMPLETED", {"ok": True}, {})
    integration = service.record_execution(result)
    assert integration["pmo"] == "PMO_OK"
    assert integration["audit"] == "AUDIT_OK"
    assert len(pmo.events) == 1
    assert len(auditor.events) == 1
'@

Write-AsciiFile -Path (Join-Path $PackageRoot "institutional_integration.py") -Content $IntegrationPy
Write-AsciiFile -Path (Join-Path $TestsRoot "test_spt0193b.py") -Content $TestB

$DocB = @'
# SGD-421 - Modelo de Integracion Institucional

## Componente

SPT-019.3B

## Integraciones

- PMO Digital: recibe resultados y metricas de ejecucion.
- Auditor Institucional: verifica cada ejecucion.
- IPSM: actualiza el estado consolidado despues de la ejecucion.

## Principio

SPT-019.3 coordina los componentes existentes mediante gateways. No replica
sus bases de datos ni su logica de negocio.
'@
Write-AsciiFile -Path (Join-Path $DocsRoot "SGD-421-Integracion-Institucional.md") -Content $DocB

Invoke-PytestGate `
    -GateName "SPT-019.3B" `
    -Targets @(
        "tests/workflows/spt0193/test_spt0193a.py",
        "tests/workflows/spt0193/test_spt0193b.py"
    ) `
    -LogPath (Join-Path $RunRoot "gate-b-pytest.txt")

# ---------------------------------------------------------------------------
# SPT-019.3C
# ---------------------------------------------------------------------------
Write-Step "Instalando SPT-019.3C"

$EventsPy = @'
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Callable, Dict, List


@dataclass(frozen=True)
class InstitutionalEvent:
    name: str
    payload: Dict[str, Any]
    occurred_at_utc: str


class InstitutionalEventBus:
    def __init__(self) -> None:
        self._subscribers: Dict[str, List[Callable[[InstitutionalEvent], None]]] = {}
        self.history: List[InstitutionalEvent] = []

    def subscribe(self, event_name: str, handler: Callable[[InstitutionalEvent], None]) -> None:
        self._subscribers.setdefault(event_name, []).append(handler)

    def publish(self, event_name: str, payload: Dict[str, Any]) -> InstitutionalEvent:
        event = InstitutionalEvent(
            name=event_name,
            payload=dict(payload),
            occurred_at_utc=datetime.now(timezone.utc).isoformat(),
        )
        self.history.append(event)
        for handler in self._subscribers.get(event_name, ()):
            handler(event)
        return event
'@

$TraceabilityPy = @'
import hashlib
import json
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from typing import Any, Dict, List


@dataclass(frozen=True)
class TraceabilityRecord:
    sequence: int
    event_name: str
    payload: Dict[str, Any]
    previous_hash: str
    record_hash: str
    occurred_at_utc: str


class TraceabilityLedger:
    def __init__(self) -> None:
        self._records: List[TraceabilityRecord] = []

    def append(self, event_name: str, payload: Dict[str, Any]) -> TraceabilityRecord:
        previous_hash = self._records[-1].record_hash if self._records else "GENESIS"
        occurred_at = datetime.now(timezone.utc).isoformat()
        raw = json.dumps(
            {
                "sequence": len(self._records) + 1,
                "event_name": event_name,
                "payload": payload,
                "previous_hash": previous_hash,
                "occurred_at_utc": occurred_at,
            },
            sort_keys=True,
            separators=(",", ":"),
        )
        record_hash = hashlib.sha256(raw.encode("utf-8")).hexdigest()
        record = TraceabilityRecord(
            sequence=len(self._records) + 1,
            event_name=event_name,
            payload=dict(payload),
            previous_hash=previous_hash,
            record_hash=record_hash,
            occurred_at_utc=occurred_at,
        )
        self._records.append(record)
        return record

    def records(self):
        return tuple(self._records)

    def verify(self) -> bool:
        previous_hash = "GENESIS"
        for index, record in enumerate(self._records, start=1):
            if record.sequence != index:
                return False
            if record.previous_hash != previous_hash:
                return False
            previous_hash = record.record_hash
        return True
'@

$EvidencePy = @'
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List


class InstitutionalEvidenceWriter:
    def __init__(self, output_path) -> None:
        self.output_path = Path(output_path)
        self._entries: List[Dict[str, Any]] = []

    def record(self, event_name: str, payload: Dict[str, Any]) -> None:
        self._entries.append(
            {
                "event_name": event_name,
                "payload": dict(payload),
                "recorded_at_utc": datetime.now(timezone.utc).isoformat(),
            }
        )
        self.flush()

    def flush(self) -> None:
        self.output_path.parent.mkdir(parents=True, exist_ok=True)
        temporary = self.output_path.with_suffix(self.output_path.suffix + ".tmp")
        temporary.write_text(
            json.dumps(
                {
                    "schema": "sgoda.spt0193.evidence.v1",
                    "entries": self._entries,
                },
                indent=2,
                sort_keys=True,
            )
            + "\n",
            encoding="utf-8",
        )
        temporary.replace(self.output_path)

    @property
    def entries(self):
        return tuple(self._entries)
'@

$TestC = @'
import json

from sgoda.workflows.spt0193.events import InstitutionalEventBus
from sgoda.workflows.spt0193.evidence import InstitutionalEvidenceWriter
from sgoda.workflows.spt0193.traceability import TraceabilityLedger


def test_event_bus_delivers_and_preserves_history():
    bus = InstitutionalEventBus()
    received = []
    bus.subscribe("workflow.completed", received.append)
    event = bus.publish("workflow.completed", {"workflow_id": "WF-1"})
    assert event.name == "workflow.completed"
    assert received[0].payload["workflow_id"] == "WF-1"
    assert len(bus.history) == 1


def test_traceability_ledger_builds_hash_chain():
    ledger = TraceabilityLedger()
    first = ledger.append("workflow.requested", {"id": "WF-1"})
    second = ledger.append("workflow.completed", {"id": "WF-1"})
    assert first.previous_hash == "GENESIS"
    assert second.previous_hash == first.record_hash
    assert ledger.verify() is True


def test_evidence_writer_persists_atomic_json(tmp_path):
    path = tmp_path / "evidence.json"
    writer = InstitutionalEvidenceWriter(path)
    writer.record("workflow.completed", {"workflow_id": "WF-2"})
    payload = json.loads(path.read_text(encoding="utf-8"))
    assert payload["schema"] == "sgoda.spt0193.evidence.v1"
    assert payload["entries"][0]["payload"]["workflow_id"] == "WF-2"
'@

Write-AsciiFile -Path (Join-Path $PackageRoot "events.py") -Content $EventsPy
Write-AsciiFile -Path (Join-Path $PackageRoot "traceability.py") -Content $TraceabilityPy
Write-AsciiFile -Path (Join-Path $PackageRoot "evidence.py") -Content $EvidencePy
Write-AsciiFile -Path (Join-Path $TestsRoot "test_spt0193c.py") -Content $TestC

$DocC = @'
# SGD-422 - Eventos, Trazabilidad y Evidencias

## Componente

SPT-019.3C

## Funciones

- Publicar eventos institucionales.
- Mantener historial en memoria durante cada ejecucion.
- Crear una cadena SHA-256 para trazabilidad.
- Persistir evidencias JSON mediante escritura atomica.

## Eventos iniciales

- workflow.requested
- workflow.completed
- workflow.failed
'@
Write-AsciiFile -Path (Join-Path $DocsRoot "SGD-422-Eventos-Trazabilidad-Evidencias.md") -Content $DocC

Invoke-PytestGate `
    -GateName "SPT-019.3C" `
    -Targets @(
        "tests/workflows/spt0193/test_spt0193a.py",
        "tests/workflows/spt0193/test_spt0193b.py",
        "tests/workflows/spt0193/test_spt0193c.py"
    ) `
    -LogPath (Join-Path $RunRoot "gate-c-pytest.txt")

# ---------------------------------------------------------------------------
# SPT-019.3D
# ---------------------------------------------------------------------------
Write-Step "Instalando SPT-019.3D"

$QualityPy = @'
from dataclasses import dataclass
from typing import Dict, Iterable, Tuple


@dataclass(frozen=True)
class GateResult:
    name: str
    passed: bool
    detail: str


@dataclass(frozen=True)
class QualityReport:
    passed: bool
    results: Tuple[GateResult, ...]


class InstitutionalQualityGate:
    def evaluate(self, checks: Dict[str, bool]) -> QualityReport:
        if not checks:
            raise ValueError("at least one quality check is required")

        results = tuple(
            GateResult(
                name=name,
                passed=bool(passed),
                detail="APPROVED" if passed else "FAILED",
            )
            for name, passed in sorted(checks.items())
        )
        return QualityReport(
            passed=all(item.passed for item in results),
            results=results,
        )

    def require(self, checks: Dict[str, bool]) -> QualityReport:
        report = self.evaluate(checks)
        if not report.passed:
            failed = ", ".join(item.name for item in report.results if not item.passed)
            raise RuntimeError("quality gates failed: {0}".format(failed))
        return report
'@

$InitFinal = @'
from .components import ComponentDescriptor, ComponentLoadError, InstitutionalComponentLoader
from .events import InstitutionalEvent, InstitutionalEventBus
from .evidence import InstitutionalEvidenceWriter
from .institutional_integration import (
    InstitutionalAuditorGateway,
    InstitutionalIntegrationService,
    PMODigitalGateway,
)
from .orchestrator import InstitutionalWorkflowOrchestrator, OrchestrationError, OrchestrationResult
from .quality import GateResult, InstitutionalQualityGate, QualityReport
from .traceability import TraceabilityLedger, TraceabilityRecord

__all__ = [
    "ComponentDescriptor",
    "ComponentLoadError",
    "InstitutionalAuditorGateway",
    "InstitutionalComponentLoader",
    "InstitutionalEvent",
    "InstitutionalEventBus",
    "InstitutionalEvidenceWriter",
    "InstitutionalIntegrationService",
    "InstitutionalQualityGate",
    "InstitutionalWorkflowOrchestrator",
    "OrchestrationError",
    "OrchestrationResult",
    "PMODigitalGateway",
    "GateResult",
    "QualityReport",
    "TraceabilityLedger",
    "TraceabilityRecord",
]
'@

$TestD = @'
import pytest

from sgoda.workflows.spt0193.events import InstitutionalEventBus
from sgoda.workflows.spt0193.orchestrator import InstitutionalWorkflowOrchestrator
from sgoda.workflows.spt0193.quality import InstitutionalQualityGate


class Registry:
    def validate(self, workflow_id):
        return True

    def get(self, workflow_id):
        return {"id": workflow_id}


class Engine:
    def execute(self, workflow, payload):
        return {"id": workflow["id"], "ok": True}


def test_quality_gate_approves_all_checks():
    report = InstitutionalQualityGate().require(
        {
            "SPT-019.3A": True,
            "SPT-019.3B": True,
            "SPT-019.3C": True,
        }
    )
    assert report.passed is True


def test_quality_gate_blocks_failed_check():
    with pytest.raises(RuntimeError):
        InstitutionalQualityGate().require(
            {"SPT-019.3A": True, "SPT-019.3B": False}
        )


def test_end_to_end_orchestration_publishes_events():
    bus = InstitutionalEventBus()
    orchestrator = InstitutionalWorkflowOrchestrator(
        Engine(),
        Registry(),
        event_bus=bus,
    )
    result = orchestrator.execute("WF-END-TO-END")
    assert result.status == "COMPLETED"
    assert [event.name for event in bus.history] == [
        "workflow.requested",
        "workflow.completed",
    ]
'@

Write-AsciiFile -Path (Join-Path $PackageRoot "quality.py") -Content $QualityPy
Write-AsciiFile -Path (Join-Path $PackageRoot "__init__.py") -Content $InitFinal
Write-AsciiFile -Path (Join-Path $TestsRoot "test_spt0193d.py") -Content $TestD

Invoke-PytestGate `
    -GateName "SPT-019.3D" `
    -Targets @("tests/workflows/spt0193") `
    -LogPath (Join-Path $RunRoot "gate-d-pytest.txt")

$FullSuiteRequested = -not $SkipFullSuite.IsPresent
$FullSuitePassed = $null
$FullSuiteLog = Join-Path $RunRoot "pytest-full-suite.txt"

if ($FullSuiteRequested) {
    Invoke-PytestGate `
        -GateName "SUITE COMPLETA" `
        -Targets @() `
        -LogPath $FullSuiteLog
    $FullSuitePassed = $true
}
else {
    Write-Host "Suite completa omitida por parametro." -ForegroundColor Yellow
}

$GeneratedFiles = Get-ChildItem -LiteralPath $PackageRoot -File |
    Select-Object -ExpandProperty FullName
$GeneratedFiles += Get-ChildItem -LiteralPath $TestsRoot -File |
    Select-Object -ExpandProperty FullName
$GeneratedFiles += Get-ChildItem -LiteralPath $DocsRoot -File |
    Select-Object -ExpandProperty FullName

$Hashes = @()
foreach ($File in $GeneratedFiles) {
    $Hashes += [PSCustomObject]@{
        path = $File.Substring($ProjectRoot.Length).TrimStart("\").Replace("\", "/")
        sha256 = (Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

$Evidence = [ordered]@{
    component = $Component
    version = $Version
    generated_at_utc = $GeneratedUtc
    run_id = $RunId
    stages = [ordered]@{
        "SPT-019.3A" = "APPROVED"
        "SPT-019.3B" = "APPROVED"
        "SPT-019.3C" = "APPROVED"
        "SPT-019.3D" = "APPROVED"
    }
    full_suite_requested = $FullSuiteRequested
    full_suite_passed = $FullSuitePassed
    powershell_execution = $true
    repository_is_source_of_truth = $true
    duplicate_store_created = $false
    duplicate_business_logic = $false
    n8n_installed = $false
    paid_services_required = $false
    files = $Hashes
}

$EvidencePath = Join-Path $RunRoot "implementation-evidence.json"
Write-JsonFile -Path $EvidencePath -Data $Evidence

$Manifest = [ordered]@{
    component = $Component
    version = $Version
    status = if ($FullSuitePassed -eq $true) {
        "CANDIDATE_FOR_INSTITUTIONAL_CLOSURE"
    }
    else {
        "IMPLEMENTED_PENDING_FULL_SUITE"
    }
    evidence = $EvidencePath.Substring($ProjectRoot.Length).TrimStart("\").Replace("\", "/")
    n8n_required = $false
    paid_services_required = $false
}
Write-JsonFile -Path (Join-Path $ReleaseRoot "manifest.json") -Data $Manifest

$ActStatus = if ($FullSuitePassed -eq $true) {
    "CANDIDATO A CIERRE INSTITUCIONAL"
}
else {
    "IMPLEMENTADO - PENDIENTE SUITE COMPLETA"
}

$Act = @"
# ACT-019.3 - Acta Tecnica de Integracion

| Campo | Valor |
|---|---|
| Componente | SPT-019.3 |
| Version | $Version |
| Estado | $ActStatus |
| SPT-019.3A | APROBADO |
| SPT-019.3B | APROBADO |
| SPT-019.3C | APROBADO |
| SPT-019.3D | APROBADO |
| Suite completa | $(if ($FullSuitePassed -eq $true) { "APROBADA" } else { "PENDIENTE" }) |
| n8n instalado | NO |
| Servicios de pago | NO |

El cierre definitivo requiere revision de la evidencia, manifiesto, estado Git y
aprobacion institucional explicita.
"@
Write-AsciiFile -Path (Join-Path $DocsRoot "ACT-019.3-Acta-Tecnica-Integracion.md") -Content $Act

foreach ($File in $GeneratedFiles) {
    $Relative = $File.Substring($ProjectRoot.Length).TrimStart("\")
    $Destination = Join-Path $ReleaseRoot $Relative
    $DestinationParent = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Path $DestinationParent -Force | Out-Null
    Copy-Item -LiteralPath $File -Destination $Destination -Force
}
Copy-Item -LiteralPath $EvidencePath -Destination (Join-Path $ReleaseRoot "implementation-evidence.json") -Force

Write-Step "Resultado final"
Write-Host "SPT-019.3A: APROBADO" -ForegroundColor Green
Write-Host "SPT-019.3B: APROBADO" -ForegroundColor Green
Write-Host "SPT-019.3C: APROBADO" -ForegroundColor Green
Write-Host "SPT-019.3D: APROBADO" -ForegroundColor Green
if ($FullSuitePassed -eq $true) {
    Write-Host "Suite completa: APROBADA" -ForegroundColor Green
}
else {
    Write-Host "Suite completa: PENDIENTE" -ForegroundColor Yellow
}
Write-Host "n8n instalado: NO" -ForegroundColor Green
Write-Host "Servicios de pago: NO" -ForegroundColor Green
Write-Host "Evidencia: $EvidencePath" -ForegroundColor Cyan
Write-Host "Release: $ReleaseRoot" -ForegroundColor Cyan
Write-Host "Estado: $ActStatus" -ForegroundColor Cyan
