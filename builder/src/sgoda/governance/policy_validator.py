"""Validación semántica de políticas de gobernanza."""

from __future__ import annotations

import math
import re
from collections.abc import Iterable, Mapping
from enum import Enum
from typing import Any

from .exceptions import PolicyValidationError
from .models import (
    PolicyDefinition,
    PolicyOperator,
    PolicyRule,
)


_IDENTIFIER_PATTERN = re.compile(
    r"^[A-Za-z0-9][A-Za-z0-9._-]*$"
)

_VERSION_PATTERN = re.compile(
    r"^[A-Za-z0-9][A-Za-z0-9.+_-]*$"
)

_FIELD_PATH_PATTERN = re.compile(
    r"""
    ^
    [A-Za-z_][A-Za-z0-9_-]*
    (?:
        \.[A-Za-z_][A-Za-z0-9_-]*
        |
        \[(?:0|[1-9][0-9]*)\]
    )*
    $
    """,
    re.VERBOSE,
)

_ORDERING_OPERATORS = frozenset(
    {
        PolicyOperator.GT,
        PolicyOperator.GTE,
        PolicyOperator.LT,
        PolicyOperator.LTE,
    }
)

_MEMBERSHIP_OPERATORS = frozenset(
    {
        PolicyOperator.IN,
        PolicyOperator.NOT_IN,
    }
)

_CONTAINMENT_OPERATORS = frozenset(
    {
        PolicyOperator.CONTAINS,
        PolicyOperator.NOT_CONTAINS,
    }
)

_EXISTENCE_OPERATORS = frozenset(
    {
        PolicyOperator.EXISTS,
        PolicyOperator.NOT_EXISTS,
    }
)


def _raise_validation_error(
    message: str,
    *,
    policy_id: str | None = None,
    rule_id: str | None = None,
    field: str | None = None,
    context: Mapping[str, Any] | None = None,
) -> None:
    """Lanza un error semántico con contexto estructurado."""
    raise PolicyValidationError(
        message,
        policy_id=policy_id,
        rule_id=rule_id,
        field=field,
        context=context,
    )


def _validate_identifier(
    value: str,
    *,
    name: str,
    policy_id: str | None = None,
    rule_id: str | None = None,
) -> None:
    """Valida identificadores estables para políticas y reglas."""
    if not _IDENTIFIER_PATTERN.fullmatch(value):
        _raise_validation_error(
            f"{name} contains unsupported characters",
            policy_id=policy_id,
            rule_id=rule_id,
            field=name,
            context={
                "value": value,
                "pattern": _IDENTIFIER_PATTERN.pattern,
            },
        )


def _validate_version(policy: PolicyDefinition) -> None:
    """Valida el formato semántico de la versión."""
    if not _VERSION_PATTERN.fullmatch(policy.version):
        _raise_validation_error(
            "version contains unsupported characters",
            policy_id=policy.policy_id,
            field="version",
            context={
                "value": policy.version,
                "pattern": _VERSION_PATTERN.pattern,
            },
        )


def _validate_field_path(
    rule: PolicyRule,
    *,
    policy_id: str,
) -> None:
    """Valida rutas de campos anidados y posiciones de secuencia."""
    if not _FIELD_PATH_PATTERN.fullmatch(rule.field):
        _raise_validation_error(
            "field must be a valid dotted or indexed path",
            policy_id=policy_id,
            rule_id=rule.rule_id,
            field="field",
            context={
                "value": rule.field,
            },
        )


