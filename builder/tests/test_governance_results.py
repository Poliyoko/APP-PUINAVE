"""Pruebas de los resultados de gobernanza."""

from __future__ import annotations

import ast
import math
from dataclasses import FrozenInstanceError
from pathlib import Path
from types import MappingProxyType

import pytest

from sgoda.governance.exceptions import PolicyValidationError
from sgoda.governance.models import (
    PolicyOperator,
    PolicySeverity,
)
from sgoda.governance.results import (
    PolicyResult,
    PolicyResultStatus,
    RuleResult,
    RuleResultStatus,
)


def make_rule_result(
    *,
    policy_id: str = "governance.owner",
    rule_id: str = "owner-exists",
    status: RuleResultStatus | str = RuleResultStatus.PASSED,
    operator: PolicyOperator | str = PolicyOperator.EXISTS,
    severity: PolicySeverity | str = PolicySeverity.ERROR,
    expected_value=None,
    actual_value=None,
    message: str | None = None,
    error: str | None = None,
    metadata=None,
) -> RuleResult:
    return RuleResult(
        policy_id=policy_id,
        rule_id=rule_id,
        field="governance.owner",
        operator=operator,
        severity=severity,
        status=status,
        expected_value=expected_value,
        actual_value=actual_value,
        message=message,
        error=error,
        metadata={} if metadata is None else metadata,
    )


def make_policy_result(
    *rule_results: RuleResult,
    policy_id: str = "governance.owner",
    enabled: bool = True,
    message: str | None = None,
    metadata=None,
) -> PolicyResult:
    return PolicyResult(
        policy_id=policy_id,
        name="Política de prueba",
        version="1.0.0",
        rule_results=rule_results,
        enabled=enabled,
        message=message,
        metadata={} if metadata is None else metadata,
    )


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("passed", RuleResultStatus.PASSED),
        ("failed", RuleResultStatus.FAILED),
        ("skipped", RuleResultStatus.SKIPPED),
        ("error", RuleResultStatus.ERROR),
    ],
)
def test_rule_status_is_normalized(
    raw: str,
    expected: RuleResultStatus,
) -> None:
    error = "evaluation failed" if raw == "error" else None

    result = make_rule_result(
        status=raw,
        error=error,
    )

    assert result.status is expected


def test_operator_and_severity_are_normalized() -> None:
    result = make_rule_result(
        operator="exists",
        severity="warning",
    )

    assert result.operator is PolicyOperator.EXISTS
    assert result.severity is PolicySeverity.WARNING


@pytest.mark.parametrize(
    ("field_name", "value"),
    [
        ("policy_id", ""),
        ("policy_id", "   "),
        ("rule_id", ""),
        ("rule_id", "   "),
    ],
)
def test_required_identifiers_are_validated(
    field_name: str,
    value: str,
) -> None:
    arguments = {
        field_name: value,
    }

    with pytest.raises(
        PolicyValidationError,
        match="non-empty string",
    ):
        make_rule_result(**arguments)


@pytest.mark.parametrize(
    "status",
    [
        "",
        "invalid",
        object(),
    ],
)
def test_invalid_rule_status_is_rejected(
    status,
) -> None:
    with pytest.raises(
        PolicyValidationError,
        match="status is not supported",
    ):
        make_rule_result(status=status)


def test_error_status_requires_error_description() -> None:
    with pytest.raises(
        PolicyValidationError,
        match="requires an error description",
    ):
        make_rule_result(
            status=RuleResultStatus.ERROR,
        )


@pytest.mark.parametrize(
    "status",
    [
        RuleResultStatus.PASSED,
        RuleResultStatus.FAILED,
        RuleResultStatus.SKIPPED,
    ],
)
def test_non_error_status_rejects_error_description(
    status: RuleResultStatus,
) -> None:
    with pytest.raises(
        PolicyValidationError,
        match="only valid for error status",
    ):
        make_rule_result(
            status=status,
            error="unexpected error",
        )


def test_optional_strings_are_trimmed() -> None:
    result = make_rule_result(
        message="  valid message  ",
    )

    assert result.message == "valid message"


def test_blank_optional_string_is_rejected() -> None:
    with pytest.raises(
        PolicyValidationError,
        match="message must be a non-empty string",
    ):
        make_rule_result(message="   ")


