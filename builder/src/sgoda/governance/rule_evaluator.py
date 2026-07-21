"""Evaluación determinista de reglas individuales de gobernanza."""

from __future__ import annotations

import math
import re
from collections.abc import Mapping, Sequence
from enum import Enum
from typing import Any

from .exceptions import PolicyValidationError
from .models import (
    PolicyOperator,
    PolicyRule,
)
from .results import (
    RuleResult,
    RuleResultStatus,
)


_MISSING = object()

_FIELD_TOKEN_PATTERN = re.compile(
    r"""
    (?P<name>[A-Za-z_][A-Za-z0-9_-]*)
    |
    \[(?P<index>0|[1-9][0-9]*)\]
    """,
    re.VERBOSE,
)


def _require_policy_id(value: Any) -> str:
    """Valida y normaliza el identificador de la política."""
    if not isinstance(value, str) or not value.strip():
        raise PolicyValidationError(
            "policy_id must be a non-empty string",
            field="policy_id",
        )

    return value.strip()


def _parse_field_path(field_path: str) -> tuple[str | int, ...]:
    """Convierte una ruta validada en componentes navegables."""
    tokens: list[str | int] = []
    position = 0

    for match in _FIELD_TOKEN_PATTERN.finditer(field_path):
        if match.start() != position:
            if (
                position < len(field_path)
                and field_path[position] == "."
            ):
                position += 1

            if match.start() != position:
                raise ValueError(
                    f"invalid field path near position {position}"
                )

        name = match.group("name")
        index = match.group("index")

        if name is not None:
            tokens.append(name)
        elif index is not None:
            tokens.append(int(index))

        position = match.end()

        if (
            position < len(field_path)
            and field_path[position] == "."
        ):
            position += 1

    if position != len(field_path) or not tokens:
        raise ValueError("invalid field path")

    return tuple(tokens)


def _resolve_field(
    values: Mapping[str, Any],
    field_path: str,
) -> tuple[bool, Any]:
    """Localiza un campo anidado en mappings y secuencias."""
    current: Any = values

    for token in _parse_field_path(field_path):
        if isinstance(token, str):
            if not isinstance(current, Mapping):
                return False, _MISSING

            if token not in current:
                return False, _MISSING

            current = current[token]
            continue

        if (
            not isinstance(current, Sequence)
            or isinstance(
                current,
                (str, bytes, bytearray),
            )
        ):
            return False, _MISSING

        if token >= len(current):
            return False, _MISSING

        current = current[token]

    return True, current


def _values_equal(left: Any, right: Any) -> bool:
    """Compara valores mediante una representación JSON canónica.

    La normalización evita diferencias accidentales entre las estructuras
    mutables del contexto y las estructuras inmutables almacenadas por los
    modelos, como ``list`` frente a ``tuple`` o ``dict`` frente a
    ``MappingProxyType``.
    """
    normalized_left = _to_result_value(
        left,
        path="$.actual_value",
    )
    normalized_right = _to_result_value(
        right,
        path="$.expected_value",
    )

    result = normalized_left == normalized_right

    if isinstance(result, bool):
        return result

    raise TypeError(
        "equality comparison did not produce a boolean"
    )


def _evaluate_operator(
    *,
    operator: PolicyOperator,
    found: bool,
    actual: Any,
    expected: Any,
) -> bool:
    """Aplica un operador de política sobre un valor resuelto."""
    if operator is PolicyOperator.EXISTS:
        return found

    if operator is PolicyOperator.NOT_EXISTS:
        return not found

    if not found:
        return False

    if operator is PolicyOperator.EQ:
        return _values_equal(actual, expected)

    if operator is PolicyOperator.NE:
        return not _values_equal(actual, expected)

    if operator is PolicyOperator.GT:
        result = actual > expected
    elif operator is PolicyOperator.GTE:
        result = actual >= expected
    elif operator is PolicyOperator.LT:
        result = actual < expected
    elif operator is PolicyOperator.LTE:
        result = actual <= expected
    elif operator is PolicyOperator.IN:
        result = actual in expected
    elif operator is PolicyOperator.NOT_IN:
        result = actual not in expected
    elif operator is PolicyOperator.CONTAINS:
        result = expected in actual
    elif operator is PolicyOperator.NOT_CONTAINS:
        result = expected not in actual
    else:
        raise ValueError(
            f"unsupported operator: {operator.value}"
        )

    if not isinstance(result, bool):
        raise TypeError(
            f"{operator.value} did not produce a boolean"
        )

    return result


