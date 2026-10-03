import inspect
import json
from pathlib import Path

import pytest

from sgoda.integration.real508_adapter import Real508StorageConfig
from sgoda.integration.real508_lexical_integration import (
    build_real508_lexical_entry,
    load_real508_into_operational_repository,
)
from sgoda.operational_platform.api import create_app
from sgoda.operational_platform.database import OperationalRepository
from sgoda.operational_platform.models import OperationalRequest
from sgoda.operational_platform.service import OperationalPlatformService
from sgoda.operational_platform.settings import OperationalSettings


ROOT = Path(__file__).resolve().parents[2]


def _config():
    payload = json.loads(
        (
            ROOT
            / "config"
            / "real508"
            / "media-storage.json"
        ).read_text(encoding="utf-8")
    )
    return Real508StorageConfig.from_dict(payload)


def _settings_path():
    candidates = sorted(
        (
            ROOT
            / "config"
        ).rglob("*.json")
    )

    for candidate in candidates:
        try:
            OperationalSettings.from_json(candidate)
        except Exception:
            continue
        return candidate

    pytest.skip("No se encontró configuración OperationalSettings válida.")


def _rlb_path():
    candidates = sorted(
        (
            ROOT
            / "tests"
        ).rglob("*.json")
    )

    for candidate in candidates:
        try:
            text = candidate.read_text(encoding="utf-8")
        except Exception:
            continue

        if "entry_id" in text:
            return candidate

    pytest.skip("No se encontró fixture RLB JSON compatible.")


def test_create_app_accepts_repository_injection():
    parameters = inspect.signature(create_app).parameters

    assert "repository" in parameters
    assert parameters["repository"].default is None


def test_real508_repository_contract_reaches_operational_service():
    config = _config()
    repository = OperationalRepository()

    entry = build_real508_lexical_entry(
        lexical_id="000001",
        config=config,
        puinave="CANARIO-R26",
        spanish="CANARIO-R26-ES",
    )

    processed = load_real508_into_operational_repository(
        repository=repository,
        entries=(entry,),
    )

    assert processed == 1
    assert repository.count() == 1

    settings = OperationalSettings.from_json(
        _settings_path()
    )

    service = OperationalPlatformService(
        settings,
        repository=repository,
    )

    response = service.execute(
        OperationalRequest(
            operation="get_lexical_card",
            entry_id="000001",
        )
    )

    assert response.status == "ok"
    assert response.data
    assert response.sources == ("RLB:000001",)


def test_real508_media_reaches_lexical_card():
    config = _config()
    repository = OperationalRepository()

    entry = build_real508_lexical_entry(
        lexical_id="000508",
        config=config,
        puinave="CANARIO-R26-508",
        spanish="CANARIO-R26-508-ES",
    )

    load_real508_into_operational_repository(
        repository=repository,
        entries=(entry,),
    )

    settings = OperationalSettings.from_json(
        _settings_path()
    )

    service = OperationalPlatformService(
        settings,
        repository=repository,
    )

    response = service.execute(
        OperationalRequest(
            operation="get_lexical_card",
            entry_id="000508",
        )
    )

    assert response.status == "ok"

    serialized = json.dumps(
        response.data,
        ensure_ascii=False,
    )

    assert "000508.mp3" in serialized
    assert '"pu"' in serialized


def test_existing_not_found_contract_is_preserved():
    repository = OperationalRepository()

    settings = OperationalSettings.from_json(
        _settings_path()
    )

    service = OperationalPlatformService(
        settings,
        repository=repository,
    )

    response = service.execute(
        OperationalRequest(
            operation="get_lexical_card",
            entry_id="999999",
        )
    )

    assert response.status == "not_found"
    assert response.data == {}


def test_create_app_keeps_existing_required_sources():
    parameters = inspect.signature(create_app).parameters

    assert "settings_path" in parameters
    assert "rlb_path" in parameters
    assert "media_path" in parameters

    assert parameters["media_path"].default is None


def test_no_parallel_real508_endpoint_is_declared():
    source = inspect.getsource(create_app)

    assert '/lexical/{entry_id}' in source
    assert "/real508/" not in source.lower()
