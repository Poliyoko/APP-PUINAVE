from __future__ import annotations

import json
from pathlib import Path

from sgoda.governance.native_ecosystem import (
    evaluate_native_ecosystem,
    is_native_spt,
    normalize_native_metadata,
)


def _write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload),
        encoding="utf-8",
    )


def test_SGD_114E_identifies_SPT_007_as_native() -> None:
    assert is_native_spt("SPT-007") is True
    assert is_native_spt("SPT-007A") is True


def test_SGD_114E_identifies_later_SPT_as_native() -> None:
    assert is_native_spt("SPT-012") is True


def test_SGD_114E_excludes_earlier_SPT() -> None:
    assert is_native_spt("SPT-006A") is False


def test_SGD_114E_normalizes_native_metadata() -> None:
    result = normalize_native_metadata(
        {
            "increment_code": "SPT-012",
            "version": "1.0.1",
        }
    )

    assert result["native_ecosystem"] is True
    assert result["ecosystem_role"] == "native_component"
    assert result["mandatory_proprietary_dependencies"] == []


def test_SGD_114E_approves_native_component(
    tmp_path: Path,
) -> None:
    _write_json(
        tmp_path / "config/x/SPT-012-component.json",
        {
            "increment_code": "SPT-012",
            "version": "1.0.1",
            "native_ecosystem": True,
            "ecosystem_role": "native_component",
            "mandatory_proprietary_dependencies": [],
        },
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is True
    assert result.component_count == 1


def test_SGD_114E_blocks_missing_native_declaration(
    tmp_path: Path,
) -> None:
    _write_json(
        tmp_path / "config/x/SPT-012-component.json",
        {
            "increment_code": "SPT-012",
            "version": "1.0.1",
        },
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is False
    assert any(
        item.rule_code == "SGD114E-R002"
        for item in result.findings
    )


def test_SGD_114E_blocks_mandatory_proprietary_dependency(
    tmp_path: Path,
) -> None:
    _write_json(
        tmp_path / "config/x/SPT-012-component.json",
        {
            "increment_code": "SPT-012",
            "native_ecosystem": True,
            "ecosystem_role": "native_component",
            "mandatory_proprietary_dependencies": [
                "PaidVendorOnly"
            ],
        },
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is False
    assert result.proprietary_dependency_count == 1


def test_SGD_114E_blocks_forbidden_terminology(
    tmp_path: Path,
) -> None:
    _write_json(
        tmp_path / "config/x/SPT-012-component.json",
        {
            "increment_code": "SPT-012",
            "native_ecosystem": True,
            "ecosystem_role": "native_component",
            "mandatory_proprietary_dependencies": [],
        },
    )
    document = tmp_path / "docs/test.md"
    document.parent.mkdir(parents=True)
    document.write_text(
        "Motor integrado por contrato.",
        encoding="utf-8",
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is False
    assert result.forbidden_term_count == 1


def test_SGD_114E_accepts_native_terminology(
    tmp_path: Path,
) -> None:
    _write_json(
        tmp_path / "config/x/SPT-012-component.json",
        {
            "increment_code": "SPT-012",
            "native_ecosystem": True,
            "ecosystem_role": "native_component",
            "mandatory_proprietary_dependencies": [],
        },
    )
    document = tmp_path / "docs/test.md"
    document.parent.mkdir(parents=True)
    document.write_text(
        "Motor integrado nativamente al ecosistema SGODA-PUINAVE.",
        encoding="utf-8",
    )

    assert evaluate_native_ecosystem(tmp_path).approved is True


def test_SGD_114E_ignores_non_native_components(
    tmp_path: Path,
) -> None:
    _write_json(
        tmp_path / "config/x/SPT-006A-component.json",
        {
            "increment_code": "SPT-006A",
        },
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is True
    assert result.component_count == 0


def test_SGD_114E_is_deterministic(
    tmp_path: Path,
) -> None:
    _write_json(
        tmp_path / "config/x/SPT-012-component.json",
        {
            "increment_code": "SPT-012",
            "native_ecosystem": True,
            "ecosystem_role": "native_component",
            "mandatory_proprietary_dependencies": [],
        },
    )

    first = evaluate_native_ecosystem(tmp_path)
    second = evaluate_native_ecosystem(tmp_path)

    assert first == second


def test_SGD_114E_exit_code_is_zero_when_approved(
    tmp_path: Path,
) -> None:
    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is True
    assert result.exit_code == 0