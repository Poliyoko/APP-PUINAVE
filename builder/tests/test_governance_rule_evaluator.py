"""Pruebas del evaluador de reglas de gobernanza."""

from __future__ import annotations

import ast
from pathlib import Path
from types import MappingProxyType

import pytest

from sgoda.governance.exceptions import (
    PolicyValidationError,
)
from sgoda.governance.models import (
    PolicyOperator,
    PolicyRule,
    PolicySeverity,
)
from sgoda.governance.results import (
    RuleResultStatus,
)
from sgoda.governance.rule_evaluator import (
    evaluate_rule,
)


POLICY_ID = "governance.test"


def make_rule(
    *,
    rule_id: str = "rule-1",
    field: str = "value",
    operator: PolicyOperator = PolicyOperator.EQ,
    value=None,
    severity: PolicySeverity = PolicySeverity.ERROR,
    message: str | None = None,
    metadata=None,
) -> PolicyRule:
    return PolicyRule(
        rule_id=rule_id,
        field=field,
        operator=operator,
        value=value,
        severity=severity,
        message=message,
        metadata={} if metadata is None else metadata,
    )


def evaluate(
    rule: PolicyRule,
    values,
):
    return evaluate_rule(
        rule,
        values,
        policy_id=POLICY_ID,
    )


def test_rejects_invalid_rule() -> None:
    with pytest.raises(
        PolicyValidationError,
        match="PolicyRule",
    ):
        evaluate_rule(
            object(),  # type: ignore[arg-type]
            {},
            policy_id=POLICY_ID,
        )


@pytest.mark.parametrize(
    "policy_id",
    [
        "",
        "   ",
        None,
        10,
    ],
)
def test_rejects_invalid_policy_id(
    policy_id,
) -> None:
    with pytest.raises(
        PolicyValidationError,
        match="policy_id must be a non-empty string",
    ):
        evaluate_rule(
            make_rule(),
            {},
            policy_id=policy_id,
        )


@pytest.mark.parametrize(
    "values",
    [
        None,
        [],
        (),
        "invalid",
        42,
    ],
)
def test_rejects_non_mapping_context(
    values,
) -> None:
    with pytest.raises(
        PolicyValidationError,
        match="values must be a mapping",
    ):
        evaluate(
            make_rule(),
            values,
        )


def test_policy_id_is_trimmed() -> None:
    result = evaluate_rule(
        make_rule(
            operator=PolicyOperator.EXISTS,
        ),
        {
            "value": 1,
        },
        policy_id="  governance.test  ",
    )

    assert result.policy_id == POLICY_ID


def test_resolves_simple_field() -> None:
    result = evaluate(
        make_rule(
            value="active",
        ),
        {
            "value": "active",
        },
    )

    assert result.status is RuleResultStatus.PASSED
    assert result.actual_value == "active"


def test_resolves_nested_mapping_field() -> None:
    result = evaluate(
        make_rule(
            field="governance.owner",
            value="data-office",
        ),
        {
            "governance": {
                "owner": "data-office",
            },
        },
    )

    assert result.status is RuleResultStatus.PASSED


def test_resolves_sequence_index() -> None:
    result = evaluate(
        make_rule(
            field="items[1].name",
            value="second",
        ),
        {
            "items": [
                {
                    "name": "first",
                },
                {
                    "name": "second",
                },
            ],
        },
    )

    assert result.status is RuleResultStatus.PASSED
    assert result.actual_value == "second"


def test_missing_intermediate_mapping_is_failed() -> None:
    result = evaluate(
        make_rule(
            field="governance.owner",
            operator=PolicyOperator.EQ,
            value="data-office",
        ),
        {},
    )

    assert result.status is RuleResultStatus.FAILED
    assert result.actual_value is None
    assert result.metadata["field_found"] is False


def test_invalid_sequence_index_is_failed() -> None:
    result = evaluate(
        make_rule(
            field="items[5].name",
            operator=PolicyOperator.EXISTS,
        ),
        {
            "items": [],
        },
    )

    assert result.status is RuleResultStatus.FAILED
    assert result.metadata["field_found"] is False


def test_index_requires_sequence() -> None:
    result = evaluate(
        make_rule(
            field="items[0]",
            operator=PolicyOperator.EXISTS,
        ),
        {
            "items": {
                "0": "value",
            },
        },
    )

    assert result.status is RuleResultStatus.FAILED


@pytest.mark.parametrize(
    "actual",
    [
        None,
        False,
        0,
        "",
        [],
        {},
    ],
)
def test_exists_checks_presence_not_truthiness(
    actual,
) -> None:
    result = evaluate(
        make_rule(
            operator=PolicyOperator.EXISTS,
        ),
        {
            "value": actual,
        },
    )

    assert result.status is RuleResultStatus.PASSED
    assert result.metadata["field_found"] is True


