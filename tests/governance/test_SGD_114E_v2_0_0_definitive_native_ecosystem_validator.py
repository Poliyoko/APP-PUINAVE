
import json
from pathlib import Path

from sgoda.governance.native_ecosystem_models import (
    NativeEcosystemFinding,
)
from sgoda.governance.native_ecosystem_validator import (
    evaluate_native_ecosystem,
)


def write_component(
    root: Path,
    code: str = "SPT-012",
    native=True,
    dependencies=None,
) -> None:
    target = root / "config" / "test"
    target.mkdir(parents=True, exist_ok=True)

    payload = {
        "increment_code": code,
        "mandatory_proprietary_dependencies": (
            [] if dependencies is None else dependencies
        ),
    }

    if native is not None:
        payload["native_ecosystem"] = native

    (target / f"{code}-component.json").write_text(
        json.dumps(payload),
        encoding="utf-8",
    )


def test_empty_repository_contract(tmp_path: Path) -> None:
    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is True
    assert result.exit_code == 0
    assert result["version"] == "1.0.3"
    assert result.version == "1.0.5"
    assert result.implementation_version == "2.0.0"
    assert result.repository_is_empty is True
    assert result["criteria"]["empty_repository_allowed"] is True


def test_valid_native_component_all_criteria_true(
    tmp_path: Path,
) -> None:
    write_component(tmp_path)

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is True
    assert result.repository_is_empty is False
    assert result["criteria"]["has_native_components"] is True
    assert all(result["criteria"].values())


def test_native_components_attribute_is_tuple(
    tmp_path: Path,
) -> None:
    write_component(tmp_path)

    result = evaluate_native_ecosystem(tmp_path)

    assert result.native_components == ("SPT-012",)
    assert result["native_components"] == ["SPT-012"]


def test_missing_native_flag_is_rejected(
    tmp_path: Path,
) -> None:
    write_component(tmp_path, native=None)

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is False
    assert result.exit_code == 2
    assert result["criteria"]["has_native_components"] is False
    assert any(
        finding.rule_code == "SGD114E-R002"
        for finding in result.findings
    )


def test_false_native_flag_is_rejected(
    tmp_path: Path,
) -> None:
    write_component(tmp_path, native=False)

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is False


def test_legacy_component_is_ignored(
    tmp_path: Path,
) -> None:
    write_component(
        tmp_path,
        code="SPT-006A",
        native=None,
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is True
    assert result.component_count == 0


def test_proprietary_dependency_alias(
    tmp_path: Path,
) -> None:
    write_component(
        tmp_path,
        dependencies=["PaidVendorOnly"],
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result.proprietary_dependency_count == 1
    assert (
        result["mandatory_proprietary_dependency_count"]
        == 1
    )


def test_invalid_json_is_rejected(
    tmp_path: Path,
) -> None:
    target = tmp_path / "config"
    target.mkdir()
    (target / "bad-component.json").write_text(
        "{invalid",
        encoding="utf-8",
    )

    result = evaluate_native_ecosystem(tmp_path)

    assert result.approved is False
    assert result.structural_error_count == 1


def test_findings_contract_and_serialization(
    tmp_path: Path,
) -> None:
    write_component(tmp_path, native=None)

    result = evaluate_native_ecosystem(tmp_path)
    payload = result.to_dict()

    assert isinstance(
        result.findings[0],
        NativeEcosystemFinding,
    )
    assert isinstance(payload["findings"][0], dict)


def test_copy_preserves_contract(
    tmp_path: Path,
) -> None:
    copied = evaluate_native_ecosystem(
        tmp_path
    ).copy()

    assert copied.approved is True
    assert copied.exit_code == 0
    assert copied["version"] == "1.0.3"
    assert copied.version == "1.0.5"
    assert copied.implementation_version == "2.0.0"