def test_rule_result_values_are_frozen() -> None:
    result = make_rule_result(
        expected_value={
            "allowed": ["active", "draft"],
        },
        actual_value=[
            {
                "status": "active",
            }
        ],
        metadata={
            "source": {
                "line": 10,
            },
        },
    )

    assert isinstance(
        result.expected_value,
        MappingProxyType,
    )
    assert result.expected_value["allowed"] == (
        "active",
        "draft",
    )
    assert isinstance(
        result.actual_value[0],
        MappingProxyType,
    )
    assert isinstance(
        result.metadata,
        MappingProxyType,
    )


@pytest.mark.parametrize(
    "value",
    [
        math.nan,
        math.inf,
        -math.inf,
    ],
)
def test_non_finite_values_are_rejected(
    value: float,
) -> None:
    with pytest.raises(
        PolicyValidationError,
        match="NaN or infinity",
    ):
        make_rule_result(actual_value=value)


def test_nested_non_finite_value_reports_path() -> None:
    with pytest.raises(
        PolicyValidationError,
        match="NaN or infinity",
    ) as captured:
        make_rule_result(
            actual_value={
                "items": [
                    {
                        "value": math.inf,
                    }
                ],
            },
        )

    assert (
        captured.value.context["path"]
        == "$.items[0].value"
    )


def test_non_string_mapping_key_is_rejected() -> None:
    with pytest.raises(
        PolicyValidationError,
        match="keys must be strings",
    ):
        make_rule_result(
            metadata={
                1: "invalid",
            },
        )


def test_non_json_value_is_rejected() -> None:
    with pytest.raises(
        PolicyValidationError,
        match="not JSON compatible",
    ):
        make_rule_result(
            actual_value=complex(1, 2),
        )


def test_rule_result_is_immutable() -> None:
    result = make_rule_result()

    with pytest.raises(FrozenInstanceError):
        result.status = RuleResultStatus.FAILED  # type: ignore[misc]


@pytest.mark.parametrize(
    ("status", "attribute"),
    [
        (RuleResultStatus.PASSED, "passed"),
        (RuleResultStatus.FAILED, "failed"),
        (RuleResultStatus.SKIPPED, "skipped"),
        (RuleResultStatus.ERROR, "has_error"),
    ],
)
def test_rule_result_status_properties(
    status: RuleResultStatus,
    attribute: str,
) -> None:
    result = make_rule_result(
        status=status,
        error=(
            "evaluation error"
            if status is RuleResultStatus.ERROR
            else None
        ),
    )

    assert getattr(result, attribute) is True


def test_empty_policy_result_is_skipped() -> None:
    result = make_policy_result()

    assert result.status is PolicyResultStatus.SKIPPED
    assert result.skipped is True
    assert result.total_count == 0


def test_all_skipped_rules_produce_skipped_policy() -> None:
    result = make_policy_result(
        make_rule_result(
            rule_id="rule-1",
            status=RuleResultStatus.SKIPPED,
        ),
        make_rule_result(
            rule_id="rule-2",
            status=RuleResultStatus.SKIPPED,
        ),
    )

    assert result.status is PolicyResultStatus.SKIPPED


def test_passed_rule_produces_passed_policy() -> None:
    result = make_policy_result(
        make_rule_result(
            status=RuleResultStatus.PASSED,
        ),
    )

    assert result.status is PolicyResultStatus.PASSED
    assert result.passed is True


def test_failed_rule_has_priority_over_passed() -> None:
    result = make_policy_result(
        make_rule_result(
            rule_id="passed-rule",
            status=RuleResultStatus.PASSED,
        ),
        make_rule_result(
            rule_id="failed-rule",
            status=RuleResultStatus.FAILED,
        ),
    )

    assert result.status is PolicyResultStatus.FAILED
    assert result.failed is True


def test_error_rule_has_highest_priority() -> None:
    result = make_policy_result(
        make_rule_result(
            rule_id="failed-rule",
            status=RuleResultStatus.FAILED,
        ),
        make_rule_result(
            rule_id="error-rule",
            status=RuleResultStatus.ERROR,
            error="comparison failed",
        ),
    )

    assert result.status is PolicyResultStatus.ERROR
    assert result.has_error is True