def _validate_json_value(
    value: Any,
    *,
    policy_id: str,
    field: str,
    rule_id: str | None = None,
    path: str = "$",
) -> None:
    """Valida recursivamente que un valor sea JSON compatible."""
    if value is None or isinstance(value, (str, bool, int)):
        return

    if isinstance(value, float):
        if not math.isfinite(value):
            _raise_validation_error(
                "value must not contain NaN or infinity",
                policy_id=policy_id,
                rule_id=rule_id,
                field=field,
                context={
                    "path": path,
                    "value": repr(value),
                },
            )

        return

    if isinstance(value, Enum):
        _validate_json_value(
            value.value,
            policy_id=policy_id,
            rule_id=rule_id,
            field=field,
            path=path,
        )
        return

    if isinstance(value, Mapping):
        for key, item in value.items():
            if not isinstance(key, str):
                _raise_validation_error(
                    "mapping keys must be strings",
                    policy_id=policy_id,
                    rule_id=rule_id,
                    field=field,
                    context={
                        "path": path,
                        "key_type": type(key).__name__,
                    },
                )

            _validate_json_value(
                item,
                policy_id=policy_id,
                rule_id=rule_id,
                field=field,
                path=f"{path}.{key}",
            )

        return

    if isinstance(value, (tuple, list)):
        for index, item in enumerate(value):
            _validate_json_value(
                item,
                policy_id=policy_id,
                rule_id=rule_id,
                field=field,
                path=f"{path}[{index}]",
            )

        return

    _raise_validation_error(
        "value is not JSON compatible",
        policy_id=policy_id,
        rule_id=rule_id,
        field=field,
        context={
            "path": path,
            "type": type(value).__name__,
        },
    )


def _is_orderable_operand(value: Any) -> bool:
    """Indica si un operando puede usarse en comparación ordenada."""
    if isinstance(value, bool):
        return False

    if isinstance(value, (int, str)):
        return True

    return isinstance(value, float) and math.isfinite(value)


def _validate_rule_operand(
    rule: PolicyRule,
    *,
    policy_id: str,
) -> None:
    """Valida la compatibilidad semántica entre operador y operando."""
    operator = rule.operator

    if operator in _EXISTENCE_OPERATORS:
        if rule.value is not None:
            _raise_validation_error(
                f"{operator.value} requires value=None",
                policy_id=policy_id,
                rule_id=rule.rule_id,
                field="value",
                context={
                    "operator": operator.value,
                },
            )

        return

    if operator in _ORDERING_OPERATORS:
        if not _is_orderable_operand(rule.value):
            _raise_validation_error(
                f"{operator.value} requires an orderable scalar value",
                policy_id=policy_id,
                rule_id=rule.rule_id,
                field="value",
                context={
                    "operator": operator.value,
                    "type": type(rule.value).__name__,
                },
            )

        return

    if operator in _MEMBERSHIP_OPERATORS:
        if not isinstance(rule.value, tuple) or not rule.value:
            _raise_validation_error(
                f"{operator.value} requires a non-empty collection",
                policy_id=policy_id,
                rule_id=rule.rule_id,
                field="value",
                context={
                    "operator": operator.value,
                },
            )

        return

    if operator in _CONTAINMENT_OPERATORS:
        if isinstance(rule.value, Mapping):
            _raise_validation_error(
                f"{operator.value} does not accept a mapping operand",
                policy_id=policy_id,
                rule_id=rule.rule_id,
                field="value",
                context={
                    "operator": operator.value,
                },
            )


def _fingerprint(value: Any) -> Any:
    """Genera una huella comparable y estable para un valor."""
    if isinstance(value, Enum):
        return (
            "enum",
            type(value).__qualname__,
            _fingerprint(value.value),
        )

    if isinstance(value, Mapping):
        return (
            "mapping",
            tuple(
                (
                    key,
                    _fingerprint(item),
                )
                for key, item in sorted(value.items())
            ),
        )

    if isinstance(value, (tuple, list)):
        return (
            "sequence",
            tuple(_fingerprint(item) for item in value),
        )

    return (
        type(value).__qualname__,
        value,
    )


def _validate_duplicate_rules(
    policy: PolicyDefinition,
) -> None:
    """Detecta reglas semánticamente duplicadas."""
    signatures: dict[
        tuple[str, PolicyOperator, Any],
        str,
    ] = {}

    for rule in policy.rules:
        signature = (
            rule.field,
            rule.operator,
            _fingerprint(rule.value),
        )

        previous_rule_id = signatures.get(signature)

        if previous_rule_id is not None:
            _raise_validation_error(
                "policy contains semantically duplicate rules",
                policy_id=policy.policy_id,
                rule_id=rule.rule_id,
                field="rules",
                context={
                    "duplicate_of": previous_rule_id,
                    "operator": rule.operator.value,
                    "target_field": rule.field,
                },
            )

        signatures[signature] = rule.rule_id


