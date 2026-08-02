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