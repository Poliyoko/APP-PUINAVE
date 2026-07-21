"""Pruebas del cargador de políticas de gobernanza."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import pytest

from sgoda.governance.exceptions import PolicyLoadError
from sgoda.governance.policy_loader import (
    load_policies,
    load_policy,
)


def _valid_policy_data(
    *,
    policy_id: str = "POL-001",
    name: str = "Política de prueba",
) -> dict[str, Any]:
    return {
        "policy_id": policy_id,
        "name": name,
        "version": "1.0",
        "description": "Política utilizada por las pruebas",
        "enabled": True,
        "rules": [
            {
                "rule_id": "RULE-001",
                "field": "metadata.owner",
                "operator": "exists",
                "value": None,
                "severity": "error",
                "message": "El propietario es obligatorio",
                "metadata": {},
            }
        ],
        "metadata": {
            "framework": "DAMA-DMBOK",
        },
    }


def _write_policy(
    path: Path,
    data: dict[str, Any] | None = None,
) -> Path:
    path.write_text(
        json.dumps(
            data or _valid_policy_data(),
            ensure_ascii=False,
            allow_nan=False,
        ),
        encoding="utf-8",
    )
    return path


def test_load_policy_from_path(tmp_path: Path) -> None:
    path = _write_policy(tmp_path / "policy.json")

    policy = load_policy(path)

    assert policy.policy_id == "POL-001"
    assert policy.name == "Política de prueba"
    assert policy.enabled is True
    assert len(policy.rules) == 1
    assert policy.rules[0].rule_id == "RULE-001"


def test_load_policy_from_string_path(tmp_path: Path) -> None:
    path = _write_policy(tmp_path / "policy.json")

    policy = load_policy(str(path))

    assert policy.policy_id == "POL-001"


def test_load_policies_preserves_order(tmp_path: Path) -> None:
    first = _write_policy(
        tmp_path / "first.json",
        _valid_policy_data(
            policy_id="POL-001",
            name="Primera",
        ),
    )
    second = _write_policy(
        tmp_path / "second.json",
        _valid_policy_data(
            policy_id="POL-002",
            name="Segunda",
        ),
    )

    policies = load_policies([first, second])

    assert isinstance(policies, tuple)
    assert tuple(
        policy.policy_id
        for policy in policies
    ) == (
        "POL-001",
        "POL-002",
    )


def test_load_policies_accepts_empty_iterable() -> None:
    assert load_policies([]) == ()


@pytest.mark.parametrize(
    "invalid_path",
    [
        "",
        "   ",
        123,
        None,
        b"policy.json",
    ],
)
def test_load_policy_rejects_invalid_path(
    invalid_path: object,
) -> None:
    with pytest.raises(PolicyLoadError):
        load_policy(invalid_path)  # type: ignore[arg-type]


def test_load_policy_rejects_missing_file(
    tmp_path: Path,
) -> None:
    with pytest.raises(PolicyLoadError):
        load_policy(tmp_path / "missing.json")


def test_load_policy_rejects_directory(
    tmp_path: Path,
) -> None:
    with pytest.raises(PolicyLoadError):
        load_policy(tmp_path)


def test_load_policy_rejects_empty_file(
    tmp_path: Path,
) -> None:
    path = tmp_path / "empty.json"
    path.write_bytes(b"")

    with pytest.raises(PolicyLoadError):
        load_policy(path)


def test_load_policy_rejects_invalid_json(
    tmp_path: Path,
) -> None:
    path = tmp_path / "invalid.json"
    path.write_text(
        "{invalid}",
        encoding="utf-8",
    )

    with pytest.raises(PolicyLoadError) as error:
        load_policy(path)

    assert isinstance(
        error.value.__cause__,
        Exception,
    )


def test_load_policy_rejects_invalid_utf8(
    tmp_path: Path,
) -> None:
    path = tmp_path / "invalid-utf8.json"
    path.write_bytes(b"\xff\xfe")

    with pytest.raises(PolicyLoadError):
        load_policy(path)


def test_load_policy_rejects_unknown_fields(
    tmp_path: Path,
) -> None:
    data = _valid_policy_data()
    data["unknown"] = True
    path = _write_policy(
        tmp_path / "unknown.json",
        data,
    )

    with pytest.raises(PolicyLoadError):
        load_policy(path)


def test_load_policy_rejects_invalid_model(
    tmp_path: Path,
) -> None:
    data = _valid_policy_data()
    data["policy_id"] = ""
    path = _write_policy(
        tmp_path / "invalid-model.json",
        data,
    )

    with pytest.raises(PolicyLoadError):
        load_policy(path)


@pytest.mark.parametrize(
    "invalid_paths",
    [
        "policy.json",
        b"policy.json",
        bytearray(b"policy.json"),
        Path("policy.json"),
        None,
        123,
    ],
)
def test_load_policies_rejects_non_collection(
    invalid_paths: object,
) -> None:
    with pytest.raises(PolicyLoadError):
        load_policies(invalid_paths)  # type: ignore[arg-type]


def test_load_policies_reports_item_failure(
    tmp_path: Path,
) -> None:
    valid = _write_policy(tmp_path / "valid.json")
    missing = tmp_path / "missing.json"

    with pytest.raises(PolicyLoadError) as error:
        load_policies([valid, missing])

    assert isinstance(
        error.value.__cause__,
        PolicyLoadError,
    )
