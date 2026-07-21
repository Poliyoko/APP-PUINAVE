"""Pruebas de los modelos de dominio de gobernanza."""

from dataclasses import FrozenInstanceError
from types import MappingProxyType

import pytest

from sgoda.governance.exceptions import PolicyValidationError
from sgoda.governance.models import (
    PolicyDefinition,
    PolicyOperator,
    PolicyRule,
    PolicySeverity,
)


def make_rule(**overrides: object) -> PolicyRule:
    values: dict[str, object] = {
        "rule_id": "owner-required",
        "field": "governance.data_owner",
        "operator": PolicyOperator.EXISTS,
        "severity": PolicySeverity.ERROR,
        "message": "A data owner is required.",
    }
    values.update(overrides)
    return PolicyRule(**values)


def test_policy_rule_normalizes_enum_values() -> None:
    rule = PolicyRule(
        rule_id="owner-required",
        field="governance.data_owner",
        operator="exists",
        severity="warning",
    )

    assert rule.operator is PolicyOperator.EXISTS
    assert rule.severity is PolicySeverity.WARNING


def test_policy_rule_is_deeply_immutable() -> None:
    rule = make_rule(
        metadata={
            "tags": ["dama", "ownership"],
            "details": {"priority": 1},
        },
    )

    assert isinstance(rule.metadata, MappingProxyType)
    assert rule.metadata["tags"] == ("dama", "ownership")
    assert isinstance(rule.metadata["details"], MappingProxyType)

    with pytest.raises((FrozenInstanceError, AttributeError)):
        rule.rule_id = "changed"

    with pytest.raises(TypeError):
        rule.metadata["new"] = "value"

    with pytest.raises(TypeError):
        rule.metadata["details"]["priority"] = 2


def test_exists_operator_requires_none_value() -> None:
    with pytest.raises(PolicyValidationError, match="value=None"):
        make_rule(value="unexpected")


def test_in_operator_requires_non_empty_iterable() -> None:
    rule = make_rule(
        operator=PolicyOperator.IN,
        value=["public", "internal"],
    )

    assert rule.value == ("public", "internal")

    with pytest.raises(PolicyValidationError):
        make_rule(
            operator=PolicyOperator.IN,
            value=[],
        )

    with pytest.raises(PolicyValidationError):
        make_rule(
            operator=PolicyOperator.IN,
            value="public",
        )


def test_policy_definition_normalizes_rules_to_tuple() -> None:
    rule = make_rule()

    policy = PolicyDefinition(
        policy_id="dama-governance",
        name="DAMA governance baseline",
        rules=[rule],
    )

    assert policy.rules == (rule,)
    assert policy.version == "1.0"
    assert policy.enabled is True


def test_policy_definition_is_deeply_immutable() -> None:
    rule = make_rule()
    policy = PolicyDefinition(
        policy_id="dama-governance",
        name="DAMA governance baseline",
        rules=(rule,),
        metadata={"owners": ["architecture", "governance"]},
    )

    assert isinstance(policy.metadata, MappingProxyType)
    assert policy.metadata["owners"] == (
        "architecture",
        "governance",
    )

    with pytest.raises((FrozenInstanceError, AttributeError)):
        policy.rules = ()

    with pytest.raises(TypeError):
        policy.metadata["new"] = "value"


def test_policy_definition_requires_rules() -> None:
    with pytest.raises(PolicyValidationError, match="at least one"):
        PolicyDefinition(
            policy_id="empty",
            name="Empty policy",
            rules=(),
        )


def test_policy_definition_rejects_duplicate_rule_ids() -> None:
    rule = make_rule()

    with pytest.raises(PolicyValidationError, match="unique"):
        PolicyDefinition(
            policy_id="duplicates",
            name="Duplicate rules",
            rules=(rule, rule),
        )


def test_policy_definition_rejects_non_rule_entries() -> None:
    with pytest.raises(PolicyValidationError, match="PolicyRule"):
        PolicyDefinition(
            policy_id="invalid",
            name="Invalid policy",
            rules=("not-a-rule",),
        )


@pytest.mark.parametrize(
    ("operator", "value"),
    [
        (PolicyOperator.EQ, "eq"),
        (PolicyOperator.NE, "ne"),
        (PolicyOperator.GT, "gt"),
        (PolicyOperator.GTE, "gte"),
        (PolicyOperator.LT, "lt"),
        (PolicyOperator.LTE, "lte"),
        (PolicyOperator.IN, "in"),
        (PolicyOperator.NOT_IN, "not_in"),
        (PolicyOperator.CONTAINS, "contains"),
        (PolicyOperator.NOT_CONTAINS, "not_contains"),
        (PolicyOperator.EXISTS, "exists"),
        (PolicyOperator.NOT_EXISTS, "not_exists"),
    ],
)
def test_policy_operator_values(
    operator: PolicyOperator,
    value: str,
) -> None:
    assert operator.value == value
