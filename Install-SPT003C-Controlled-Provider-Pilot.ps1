<#
.SYNOPSIS
    Implementa SPT-003C — Piloto Controlado de Proveedores Reales.

.DESCRIPTION
    Instala desde un solo archivo:
      - política de activación controlada;
      - presupuesto y cuotas;
      - aprobaciones humana, cultural y administrativa;
      - modo dry-run obligatorio por defecto;
      - circuit breaker;
      - registro de consumo y costos;
      - validación de secretos por variables de entorno;
      - selección y promoción de proveedores;
      - ejecución piloto sobre la cola SPT-003A/SPT-003B;
      - pruebas automatizadas;
      - documentación, evidencias, dashboard, release y quality gate.

    Esta versión NO ejecuta llamadas externas durante la instalación ni
    durante las pruebas. El proveedor real solo puede activarse cuando
    existe una autorización institucional explícita.

.PARAMETER ProjectRoot
    Ruta raíz del repositorio SGODA-PUINAVE.

.PARAMETER SkipFullSuite
    Omite la suite completa. Las pruebas específicas siempre se ejecutan.

.EXAMPLE
    .\Install-SPT003C-Controlled-Provider-Pilot.ps1
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipFullSuite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Assert-Path {
    param([string]$Path, [string]$Description)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se encontró $Description en: $Path"
    }
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)

    $Parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se pudo crear: $Path"
    }

    $Info = Get-Item -LiteralPath $Path
    Write-Host "Creado: $Path ($($Info.Length) bytes)" -ForegroundColor Green
}

