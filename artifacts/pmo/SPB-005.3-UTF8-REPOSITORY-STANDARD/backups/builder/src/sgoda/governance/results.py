"""Resultados inmutables de evaluación de políticas de gobernanza."""

from __future__ import annotations

import math
from collections.abc import Mapping
from dataclasses import dataclass, field
from enum import Enum
from types import MappingProxyType
from typing import Any

from .exceptions import PolicyValidationError
from .models import (
    PolicyOperator,
    PolicySeverity,
)


class RuleResultStatus(str, Enum):
    """Estado producido por la evaluación de una regla."""

    PASSED = "passed"
    FAILED = "failed"
    SKIPPED = "skipped"
    ERROR = "error"


class PolicyResultStatus(str, Enum):
    """Estado agregado producido por la evaluación de una política."""

    PASSED = "passed"
    FAILED = "failed"
    SKIPPED = "skipped"
    ERROR = "error"


def _require_non_empty_string(
    value: Any,
    *,
    field_name: str,
    policy_id: str | None = None,
    rule_id: str | None = None,
) -> str:
    """Valida y normaliza un texto obligatorio."""
    if not isinstance(value, str) or not value.strip():
        raise PolicyValidationError(
            f"{field_name} must be a non-empty string",
            policy_id=policy_id,
            rule_id=rule_id,
            field=field_name,
        )

    return value.strip()


def _normalize_optional_string(
    value: Any,
    *,
    field_name: str,
    policy_id: str | None = None,
    rule_id: str | None = None,
) -> str | None:
    """Valida y normaliza un texto opcional."""
    if value is None:
        return None

    return _require_non_empty_string(
        value,
        field_name=field_name,
        policy_id=policy_id,
        rule_id=rule_id,
    )


def _normalize_enum(
    value: Any,
    *,
    enum_type: type[Enum],
    field_name: str,
    policy_id: str | None = None,
    rule_id: str | None = None,
) -> Enum:
    """Normaliza un valor perteneciente a una enumeración."""
    if isinstance(value, enum_type):
        return value

    try:
        return enum_type(value)
    except (TypeError, ValueError) as exc:
        raise PolicyValidationError(
            f"{field_name} is not supported",
            policy_id=policy_id,
            rule_id=rule_id,
            field=field_name,
            context={
                "value": value,
                "enum": enum_type.__name__,
            },
        ) from exc


def _freeze_json_value(
    value: Any,
    *,
    policy_id: str,
    field_name: str,
    rule_id: str | None = None,
    path: str = "$",
) -> Any:
    """Valida y convierte un valor JSON en una estructura inmutable."""
    if value is None or isinstance(value, (str, bool, int)):
        return value

    if isinstance(value, float):
        if not math.isfinite(value):
            raise PolicyValidationError(
                "result values must not contain NaN or infinity",
                policy_id=policy_id,
                rule_id=rule_id,
                field=field_name,
                context={
                    "path": path,
                    "value": repr(value),
                },
            )

        return value

    if isinstance(value, Enum):
        return _freeze_json_value(
            value.value,
            policy_id=policy_id,
            rule_id=rule_id,
            field_name=field_name,
            path=path,
        )

    if isinstance(value, Mapping):
        normalized: dict[str, Any] = {}

        for key, item in value.items():
            if not isinstance(key, str):
                raise PolicyValidationError(
                    "result mapping keys must be strings",
                    policy_id=policy_id,
                    rule_id=rule_id,
                    field=field_name,
                    context={
                        "path": path,
                        "key_type": type(key).__name__,
                    },
                )

            if key in normalized:
                raise PolicyValidationError(
                    "result mapping contains duplicate keys",
                    policy_id=policy_id,
                    rule_id=rule_id,
                    field=field_name,
                    context={
                        "path": path,
                        "key": key,
                    },
                )

            normalized[key] = _freeze_json_value(
                item,
                policy_id=policy_id,
                rule_id=rule_id,
                field_name=field_name,
                path=f"{path}.{key}",
            )

        return MappingProxyType(
            {
                key: normalized[key]
                for key in sorted(normalized)
            }
        )

    if isinstance(value, (tuple, list)):
        return tuple(
            _freeze_json_value(
                item,
                policy_id=policy_id,
                rule_id=rule_id,
                field_name=field_name,
                path=f"{path}[{index}]",
            )
            for index, item in enumerate(value)
        )

    raise PolicyValidationError(
        "result value is not JSON compatible",
        policy_id=policy_id,
        rule_id=rule_id,
        field=field_name,
        context={
            "path": path,
            "type": type(value).__name__,
        },
    )


def _aggregate_policy_status(
    rule_results: tuple[RuleResult, ...],
) -> PolicyResultStatus:
    """Calcula el estado agregado de una política."""
    statuses = {
        result.status
        for result in rule_results
    }

    if RuleResultStatus.ERROR in statuses:
        return PolicyResultStatus.ERROR

    if RuleResultStatus.FAILED in statuses:
        return PolicyResultStatus.FAILED

    if RuleResultStatus.PASSED in statuses:
        return PolicyResultStatus.PASSED

    return PolicyResultStatus.SKIPPED