def _validate_existence_conflicts(
    policy: PolicyDefinition,
) -> None:
    """Detecta requisitos de existencia mutuamente excluyentes."""
    by_field: dict[str, dict[PolicyOperator, str]] = {}

    for rule in policy.rules:
        if rule.operator not in _EXISTENCE_OPERATORS:
            continue

        operators = by_field.setdefault(rule.field, {})
        operators[rule.operator] = rule.rule_id

    for field_name, operators in by_field.items():
        if (
            PolicyOperator.EXISTS in operators
            and PolicyOperator.NOT_EXISTS in operators
        ):
            _raise_validation_error(
                "field cannot be required to both exist and not exist",
                policy_id=policy.policy_id,
                field="rules",
                context={
                    "target_field": field_name,
                    "exists_rule": operators[PolicyOperator.EXISTS],
                    "not_exists_rule": operators[
                        PolicyOperator.NOT_EXISTS
                    ],
                },
            )


def _validate_equality_conflicts(
    policy: PolicyDefinition,
) -> None:
    """Detecta restricciones de igualdad incompatibles."""
    equals_by_field: dict[str, tuple[Any, str]] = {}
    not_equals_by_field: dict[str, dict[Any, str]] = {}
    in_by_field: dict[str, tuple[set[Any], str]] = {}
    not_in_by_field: dict[str, tuple[set[Any], str]] = {}

    for rule in policy.rules:
        value_fingerprint = _fingerprint(rule.value)

        if rule.operator is PolicyOperator.EQ:
            previous = equals_by_field.get(rule.field)

            if (
                previous is not None
                and previous[0] != value_fingerprint
            ):
                _raise_validation_error(
                    "field cannot equal multiple different values",
                    policy_id=policy.policy_id,
                    rule_id=rule.rule_id,
                    field="rules",
                    context={
                        "target_field": rule.field,
                        "conflicting_rule": previous[1],
                    },
                )

            equals_by_field[rule.field] = (
                value_fingerprint,
                rule.rule_id,
            )

        elif rule.operator is PolicyOperator.NE:
            not_equals_by_field.setdefault(
                rule.field,
                {},
            )[value_fingerprint] = rule.rule_id

        elif rule.operator is PolicyOperator.IN:
            in_by_field[rule.field] = (
                {
                    _fingerprint(item)
                    for item in rule.value
                },
                rule.rule_id,
            )

        elif rule.operator is PolicyOperator.NOT_IN:
            not_in_by_field[rule.field] = (
                {
                    _fingerprint(item)
                    for item in rule.value
                },
                rule.rule_id,
            )

    for field_name, (expected, equality_rule_id) in (
        equals_by_field.items()
    ):
        excluded = not_equals_by_field.get(field_name, {})

        if expected in excluded:
            _raise_validation_error(
                "equal and not-equal rules conflict",
                policy_id=policy.policy_id,
                rule_id=equality_rule_id,
                field="rules",
                context={
                    "target_field": field_name,
                    "conflicting_rule": excluded[expected],
                },
            )

        allowed_entry = in_by_field.get(field_name)

        if allowed_entry is not None:
            allowed, in_rule_id = allowed_entry

            if expected not in allowed:
                _raise_validation_error(
                    "equal value is excluded by an in rule",
                    policy_id=policy.policy_id,
                    rule_id=equality_rule_id,
                    field="rules",
                    context={
                        "target_field": field_name,
                        "conflicting_rule": in_rule_id,
                    },
                )

        denied_entry = not_in_by_field.get(field_name)

        if denied_entry is not None:
            denied, not_in_rule_id = denied_entry

            if expected in denied:
                _raise_validation_error(
                    "equal value is excluded by a not_in rule",
                    policy_id=policy.policy_id,
                    rule_id=equality_rule_id,
                    field="rules",
                    context={
                        "target_field": field_name,
                        "conflicting_rule": not_in_rule_id,
                    },
                )


