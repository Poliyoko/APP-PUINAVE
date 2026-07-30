"""Modelos de dominio inmutables para políticas de gobernanza."""

from __future__ import annotations

from collections.abc import Iterable, Mapping
from dataclasses import dataclass, field
from enum import Enum
from types import MappingProxyType
from typing import Any

from .exceptions import PolicyValidationError


class PolicyOperator(str, Enum):
    """Operadores soportados por una regla de política."""

    EQ = "eq"
    NE = "ne"
    GT = "gt"
    GTE = "gte"
    LT = "lt"
    LTE = "lte"
    IN = "in"
    NOT_IN = "not_in"
    CONTAINS = "contains"
    NOT_CONTAINS = "not_contains"
    EXISTS = "exists"
    NOT_EXISTS = "not_exists"


class PolicySeverity(str, Enum):
    """Severidad declarada por una regla de política."""

    INFO = "info"
    WARNING = "warning"
    ERROR = "error"
    CRITICAL = "critical"


def _require_non_empty_string(value: Any, field_name: str) -> str:
    """Valida y normaliza un texto obligatorio."""
    if not isinstance(value, str) or not value.strip():
        raise PolicyValidationError(
            f"{field_name} must be a non-empty string",
            field=field_name,
        )

    return value.strip()


def _normalize_optional_string(
    value: Any,
    field_name: str,
) -> str | None:
    """Valida y normaliza un texto opcional."""
    if value is None:
        return None

    return _require_non_empty_string(value, field_name)


def _freeze_value(value: Any) -> Any:
    """Convierte estructuras contenedoras en valores inmutables."""
    if isinstance(value, Mapping):
        normalized: dict[str, Any] = {}

        for key, item in value.items():
            normalized_key = str(key)

            if normalized_key in normalized:
                raise PolicyValidationError(
                    "mapping contains duplicate keys after normalization",
                    context={"key": normalized_key},
                )

            normalized[normalized_key] = _freeze_value(item)

        return MappingProxyType(
            {
                key: normalized[key]
                for key in sorted(normalized)
            }
        )

    if isinstance(value, (list, tuple)):
        return tuple(_freeze_value(item) for item in value)

    if isinstance(value, (set, frozenset)):
        frozen_items = tuple(_freeze_value(item) for item in value)

        try:
            return tuple(sorted(frozen_items))
        except TypeError:
            return tuple(sorted(frozen_items, key=repr))

    return value


def _normalize_operator(value: Any) -> PolicyOperator:
    """Convierte una entrada válida en PolicyOperator."""
    if isinstance(value, PolicyOperator):
        return value

    try:
        return PolicyOperator(value)
    except (TypeError, ValueError) as exc:
        raise PolicyValidationError(
            "operator is not supported",
            field="operator",
            context={"value": value},
        ) from exc


def _normalize_severity(value: Any) -> PolicySeverity:
    """Convierte una entrada válida en PolicySeverity."""
    if isinstance(value, PolicySeverity):
        return value

    try:
        return PolicySeverity(value)
    except (TypeError, ValueError) as exc:
        raise PolicyValidationError(
            "severity is not supported",
            field="severity",
            context={"value": value},
        ) from exc


def _normalize_collection_operand(
    value: Any,
    *,
    operator: PolicyOperator,
) -> tuple[Any, ...]:
    """Valida operandos de los operadores IN y NOT_IN."""
    if isinstance(value, (str, bytes, bytearray, Mapping)):
        raise PolicyValidationError(
            f"{operator.value} requires a non-string iterable value",
            field="value",
            context={"operator": operator.value},
        )

    if not isinstance(value, Iterable):
        raise PolicyValidationError(
            f"{operator.value} requires an iterable value",
            field="value",
            context={"operator": operator.value},
        )

    normalized = tuple(_freeze_value(item) for item in value)

    if not normalized:
        raise PolicyValidationError(
            f"{operator.value} requires at least one value",
            field="value",
            context={"operator": operator.value},
        )

    return normalized


