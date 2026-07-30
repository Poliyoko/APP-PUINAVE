"""Serialización determinista de políticas de gobernanza."""

from __future__ import annotations

import json
from collections.abc import Mapping
from enum import Enum
from typing import Any

from .exceptions import (
    PolicySerializationError,
    PolicyValidationError,
)
from .models import (
    PolicyDefinition,
    PolicyRule,
)


_RULE_REQUIRED_FIELDS = frozenset(
    {
        "rule_id",
        "field",
        "operator",
    }
)

_RULE_OPTIONAL_FIELDS = frozenset(
    {
        "value",
        "severity",
        "message",
        "metadata",
    }
)

_POLICY_REQUIRED_FIELDS = frozenset(
    {
        "policy_id",
        "name",
        "rules",
    }
)

_POLICY_OPTIONAL_FIELDS = frozenset(
    {
        "version",
        "description",
        "enabled",
        "metadata",
    }
)


def _to_plain_value(value: Any) -> Any:
    """Convierte valores de dominio en estructuras JSON compatibles."""
    if value is None or isinstance(value, (str, int, float, bool)):
        return value

    if isinstance(value, Enum):
        return value.value

    if isinstance(value, Mapping):
        plain_mapping: dict[str, Any] = {}

        for key in sorted(value):
            if not isinstance(key, str):
                raise PolicySerializationError(
                    "mapping keys must be strings",
                    context={
                        "key_type": type(key).__name__,
                    },
                )

            plain_mapping[key] = _to_plain_value(value[key])

        return plain_mapping

    if isinstance(value, (tuple, list)):
        return [_to_plain_value(item) for item in value]

    raise PolicySerializationError(
        "value is not JSON serializable",
        context={
            "type": type(value).__name__,
        },
    )


def _require_mapping(
    value: Any,
    *,
    object_name: str,
) -> Mapping[str, Any]:
    """Valida que una entrada deserializada sea un objeto."""
    if not isinstance(value, Mapping):
        raise PolicySerializationError(
            f"{object_name} must be a mapping",
            context={
                "type": type(value).__name__,
            },
        )

    non_string_keys = tuple(
        sorted(
            repr(key)
            for key in value
            if not isinstance(key, str)
        )
    )

    if non_string_keys:
        raise PolicySerializationError(
            f"{object_name} keys must be strings",
            context={
                "keys": non_string_keys,
            },
        )

    return value


def _validate_fields(
    data: Mapping[str, Any],
    *,
    required: frozenset[str],
    optional: frozenset[str],
    object_name: str,
) -> None:
    """Valida campos requeridos y campos desconocidos."""
    keys = frozenset(data)

    missing = tuple(sorted(required - keys))
    unknown = tuple(sorted(keys - required - optional))

    if missing:
        raise PolicySerializationError(
            f"{object_name} is missing required fields",
            context={
                "missing": missing,
            },
        )

    if unknown:
        raise PolicySerializationError(
            f"{object_name} contains unknown fields",
            context={
                "unknown": unknown,
            },
        )


def policy_rule_to_dict(rule: PolicyRule) -> dict[str, Any]:
    """Convierte una regla en un diccionario JSON compatible."""
    if not isinstance(rule, PolicyRule):
        raise PolicySerializationError(
            "rule must be a PolicyRule instance",
            context={
                "type": type(rule).__name__,
            },
        )

    return {
        "rule_id": rule.rule_id,
        "field": rule.field,
        "operator": rule.operator.value,
        "value": _to_plain_value(rule.value),
        "severity": rule.severity.value,
        "message": rule.message,
        "metadata": _to_plain_value(rule.metadata),
    }


def policy_rule_from_dict(data: Mapping[str, Any]) -> PolicyRule:
    """Construye una regla a partir de un diccionario."""
    normalized = _require_mapping(
        data,
        object_name="policy rule",
    )

    _validate_fields(
        normalized,
        required=_RULE_REQUIRED_FIELDS,
        optional=_RULE_OPTIONAL_FIELDS,
        object_name="policy rule",
    )

    try:
        return PolicyRule(
            rule_id=normalized["rule_id"],
            field=normalized["field"],
            operator=normalized["operator"],
            value=normalized.get("value"),
            severity=normalized.get("severity", "error"),
            message=normalized.get("message"),
            metadata=normalized.get("metadata", {}),
        )
    except PolicyValidationError as exc:
        raise PolicySerializationError(
            "policy rule data is invalid",
            context={
                "cause": str(exc),
            },
        ) from exc