@dataclass(frozen=True, slots=True)
class RuleResult:
    """Resultado inmutable de la evaluación de una regla."""

    policy_id: str
    rule_id: str
    field: str
    operator: PolicyOperator
    severity: PolicySeverity
    status: RuleResultStatus
    expected_value: Any = None
    actual_value: Any = None
    message: str | None = None
    error: str | None = None
    metadata: Mapping[str, Any] = field(default_factory=dict)

    def __post_init__(self) -> None:
        normalized_policy_id = _require_non_empty_string(
            self.policy_id,
            field_name="policy_id",
        )
        normalized_rule_id = _require_non_empty_string(
            self.rule_id,
            field_name="rule_id",
            policy_id=normalized_policy_id,
        )
        normalized_field = _require_non_empty_string(
            self.field,
            field_name="field",
            policy_id=normalized_policy_id,
            rule_id=normalized_rule_id,
        )

        normalized_operator = _normalize_enum(
            self.operator,
            enum_type=PolicyOperator,
            field_name="operator",
            policy_id=normalized_policy_id,
            rule_id=normalized_rule_id,
        )
        normalized_severity = _normalize_enum(
            self.severity,
            enum_type=PolicySeverity,
            field_name="severity",
            policy_id=normalized_policy_id,
            rule_id=normalized_rule_id,
        )
        normalized_status = _normalize_enum(
            self.status,
            enum_type=RuleResultStatus,
            field_name="status",
            policy_id=normalized_policy_id,
            rule_id=normalized_rule_id,
        )

        normalized_message = _normalize_optional_string(
            self.message,
            field_name="message",
            policy_id=normalized_policy_id,
            rule_id=normalized_rule_id,
        )
        normalized_error = _normalize_optional_string(
            self.error,
            field_name="error",
            policy_id=normalized_policy_id,
            rule_id=normalized_rule_id,
        )

        if normalized_status is RuleResultStatus.ERROR:
            if normalized_error is None:
                raise PolicyValidationError(
                    "error status requires an error description",
                    policy_id=normalized_policy_id,
                    rule_id=normalized_rule_id,
                    field="error",
                )
        elif normalized_error is not None:
            raise PolicyValidationError(
                "error description is only valid for error status",
                policy_id=normalized_policy_id,
                rule_id=normalized_rule_id,
                field="error",
                context={
                    "status": normalized_status.value,
                },
            )

        if not isinstance(self.metadata, Mapping):
            raise PolicyValidationError(
                "metadata must be a mapping",
                policy_id=normalized_policy_id,
                rule_id=normalized_rule_id,
                field="metadata",
            )

        normalized_expected = _freeze_json_value(
            self.expected_value,
            policy_id=normalized_policy_id,
            rule_id=normalized_rule_id,
            field_name="expected_value",
        )
        normalized_actual = _freeze_json_value(
            self.actual_value,
            policy_id=normalized_policy_id,
            rule_id=normalized_rule_id,
            field_name="actual_value",
        )
        normalized_metadata = _freeze_json_value(
            self.metadata,
            policy_id=normalized_policy_id,
            rule_id=normalized_rule_id,
            field_name="metadata",
        )

        object.__setattr__(
            self,
            "policy_id",
            normalized_policy_id,
        )
        object.__setattr__(
            self,
            "rule_id",
            normalized_rule_id,
        )
        object.__setattr__(
            self,
            "field",
            normalized_field,
        )
        object.__setattr__(
            self,
            "operator",
            normalized_operator,
        )
        object.__setattr__(
            self,
            "severity",
            normalized_severity,
        )
        object.__setattr__(
            self,
            "status",
            normalized_status,
        )
        object.__setattr__(
            self,
            "expected_value",
            normalized_expected,
        )
        object.__setattr__(
            self,
            "actual_value",
            normalized_actual,
        )
        object.__setattr__(
            self,
            "message",
            normalized_message,
        )
        object.__setattr__(
            self,
            "error",
            normalized_error,
        )
        object.__setattr__(
            self,
            "metadata",
            normalized_metadata,
        )

    @property
    def passed(self) -> bool:
        """Indica si la regla fue satisfecha."""
        return self.status is RuleResultStatus.PASSED

    @property
    def failed(self) -> bool:
        """Indica si la regla incumplió la política."""
        return self.status is RuleResultStatus.FAILED

    @property
    def skipped(self) -> bool:
        """Indica si la regla no fue evaluada."""
        return self.status is RuleResultStatus.SKIPPED

    @property
    def has_error(self) -> bool:
        """Indica si ocurrió un error durante la evaluación."""
        return self.status is RuleResultStatus.ERROR


