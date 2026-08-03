from __future__ import annotations

import json
from pathlib import Path

from sgoda.governance.native_ecosystem_models import (
    NativeEcosystemFinding,
)
from sgoda.governance.native_ecosystem_validator import (
    evaluate_native_ecosystem,
)


def _write(root: Path, code: str, payload: dict) -> None:
    target = root / "config" / "test"
    target.mkdir(parents=True, exist_ok=True)

    (target / f"{code}-component.json").write_text(
        json.dumps(
            {
                "increment_code": code,
                **payload,
            }
        ),
        encoding="utf-8",
    )


def test_contract_and_implementation_versions(
    tmp_path: Path,
) -> None:
    result = evaluate_native_ecosystem(tmp_path)

    assert result["version"] == "1.0.3"
    assert result.version == "1.0.5"
    assert result.implementation_version == "2.0.0"


def test_empty_repository_is_approved(
    tmp_path: Path,
) -> None:
    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is True
    assert result.exit_code == 0
    assert result.repository_is_empty is True


def test_legacy_component_is_ignored(
    tmp_path: Path,
) -> None:
    _write(tmp_path, "SPT-006A", {})

    assert evaluate_native_ecosystem(
        tmp_path
    ).approved is True


def test_governed_component_requires_native_flag(
    tmp_path: Path,
) -> None:
    _write(tmp_path, "SPT-012", {})

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is False
    assert any(
        finding.rule_code == "SGD114E-R002"
        for finding in result.findings
    )


def test_native_component_is_counted(
    tmp_path: Path,
) -> None:
    _write(
        tmp_path,
        "SPT-012",
        {
            "native_ecosystem": True,
            "mandatory_proprietary_dependencies": [],
        },
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is True
    assert result.component_count == 1
    assert result.native_components == ("SPT-012",)


def test_proprietary_alias_is_preserved(
    tmp_path: Path,
) -> None:
    _write(
        tmp_path,
        "SPT-012",
        {
            "native_ecosystem": True,
            "mandatory_proprietary_dependencies": ["X"],
        },
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result.proprietary_dependency_count == 1


def test_findings_have_attribute_contract(
    tmp_path: Path,
) -> None:
    _write(tmp_path, "SPT-012", {})

    result = evaluate_native_ecosystem(tmp_path)

    assert isinstance(
        result.findings[0],
        NativeEcosystemFinding,
    )


def test_to_dict_serializes_findings(
    tmp_path: Path,
) -> None:
    _write(tmp_path, "SPT-012", {})

    payload = evaluate_native_ecosystem(
        tmp_path
    ).to_dict()

    assert isinstance(payload["findings"][0], dict)


def test_attribute_and_mapping_access_coexist(
    tmp_path: Path,
) -> None:
    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved == result["approved"]
    assert result.exit_code == result["exit_code"]


def test_copy_preserves_contract(
    tmp_path: Path,
) -> None:
    result = evaluate_native_ecosystem(
        tmp_path
    ).copy()

    assert result["version"] == "1.0.3"
    assert result.version == "1.0.5"
    assert result.implementation_version == "2.0.0"