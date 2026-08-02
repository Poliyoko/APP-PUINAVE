"""Pruebas SPT-006A v0.2.0."""

import json
from pathlib import Path

import pytest

from sgoda.language_engine.diagnostic import run_diagnostic
from sgoda.language_engine.engine import FreeLocalLanguageEngine
from sgoda.language_engine.licensing import (
    ModelBlockedError,
    approved_models,
    load_allowlist,
    validate_model,
)
from sgoda.language_engine.models import ModelLicenseRecord
from sgoda.language_engine.translation import ArgosLocalTranslator


def _allowlist(tmp_path: Path) -> Path:
    path = tmp_path / "allowlist.json"
    path.write_text(
        json.dumps(
            {
                "models": [
                    {
                        "model_id": "en-us-approved",
                        "purpose": "tts",
                        "language": "English",
                        "locale": "en-US",
                        "provider": "piper",
                        "local": True,
                        "requires_payment": False,
                        "requires_api_key": False,
                        "license_name": "TEST-OPEN",
                        "license_url": "https://example.test/license",
                        "model_card_verified": True,
                        "approved": True,
                        "checksum_sha256": None,
                        "metadata": {},
                    },
                    {
                        "model_id": "it-it-blocked",
                        "purpose": "tts",
                        "language": "Italian",
                        "locale": "it-IT",
                        "provider": "piper",
                        "local": True,
                        "requires_payment": False,
                        "requires_api_key": False,
                        "license_name": None,
                        "license_url": None,
                        "model_card_verified": False,
                        "approved": False,
                        "checksum_sha256": None,
                        "metadata": {},
                    },
                ]
            }
        ),
        encoding="utf-8",
    )
    return path


def test_SPT_006A_loads_allowlist(tmp_path):
    assert len(load_allowlist(_allowlist(tmp_path))) == 2


def test_SPT_006A_accepts_free_verified_model():
    model = ModelLicenseRecord(
        model_id="ok",
        purpose="tts",
        language="English",
        locale="en-US",
        provider="piper",
        local=True,
        requires_payment=False,
        requires_api_key=False,
        license_name="OPEN",
        license_url="https://example.test",
        model_card_verified=True,
        approved=True,
    )
    validate_model(model)


def test_SPT_006A_blocks_paid_model():
    model = ModelLicenseRecord(
        model_id="paid",
        purpose="tts",
        language="English",
        locale="en-US",
        provider="piper",
        local=True,
        requires_payment=True,
        requires_api_key=False,
        license_name="COMMERCIAL",
        license_url="https://example.test",
        model_card_verified=True,
        approved=True,
    )
    with pytest.raises(ModelBlockedError):
        validate_model(model)


def test_SPT_006A_blocks_api_key_model():
    model = ModelLicenseRecord(
        model_id="api",
        purpose="tts",
        language="Italian",
        locale="it-IT",
        provider="cloud",
        local=False,
        requires_payment=False,
        requires_api_key=True,
        license_name="UNKNOWN",
        license_url="https://example.test",
        model_card_verified=True,
        approved=True,
    )
    with pytest.raises(ModelBlockedError):
        validate_model(model)


def test_SPT_006A_blocks_unknown_license():
    model = ModelLicenseRecord(
        model_id="unknown",
        purpose="tts",
        language="Italian",
        locale="it-IT",
        provider="piper",
        local=True,
        requires_payment=False,
        requires_api_key=False,
        license_name=None,
        license_url=None,
        model_card_verified=False,
        approved=False,
    )
    with pytest.raises(ModelBlockedError):
        validate_model(model)


def test_SPT_006A_filters_approved_models(tmp_path):
    models = approved_models(
        _allowlist(tmp_path),
        purpose="tts",
        locale="en-US",
    )
    assert [item.model_id for item in models] == [
        "en-us-approved"
    ]


def test_SPT_006A_diagnostic_is_offline(tmp_path):
    result = run_diagnostic(tmp_path / "models")
    assert result["internet_required_for_runtime"] is False
    assert result["api_keys_required"] is False
    assert result["paid_services_enabled"] is False


def test_SPT_006A_argos_inventory_is_safe():
    assert isinstance(ArgosLocalTranslator.available_pairs(), list)


def test_SPT_006A_engine_reports_required_locales(
    tmp_path,
):
    engine = FreeLocalLanguageEngine(
        allowlist_path=_allowlist(tmp_path),
        models_root=tmp_path / "models",
    )
    inventory = engine.translation_inventory()
    assert {"source": "es", "target": "en"} in (
        inventory["required_pairs"]
    )
    assert {"source": "es", "target": "it"} in (
        inventory["required_pairs"]
    )


def test_SPT_006A_engine_reports_en_us(tmp_path):
    engine = FreeLocalLanguageEngine(
        allowlist_path=_allowlist(tmp_path),
        models_root=tmp_path / "models",
    )
    assert engine.diagnostic()[
        "approved_tts_models_en_us"
    ] == 1


def test_SPT_006A_engine_blocks_unapproved_it_it(
    tmp_path,
):
    engine = FreeLocalLanguageEngine(
        allowlist_path=_allowlist(tmp_path),
        models_root=tmp_path / "models",
    )
    assert engine.diagnostic()[
        "approved_tts_models_it_it"
    ] == 0


def test_SPT_006A_publishes_diagnostic(tmp_path):
    engine = FreeLocalLanguageEngine(
        allowlist_path=_allowlist(tmp_path),
        models_root=tmp_path / "models",
    )
    path = engine.publish_diagnostic(
        tmp_path / "diagnostic.json"
    )
    payload = json.loads(path.read_text(encoding="utf-8"))
    assert payload["policy"]["paid_services_allowed"] is False
    assert payload["policy"]["unknown_license_policy"] == "block"