function Write-JsonUtf8 {
    param([string]$Path, [object]$Data)

    $Parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    $Json = $Data | ConvertTo-Json -Depth 50
    [System.IO.File]::WriteAllText(
        $Path,
        $Json + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$SourceDir = Join-Path $ProjectRoot "src\sgoda\automation\pilot"
$TestsDir = Join-Path $ProjectRoot "tests\automation"
$ConfigDir = Join-Path $ProjectRoot "config\automation"
$DocsDir = Join-Path $ProjectRoot "docs\05_Fase_Tecnologica\SPT-003"
$ScriptsDir = Join-Path $ProjectRoot "scripts"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\automation\SPT-003C"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-003C"
$DashboardDir = Join-Path $ProjectRoot "dashboard"
$ReleaseDir = Join-Path $ProjectRoot "releases\SPT-003C-v0.1.0"

$ModelsPath = Join-Path $SourceDir "models.py"
$GovernancePath = Join-Path $SourceDir "governance.py"
$BudgetPath = Join-Path $SourceDir "budget.py"
$CircuitPath = Join-Path $SourceDir "circuit_breaker.py"
$RunnerPath = Join-Path $SourceDir "runner.py"
$InitPath = Join-Path $SourceDir "__init__.py"
$TestPath = Join-Path $TestsDir "test_SPT_003C_controlled_provider_pilot.py"
$PolicyPath = Join-Path $ConfigDir "SPT-003C-pilot-policy.json"
$ApprovalTemplatePath = Join-Path $ConfigDir "SPT-003C-approval-template.json"
$PricingTemplatePath = Join-Path $ConfigDir "SPT-003C-pricing-template.json"
$ComponentPath = Join-Path $ConfigDir "SPT-003C-component.json"
$DocPath = Join-Path $DocsDir "SPT-003C-Piloto-Controlado-Proveedores.md"
$ProtocolPath = Join-Path $DocsDir "SPT-003C-Protocolo-Aprobacion-Cultural.md"
$InvokePath = Join-Path $ScriptsDir "Invoke-SPT003C-ControlledPilot.ps1"
$EvidencePath = Join-Path $PmoDir "implementation-evidence.json"
$TracePath = Join-Path $PmoDir "traceability-SPT-003C.json"
$GatePath = Join-Path $PmoDir "SPT-003C-quality-gate.json"
$DashboardPath = Join-Path $DashboardDir "SPT-003C-dashboard.json"

Write-Step "Validando línea base SPT-003B y SGD-115"

foreach ($Required in @(
    (Join-Path $ProjectRoot "src\sgoda\automation\adapters\processor.py"),
    (Join-Path $ProjectRoot "src\sgoda\automation\adapters\providers.py"),
    (Join-Path $ProjectRoot "artifacts\pmo\SPT-003B\SPT-003B-quality-gate.json"),
    (Join-Path $ProjectRoot "artifacts\automation\SPT-003A\multimedia-jobs.sqlite3"),
    (Join-Path $ProjectRoot "docs\00_INDICE_MAESTRO.md"),
    (Join-Path $ProjectRoot "docs\00_ARQUITECTURA_MAESTRA.md"),
    (Join-Path $ProjectRoot "docs\00_REGISTRO_MAESTRO_COMPONENTES.md"),
    (Join-Path $ProjectRoot "config\governance\sgd-114-policy.json"),
    (Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1"),
    (Join-Path $ProjectRoot "pytest.ini"),
    (Join-Path $ProjectRoot ".git")
)) {
    Assert-Path -Path $Required -Description $Required
}

$GitStatus = @(
    git status --porcelain |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
)

$AllowedPatterns = @(
    '^\?\? Install-SPT003C-Controlled-Provider-Pilot\.ps1$',
    '^\?\? Repair-SPT003C-v[0-9.]+-.*\.ps1$',
    '^\?\? SPT003C-.*\.zip$',
    '^\?\? LEAME-SPT003C.*\.txt$'
)

$Unexpected = @(
    foreach ($Entry in $GitStatus) {
        $Allowed = $false
        foreach ($Pattern in $AllowedPatterns) {
            if ($Entry -match $Pattern) {
                $Allowed = $true
                break
            }
        }
        if (-not $Allowed) {
            $Entry
        }
    }
)

if ($Unexpected.Count -gt 0) {
    Write-Host "Cambios Git no permitidos antes de SPT-003C:" -ForegroundColor Red
    $Unexpected | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Red
    }
    throw "La línea base contiene cambios ajenos a SPT-003C."
}

$ModelsContent = @'
"""Modelos del piloto controlado SPT-003C."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(slots=True)
class AprobacionPiloto:
    approval_id: str
    provider: str
    approved_by: str
    approved_at_utc: str
    expires_at_utc: str
    administrative_approved: bool
    cultural_approved: bool
    privacy_approved: bool
    budget_approved: bool
    live_calls_authorized: bool
    allowed_job_types: list[str] = field(default_factory=list)
    max_jobs: int = 0
    max_cost_usd: float = 0.0


@dataclass(slots=True)
class DecisionPiloto:
    allowed: bool
    mode: str
    reasons: list[str] = field(default_factory=list)


@dataclass(slots=True)
class RegistroConsumo:
    provider: str
    job_type: str
    units: int
    estimated_cost_usd: float
    job_id: str | None = None
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class ResumenPiloto:
    provider: str
    mode: str
    requested_jobs: int
    authorized_jobs: int
    executed_jobs: int
    blocked_jobs: int
    estimated_cost_usd: float
    circuit_state: str
    approval_id: str | None
'@

$GovernanceContent = @'
"""Gobernanza de activación de proveedores reales."""

from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .models import AprobacionPiloto, DecisionPiloto


PROVIDER_SECRETS = {
    "openai-image": "OPENAI_API_KEY",
    "google-tts": "GOOGLE_APPLICATION_CREDENTIALS",
    "azure-speech": "AZURE_SPEECH_KEY",
}


def load_approval(path: str | Path) -> AprobacionPiloto:
    payload = json.loads(Path(path).read_text(encoding="utf-8"))

    return AprobacionPiloto(
        approval_id=str(payload["approval_id"]),
        provider=str(payload["provider"]),
        approved_by=str(payload["approved_by"]),
        approved_at_utc=str(payload["approved_at_utc"]),
        expires_at_utc=str(payload["expires_at_utc"]),
        administrative_approved=bool(
            payload["administrative_approved"]
        ),
        cultural_approved=bool(payload["cultural_approved"]),
        privacy_approved=bool(payload["privacy_approved"]),
        budget_approved=bool(payload["budget_approved"]),
        live_calls_authorized=bool(
            payload["live_calls_authorized"]
        ),
        allowed_job_types=[
            str(item) for item in payload.get("allowed_job_types", [])
        ],
        max_jobs=int(payload.get("max_jobs", 0)),
        max_cost_usd=float(payload.get("max_cost_usd", 0.0)),
    )


def evaluate_activation(
    *,
    provider: str,
    requested_jobs: int,
    estimated_cost_usd: float,
    job_types: list[str],
    approval: AprobacionPiloto | None,
    dry_run: bool,
) -> DecisionPiloto:
    reasons: list[str] = []

    if dry_run:
        return DecisionPiloto(
            allowed=True,
            mode="dry-run",
            reasons=["Modo dry-run: no se ejecutan llamadas externas."],
        )

    if provider == "mock":
        return DecisionPiloto(
            allowed=True,
            mode="mock",
            reasons=["Proveedor simulado autorizado."],
        )

    if approval is None:
        reasons.append("No existe aprobación institucional.")

    if approval is not None:
        now = datetime.now(timezone.utc)
        expires = datetime.fromisoformat(
            approval.expires_at_utc.replace("Z", "+00:00")
        )

        if approval.provider != provider:
            reasons.append("La aprobación corresponde a otro proveedor.")

        if expires <= now:
            reasons.append("La aprobación está vencida.")

        required_flags = {
            "administrative_approved": approval.administrative_approved,
            "cultural_approved": approval.cultural_approved,
            "privacy_approved": approval.privacy_approved,
            "budget_approved": approval.budget_approved,
            "live_calls_authorized": approval.live_calls_authorized,
        }

        for name, value in required_flags.items():
            if not value:
                reasons.append(f"Falta aprobación: {name}.")

        if requested_jobs > approval.max_jobs:
            reasons.append("La cantidad solicitada supera el límite.")

        if estimated_cost_usd > approval.max_cost_usd:
            reasons.append("El costo estimado supera el presupuesto.")

        unauthorized = sorted(
            set(job_types) - set(approval.allowed_job_types)
        )
        if unauthorized:
            reasons.append(
                "Tipos de trabajo no autorizados: "
                + ", ".join(unauthorized)
            )

    secret_name = PROVIDER_SECRETS.get(provider)
    if secret_name is None:
        reasons.append("Proveedor real no registrado.")
    elif not os.getenv(secret_name):
        reasons.append(
            f"Falta la variable de entorno {secret_name}."
        )

    return DecisionPiloto(
        allowed=not reasons,
        mode="live" if not reasons else "blocked",
        reasons=reasons,
    )
'@

$BudgetContent = @'
"""Control de presupuesto y registro de consumo."""

from __future__ import annotations

import json
from dataclasses import asdict
from pathlib import Path
from typing import Any

from .models import RegistroConsumo


class LibroConsumo:
    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)

    def append(self, record: RegistroConsumo) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with self.path.open("a", encoding="utf-8") as stream:
            stream.write(
                json.dumps(
                    asdict(record),
                    ensure_ascii=False,
                )
                + "\n"
            )

    def total_cost(self) -> float:
        if not self.path.is_file():
            return 0.0

        total = 0.0
        for line in self.path.read_text(
            encoding="utf-8"
        ).splitlines():
            if not line.strip():
                continue
            payload: dict[str, Any] = json.loads(line)
            total += float(payload["estimated_cost_usd"])

        return round(total, 8)


def estimate_cost(
    *,
    provider: str,
    job_type: str,
    units: int,
    pricing: dict[str, Any],
) -> float:
    provider_pricing = pricing.get(provider, {})
    rate = float(provider_pricing.get(job_type, 0.0))
    return round(rate * units, 8)
'@

$CircuitContent = @'
"""Circuit breaker persistente para el piloto controlado."""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from pathlib import Path


class CircuitBreaker:
    def __init__(
        self,
        *,
        path: str | Path,
        failure_threshold: int = 3,
        cooldown_seconds: int = 300,
    ) -> None:
        self.path = Path(path)
        self.failure_threshold = failure_threshold
        self.cooldown_seconds = cooldown_seconds

    def _default(self) -> dict:
        return {
            "state": "closed",
            "failure_count": 0,
            "opened_at_utc": None,
        }

    def load(self) -> dict:
        if not self.path.is_file():
            return self._default()
        return json.loads(self.path.read_text(encoding="utf-8"))

    def save(self, payload: dict) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

    def allow_request(self) -> bool:
        state = self.load()

        if state["state"] == "closed":
            return True

        if state["state"] == "open":
            opened = datetime.fromisoformat(
                state["opened_at_utc"].replace("Z", "+00:00")
            )
            now = datetime.now(timezone.utc)
            if now >= opened + timedelta(
                seconds=self.cooldown_seconds
            ):
                state["state"] = "half-open"
                self.save(state)
                return True
            return False

        return state["state"] == "half-open"

    def record_success(self) -> None:
        self.save(self._default())

    def record_failure(self) -> None:
        state = self.load()
        state["failure_count"] += 1

        if state["failure_count"] >= self.failure_threshold:
            state["state"] = "open"
            state["opened_at_utc"] = datetime.now(
                timezone.utc
            ).isoformat()

        self.save(state)
'@

$RunnerContent = @'
"""Ejecución controlada del piloto SPT-003C."""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict
from pathlib import Path
from typing import Any

from sgoda.automation.adapters.processor import (
    ProcesadorTrabajosMultimedia,
)
from sgoda.automation.adapters.providers import construir_proveedor
from sgoda.automation.adapters.storage import AlmacenamientoLocalRMR
from sgoda.automation.adapters.n8n import PublicadorEventosArchivo
from sgoda.automation.job_queue import ColaTrabajosMultimedia

from .budget import LibroConsumo, estimate_cost
from .circuit_breaker import CircuitBreaker
from .governance import evaluate_activation, load_approval
from .models import RegistroConsumo, ResumenPiloto


def run_pilot(
    *,
    jobs_database: str | Path,
    storage_root: str | Path,
    events_path: str | Path,
    rmr_database: str | Path,
    provider_name: str,
    requested_jobs: int,
    pricing: dict[str, Any],
    approval_path: str | Path | None,
    dry_run: bool,
    ledger_path: str | Path,
    circuit_path: str | Path,
) -> ResumenPiloto:
    queue = ColaTrabajosMultimedia(jobs_database)
    pending = queue.count("pending")
    authorized_jobs = min(requested_jobs, pending)

    job_types = sorted(
        key for key, value in queue.statistics()["by_type"].items()
        if value > 0
    )

    estimated = sum(
        estimate_cost(
            provider=provider_name,
            job_type=job_type,
            units=authorized_jobs,
            pricing=pricing,
        )
        for job_type in job_types
    )

    approval = (
        load_approval(approval_path)
        if approval_path is not None
        and Path(approval_path).is_file()
        else None
    )

    decision = evaluate_activation(
        provider=provider_name,
        requested_jobs=authorized_jobs,
        estimated_cost_usd=estimated,
        job_types=job_types,
        approval=approval,
        dry_run=dry_run,
    )

    breaker = CircuitBreaker(path=circuit_path)

    if not breaker.allow_request():
        return ResumenPiloto(
            provider=provider_name,
            mode="blocked",
            requested_jobs=requested_jobs,
            authorized_jobs=0,
            executed_jobs=0,
            blocked_jobs=requested_jobs,
            estimated_cost_usd=estimated,
            circuit_state=breaker.load()["state"],
            approval_id=approval.approval_id if approval else None,
        )

    if not decision.allowed:
        return ResumenPiloto(
            provider=provider_name,
            mode=decision.mode,
            requested_jobs=requested_jobs,
            authorized_jobs=0,
            executed_jobs=0,
            blocked_jobs=requested_jobs,
            estimated_cost_usd=estimated,
            circuit_state=breaker.load()["state"],
            approval_id=approval.approval_id if approval else None,
        )

    if decision.mode == "dry-run":
        return ResumenPiloto(
            provider=provider_name,
            mode="dry-run",
            requested_jobs=requested_jobs,
            authorized_jobs=authorized_jobs,
            executed_jobs=0,
            blocked_jobs=0,
            estimated_cost_usd=estimated,
            circuit_state=breaker.load()["state"],
            approval_id=approval.approval_id if approval else None,
        )

    provider = construir_proveedor(provider_name)
    processor = ProcesadorTrabajosMultimedia(
        queue=queue,
        provider=provider,
        storage=AlmacenamientoLocalRMR(
            root=storage_root,
            rmr_database=rmr_database,
        ),
        events=PublicadorEventosArchivo(events_path),
        worker_id="SPT-003C-pilot",
    )

    summary = processor.process_batch(limit=authorized_jobs)
    executed = int(summary["completed"])

    if int(summary["failed"]) > 0:
        breaker.record_failure()
    else:
        breaker.record_success()

    ledger = LibroConsumo(ledger_path)
    if executed > 0:
        ledger.append(
            RegistroConsumo(
                provider=provider_name,
                job_type="batch",
                units=executed,
                estimated_cost_usd=estimated,
                metadata={
                    "mode": decision.mode,
                    "approval_id": (
                        approval.approval_id if approval else None
                    ),
                },
            )
        )

    return ResumenPiloto(
        provider=provider_name,
        mode=decision.mode,
        requested_jobs=requested_jobs,
        authorized_jobs=authorized_jobs,
        executed_jobs=executed,
        blocked_jobs=requested_jobs - authorized_jobs,
        estimated_cost_usd=estimated,
        circuit_state=breaker.load()["state"],
        approval_id=approval.approval_id if approval else None,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--jobs",
        default=(
            "artifacts/automation/SPT-003A/"
            "multimedia-jobs.sqlite3"
        ),
    )
    parser.add_argument(
        "--storage",
        default="artifacts/automation/SPT-003C/media",
    )
    parser.add_argument(
        "--events",
        default=(
            "artifacts/automation/SPT-003C/"
            "multimedia-events.jsonl"
        ),
    )
    parser.add_argument(
        "--rmr",
        default="artifacts/media/ADR-010/rmr.sqlite3",
    )
    parser.add_argument("--provider", default="mock")
    parser.add_argument("--limit", type=int, default=2)
    parser.add_argument(
        "--pricing",
        default="config/automation/SPT-003C-pricing-template.json",
    )
    parser.add_argument("--approval")
    parser.add_argument("--live", action="store_true")
    parser.add_argument(
        "--ledger",
        default=(
            "artifacts/automation/SPT-003C/"
            "consumption-ledger.jsonl"
        ),
    )
    parser.add_argument(
        "--circuit",
        default=(
            "artifacts/automation/SPT-003C/"
            "circuit-breaker.json"
        ),
    )
    parser.add_argument(
        "--summary",
        default=(
            "artifacts/automation/SPT-003C/"
            "pilot-summary.json"
        ),
    )
    args = parser.parse_args()

    pricing = json.loads(
        Path(args.pricing).read_text(encoding="utf-8")
    )

    summary = run_pilot(
        jobs_database=args.jobs,
        storage_root=args.storage,
        events_path=args.events,
        rmr_database=args.rmr,
        provider_name=args.provider,
        requested_jobs=args.limit,
        pricing=pricing,
        approval_path=args.approval,
        dry_run=not args.live,
        ledger_path=args.ledger,
        circuit_path=args.circuit,
    )

    summary_path = Path(args.summary)
    summary_path.parent.mkdir(parents=True, exist_ok=True)
    summary_path.write_text(
        json.dumps(
            asdict(summary),
            ensure_ascii=False,
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )

    print("SPT-003C ejecutado correctamente.")
    print(f"Proveedor: {summary.provider}")
    print(f"Modo: {summary.mode}")
    print(f"Solicitados: {summary.requested_jobs}")
    print(f"Autorizados: {summary.authorized_jobs}")
    print(f"Ejecutados: {summary.executed_jobs}")
    print(f"Costo estimado USD: {summary.estimated_cost_usd}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
'@

$InitContent = @'
"""Piloto controlado de proveedores SPT-003C."""

from __future__ import annotations

from typing import Any

__all__ = [
    "AprobacionPiloto",
    "CircuitBreaker",
    "DecisionPiloto",
    "LibroConsumo",
    "RegistroConsumo",
    "ResumenPiloto",
    "evaluate_activation",
    "estimate_cost",
    "load_approval",
    "run_pilot",
]


def __getattr__(name: str) -> Any:
    if name not in __all__:
        raise AttributeError(name)

    if name in {
        "AprobacionPiloto",
        "DecisionPiloto",
        "RegistroConsumo",
        "ResumenPiloto",
    }:
        from . import models
        return getattr(models, name)

    if name in {"LibroConsumo", "estimate_cost"}:
        from . import budget
        return getattr(budget, name)

    if name == "CircuitBreaker":
        from . import circuit_breaker
        return getattr(circuit_breaker, name)

    if name in {"evaluate_activation", "load_approval"}:
        from . import governance
        return getattr(governance, name)

    if name == "run_pilot":
        from . import runner
        return getattr(runner, name)

    raise AttributeError(name)
'@

$TestContent = @'
"""Pruebas SPT-003C del piloto controlado."""

import json
from datetime import datetime, timedelta, timezone
from pathlib import Path

from sgoda.automation.pilot.budget import LibroConsumo, estimate_cost
from sgoda.automation.pilot.circuit_breaker import CircuitBreaker
from sgoda.automation.pilot.governance import evaluate_activation
from sgoda.automation.pilot.models import (
    AprobacionPiloto,
    RegistroConsumo,
)


def _approval(**overrides) -> AprobacionPiloto:
    payload = {
        "approval_id": "APR-001",
        "provider": "openai-image",
        "approved_by": "PMO Digital",
        "approved_at_utc": datetime.now(
            timezone.utc
        ).isoformat(),
        "expires_at_utc": (
            datetime.now(timezone.utc) + timedelta(days=30)
        ).isoformat(),
        "administrative_approved": True,
        "cultural_approved": True,
        "privacy_approved": True,
        "budget_approved": True,
        "live_calls_authorized": True,
        "allowed_job_types": ["generate_image"],
        "max_jobs": 5,
        "max_cost_usd": 10.0,
    }
    payload.update(overrides)
    return AprobacionPiloto(**payload)


def test_SPT_003C_dry_run_siempre_permitido() -> None:
    result = evaluate_activation(
        provider="openai-image",
        requested_jobs=100,
        estimated_cost_usd=999.0,
        job_types=["generate_image"],
        approval=None,
        dry_run=True,
    )

    assert result.allowed is True
    assert result.mode == "dry-run"


def test_SPT_003C_bloquea_sin_aprobacion(
    monkeypatch,
) -> None:
    monkeypatch.setenv("OPENAI_API_KEY", "test")
    result = evaluate_activation(
        provider="openai-image",
        requested_jobs=1,
        estimated_cost_usd=1.0,
        job_types=["generate_image"],
        approval=None,
        dry_run=False,
    )

    assert result.allowed is False
    assert "No existe aprobación institucional." in result.reasons


def test_SPT_003C_bloquea_sin_validacion_cultural(
    monkeypatch,
) -> None:
    monkeypatch.setenv("OPENAI_API_KEY", "test")
    result = evaluate_activation(
        provider="openai-image",
        requested_jobs=1,
        estimated_cost_usd=1.0,
        job_types=["generate_image"],
        approval=_approval(cultural_approved=False),
        dry_run=False,
    )

    assert result.allowed is False
    assert any("cultural_approved" in item for item in result.reasons)


def test_SPT_003C_bloquea_presupuesto_excedido(
    monkeypatch,
) -> None:
    monkeypatch.setenv("OPENAI_API_KEY", "test")
    result = evaluate_activation(
        provider="openai-image",
        requested_jobs=1,
        estimated_cost_usd=20.0,
        job_types=["generate_image"],
        approval=_approval(max_cost_usd=10.0),
        dry_run=False,
    )

    assert result.allowed is False
    assert any("presupuesto" in item for item in result.reasons)


def test_SPT_003C_bloquea_tipo_no_autorizado(
    monkeypatch,
) -> None:
    monkeypatch.setenv("OPENAI_API_KEY", "test")
    result = evaluate_activation(
        provider="openai-image",
        requested_jobs=1,
        estimated_cost_usd=1.0,
        job_types=["generate_tts"],
        approval=_approval(),
        dry_run=False,
    )

    assert result.allowed is False
    assert any("no autorizados" in item for item in result.reasons)


def test_SPT_003C_aprueba_con_todos_los_controles(
    monkeypatch,
) -> None:
    monkeypatch.setenv("OPENAI_API_KEY", "test")
    result = evaluate_activation(
        provider="openai-image",
        requested_jobs=1,
        estimated_cost_usd=1.0,
        job_types=["generate_image"],
        approval=_approval(),
        dry_run=False,
    )

    assert result.allowed is True
    assert result.mode == "live"


def test_SPT_003C_estimacion_costos() -> None:
    pricing = {
        "openai-image": {
            "generate_image": 0.04,
        }
    }

    assert estimate_cost(
        provider="openai-image",
        job_type="generate_image",
        units=10,
        pricing=pricing,
    ) == 0.4


def test_SPT_003C_libro_consumo(tmp_path: Path) -> None:
    ledger = LibroConsumo(tmp_path / "ledger.jsonl")
    ledger.append(
        RegistroConsumo(
            provider="mock",
            job_type="batch",
            units=2,
            estimated_cost_usd=0.5,
        )
    )
    ledger.append(
        RegistroConsumo(
            provider="mock",
            job_type="batch",
            units=1,
            estimated_cost_usd=0.25,
        )
    )

    assert ledger.total_cost() == 0.75


def test_SPT_003C_circuit_breaker_abre(
    tmp_path: Path,
) -> None:
    breaker = CircuitBreaker(
        path=tmp_path / "circuit.json",
        failure_threshold=2,
    )

    breaker.record_failure()
    assert breaker.allow_request() is True

    breaker.record_failure()
    assert breaker.load()["state"] == "open"
    assert breaker.allow_request() is False


def test_SPT_003C_circuit_breaker_cierra(
    tmp_path: Path,
) -> None:
    breaker = CircuitBreaker(
        path=tmp_path / "circuit.json",
    )

    breaker.record_failure()
    breaker.record_success()

    assert breaker.load()["state"] == "closed"
    assert breaker.load()["failure_count"] == 0
'@

$PolicyContent = @'
{
  "increment_code": "SPT-003C",
  "version": "0.1.0",
  "policy_name": "Piloto Controlado de Proveedores Reales",
  "default_mode": "dry-run",
  "live_calls_default": false,
  "mandatory_approvals": [
    "administrative",
    "cultural",
    "privacy",
    "budget",
    "live_calls"
  ],
  "credential_storage": "environment_variables_only",
  "human_review_required": true,
  "cultural_review_required": true,
  "budget_control_required": true,
  "circuit_breaker_required": true,
  "consumption_ledger_required": true,
  "maximum_initial_pilot_jobs": 5,
  "governed_by": "SGD-114-v2.0.1"
}
'@

$ApprovalTemplateContent = @'
{
  "approval_id": "PENDING",
  "provider": "openai-image",
  "approved_by": "PENDING",
  "approved_at_utc": "PENDING",
  "expires_at_utc": "PENDING",
  "administrative_approved": false,
  "cultural_approved": false,
  "privacy_approved": false,
  "budget_approved": false,
  "live_calls_authorized": false,
  "allowed_job_types": [],
  "max_jobs": 0,
  "max_cost_usd": 0.0
}
'@

$PricingTemplateContent = @'
{
  "mock": {
    "generate_image": 0.0,
    "generate_tts": 0.0,
    "record_native_audio": 0.0
  },
  "openai-image": {
    "generate_image": 0.0
  },
  "google-tts": {
    "generate_tts": 0.0
  },
  "azure-speech": {
    "generate_tts": 0.0
  }
}
'@

$ComponentContent = @'
{
  "increment_code": "SPT-003C",
  "name": "Piloto Controlado de Proveedores Reales",
  "component_type": "controlled_provider_pilot",
  "version": "0.1.0",
  "status": "technically_completed",
  "entrypoint": "sgoda.automation.pilot.runner",
  "source": [
    "src/sgoda/automation/pilot/models.py",
    "src/sgoda/automation/pilot/governance.py",
    "src/sgoda/automation/pilot/budget.py",
    "src/sgoda/automation/pilot/circuit_breaker.py",
    "src/sgoda/automation/pilot/runner.py"
  ],
  "tests": [
    "tests/automation/test_SPT_003C_controlled_provider_pilot.py"
  ],
  "governed_by": "SGD-114-v2.0.1"
}
'@

$DocContent = @'
# SPT-003C — Piloto Controlado de Proveedores Reales

## Objetivo

Permitir la activación gradual de proveedores reales de imagen o TTS sin
comprometer presupuesto, privacidad, soberanía cultural ni trazabilidad.

## Estado predeterminado

Toda ejecución comienza en `dry-run`. No se realizan llamadas externas.

## Controles obligatorios

- aprobación administrativa;
- aprobación cultural;
- aprobación de privacidad;
- aprobación presupuestal;
- autorización de llamadas reales;
- variables de entorno para secretos;
- límite de trabajos;
- límite de costo;
- circuit breaker;
- libro de consumo;
- revisión humana.

## Alcance v0.1.0

Se implementa el gobierno técnico del piloto. Los precios del proveedor
deben ser actualizados institucionalmente antes de cualquier activación.
'@

$ProtocolContent = @'
# SPT-003C — Protocolo de Aprobación Cultural

Un recurso generado por IA no se incorpora automáticamente al RMR
productivo.

Debe pasar por:

1. revisión lingüística;
2. revisión de un hablante o autoridad Puinave;
3. revisión de pertinencia cultural;
4. verificación de ausencia de estereotipos;
5. verificación de consentimiento;
6. aprobación de uso educativo;
7. registro de la decisión y de la persona revisora.

Las aprobaciones técnicas no sustituyen la autoridad cultural.
'@

$InvokeContent = @'
[CmdletBinding()]
param(
    [string]$Provider = "mock",
    [int]$Limit = 2,
    [string]$ApprovalPath = "",
    [switch]$Live
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

$Arguments = @(
    "-m",
    "sgoda.automation.pilot.runner",
    "--provider",
    $Provider,
    "--limit",
    $Limit,
    "--pricing",
    "config/automation/SPT-003C-pricing-template.json"
)

if (-not [string]::IsNullOrWhiteSpace($ApprovalPath)) {
    $Arguments += @("--approval", $ApprovalPath)
}

if ($Live) {
    $Arguments += "--live"
}

& python @Arguments

if ($LASTEXITCODE -ne 0) {
    throw "SPT-003C terminó con errores."
}
'@

Write-Step "Instalando SPT-003C"

Write-Utf8NoBom -Path $ModelsPath -Content $ModelsContent
Write-Utf8NoBom -Path $GovernancePath -Content $GovernanceContent
Write-Utf8NoBom -Path $BudgetPath -Content $BudgetContent
Write-Utf8NoBom -Path $CircuitPath -Content $CircuitContent
Write-Utf8NoBom -Path $RunnerPath -Content $RunnerContent
Write-Utf8NoBom -Path $InitPath -Content $InitContent
Write-Utf8NoBom -Path $TestPath -Content $TestContent
Write-Utf8NoBom -Path $PolicyPath -Content $PolicyContent
Write-Utf8NoBom -Path $ApprovalTemplatePath -Content $ApprovalTemplateContent
Write-Utf8NoBom -Path $PricingTemplatePath -Content $PricingTemplateContent
Write-Utf8NoBom -Path $ComponentPath -Content $ComponentContent
Write-Utf8NoBom -Path $DocPath -Content $DocContent
Write-Utf8NoBom -Path $ProtocolPath -Content $ProtocolContent
Write-Utf8NoBom -Path $InvokePath -Content $InvokeContent

Write-Step "Generando evidencia y trazabilidad"

$Timestamp = [DateTime]::UtcNow.ToString("o")

$Evidence = [ordered]@{
    increment_code = "SPT-003C"
    version = "0.1.0"
    status = "implemented"
    generated_at_utc = $Timestamp
    default_mode = "dry-run"
    live_calls_executed = $false
    controls = @(
        "administrative_approval",
        "cultural_approval",
        "privacy_approval",
        "budget_approval",
        "secret_validation",
        "cost_estimation",
        "consumption_ledger",
        "circuit_breaker"
    )
}
Write-JsonUtf8 -Path $EvidencePath -Data $Evidence

$Trace = [ordered]@{
    increment_code = "SPT-003C"
    generated_at_utc = $Timestamp
    source = @(
        "src/sgoda/automation/pilot/"
    )
    tests = @(
        "tests/automation/test_SPT_003C_controlled_provider_pilot.py"
    )
    documentation = @(
        "docs/05_Fase_Tecnologica/SPT-003/SPT-003C-Piloto-Controlado-Proveedores.md",
        "docs/05_Fase_Tecnologica/SPT-003/SPT-003C-Protocolo-Aprobacion-Cultural.md"
    )
    evidence = @(
        "artifacts/pmo/SPT-003C/implementation-evidence.json"
    )
}
Write-JsonUtf8 -Path $TracePath -Data $Trace

Write-Step "Validando sintaxis e importaciones"

& python -m py_compile `
    "src/sgoda/automation/pilot/models.py" `
    "src/sgoda/automation/pilot/governance.py" `
    "src/sgoda/automation/pilot/budget.py" `
    "src/sgoda/automation/pilot/circuit_breaker.py" `
    "src/sgoda/automation/pilot/runner.py"

if ($LASTEXITCODE -ne 0) {
    throw "La compilación de SPT-003C falló."
}

& python -c "from sgoda.automation.pilot import evaluate_activation, CircuitBreaker, run_pilot; print(evaluate_activation.__name__, CircuitBreaker.__name__, run_pilot.__name__)"

if ($LASTEXITCODE -ne 0) {
    throw "Falló la importación de SPT-003C."
}

Write-Step "Ejecutando 10 pruebas específicas SPT-003C"

& python -m pytest `
    "tests/automation/test_SPT_003C_controlled_provider_pilot.py" `
    -q

if ($LASTEXITCODE -ne 0) {
    throw "Las pruebas específicas SPT-003C fallaron."
}

if (-not $SkipFullSuite) {
    Write-Step "Ejecutando suite completa"

    & python -m pytest

    if ($LASTEXITCODE -ne 0) {
        throw "La suite completa terminó con errores."
    }
}

Write-Step "Ejecutando piloto institucional en dry-run"

& python -m sgoda.automation.pilot.runner `
    --provider "openai-image" `
    --limit 2 `
    --pricing "config/automation/SPT-003C-pricing-template.json" `
    --summary "artifacts/automation/SPT-003C/pilot-summary.json"

if ($LASTEXITCODE -ne 0) {
    throw "El piloto dry-run SPT-003C falló."
}

$SummaryPath = Join-Path $ArtifactsDir "pilot-summary.json"
Assert-Path -Path $SummaryPath -Description "pilot-summary.json"

$Summary = Get-Content -LiteralPath $SummaryPath -Raw |
    ConvertFrom-Json

if ($Summary.mode -ne "dry-run") {
    throw "El piloto institucional debía ejecutarse en dry-run."
}

if ([int]$Summary.executed_jobs -ne 0) {
    throw "El dry-run no debe ejecutar trabajos reales."
}

Write-Step "Publicando release técnico"

if (-not (Test-Path -LiteralPath $ReleaseDir)) {
    New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null
}

foreach ($Artifact in @(
    $SummaryPath,
    $PolicyPath,
    $ApprovalTemplatePath,
    $PricingTemplatePath,
    $ComponentPath,
    $DocPath,
    $ProtocolPath
)) {
    Copy-Item `
        -LiteralPath $Artifact `
        -Destination (Join-Path $ReleaseDir (Split-Path $Artifact -Leaf)) `
        -Force
}

Write-Step "Ejecutando quality gate SGD-114"

& python -m sgoda.governance.evidence_policy `
    --root "$ProjectRoot" `
    --policy "config/governance/sgd-114-policy.json" `
    --increment "SPT-003C" `
    --status "technically_completed" `
    --output "$GatePath"

if ($LASTEXITCODE -ne 0) {
    throw "El quality gate SPT-003C no fue aprobado."
}

$Gate = Get-Content -LiteralPath $GatePath -Raw |
    ConvertFrom-Json

if (-not $Gate.passed) {
    throw "SPT-003C no contiene passed=true."
}

$Dashboard = [ordered]@{
    increment_code = "SPT-003C"
    version = "0.1.0"
    status = "technically_completed"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    default_mode = "dry-run"
    live_calls_executed = $false
    pilot_provider = $Summary.provider
    pilot_requested_jobs = $Summary.requested_jobs
    pilot_authorized_jobs = $Summary.authorized_jobs
    pilot_executed_jobs = $Summary.executed_jobs
    mandatory_approvals = 5
    secrets_policy = "environment_variables_only"
    budget_control = $true
    circuit_breaker = $true
    cultural_review = $true
    specific_tests = 10
    expected_total_tests = 139
    quality_gate = "approved"
    release = "SPT-003C-v0.1.0"
}
Write-JsonUtf8 -Path $DashboardPath -Data $Dashboard

Write-Step "Actualizando documentación maestra SGD-115"

& python -m sgoda.documentation.master_docs `
    --root "$ProjectRoot" `
    --output "artifacts/documentation/SGD-115"

if ($LASTEXITCODE -ne 0) {
    throw "La actualización documental SGD-115 falló."
}

Write-Step "Resultado final"

Write-Host "SPT-003C implementado y validado." -ForegroundColor Green
Write-Host "Pruebas específicas: 10 APROBADAS." -ForegroundColor Green
Write-Host "Suite total esperada desde 129: 139 pruebas." -ForegroundColor Cyan
Write-Host "Piloto institucional: DRY-RUN APROBADO." -ForegroundColor Green
Write-Host "Llamadas externas ejecutadas: 0." -ForegroundColor Green
Write-Host "Aprobación cultural: OBLIGATORIA." -ForegroundColor Green
Write-Host "Control presupuestal: IMPLEMENTADO." -ForegroundColor Green
Write-Host "Circuit breaker: IMPLEMENTADO." -ForegroundColor Green
Write-Host "Quality gate: APROBADO." -ForegroundColor Green
Write-Host "Documentación maestra: ACTUALIZADA." -ForegroundColor Green
Write-Host "Release: releases\SPT-003C-v0.1.0" -ForegroundColor Cyan
