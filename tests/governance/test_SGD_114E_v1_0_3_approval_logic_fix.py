from __future__ import annotations

import json
from pathlib import Path

from sgoda.governance.native_ecosystem_validator import (
    evaluate_native_ecosystem,
)


def _write_component(
    root: Path,
    *,
    code: str = "SPT-016A",
    native: bool = True,
    dependencies: list[str] | None = None,
) -> None:
    target = root / "config" / "test"
    target.mkdir(parents=True, exist_ok=True)
    (target / "component.json").write_text(
        json.dumps(
            {
                "increment_code": code,
                "native_ecosystem": native,
                "mandatory_proprietary_dependencies": (
                    dependencies or []
                ),
            }
        ),
        encoding="utf-8",
    )


def test_approves_valid_native_ecosystem(
    tmp_path: Path,
) -> None:
    _write_component(tmp_path)

    result = evaluate_native_ecosystem(tmp_path)

    assert result["approved"] is True
    assert result["result"] == "APROBADO"


def test_rejects_without_native_components(
    tmp_path: Path,
) -> None:
    _write_component(tmp_path, native=False)

    result = evaluate_native_ecosystem(tmp_path)

    assert result["approved"] is False
    assert result["criteria"]["has_native_components"] is False


def test_rejects_proprietary_dependency(
    tmp_path: Path,
) -> None:
    _write_component(
        tmp_path,
        dependencies=["proprietary-service"],
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result["approved"] is False
    assert (
        result["mandatory_proprietary_dependency_count"]
        == 1
    )


def test_rejects_forbidden_term(
    tmp_path: Path,
) -> None:
    _write_component(tmp_path)
    docs = tmp_path / "docs"
    docs.mkdir(parents=True)
    (docs / "bad.md").write_text(
        "integrado por contrato",
        encoding="utf-8",
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result["approved"] is False
    assert result["forbidden_term_count"] == 1


def test_rejects_invalid_json(
    tmp_path: Path,
) -> None:
    target = tmp_path / "config" / "test"
    target.mkdir(parents=True)
    (target / "component.json").write_text(
        "{invalid",
        encoding="utf-8",
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result["approved"] is False
    assert result["structural_error_count"] == 1


def test_decision_rule_uses_all_criteria(
    tmp_path: Path,
) -> None:
    _write_component(tmp_path)

    result = evaluate_native_ecosystem(tmp_path)

    assert all(result["criteria"].values())
    assert result["approved"] is True


def test_counts_native_components(
    tmp_path: Path,
) -> None:
    _write_component(tmp_path, code="SPT-016A")

    second = tmp_path / "config" / "second"
    second.mkdir(parents=True)
    (second / "component.json").write_text(
        json.dumps(
            {
                "increment_code": "SPT-017",
                "native_ecosystem": True,
                "mandatory_proprietary_dependencies": [],
            }
        ),
        encoding="utf-8",
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result["native_component_count"] == 2


def test_returns_version_1_0_3(
    tmp_path: Path,
) -> None:
    _write_component(tmp_path)

    result = evaluate_native_ecosystem(tmp_path)

    assert result["version"] == "1.0.3"


def test_empty_dependency_list_is_valid(
    tmp_path: Path,
) -> None:
    _write_component(tmp_path, dependencies=[])

    result = evaluate_native_ecosystem(tmp_path)

    assert result["approved"] is True


def test_none_dependency_list_is_valid(
    tmp_path: Path,
) -> None:
    target = tmp_path / "config" / "test"
    target.mkdir(parents=True)
    (target / "component.json").write_text(
        json.dumps(
            {
                "increment_code": "SPT-016A",
                "native_ecosystem": True,
                "mandatory_proprietary_dependencies": None,
            }
        ),
        encoding="utf-8",
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result["approved"] is True