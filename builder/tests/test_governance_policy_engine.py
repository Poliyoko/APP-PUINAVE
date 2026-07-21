"""Pruebas del motor de políticas de gobernanza."""

from __future__ import annotations

import ast
import inspect
from pathlib import Path
from types import MappingProxyType

import pytest

from sgoda.governance.exceptions import (
    PolicyValidationError,
)
from sgoda.governance.models import (
    PolicyDefinition,
    PolicyOperator,
    PolicyRule,
    PolicySeverity,
)
from sgoda.governance.policy_engine import (
    evaluate_policies,
    evaluate_policy,
)
from sgoda.governance.results import (
    PolicyResult,
    PolicyResultStatus,
    RuleResultStatus,
)


def make_rule(
    *,
    rule_id: str = "owner-exists",
    field: str = "governance.owner",
    operator: PolicyOperator = PolicyOperator.EXISTS,
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


def make_policy(
    *rules: PolicyRule,
    policy_id: str = "governance.owner",
    name: str = "Gobernanza mínima",
    version: str = "1.0.0",
    enabled: bool = True,
    metadata=None,
) -> PolicyDefinition:
    return PolicyDefinition(
        policy_id=policy_id,
        name=name,
        version=version,
        enabled=enabled,
        rules=rules or (
            make_rule(),
        ),
        metadata={} if metadata is None else metadata,
    )


def test_evaluate_policy_returns_policy_result() -> None:
    result = evaluate_policy(
        make_policy(),
        {
            "governance": {
                "owner": "Unidad de Gobierno de Datos",
            },
        },
    )

    assert isinstance(result, PolicyResult)
    assert result.policy_id == "governance.owner"
    assert result.name == "Gobernanza mínima"
    assert result.version == "1.0.0"
    assert result.enabled is True


def test_passed_policy() -> None:
    result = evaluate_policy(
        make_policy(),
        {
            "governance": {
                "owner": "Unidad de Gobierno de Datos",
            },
        },
    )

    assert result.status is PolicyResultStatus.PASSED
    assert result.passed is True
    assert result.passed_count == 1
    assert result.failed_count == 0
    assert result.error_count == 0


def test_failed_policy() -> None:
    policy = make_policy(
        make_rule(
            rule_id="status-active",
            field="status",
            operator=PolicyOperator.EQ,
            value="active",
            message="El estado debe ser active",
        ),
    )

    result = evaluate_policy(
        policy,
        {
            "status": "draft",
        },
    )

    assert result.status is PolicyResultStatus.FAILED
    assert result.failed is True
    assert result.failed_count == 1
    assert result.rule_results[0].message == (
        "El estado debe ser active"
    )


def test_rule_error_produces_policy_error() -> None:
    policy = make_policy(
        make_rule(
            rule_id="minimum-score",
            field="score",
            operator=PolicyOperator.GT,
            value=10,
        ),
    )

    result = evaluate_policy(
        policy,
        {
            "score": "not-numeric",
        },
    )

    assert result.status is PolicyResultStatus.ERROR
    assert result.has_error is True
    assert result.error_count == 1
    assert (
        result.rule_results[0].status
        is RuleResultStatus.ERROR
    )


def test_all_rules_are_evaluated() -> None:
    policy = make_policy(
        make_rule(
            rule_id="owner-exists",
            field="owner",
            operator=PolicyOperator.EXISTS,
        ),
        make_rule(
            rule_id="status-active",
            field="status",
            operator=PolicyOperator.EQ,
            value="active",
        ),
        make_rule(
            rule_id="score-minimum",
            field="score",
            operator=PolicyOperator.GTE,
            value=80,
        ),
    )

    result = evaluate_policy(
        policy,
        {
            "owner": "Gobierno de Datos",
            "status": "draft",
            "score": 90,
        },
    )

    assert result.total_count == 3
    assert result.passed_count == 2
    assert result.failed_count == 1
    assert tuple(
        item.rule_id
        for item in result.rule_results
    ) == (
        "owner-exists",
        "status-active",
        "score-minimum",
    )


def test_rule_order_is_preserved() -> None:
    policy = make_policy(
        make_rule(
            rule_id="first",
            field="first",
        ),
        make_rule(
            rule_id="second",
            field="second",
        ),
        make_rule(
            rule_id="third",
            field="third",
        ),
    )

    result = evaluate_policy(
        policy,
        {
            "first": 1,
            "second": 2,
            "third": 3,
        },
    )

    assert tuple(
        rule_result.rule_id
        for rule_result in result.rule_results
    ) == (
        "first",
        "second",
        "third",
    )


def test_disabled_policy_is_skipped() -> None:
    policy = make_policy(
        enabled=False,
    )

    result = evaluate_policy(
        policy,
        {},
    )

    assert result.enabled is False
    assert result.status is PolicyResultStatus.SKIPPED
    assert result.skipped is True
    assert result.rule_results == ()
    assert result.total_count == 0
    assert result.message == (
        "Policy is disabled and was not evaluated"
    )
    assert result.metadata["evaluation"] == "skipped"


def test_disabled_policy_does_not_require_fields() -> None:
    policy = make_policy(
        make_rule(
            field="required.value",
        ),
        enabled=False,
    )

    result = evaluate_policy(
        policy,
        {},
    )

    assert result.status is PolicyResultStatus.SKIPPED
    assert result.rule_results == ()


def test_policy_metadata_is_propagated() -> None:
    policy = make_policy(
        metadata={
            "framework": "DAMA-DMBOK",
            "domain": {
                "name": "Gobierno de Datos",
            },
        },
    )

    result = evaluate_policy(
        policy,
        {
            "governance": {
                "owner": "Unidad responsable",
            },
        },
    )

    assert isinstance(result.metadata, MappingProxyType)
    assert (
        result.metadata["policy_metadata"]["framework"]
        == "DAMA-DMBOK"
    )
    assert (
        result.metadata["policy_metadata"]["domain"]["name"]
        == "Gobierno de Datos"
    )
    assert result.metadata["rule_count"] == 1
    assert result.metadata["evaluation"] == "completed"


def test_values_are_not_modified() -> None:
    values = {
        "governance": {
            "owner": "Unidad responsable",
        },
    }

    original = {
        "governance": {
            "owner": "Unidad responsable",
        },
    }

    evaluate_policy(
        make_policy(),
        values,
    )

    assert values == original


@pytest.mark.parametrize(
    "invalid_values",
    [
        None,
        [],
        (),
        "values",
        123,
    ],
)
def test_values_must_be_mapping(
    invalid_values: object,
) -> None:
    with pytest.raises(
        PolicyValidationError,
        match="values must be a mapping",
    ):
        evaluate_policy(
            make_policy(),
            invalid_values,  # type: ignore[arg-type]
        )


def test_policy_must_be_policy_definition() -> None:
    with pytest.raises(
        PolicyValidationError,
        match="PolicyDefinition",
    ):
        evaluate_policy(
            object(),  # type: ignore[arg-type]
            {},
        )


def test_semantically_invalid_policy_is_rejected() -> None:
    policy = make_policy(
        policy_id="invalid policy id",
    )

    with pytest.raises(
        PolicyValidationError,
        match="unsupported characters",
    ):
        evaluate_policy(
            policy,
            {},
        )


def test_evaluate_policies_preserves_order() -> None:
    first = make_policy(
        policy_id="policy.first",
        name="Primera política",
    )
    second = make_policy(
        policy_id="policy.second",
        name="Segunda política",
    )

    results = evaluate_policies(
        (
            first,
            second,
        ),
        {
            "governance": {
                "owner": "Unidad responsable",
            },
        },
    )

    assert isinstance(results, tuple)
    assert tuple(
        result.policy_id
        for result in results
    ) == (
        "policy.first",
        "policy.second",
    )


def test_evaluate_policies_accepts_empty_iterable() -> None:
    assert evaluate_policies(
        [],
        {},
    ) == ()


def test_evaluate_policies_accepts_generator() -> None:
    policies = (
        make_policy(
            policy_id=f"policy.{index}",
            name=f"Política {index}",
        )
        for index in range(3)
    )

    results = evaluate_policies(
        policies,
        {
            "governance": {
                "owner": "Unidad responsable",
            },
        },
    )

    assert tuple(
        result.policy_id
        for result in results
    ) == (
        "policy.0",
        "policy.1",
        "policy.2",
    )


def test_evaluate_policies_supports_enabled_and_disabled() -> None:
    enabled = make_policy(
        policy_id="policy.enabled",
        name="Política habilitada",
    )
    disabled = make_policy(
        policy_id="policy.disabled",
        name="Política deshabilitada",
        enabled=False,
    )

    results = evaluate_policies(
        (
            enabled,
            disabled,
        ),
        {
            "governance": {
                "owner": "Unidad responsable",
            },
        },
    )

    assert (
        results[0].status
        is PolicyResultStatus.PASSED
    )
    assert (
        results[1].status
        is PolicyResultStatus.SKIPPED
    )


def test_evaluate_policies_rejects_duplicate_ids() -> None:
    first = make_policy(
        policy_id="policy.same",
        name="Primera",
    )
    second = make_policy(
        policy_id="policy.same",
        name="Segunda",
    )

    with pytest.raises(
        PolicyValidationError,
        match="identifiers must be unique",
    ):
        evaluate_policies(
            (
                first,
                second,
            ),
            {},
        )


@pytest.mark.parametrize(
    "invalid_policies",
    [
        None,
        123,
        "policies",
        b"policies",
        {},
    ],
)
def test_evaluate_policies_rejects_invalid_collection(
    invalid_policies: object,
) -> None:
    with pytest.raises(PolicyValidationError):
        evaluate_policies(
            invalid_policies,  # type: ignore[arg-type]
            {},
        )


def test_result_is_deterministic() -> None:
    policy = make_policy(
        make_rule(
            rule_id="status",
            field="status",
            operator=PolicyOperator.EQ,
            value={
                "state": [
                    "active",
                    "draft",
                ],
            },
        ),
        metadata={
            "z": 1,
            "a": 2,
        },
    )

    values = {
        "status": {
            "state": [
                "active",
                "draft",
            ],
        },
    }

    first = evaluate_policy(policy, values)
    second = evaluate_policy(policy, values)

    assert first == second
    assert first.rule_results == second.rule_results


def test_module_has_no_forbidden_dependencies() -> None:
    path = Path(
        "src/sgoda/governance/policy_engine.py"
    )

    tree = ast.parse(
        path.read_text(encoding="utf-8-sig"),
        filename=str(path),
    )

    prohibited = (
        "sgoda.audit",
        "sgoda.cli",
        "sgoda.services",
    )

    violations: list[str] = []

    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            modules = [
                alias.name
                for alias in node.names
            ]
        elif isinstance(node, ast.ImportFrom):
            modules = (
                [node.module]
                if node.module
                else []
            )
        else:
            continue

        for module in modules:
            if any(
                module == prefix
                or module.startswith(f"{prefix}.")
                for prefix in prohibited
            ):
                violations.append(module)

    assert not violations


def test_public_api() -> None:
    import sgoda.governance.policy_engine as module

    assert module.__all__ == [
        "evaluate_policies",
        "evaluate_policy",
    ]

    policy_signature = inspect.signature(
        evaluate_policy
    )
    policies_signature = inspect.signature(
        evaluate_policies
    )

    assert tuple(policy_signature.parameters) == (
        "policy",
        "values",
    )
    assert tuple(policies_signature.parameters) == (
        "policies",
        "values",
    )
