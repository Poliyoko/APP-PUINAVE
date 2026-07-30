"""Pruebas del contrato de excepciones de gobernanza."""

from types import MappingProxyType

import pytest

from sgoda.governance.exceptions import (
    GovernanceError,
    PolicyEvaluationError,
    PolicyLoadError,
    PolicySerializationError,
    PolicyValidationError,
)


def test_governance_error_exposes_immutable_context() -> None:
    error = GovernanceError(
        "failure",
        policy_id="policy-1",
        rule_id="rule-1",
        context={
            "nested": {
                "items": [1, 2],
            },
        },
    )

    assert str(error) == "failure"
    assert error.context["policy_id"] == "policy-1"
    assert error.context["rule_id"] == "rule-1"
    assert isinstance(error.context, MappingProxyType)
    assert isinstance(error.context["nested"], MappingProxyType)
    assert error.context["nested"]["items"] == (1, 2)

    with pytest.raises(TypeError):
        error.context["new"] = "value"

    with pytest.raises(TypeError):
        error.context["nested"]["new"] = "value"


def test_governance_error_repr_is_deterministic() -> None:
    first = GovernanceError(
        "failure",
        context={"z": 2, "a": 1},
    )
    second = GovernanceError(
        "failure",
        context={"a": 1, "z": 2},
    )

    assert repr(first) == repr(second)


def test_governance_error_validates_message() -> None:
    with pytest.raises(ValueError, match="message"):
        GovernanceError("   ")


def test_governance_error_rejects_conflicting_context_keys() -> None:
    with pytest.raises(ValueError, match="conflicts"):
        GovernanceError(
            "failure",
            policy_id="policy-1",
            context={"policy_id": "other"},
        )


@pytest.mark.parametrize(
    "error_type",
    [
        PolicyValidationError,
        PolicyLoadError,
        PolicySerializationError,
        PolicyEvaluationError,
    ],
)
def test_specific_exceptions_derive_from_governance_error(
    error_type: type[GovernanceError],
) -> None:
    assert issubclass(error_type, GovernanceError)