def policy_to_dict(policy: PolicyDefinition) -> dict[str, Any]:
    """Convierte una política en un diccionario JSON compatible."""
    if not isinstance(policy, PolicyDefinition):
        raise PolicySerializationError(
            "policy must be a PolicyDefinition instance",
            context={
                "type": type(policy).__name__,
            },
        )

    return {
        "policy_id": policy.policy_id,
        "name": policy.name,
        "version": policy.version,
        "description": policy.description,
        "enabled": policy.enabled,
        "rules": [
            policy_rule_to_dict(rule)
            for rule in policy.rules
        ],
        "metadata": _to_plain_value(policy.metadata),
    }


def policy_from_dict(data: Mapping[str, Any]) -> PolicyDefinition:
    """Construye una política a partir de un diccionario."""
    normalized = _require_mapping(
        data,
        object_name="policy",
    )

    _validate_fields(
        normalized,
        required=_POLICY_REQUIRED_FIELDS,
        optional=_POLICY_OPTIONAL_FIELDS,
        object_name="policy",
    )

    raw_rules = normalized["rules"]

    if not isinstance(raw_rules, (list, tuple)):
        raise PolicySerializationError(
            "policy rules must be a list",
            context={
                "type": type(raw_rules).__name__,
            },
        )

    try:
        rules = tuple(
            policy_rule_from_dict(rule_data)
            for rule_data in raw_rules
        )

        return PolicyDefinition(
            policy_id=normalized["policy_id"],
            name=normalized["name"],
            rules=rules,
            version=normalized.get("version", "1.0"),
            description=normalized.get("description"),
            enabled=normalized.get("enabled", True),
            metadata=normalized.get("metadata", {}),
        )
    except PolicySerializationError:
        raise
    except PolicyValidationError as exc:
        raise PolicySerializationError(
            "policy data is invalid",
            context={
                "cause": str(exc),
            },
        ) from exc


def serialize_policy(
    policy: PolicyDefinition,
    *,
    indent: int | None = None,
) -> str:
    """Serializa una política como JSON determinista."""
    if indent is not None:
        if isinstance(indent, bool) or not isinstance(indent, int):
            raise PolicySerializationError(
                "indent must be an integer or None",
                context={
                    "type": type(indent).__name__,
                },
            )

        if indent < 0:
            raise PolicySerializationError(
                "indent must not be negative",
                context={
                    "value": indent,
                },
            )

    try:
        return json.dumps(
            policy_to_dict(policy),
            ensure_ascii=False,
            allow_nan=False,
            sort_keys=True,
            indent=indent,
            separators=None if indent is not None else (",", ":"),
        )
    except PolicySerializationError:
        raise
    except (TypeError, ValueError) as exc:
        raise PolicySerializationError(
            "policy could not be serialized",
            context={
                "cause": str(exc),
            },
        ) from exc


def _reject_json_constant(value: str) -> None:
    """Rechaza NaN e infinitos, que no pertenecen al JSON estándar."""
    raise ValueError(f"invalid JSON constant: {value}")


def deserialize_policy(
    payload: str | bytes | bytearray,
) -> PolicyDefinition:
    """Deserializa una política desde JSON."""
    if isinstance(payload, (bytes, bytearray)):
        try:
            normalized_payload = bytes(payload).decode("utf-8")
        except UnicodeDecodeError as exc:
            raise PolicySerializationError(
                "policy payload must contain valid UTF-8",
                context={
                    "cause": str(exc),
                },
            ) from exc
    elif isinstance(payload, str):
        normalized_payload = payload
    else:
        raise PolicySerializationError(
            "policy payload must be text or UTF-8 bytes",
            context={
                "type": type(payload).__name__,
            },
        )

    if not normalized_payload.strip():
        raise PolicySerializationError(
            "policy payload must not be empty",
        )

    try:
        decoded = json.loads(
            normalized_payload,
            parse_constant=_reject_json_constant,
        )
    except (json.JSONDecodeError, ValueError) as exc:
        raise PolicySerializationError(
            "policy payload is not valid JSON",
            context={
                "cause": str(exc),
            },
        ) from exc

    return policy_from_dict(decoded)


__all__ = [
    "deserialize_policy",
    "policy_from_dict",
    "policy_rule_from_dict",
    "policy_rule_to_dict",
    "policy_to_dict",
    "serialize_policy",
]
