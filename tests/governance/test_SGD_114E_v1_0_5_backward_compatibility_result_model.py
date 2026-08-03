from __future__ import annotations

import json
from pathlib import Path

from sgoda.governance.native_ecosystem_models import (
    NativeEcosystemValidationResult,
)
from sgoda.governance.native_ecosystem_validator import (
    evaluate_native_ecosystem,
)


def _write_component(root: Path) -> None:
    target = root / "config" / "test"
    target.mkdir(parents=True, exist_ok=True)
    (target / "component.json").write_text(
        json.dumps(
            {
                "increment_code": "SPT-016A",
                "native_ecosystem": True,
                "mandatory_proprietary_dependencies": [],
            }
        ),
        encoding="utf-8",
    )


def test_result_supports_attribute_access(
    tmp_path: Path,
) -> None:
    _write_component(tmp_path)
    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is True
    assert result.result == "APROBADO"


def test_result_supports_mapping_access(
    tmp_path: Path,
) -> None:
    _write_component(tmp_path)
    result = evaluate_native_ecosystem(tmp_path)

    assert result["approved"] is True
    assert result["result"] == "APROBADO"


def test_result_supports_to_dict(
    tmp_path: Path,
) -> None:
    _write_component(tmp_path)
    result = evaluate_native_ecosystem(tmp_path)
    payload = result.to_dict()

    assert isinstance(payload, dict)
    assert payload["approved"] is True


def test_result_is_dict_subclass(
    tmp_path: Path,
) -> None:
    _write_component(tmp_path)
    result = evaluate_native_ecosystem(tmp_path)

    assert isinstance(result, dict)
    assert isinstance(
        result,
        NativeEcosystemValidationResult,
    )


def test_attribute_and_mapping_values_match(
    tmp_path: Path,
) -> None:
    _write_component(tmp_path)
    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved == result["approved"]
    assert result.native_components == tuple(
        result["native_components"]
    )


def test_copy_preserves_result_model(
    tmp_path: Path,
) -> None:
    _write_component(tmp_path)
    result = evaluate_native_ecosystem(tmp_path)
    copied = result.copy()

    assert isinstance(
        copied,
        NativeEcosystemValidationResult,
    )
    assert copied.approved is True


def test_missing_attribute_raises_attribute_error() -> None:
    result = NativeEcosystemValidationResult()

    try:
        _ = result.missing_property
    except AttributeError:
        pass
    else:
        raise AssertionError(
            "Debe generar AttributeError."
        )


def test_set_attribute_updates_mapping() -> None:
    result = NativeEcosystemValidationResult(
        {"approved": False}
    )
    result.custom_value = "ok"

    assert result["custom_value"] == "ok"


def test_to_dict_returns_independent_copy() -> None:
    result = NativeEcosystemValidationResult(
        {
            "approved": True,
            "criteria": {"a": True},
        }
    )
    payload = result.to_dict()
    payload["criteria"]["a"] = False

    assert result["criteria"]["a"] is True


def test_version_is_1_0_5(
    tmp_path: Path,
) -> None:
    _write_component(tmp_path)
    result = evaluate_native_ecosystem(tmp_path)

    assert result.version == "1.0.5"