def validate_rule(
    rule: PolicyRule,
    *,
    policy_id: str,
) -> PolicyRule:
    """Valida semánticamente una regla de política.

    La regla original se devuelve sin modificación cuando es válida.
    """
    if not isinstance(rule, PolicyRule):
        _raise_validation_error(
            "rule must be a PolicyRule instance",
            policy_id=policy_id,
            field="rule",
            context={
                "type": type(rule).__name__,
            },
        )

    if (
        not isinstance(policy_id, str)
        or not policy_id.strip()
    ):
        _raise_validation_error(
            "policy_id must be a non-empty string",
            field="policy_id",
        )

    normalized_policy_id = policy_id.strip()

    _validate_identifier(
        rule.rule_id,
        name="rule_id",
        policy_id=normalized_policy_id,
        rule_id=rule.rule_id,
    )
    _validate_field_path(
        rule,
        policy_id=normalized_policy_id,
    )
    _validate_json_value(
        rule.value,
        policy_id=normalized_policy_id,
        rule_id=rule.rule_id,
        field="value",
    )
    _validate_json_value(
        rule.metadata,
        policy_id=normalized_policy_id,
        rule_id=rule.rule_id,
        field="metadata",
    )
    _validate_rule_operand(
        rule,
        policy_id=normalized_policy_id,
    )

    return rule


def validate_policy(
    policy: PolicyDefinition,
    *,
    allow_disabled: bool = True,
) -> PolicyDefinition:
    """Valida semánticamente una política.

    Args:
        policy:
            Política de dominio previamente construida.
        allow_disabled:
            Cuando es ``False``, una política deshabilitada se considera
            inválida para procesamiento.

    Returns:
        La misma instancia recibida, sin modificaciones.

    Raises:
        PolicyValidationError:
            Si la política presenta una inconsistencia semántica.
    """
    if not isinstance(policy, PolicyDefinition):
        _raise_validation_error(
            "policy must be a PolicyDefinition instance",
            field="policy",
            context={
                "type": type(policy).__name__,
            },
        )

    if not isinstance(allow_disabled, bool):
        _raise_validation_error(
            "allow_disabled must be a boolean",
            policy_id=policy.policy_id,
            field="allow_disabled",
            context={
                "type": type(allow_disabled).__name__,
            },
        )

    _validate_identifier(
        policy.policy_id,
        name="policy_id",
        policy_id=policy.policy_id,
    )
    _validate_version(policy)

    if not allow_disabled and not policy.enabled:
        _raise_validation_error(
            "disabled policy is not allowed",
            policy_id=policy.policy_id,
            field="enabled",
        )

    _validate_json_value(
        policy.metadata,
        policy_id=policy.policy_id,
        field="metadata",
    )

    for rule in policy.rules:
        validate_rule(
            rule,
            policy_id=policy.policy_id,
        )

    _validate_duplicate_rules(policy)
    _validate_existence_conflicts(policy)
    _validate_equality_conflicts(policy)

    return policy


def validate_policies(
    policies: Iterable[PolicyDefinition],
    *,
    allow_disabled: bool = True,
) -> tuple[PolicyDefinition, ...]:
    """Valida varias políticas y conserva el orden de entrada."""
    if isinstance(
        policies,
        (str, bytes, bytearray, Mapping),
    ):
        _raise_validation_error(
            "policies must be an iterable of PolicyDefinition instances",
            field="policies",
            context={
                "type": type(policies).__name__,
            },
        )

    try:
        normalized = tuple(policies)
    except TypeError as exc:
        raise PolicyValidationError(
            "policies must be iterable",
            field="policies",
            context={
                "type": type(policies).__name__,
            },
        ) from exc

    seen_policy_ids: dict[str, int] = {}

    for index, policy in enumerate(normalized):
        if not isinstance(policy, PolicyDefinition):
            _raise_validation_error(
                "policies must contain only PolicyDefinition instances",
                field="policies",
                context={
                    "index": index,
                    "type": type(policy).__name__,
                },
            )

        previous_index = seen_policy_ids.get(policy.policy_id)

        if previous_index is not None:
            _raise_validation_error(
                "policy identifiers must be unique",
                policy_id=policy.policy_id,
                field="policies",
                context={
                    "index": index,
                    "duplicate_of_index": previous_index,
                },
            )

        seen_policy_ids[policy.policy_id] = index
        validate_policy(
            policy,
            allow_disabled=allow_disabled,
        )

    return normalized


__all__ = [
    "validate_policies",
    "validate_policy",
    "validate_rule",
]