@dataclass(frozen=True, slots=True)
class PolicyRule:
    """Regla declarativa perteneciente a una política."""

    rule_id: str
    field: str
    operator: PolicyOperator
    value: Any = None
    severity: PolicySeverity = PolicySeverity.ERROR
    message: str | None = None
    metadata: Mapping[str, Any] = field(default_factory=dict)

    def __post_init__(self) -> None:
        normalized_rule_id = _require_non_empty_string(
            self.rule_id,
            "rule_id",
        )
        normalized_field = _require_non_empty_string(
            self.field,
            "field",
        )
        normalized_operator = _normalize_operator(self.operator)
        normalized_severity = _normalize_severity(self.severity)
        normalized_message = _normalize_optional_string(
            self.message,
            "message",
        )

        if not isinstance(self.metadata, Mapping):
            raise PolicyValidationError(
                "metadata must be a mapping",
                rule_id=normalized_rule_id,
                field="metadata",
            )

        if normalized_operator in {
            PolicyOperator.EXISTS,
            PolicyOperator.NOT_EXISTS,
        }:
            if self.value is not None:
                raise PolicyValidationError(
                    f"{normalized_operator.value} requires value=None",
                    rule_id=normalized_rule_id,
                    field="value",
                    context={"operator": normalized_operator.value},
                )

            normalized_value = None

        elif normalized_operator in {
            PolicyOperator.IN,
            PolicyOperator.NOT_IN,
        }:
            normalized_value = _normalize_collection_operand(
                self.value,
                operator=normalized_operator,
            )

        else:
            normalized_value = _freeze_value(self.value)

        object.__setattr__(self, "rule_id", normalized_rule_id)
        object.__setattr__(self, "field", normalized_field)
        object.__setattr__(self, "operator", normalized_operator)
        object.__setattr__(self, "value", normalized_value)
        object.__setattr__(self, "severity", normalized_severity)
        object.__setattr__(self, "message", normalized_message)
        object.__setattr__(
            self,
            "metadata",
            _freeze_value(self.metadata),
        )


@dataclass(frozen=True, slots=True)
class PolicyDefinition:
    """Definición completa de una política de gobernanza."""

    policy_id: str
    name: str
    rules: tuple[PolicyRule, ...]
    version: str = "1.0"
    description: str | None = None
    enabled: bool = True
    metadata: Mapping[str, Any] = field(default_factory=dict)

    def __post_init__(self) -> None:
        normalized_policy_id = _require_non_empty_string(
            self.policy_id,
            "policy_id",
        )
        normalized_name = _require_non_empty_string(
            self.name,
            "name",
        )
        normalized_version = _require_non_empty_string(
            self.version,
            "version",
        )
        normalized_description = _normalize_optional_string(
            self.description,
            "description",
        )

        if not isinstance(self.enabled, bool):
            raise PolicyValidationError(
                "enabled must be a boolean",
                policy_id=normalized_policy_id,
                field="enabled",
            )

        if isinstance(self.rules, (str, bytes, bytearray)):
            raise PolicyValidationError(
                "rules must be an iterable of PolicyRule instances",
                policy_id=normalized_policy_id,
                field="rules",
            )

        try:
            normalized_rules = tuple(self.rules)
        except TypeError as exc:
            raise PolicyValidationError(
                "rules must be an iterable of PolicyRule instances",
                policy_id=normalized_policy_id,
                field="rules",
            ) from exc

        if not normalized_rules:
            raise PolicyValidationError(
                "rules must contain at least one rule",
                policy_id=normalized_policy_id,
                field="rules",
            )

        for index, rule in enumerate(normalized_rules):
            if not isinstance(rule, PolicyRule):
                raise PolicyValidationError(
                    "rules must contain only PolicyRule instances",
                    policy_id=normalized_policy_id,
                    field="rules",
                    context={
                        "index": index,
                        "type": type(rule).__name__,
                    },
                )

        rule_ids = [rule.rule_id for rule in normalized_rules]

        if len(rule_ids) != len(set(rule_ids)):
            duplicates = tuple(
                sorted(
                    rule_id
                    for rule_id in set(rule_ids)
                    if rule_ids.count(rule_id) > 1
                )
            )

            raise PolicyValidationError(
                "rule identifiers must be unique within a policy",
                policy_id=normalized_policy_id,
                field="rules",
                context={"duplicates": duplicates},
            )

        if not isinstance(self.metadata, Mapping):
            raise PolicyValidationError(
                "metadata must be a mapping",
                policy_id=normalized_policy_id,
                field="metadata",
            )

        object.__setattr__(self, "policy_id", normalized_policy_id)
        object.__setattr__(self, "name", normalized_name)
        object.__setattr__(self, "rules", normalized_rules)
        object.__setattr__(self, "version", normalized_version)
        object.__setattr__(
            self,
            "description",
            normalized_description,
        )
        object.__setattr__(
            self,
            "metadata",
            _freeze_value(self.metadata),
        )


__all__ = [
    "PolicyDefinition",
    "PolicyOperator",
    "PolicyRule",
    "PolicySeverity",
]