def _to_result_value(
    value: Any,
    *,
    path: str = "$",
) -> Any:
    """Convierte un valor evaluado en una estructura JSON compatible."""
    if value is None or isinstance(
        value,
        (str, bool, int),
    ):
        return value

    if isinstance(value, float):
        if not math.isfinite(value):
            raise TypeError(
                f"non-finite float at {path}"
            )

        return value

    if isinstance(value, Enum):
        return _to_result_value(
            value.value,
            path=path,
        )

    if isinstance(value, Mapping):
        normalized: dict[str, Any] = {}

        for key, item in value.items():
            if not isinstance(key, str):
                raise TypeError(
                    f"non-string mapping key at {path}"
                )

            normalized[key] = _to_result_value(
                item,
                path=f"{path}.{key}",
            )

        return {
            key: normalized[key]
            for key in sorted(normalized)
        }

    if isinstance(value, (list, tuple)):
        return [
            _to_result_value(
                item,
                path=f"{path}[{index}]",
            )
            for index, item in enumerate(value)
        ]

    raise TypeError(
        f"non-JSON-compatible value at {path}: "
        f"{type(value).__name__}"
    )


def _result_metadata(
    *,
    rule: PolicyRule,
    field_found: bool,
) -> dict[str, Any]:
    """Construye metadatos mínimos y deterministas."""
    metadata: dict[str, Any] = {
        "field_found": field_found,
    }

    if rule.metadata:
        metadata["rule_metadata"] = _to_result_value(
            rule.metadata,
            path="$.rule_metadata",
        )

    return metadata


def _failure_message(rule: PolicyRule) -> str:
    """Produce un mensaje estable para una regla incumplida."""
    if rule.message is not None:
        return rule.message

    return (
        f"Rule '{rule.rule_id}' failed for field "
        f"'{rule.field}' using operator "
        f"'{rule.operator.value}'"
    )


def _error_result(
    *,
    policy_id: str,
    rule: PolicyRule,
    found: bool,
    error: Exception,
    actual_value: Any = None,
) -> RuleResult:
    """Convierte un error operacional en un resultado de regla."""
    try:
        safe_expected = _to_result_value(
            rule.value,
            path="$.expected_value",
        )
    except (TypeError, ValueError):
        safe_expected = None

    try:
        safe_actual = (
            _to_result_value(
                actual_value,
                path="$.actual_value",
            )
            if found
            else None
        )
    except (TypeError, ValueError):
        safe_actual = None

    try:
        metadata = _result_metadata(
            rule=rule,
            field_found=found,
        )
    except (TypeError, ValueError):
        metadata = {
            "field_found": found,
        }

    metadata["exception_type"] = type(error).__name__

    return RuleResult(
        policy_id=policy_id,
        rule_id=rule.rule_id,
        field=rule.field,
        operator=rule.operator,
        severity=rule.severity,
        status=RuleResultStatus.ERROR,
        expected_value=safe_expected,
        actual_value=safe_actual,
        message=rule.message,
        error=(
            f"{type(error).__name__}: {error}"
        ),
        metadata=metadata,
    )


def evaluate_rule(
    rule: PolicyRule,
    values: Mapping[str, Any],
    *,
    policy_id: str,
) -> RuleResult:
    """Evalúa una regla declarativa contra un contexto de valores.

    Los errores de resolución, comparación o representación se convierten
    en ``RuleResultStatus.ERROR``. Los errores de uso de la API, como recibir
    un objeto que no sea ``PolicyRule`` o un contexto que no sea ``Mapping``,
    se notifican mediante ``PolicyValidationError``.
    """
    normalized_policy_id = _require_policy_id(policy_id)

    if not isinstance(rule, PolicyRule):
        raise PolicyValidationError(
            "rule must be a PolicyRule instance",
            policy_id=normalized_policy_id,
            field="rule",
            context={
                "type": type(rule).__name__,
            },
        )

    if not isinstance(values, Mapping):
        raise PolicyValidationError(
            "values must be a mapping",
            policy_id=normalized_policy_id,
            rule_id=rule.rule_id,
            field="values",
            context={
                "type": type(values).__name__,
            },
        )

    found = False
    actual_value: Any = None

    try:
        found, resolved = _resolve_field(
            values,
            rule.field,
        )

        if found:
            actual_value = resolved

        passed = _evaluate_operator(
            operator=rule.operator,
            found=found,
            actual=resolved if found else _MISSING,
            expected=rule.value,
        )

        safe_expected = _to_result_value(
            rule.value,
            path="$.expected_value",
        )
        safe_actual = (
            _to_result_value(
                actual_value,
                path="$.actual_value",
            )
            if found
            else None
        )
        metadata = _result_metadata(
            rule=rule,
            field_found=found,
        )

        return RuleResult(
            policy_id=normalized_policy_id,
            rule_id=rule.rule_id,
            field=rule.field,
            operator=rule.operator,
            severity=rule.severity,
            status=(
                RuleResultStatus.PASSED
                if passed
                else RuleResultStatus.FAILED
            ),
            expected_value=safe_expected,
            actual_value=safe_actual,
            message=(
                None
                if passed
                else _failure_message(rule)
            ),
            metadata=metadata,
        )

    except (
        ArithmeticError,
        AttributeError,
        IndexError,
        KeyError,
        TypeError,
        ValueError,
    ) as exc:
        return _error_result(
            policy_id=normalized_policy_id,
            rule=rule,
            found=found,
            error=exc,
            actual_value=actual_value,
        )


__all__ = [
    "evaluate_rule",
]