def test_policy_result_counts_statuses() -> None:
    result = make_policy_result(
        make_rule_result(
            rule_id="passed-rule",
            status=RuleResultStatus.PASSED,
        ),
        make_rule_result(
            rule_id="failed-rule",
            status=RuleResultStatus.FAILED,
        ),
        make_rule_result(
            rule_id="skipped-rule",
            status=RuleResultStatus.SKIPPED,
        ),
        make_rule_result(
            rule_id="error-rule",
            status=RuleResultStatus.ERROR,
            error="evaluation error",
        ),
    )

    assert result.total_count == 4
    assert result.passed_count == 1
    assert result.failed_count == 1
    assert result.skipped_count == 1
    assert result.error_count == 1


def test_policy_result_preserves_rule_order() -> None:
    first = make_rule_result(rule_id="first")
    second = make_rule_result(rule_id="second")

    result = make_policy_result(first, second)

    assert result.rule_results == (
        first,
        second,
    )


def test_policy_result_accepts_list_and_converts_to_tuple() -> None:
    first = make_rule_result(rule_id="first")
    second = make_rule_result(rule_id="second")

    result = PolicyResult(
        policy_id="governance.owner",
        name="Política",
        version="1.0",
        rule_results=[first, second],  # type: ignore[arg-type]
    )

    assert result.rule_results == (
        first,
        second,
    )


@pytest.mark.parametrize(
    "rule_results",
    [
        "invalid",
        b"invalid",
        {"rule": "invalid"},
        42,
    ],
)
def test_policy_result_rejects_invalid_collection(
    rule_results,
) -> None:
    with pytest.raises(PolicyValidationError):
        PolicyResult(
            policy_id="governance.owner",
            name="Política",
            version="1.0",
            rule_results=rule_results,
        )


def test_policy_result_rejects_invalid_item() -> None:
    with pytest.raises(
        PolicyValidationError,
        match="only RuleResult",
    ):
        PolicyResult(
            policy_id="governance.owner",
            name="Política",
            version="1.0",
            rule_results=(
                make_rule_result(),
                object(),
            ),
        )


def test_rule_result_must_belong_to_policy() -> None:
    foreign_result = make_rule_result(
        policy_id="governance.foreign",
    )

    with pytest.raises(
        PolicyValidationError,
        match="different policy",
    ) as captured:
        make_policy_result(foreign_result)

    assert (
        captured.value.context["result_policy_id"]
        == "governance.foreign"
    )


def test_duplicate_rule_result_ids_are_rejected() -> None:
    first = make_rule_result(
        rule_id="duplicate",
    )
    second = make_rule_result(
        rule_id="duplicate",
        status=RuleResultStatus.FAILED,
    )

    with pytest.raises(
        PolicyValidationError,
        match="identifiers must be unique",
    ) as captured:
        make_policy_result(first, second)

    assert captured.value.context["duplicate_of_index"] == 0
    assert captured.value.context["index"] == 1


def test_enabled_must_be_boolean() -> None:
    with pytest.raises(
        PolicyValidationError,
        match="enabled must be a boolean",
    ):
        make_policy_result(
            enabled=1,  # type: ignore[arg-type]
        )


def test_policy_metadata_is_frozen() -> None:
    result = make_policy_result(
        metadata={
            "summary": {
                "source": "engine",
            },
        },
    )

    assert isinstance(result.metadata, MappingProxyType)
    assert isinstance(
        result.metadata["summary"],
        MappingProxyType,
    )


def test_policy_result_is_immutable() -> None:
    result = make_policy_result()

    with pytest.raises(FrozenInstanceError):
        result.status = PolicyResultStatus.PASSED  # type: ignore[misc]


def test_status_cannot_be_provided_to_constructor() -> None:
    with pytest.raises(TypeError):
        PolicyResult(
            policy_id="governance.owner",
            name="Política",
            version="1.0",
            rule_results=(),
            status=PolicyResultStatus.PASSED,  # type: ignore[call-arg]
        )


def test_module_does_not_import_audit() -> None:
    module_path = (
        Path(__file__).parents[1]
        / "src"
        / "sgoda"
        / "governance"
        / "results.py"
    )

    tree = ast.parse(
        module_path.read_text(encoding="utf-8-sig")
    )

    imported_modules: list[str] = []

    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            imported_modules.extend(
                alias.name
                for alias in node.names
            )
        elif isinstance(node, ast.ImportFrom):
            if node.module:
                imported_modules.append(node.module)

    assert not any(
        module == "sgoda.audit"
        or module.startswith("sgoda.audit.")
        for module in imported_modules
    )