def test_exists_fails_for_missing_field() -> None:
    result = evaluate(
        make_rule(
            operator=PolicyOperator.EXISTS,
        ),
        {},
    )

    assert result.status is RuleResultStatus.FAILED


def test_not_exists_passes_for_missing_field() -> None:
    result = evaluate(
        make_rule(
            operator=PolicyOperator.NOT_EXISTS,
        ),
        {},
    )

    assert result.status is RuleResultStatus.PASSED


def test_not_exists_fails_for_present_none() -> None:
    result = evaluate(
        make_rule(
            operator=PolicyOperator.NOT_EXISTS,
        ),
        {
            "value": None,
        },
    )

    assert result.status is RuleResultStatus.FAILED


@pytest.mark.parametrize(
    ("operator", "actual", "expected", "passed"),
    [
        (PolicyOperator.EQ, 10, 10, True),
        (PolicyOperator.EQ, 10, 11, False),
        (PolicyOperator.NE, 10, 11, True),
        (PolicyOperator.NE, 10, 10, False),
        (PolicyOperator.GT, 11, 10, True),
        (PolicyOperator.GT, 10, 10, False),
        (PolicyOperator.GTE, 10, 10, True),
        (PolicyOperator.GTE, 9, 10, False),
        (PolicyOperator.LT, 9, 10, True),
        (PolicyOperator.LT, 10, 10, False),
        (PolicyOperator.LTE, 10, 10, True),
        (PolicyOperator.LTE, 11, 10, False),
    ],
)
def test_comparison_operators(
    operator: PolicyOperator,
    actual,
    expected,
    passed: bool,
) -> None:
    result = evaluate(
        make_rule(
            operator=operator,
            value=expected,
        ),
        {
            "value": actual,
        },
    )

    assert (
        result.status
        is (
            RuleResultStatus.PASSED
            if passed
            else RuleResultStatus.FAILED
        )
    )


@pytest.mark.parametrize(
    ("operator", "actual", "expected", "passed"),
    [
        (
            PolicyOperator.IN,
            "active",
            ("active", "draft"),
            True,
        ),
        (
            PolicyOperator.IN,
            "archived",
            ("active", "draft"),
            False,
        ),
        (
            PolicyOperator.NOT_IN,
            "archived",
            ("active", "draft"),
            True,
        ),
        (
            PolicyOperator.NOT_IN,
            "active",
            ("active", "draft"),
            False,
        ),
    ],
)
def test_membership_operators(
    operator: PolicyOperator,
    actual,
    expected,
    passed: bool,
) -> None:
    result = evaluate(
        make_rule(
            operator=operator,
            value=expected,
        ),
        {
            "value": actual,
        },
    )

    assert (
        result.status
        is (
            RuleResultStatus.PASSED
            if passed
            else RuleResultStatus.FAILED
        )
    )


@pytest.mark.parametrize(
    ("operator", "actual", "expected", "passed"),
    [
        (
            PolicyOperator.CONTAINS,
            "governance-policy",
            "policy",
            True,
        ),
        (
            PolicyOperator.CONTAINS,
            ("owner", "status"),
            "owner",
            True,
        ),
        (
            PolicyOperator.CONTAINS,
            {
                "owner": "data-office",
            },
            "owner",
            True,
        ),
        (
            PolicyOperator.NOT_CONTAINS,
            "governance-policy",
            "audit",
            True,
        ),
        (
            PolicyOperator.NOT_CONTAINS,
            ("owner", "status"),
            "owner",
            False,
        ),
    ],
)
def test_containment_operators(
    operator: PolicyOperator,
    actual,
    expected,
    passed: bool,
) -> None:
    result = evaluate(
        make_rule(
            operator=operator,
            value=expected,
        ),
        {
            "value": actual,
        },
    )

    assert (
        result.status
        is (
            RuleResultStatus.PASSED
            if passed
            else RuleResultStatus.FAILED
        )
    )


@pytest.mark.parametrize(
    "operator",
    [
        PolicyOperator.EQ,
        PolicyOperator.NE,
        PolicyOperator.GT,
        PolicyOperator.GTE,
        PolicyOperator.LT,
        PolicyOperator.LTE,
        PolicyOperator.IN,
        PolicyOperator.NOT_IN,
        PolicyOperator.CONTAINS,
        PolicyOperator.NOT_CONTAINS,
    ],
)
def test_non_existence_operator_fails_when_field_missing(
    operator: PolicyOperator,
) -> None:
    value = (
        ("active", "draft")
        if operator in {
            PolicyOperator.IN,
            PolicyOperator.NOT_IN,
        }
        else "active"
    )

    result = evaluate(
        make_rule(
            operator=operator,
            value=value,
        ),
        {},
    )

    assert result.status is RuleResultStatus.FAILED
    assert result.has_error is False


