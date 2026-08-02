from __future__ import annotations

import json
from pathlib import Path

import pytest

from sgoda.operational_platform import (
    OperationalPlatformService,
    OperationalRequest,
    OperationalSettings,
)
from sgoda.operational_platform.n8n_contracts import (
    lexical_entry_event,
)
from sgoda.operational_platform.rlb_adapter import load_rlb


def _settings(tmp_path: Path) -> Path:
    path = tmp_path / "settings.json"
    path.write_text(
        json.dumps(
            {
                "database_url": "sqlite:///demo.db",
                "database_mode": "local",
                "api_host": "127.0.0.1",
                "api_port": 8000,
                "n8n_enabled": False,
                "flutter_contract_enabled": True,
                "require_validated_entries": True,
                "no_invention": True,
            }
        ),
        encoding="utf-8",
    )
    return path


def _rlb(tmp_path: Path) -> Path:
    path = tmp_path / "rlb.json"
    path.write_text(
        json.dumps(
            {
                "entries": [
                    {
                        "entry_id": "LEX-001",
                        "puinave": "AMDA",
                        "spanish": "casa",
                        "english_us": "house",
                        "italian": "casa",
                        "validated": True,
                        "category": "sustantivo",
                    },
                    {
                        "entry_id": "LEX-999",
                        "puinave": "NO-VALIDADO",
                        "validated": False,
                    },
                ]
            }
        ),
        encoding="utf-8",
    )
    return path


def _media(tmp_path: Path) -> Path:
    path = tmp_path / "media.json"
    path.write_text(
        json.dumps(
            {
                "resources": [
                    {
                        "entry_id": "LEX-001",
                        "media_type": "audio_puinave",
                        "uri": "media/audio/LEX-001-pu.wav",
                        "validated": True,
                        "autoplay": True,
                    },
                    {
                        "entry_id": "LEX-001",
                        "media_type": "image",
                        "uri": "media/images/LEX-001.webp",
                        "validated": True,
                        "autoplay": True,
                    },
                ]
            }
        ),
        encoding="utf-8",
    )
    return path


def _service(tmp_path: Path) -> OperationalPlatformService:
    service = OperationalPlatformService(
        OperationalSettings.from_json(
            _settings(tmp_path)
        )
    )
    service.load_sources(
        _rlb(tmp_path),
        _media(tmp_path),
    )
    return service


def test_SPT_011_loads_validated_rlb(tmp_path: Path) -> None:
    records = load_rlb(_rlb(tmp_path), validated_only=True)

    assert len(records) == 1
    assert records[0]["entry_id"] == "LEX-001"


def test_SPT_011_reports_healthy_runtime(tmp_path: Path) -> None:
    response = _service(tmp_path).execute(
        OperationalRequest(operation="health")
    )

    assert response.status == "ok"
    assert response.data["healthy"] is True
    assert response.data["entry_count"] == 1


def test_SPT_011_builds_flutter_lexical_card(
    tmp_path: Path,
) -> None:
    response = _service(tmp_path).execute(
        OperationalRequest(
            operation="get_lexical_card",
            entry_id="LEX-001",
        )
    )

    assert response.status == "ok"
    assert response.data["languages"]["pu"] == "AMDA"
    assert response.data["languages"]["en-US"] == "house"
    assert response.data["noInvention"] is True


def test_SPT_011_includes_validated_media(
    tmp_path: Path,
) -> None:
    response = _service(tmp_path).execute(
        OperationalRequest(
            operation="get_lexical_card",
            entry_id="LEX-001",
        )
    )

    assert len(response.data["media"]) == 2
    assert response.data["media"][0]["validated"] is True


def test_SPT_011_returns_not_found_without_invention(
    tmp_path: Path,
) -> None:
    response = _service(tmp_path).execute(
        OperationalRequest(
            operation="get_lexical_card",
            entry_id="UNKNOWN",
        )
    )

    assert response.status == "not_found"
    assert response.no_invention is True
    assert response.data == {}


def test_SPT_011_lists_entries(tmp_path: Path) -> None:
    response = _service(tmp_path).execute(
        OperationalRequest(operation="list_entries")
    )

    assert response.status == "ok"
    assert response.data["total"] == 1


def test_SPT_011_builds_n8n_event(tmp_path: Path) -> None:
    response = _service(tmp_path).execute(
        OperationalRequest(
            operation="n8n_event",
            entry_id="LEX-001",
            payload={"event_operation": "validated"},
        )
    )

    assert response.status == "ok"
    assert response.data["event_type"] == (
        "sgoda.lexical.validated"
    )
    assert response.data["delivery_enabled"] is False


def test_SPT_011_n8n_event_is_idempotent() -> None:
    first = lexical_entry_event(
        "LEX-001",
        "validated",
    )
    second = lexical_entry_event(
        "LEX-001",
        "validated",
    )

    assert first == second


def test_SPT_011_rejects_unknown_n8n_operation() -> None:
    with pytest.raises(ValueError):
        lexical_entry_event(
            "LEX-001",
            "unknown",
        )


def test_SPT_011_rejects_unsupported_operation(
    tmp_path: Path,
) -> None:
    response = _service(tmp_path).execute(
        OperationalRequest(operation="unknown")
    )

    assert response.status == "unsupported_operation"
    assert response.warnings


def test_SPT_011_is_deterministic(tmp_path: Path) -> None:
    service = _service(tmp_path)
    request = OperationalRequest(
        operation="get_lexical_card",
        entry_id="LEX-001",
    )

    assert service.execute(request) == service.execute(request)


def test_SPT_011_preserves_four_languages(
    tmp_path: Path,
) -> None:
    response = _service(tmp_path).execute(
        OperationalRequest(
            operation="get_lexical_card",
            entry_id="LEX-001",
        )
    )

    assert set(response.data["languages"]) == {
        "pu",
        "es",
        "en-US",
        "it",
    }


def test_SPT_011_runtime_status_is_explicit(
    tmp_path: Path,
) -> None:
    status = _service(tmp_path).runtime_status()

    assert status.database_mode == "local"
    assert status.rlb_loaded is True
    assert status.media_loaded is True
    assert status.api_enabled is True


def test_SPT_011_settings_are_loaded(tmp_path: Path) -> None:
    settings = OperationalSettings.from_json(
        _settings(tmp_path)
    )

    assert settings.api_port == 8000
    assert settings.no_invention is True