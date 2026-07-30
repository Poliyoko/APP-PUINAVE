"""Excepciones públicas del subsistema de gobernanza."""

from __future__ import annotations

from collections.abc import Mapping
from types import MappingProxyType
from typing import Any


def _freeze_value(value: Any) -> Any:
    """Convierte estructuras mutables de contexto en valores inmutables."""
    if isinstance(value, Mapping):
        return MappingProxyType(
            {
                str(key): _freeze_value(item)
                for key, item in sorted(
                    value.items(),
                    key=lambda pair: str(pair[0]),
                )
            }
        )

    if isinstance(value, (list, tuple)):
        return tuple(_freeze_value(item) for item in value)

    if isinstance(value, (set, frozenset)):
        return frozenset(_freeze_value(item) for item in value)

    return value


def _stable_repr(value: Any) -> str:
    """Genera una representación estable del contexto."""
    if isinstance(value, Mapping):
        items = ", ".join(
            f"{key!r}: {_stable_repr(item)}"
            for key, item in sorted(
                value.items(),
                key=lambda pair: str(pair[0]),
            )
        )
        return "{" + items + "}"

    if isinstance(value, tuple):
        items = ", ".join(_stable_repr(item) for item in value)
        if len(value) == 1:
            items += ","
        return "(" + items + ")"

    if isinstance(value, frozenset):
        items = ", ".join(sorted(_stable_repr(item) for item in value))
        return f"frozenset({{{items}}})"

    return repr(value)


class GovernanceError(Exception):
    """Excepción base para errores verificables de gobernanza."""

    def __init__(
        self,
        message: str,
        *,
        policy_id: str | None = None,
        rule_id: str | None = None,
        field: str | None = None,
        source: str | None = None,
        context: Mapping[str, Any] | None = None,
    ) -> None:
        if not isinstance(message, str) or not message.strip():
            raise ValueError("message must be a non-empty string")

        values: dict[str, Any] = {}

        for key, value in (
            ("policy_id", policy_id),
            ("rule_id", rule_id),
            ("field", field),
            ("source", source),
        ):
            if value is not None:
                if not isinstance(value, str) or not value.strip():
                    raise ValueError(
                        f"{key} must be a non-empty string or None"
                    )

                values[key] = value.strip()

        if context is not None:
            if not isinstance(context, Mapping):
                raise TypeError("context must be a mapping or None")

            for key, value in context.items():
                normalized_key = str(key)

                if normalized_key in values:
                    raise ValueError(
                        "context key conflicts with structured field: "
                        f"{normalized_key}"
                    )

                values[normalized_key] = value

        self.message = message.strip()
        self._context = MappingProxyType(
            {
                key: _freeze_value(value)
                for key, value in sorted(values.items())
            }
        )

        super().__init__(self.message)

    @property
    def context(self) -> Mapping[str, Any]:
        """Contexto estructurado e inmutable del error."""
        return self._context

    def __str__(self) -> str:
        return self.message

    def __repr__(self) -> str:
        return (
            f"{type(self).__name__}("
            f"{self.message!r}, "
            f"context={_stable_repr(self._context)})"
        )


class PolicyValidationError(GovernanceError):
    """Una política o regla incumple su contrato de dominio."""


class PolicyLoadError(GovernanceError):
    """No fue posible cargar una política desde una fuente externa."""


class PolicySerializationError(GovernanceError):
    """No fue posible serializar o deserializar una política."""


class PolicyEvaluationError(GovernanceError):
    """No fue posible evaluar una política o una de sus reglas."""


__all__ = [
    "GovernanceError",
    "PolicyEvaluationError",
    "PolicyLoadError",
    "PolicySerializationError",
    "PolicyValidationError",
]