@dataclass(frozen=True, slots=True)
class PolicyResult:
    """Resultado agregado e inmutable de una política."""

    policy_id: str
    name: str
    version: str
    rule_results: tuple[RuleResult, ...]
    enabled: bool = True
    message: str | None = None
    metadata: Mapping[str, Any] = field(default_factory=dict)
    status: PolicyResultStatus = field(init=False)

    def __post_init__(self) -> None:
        normalized_policy_id = _require_non_empty_string(
            self.policy_id,
            field_name="policy_id",
        )
        normalized_name = _require_non_empty_string(
            self.name,
            field_name="name",
            policy_id=normalized_policy_id,
        )
        normalized_version = _require_non_empty_string(
            self.version,
            field_name="version",
            policy_id=normalized_policy_id,
        )
        normalized_message = _normalize_optional_string(
            self.message,
            field_name="message",
            policy_id=normalized_policy_id,
        )

        if not isinstance(self.enabled, bool):
            raise PolicyValidationError(
                "enabled must be a boolean",
                policy_id=normalized_policy_id,
                field="enabled",
            )

        if isinstance(
            self.rule_results,
            (str, bytes, bytearray, Mapping),
        ):
            raise PolicyValidationError(
                "rule_results must be an iterable of RuleResult instances",
                policy_id=normalized_policy_id,
                field="rule_results",
            )

        try:
            normalized_results = tuple(self.rule_results)
        except TypeError as exc:
            raise PolicyValidationError(
                "rule_results must be iterable",
                policy_id=normalized_policy_id,
                field="rule_results",
            ) from exc

        seen_rule_ids: dict[str, int] = {}

        for index, result in enumerate(normalized_results):
            if not isinstance(result, RuleResult):
                raise PolicyValidationError(
                    "rule_results must contain only RuleResult instances",
                    policy_id=normalized_policy_id,
                    field="rule_results",
                    context={
                        "index": index,
                        "type": type(result).__name__,
                    },
                )

            if result.policy_id != normalized_policy_id:
                raise PolicyValidationError(
                    "rule result belongs to a different policy",
                    policy_id=normalized_policy_id,
                    rule_id=result.rule_id,
                    field="rule_results",
                    context={
                        "index": index,
                        "result_policy_id": result.policy_id,
                    },
                )

            previous_index = seen_rule_ids.get(result.rule_id)

            if previous_index is not None:
                raise PolicyValidationError(
                    "rule result identifiers must be unique",
                    policy_id=normalized_policy_id,
                    rule_id=result.rule_id,
                    field="rule_results",
                    context={
                        "index": index,
                        "duplicate_of_index": previous_index,
                    },
                )

            seen_rule_ids[result.rule_id] = index

        if not isinstance(self.metadata, Mapping):
            raise PolicyValidationError(
                "metadata must be a mapping",
                policy_id=normalized_policy_id,
                field="metadata",
            )

        normalized_metadata = _freeze_json_value(
            self.metadata,
            policy_id=normalized_policy_id,
            field_name="metadata",
        )
        aggregated_status = _aggregate_policy_status(
            normalized_results
        )

        object.__setattr__(
            self,
            "policy_id",
            normalized_policy_id,
        )
        object.__setattr__(
            self,
            "name",
            normalized_name,
        )
        object.__setattr__(
            self,
            "version",
            normalized_version,
        )
        object.__setattr__(
            self,
            "rule_results",
            normalized_results,
        )
        object.__setattr__(
            self,
            "message",
            normalized_message,
        )
        object.__setattr__(
            self,
            "metadata",
            normalized_metadata,
        )
        object.__setattr__(
            self,
            "status",
            aggregated_status,
        )

    @property
    def passed(self) -> bool:
        """Indica si la política fue satisfecha."""
        return self.status is PolicyResultStatus.PASSED

    @property
    def failed(self) -> bool:
        """Indica si la política tuvo incumplimientos."""
        return self.status is PolicyResultStatus.FAILED

    @property
    def skipped(self) -> bool:
        """Indica si ninguna regla fue evaluada."""
        return self.status is PolicyResultStatus.SKIPPED

    @property
    def has_error(self) -> bool:
        """Indica si alguna regla produjo un error."""
        return self.status is PolicyResultStatus.ERROR

    @property
    def passed_count(self) -> int:
        """Número de reglas satisfechas."""
        return sum(
            result.status is RuleResultStatus.PASSED
            for result in self.rule_results
        )

    @property
    def failed_count(self) -> int:
        """Número de reglas incumplidas."""
        return sum(
            result.status is RuleResultStatus.FAILED
            for result in self.rule_results
        )

    @property
    def skipped_count(self) -> int:
        """Número de reglas omitidas."""
        return sum(
            result.status is RuleResultStatus.SKIPPED
            for result in self.rule_results
        )

    @property
    def error_count(self) -> int:
        """Número de reglas que produjeron error."""
        return sum(
            result.status is RuleResultStatus.ERROR
            for result in self.rule_results
        )

    @property
    def total_count(self) -> int:
        """Número total de resultados de reglas."""
        return len(self.rule_results)


__all__ = [
    "PolicyResult",
    "PolicyResultStatus",
    "RuleResult",
    "RuleResultStatus",
]
