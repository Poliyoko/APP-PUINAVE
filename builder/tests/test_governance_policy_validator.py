"""Pruebas del validador semántico de políticas."""

from __future__ import annotations

import ast
import math
from pathlib import Path

import pytest

from sgoda.governance.exceptions import PolicyValidationError
from sgoda.governance.models import (
    PolicyDefinition,
    PolicyOperator,
    PolicyRule,
)
from sgoda.governance.policy_validator import (
    validate_policies,
    validate_policy,
    validate_rule,
)


def make_rule(
    *,
    rule_id: str = "rule-1",
    field: str = "governance.owner",
    operator: PolicyOperator = PolicyOperator.EXISTS,
    value=None,
    metadata=None,
) -> PolicyRule:
    return PolicyRule(
        rule_id=rule_id,
        field=field,
        operator=operator,
        value=value,
        metadata={} if metadata is None else metadata,
    )


def make_policy(
    *rules: PolicyRule,
    policy_id: str = "governance.owner",
    version: str = "1.0.0",
    enabled: bool = True,
    metadata=None,
) -> PolicyDefinition:
    return PolicyDefinition(
        policy_id=policy_id,
        name="Política de prueba",
        version=version,
        enabled=enabled,
        rules=rules or (make_rule(),),
        metadata={} if metadata is None else metadata,
    )


def test_validate_rule_returns_same_instance() -> None:
    rule = make_rule()

    assert validate_rule(
        rule,
        policy_id="governance.owner",
    ) is rule


def test_validate_policy_returns_same_instance() -> None:
    policy = make_policy()

    assert validate_policy(policy) is policy


def test_validate_policy_rejects_non_policy() -> None:
    with pytest.raises(
        PolicyValidationError,
        match="PolicyDefinition",
    ):
        validate_policy(object())  # type: ignore[arg-type]


def test_validate_rule_rejects_non_rule() -> None:
    with pytest.raises(
        PolicyValidationError,
        match="PolicyRule",
    ):
        validate_rule(  # type: ignore[arg-type]
            object(),
            policy_id="policy-1",
        )


@pytest.mark.parametrize(
    "policy_id",
    [
        "policy id",
        ".policy",
        "policy/",
        "área.policy",
    ],
)
def test_invalid_policy_identifier_is_rejected(
    policy_id: str,
) -> None:
    policy = make_policy(policy_id=policy_id)

    with pytest.raises(
        PolicyValidationError,
        match="unsupported characters",
    ):
        validate_policy(policy)


@pytest.mark.parametrize(
    "rule_id",
    [
        "rule id",
        ".rule",
        "rule/",
        "regla-á",
    ],
)
def test_invalid_rule_identifier_is_rejected(
    rule_id: str,
) -> None:
    policy = make_policy(
        make_rule(rule_id=rule_id),
    )

    with pytest.raises(
        PolicyValidationError,
        match="unsupported characters",
    ):
        validate_policy(policy)


@pytest.mark.parametrize(
    "field",
    [
        ".owner",
        "governance..owner",
        "owner.",
        "owners[-1]",
        "owners[01]",
        "owners[]",
        "owner name",
    ],
)
def test_invalid_field_path_is_rejected(
    field: str,
) -> None:
    policy = make_policy(
        make_rule(field=field),
    )

    with pytest.raises(
        PolicyValidationError,
        match="valid dotted or indexed path",
    ):
        validate_policy(policy)


@pytest.mark.parametrize(
    "field",
    [
        "owner",
        "governance.owner",
        "owners[0].name",
        "metadata.data-owner",
        "_internal.value_1",
    ],
)
def test_valid_field_paths_are_accepted(
    field: str,
) -> None:
    policy = make_policy(
        make_rule(field=field),
    )

    assert validate_policy(policy) is policy


@pytest.mark.parametrize(
    "version",
    [
        "1 0",
        ".1.0",
        "1/0",
        "v1:beta",
    ],
)
def test_invalid_version_is_rejected(
    version: str,
) -> None:
    policy = make_policy(version=version)

    with pytest.raises(
        PolicyValidationError,
        match="version contains unsupported",
    ):
        validate_policy(policy)