def test_incompatible_ordering_becomes_error() -> None:
    result = evaluate(
        make_rule(
            operator=PolicyOperator.GT,
            value=10,
        ),
        {
            "value": "ten",
        },
    )

    assert result.status is RuleResultStatus.ERROR
    assert result.error is not None
    assert "TypeError" in result.error
    assert result.metadata["exception_type"] == "TypeError"


def test_invalid_contains_target_becomes_error() -> None:
    result = evaluate(
        make_rule(
            operator=PolicyOperator.CONTAINS,
            value=1,
        ),
        {
            "value": 10,
        },
    )

    assert result.status is RuleResultStatus.ERROR
    assert result.has_error is True


def test_default_failure_message_is_deterministic() -> None:
    result = evaluate(
        make_rule(
            rule_id="status-eq",
            field="status",
            operator=PolicyOperator.EQ,
            value="active",
        ),
        {
            "status": "draft",
        },
    )

    assert result.message == (
        "Rule 'status-eq' failed for field "
        "'status' using operator 'eq'"
    )


def test_custom_failure_message_is_preserved() -> None:
    result = evaluate(
        make_rule(
            value="active",
            message="El estado debe estar activo",
        ),
        {
            "value": "draft",
        },
    )

    assert result.status is RuleResultStatus.FAILED
    assert result.message == "El estado debe estar activo"


def test_passed_result_does_not_emit_failure_message() -> None:
    result = evaluate(
        make_rule(
            value="active",
            message="Mensaje de incumplimiento",
        ),
        {
            "value": "active",
        },
    )

    assert result.status is RuleResultStatus.PASSED
    assert result.message is None


def test_rule_identity_is_preserved() -> None:
    result = evaluate(
        make_rule(
            rule_id="owner-rule",
            field="governance.owner",
            operator=PolicyOperator.EXISTS,
            severity=PolicySeverity.CRITICAL,
        ),
        {
            "governance": {
                "owner": "data-office",
            },
        },
    )

    assert result.policy_id == POLICY_ID
    assert result.rule_id == "owner-rule"
    assert result.field == "governance.owner"
    assert result.operator is PolicyOperator.EXISTS
    assert result.severity is PolicySeverity.CRITICAL


def test_rule_metadata_is_propagated() -> None:
    result = evaluate(
        make_rule(
            operator=PolicyOperator.EXISTS,
            metadata={
                "source": "policy-file",
                "line": 10,
            },
        ),
        {
            "value": "present",
        },
    )

    assert isinstance(
        result.metadata,
        MappingProxyType,
    )
    assert result.metadata["field_found"] is True
    assert isinstance(
        result.metadata["rule_metadata"],
        MappingProxyType,
    )
    assert (
        result.metadata["rule_metadata"]["source"]
        == "policy-file"
    )


def test_result_values_are_frozen_by_result_model() -> None:
    result = evaluate(
        make_rule(
            operator=PolicyOperator.EQ,
            value={
                "status": [
                    "active",
                    "draft",
                ],
            },
        ),
        {
            "value": {
                "status": [
                    "active",
                    "draft",
                ],
            },
        },
    )

    assert result.status is RuleResultStatus.PASSED
    assert isinstance(
        result.actual_value,
        MappingProxyType,
    )
    assert result.actual_value["status"] == (
        "active",
        "draft",
    )


def test_non_json_actual_value_becomes_error() -> None:
    result = evaluate(
        make_rule(
            operator=PolicyOperator.EXISTS,
        ),
        {
            "value": object(),
        },
    )

    assert result.status is RuleResultStatus.ERROR
    assert result.actual_value is None
    assert "non-JSON-compatible value" in result.error


def test_module_does_not_import_audit_or_engine() -> None:
    module_path = (
        Path(__file__).parents[1]
        / "src"
        / "sgoda"
        / "governance"
        / "rule_evaluator.py"
    )

    tree = ast.parse(
        module_path.read_text(
            encoding="utf-8-sig"
        )
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

    prohibited = (
        "sgoda.audit",
        "sgoda.cli",
        "sgoda.governance.policy_engine",
        "sgoda.governance.service",
    )

    assert not any(
        module == prefix
        or module.startswith(f"{prefix}.")
        for module in imported_modules
        for prefix in prohibited
    )


def test_public_api_contains_only_evaluate_rule() -> None:
    import sgoda.governance.rule_evaluator as module

    assert module.__all__ == [
        "evaluate_rule",
    ]
