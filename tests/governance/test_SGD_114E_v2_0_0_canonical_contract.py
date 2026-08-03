from __future__ import annotations

from pathlib import Path

from sgoda.governance.native_ecosystem_validator import (
    evaluate_native_ecosystem,
)


def test_canonical_implementation_version(
    tmp_path: Path,
) -> None:
    result = evaluate_native_ecosystem(tmp_path)

    assert result.implementation_version == "2.0.0"


def test_historical_mapping_contract(
    tmp_path: Path,
) -> None:
    result = evaluate_native_ecosystem(tmp_path)

    assert result["version"] == "1.0.3"


def test_historical_attribute_contract(
    tmp_path: Path,
) -> None:
    result = evaluate_native_ecosystem(tmp_path)

    assert result.version == "1.0.5"


def test_empty_repository_policy_and_state(
    tmp_path: Path,
) -> None:
    result = evaluate_native_ecosystem(tmp_path)

    assert result["criteria"]["empty_repository_allowed"] is True
    assert result.repository_is_empty is True


def test_exit_code_matches_approval(
    tmp_path: Path,
) -> None:
    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is True
    assert result.exit_code == 0


def test_native_components_attribute_is_tuple(
    tmp_path: Path,
) -> None:
    result = evaluate_native_ecosystem(tmp_path)

    assert isinstance(result.native_components, tuple)


def test_to_dict_is_json_ready(
    tmp_path: Path,
) -> None:
    payload = evaluate_native_ecosystem(
        tmp_path
    ).to_dict()

    assert isinstance(payload, dict)
    assert payload["implementation_version"] == "2.0.0"