@pytest.mark.parametrize(
    "version",
    [
        "1",
        "1.0.0",
        "v2-beta",
        "2026.1+build_4",
    ],
)
def test_valid_version_is_accepted(
    version: str,
) -> None:
    policy = make_policy(version=version)

    assert validate_policy(policy) is policy


def test_disabled_policy_is_allowed_by_default() -> None:
    policy = make_policy(enabled=False)

    assert validate_policy(policy) is policy


def test_disabled_policy_can_be_rejected() -> None:
    policy = make_policy(enabled=False)

    with pytest.raises(
        PolicyValidationError,
        match="disabled policy",
    ):
        validate_policy(
            policy,
            allow_disabled=False,
        )


def test_allow_disabled_must_be_boolean() -> None:
    with pytest.raises(
        PolicyValidationError,
        match="must be a boolean",
    ):
        validate_policy(
            make_policy(),
            allow_disabled=1,  # type: ignore[arg-type]
        )


@pytest.mark.parametrize(
    "operator",
    [
        PolicyOperator.GT,
        PolicyOperator.GTE,
        PolicyOperator.LT,
        PolicyOperator.LTE,
    ],
)
def test_ordering_operator_accepts_numeric_operand(
    operator: PolicyOperator,
) -> None:
    policy = make_policy(
        make_rule(
            operator=operator,
            value=10,
        ),
    )

    assert validate_policy(policy) is policy


@pytest.mark.parametrize(
    "operator",
    [
        PolicyOperator.GT,
        PolicyOperator.GTE,
        PolicyOperator.LT,
        PolicyOperator.LTE,
    ],
)
def test_ordering_operator_rejects_boolean(
    operator: PolicyOperator,
) -> None:
    policy = make_policy(
        make_rule(
            operator=operator,
            value=True,
        ),
    )

    with pytest.raises(
        PolicyValidationError,
        match="orderable scalar",
    ):
        validate_policy(policy)


def test_non_finite_rule_value_is_rejected() -> None:
    policy = make_policy(
        make_rule(
            operator=PolicyOperator.EQ,
            value=math.inf,
        ),
    )

    with pytest.raises(
        PolicyValidationError,
        match="NaN or infinity",
    ):
        validate_policy(policy)


def test_nested_non_finite_metadata_is_rejected() -> None:
    policy = make_policy(
        metadata={
            "limits": {
                "value": math.nan,
            },
        },
    )

    with pytest.raises(
        PolicyValidationError,
        match="NaN or infinity",
    ) as captured:
        validate_policy(policy)

    assert captured.value.context["path"] == "$.limits.value"


def test_non_json_value_is_rejected() -> None:
    policy = make_policy(
        make_rule(
            operator=PolicyOperator.EQ,
            value=complex(1, 2),
        ),
    )

    with pytest.raises(
        PolicyValidationError,
        match="not JSON compatible",
    ):
        validate_policy(policy)


def test_duplicate_semantic_rules_are_rejected() -> None:
    policy = make_policy(
        make_rule(
            rule_id="rule-1",
            operator=PolicyOperator.EQ,
            value="active",
        ),
        make_rule(
            rule_id="rule-2",
            operator=PolicyOperator.EQ,
            value="active",
        ),
    )

    with pytest.raises(
        PolicyValidationError,
        match="semantically duplicate",
    ) as captured:
        validate_policy(policy)

    assert captured.value.context["duplicate_of"] == "rule-1"


def test_exists_and_not_exists_conflict() -> None:
    policy = make_policy(
        make_rule(
            rule_id="exists",
            operator=PolicyOperator.EXISTS,
        ),
        make_rule(
            rule_id="not-exists",
            operator=PolicyOperator.NOT_EXISTS,
        ),
    )

    with pytest.raises(
        PolicyValidationError,
        match="both exist and not exist",
    ):
        validate_policy(policy)


def test_different_equal_values_conflict() -> None:
    policy = make_policy(
        make_rule(
            rule_id="eq-active",
            field="status",
            operator=PolicyOperator.EQ,
            value="active",
        ),
        make_rule(
            rule_id="eq-draft",
            field="status",
            operator=PolicyOperator.EQ,
            value="draft",
        ),
    )

    with pytest.raises(
        PolicyValidationError,
        match="multiple different values",
    ):
        validate_policy(policy)


def test_equal_and_not_equal_same_value_conflict() -> None:
    policy = make_policy(
        make_rule(
            rule_id="eq-active",
            field="status",
            operator=PolicyOperator.EQ,
            value="active",
        ),
        make_rule(
            rule_id="ne-active",
            field="status",
            operator=PolicyOperator.NE,
            value="active",
        ),
    )

    with pytest.raises(
        PolicyValidationError,
        match="equal and not-equal",
    ):
        validate_policy(policy)


def test_equal_value_must_be_in_allowed_collection() -> None:
    policy = make_policy(
        make_rule(
            rule_id="eq-archived",
            field="status",
            operator=PolicyOperator.EQ,
            value="archived",
        ),
        make_rule(
            rule_id="allowed",
            field="status",
            operator=PolicyOperator.IN,
            value=("active", "draft"),
        ),
    )

    with pytest.raises(
        PolicyValidationError,
        match="excluded by an in rule",
    ):
        validate_policy(policy)


def test_equal_value_must_not_be_denied() -> None:
    policy = make_policy(
        make_rule(
            rule_id="eq-active",
            field="status",
            operator=PolicyOperator.EQ,
            value="active",
        ),
        make_rule(
            rule_id="denied",
            field="status",
            operator=PolicyOperator.NOT_IN,
            value=("active", "blocked"),
        ),
    )

    with pytest.raises(
        PolicyValidationError,
        match="excluded by a not_in rule",
    ):
        validate_policy(policy)


def test_compatible_equality_and_membership_rules_pass() -> None:
    policy = make_policy(
        make_rule(
            rule_id="eq-active",
            field="status",
            operator=PolicyOperator.EQ,
            value="active",
        ),
        make_rule(
            rule_id="allowed",
            field="status",
            operator=PolicyOperator.IN,
            value=("active", "draft"),
        ),
        make_rule(
            rule_id="denied",
            field="status",
            operator=PolicyOperator.NOT_IN,
            value=("blocked", "deleted"),
        ),
    )

    assert validate_policy(policy) is policy


def test_validate_policies_preserves_order() -> None:
    first = make_policy(policy_id="policy.first")
    second = make_policy(policy_id="policy.second")

    assert validate_policies([first, second]) == (
        first,
        second,
    )


def test_validate_policies_accepts_empty_iterable() -> None:
    assert validate_policies([]) == ()


@pytest.mark.parametrize(
    "value",
    [
        "policy",
        b"policy",
        {"policy": "value"},
        42,
    ],
)
def test_validate_policies_rejects_invalid_container(
    value,
) -> None:
    with pytest.raises(PolicyValidationError):
        validate_policies(value)


def test_validate_policies_rejects_invalid_item() -> None:
    with pytest.raises(
        PolicyValidationError,
        match="only PolicyDefinition",
    ):
        validate_policies(
            [
                make_policy(),
                object(),
            ]
        )


def test_validate_policies_rejects_duplicate_policy_ids() -> None:
    first = make_policy(policy_id="policy.same")
    second = make_policy(policy_id="policy.same")

    with pytest.raises(
        PolicyValidationError,
        match="identifiers must be unique",
    ) as captured:
        validate_policies([first, second])

    assert captured.value.context["duplicate_of_index"] == 0
    assert captured.value.context["index"] == 1


def test_module_does_not_import_audit() -> None:
    module_path = (
        Path(__file__).parents[1]
        / "src"
        / "sgoda"
        / "governance"
        / "policy_validator.py"
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
