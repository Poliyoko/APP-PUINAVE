"""Repositorio determinista en memoria para políticas de gobernanza."""

from __future__ import annotations

from collections.abc import Iterable, Iterator
from typing import Final

from .exceptions import PolicyValidationError
from .models import PolicyDefinition
from .policy_validator import (
    validate_policies,
    validate_policy,
)


class PolicyRepositoryError(Exception):
    """Error base de operaciones del repositorio de políticas."""


class PolicyAlreadyExistsError(PolicyRepositoryError):
    """Indica que una política ya existe en el repositorio."""

    def __init__(self, policy_id: str) -> None:
        self.policy_id = policy_id

        super().__init__(
            f"policy already exists: {policy_id}"
        )


class PolicyNotFoundError(PolicyRepositoryError):
    """Indica que una política no existe en el repositorio."""

    def __init__(self, policy_id: str) -> None:
        self.policy_id = policy_id

        super().__init__(
            f"policy not found: {policy_id}"
        )


_MISSING: Final = object()


def _require_policy_id(policy_id: object) -> str:
    """Valida y normaliza un identificador recibido por la API."""
    if not isinstance(policy_id, str):
        raise PolicyValidationError(
            "policy_id must be a string",
            field="policy_id",
            context={
                "type": type(policy_id).__name__,
            },
        )

    normalized = policy_id.strip()

    if not normalized:
        raise PolicyValidationError(
            "policy_id must be a non-empty string",
            field="policy_id",
        )

    if normalized != policy_id:
        raise PolicyValidationError(
            "policy_id must not contain surrounding whitespace",
            policy_id=normalized,
            field="policy_id",
        )

    return normalized


class PolicyRepository:
    """Repositorio mutable en memoria de políticas inmutables.

    El repositorio conserva las mismas instancias de ``PolicyDefinition``
    que recibe. La iteración, ``list`` e ``ids`` siguen siempre el orden
    lexicográfico de ``policy_id``, independientemente del orden de inserción.
    """

    __slots__ = ("_policies",)

    def __init__(
        self,
        policies: Iterable[PolicyDefinition] = (),
    ) -> None:
        validated = validate_policies(
            policies,
            allow_disabled=True,
        )

        self._policies: dict[str, PolicyDefinition] = {
            policy.policy_id: policy
            for policy in validated
        }

    def __len__(self) -> int:
        """Devuelve la cantidad de políticas registradas."""
        return len(self._policies)

    def __bool__(self) -> bool:
        """Indica si el repositorio contiene al menos una política."""
        return bool(self._policies)

    def __contains__(self, policy_id: object) -> bool:
        """Comprueba pertenencia sin lanzar errores por tipos inválidos."""
        if not isinstance(policy_id, str):
            return False

        return policy_id in self._policies

    def __iter__(self) -> Iterator[PolicyDefinition]:
        """Itera sobre las políticas en orden determinista."""
        return iter(self.list())

    def add(
        self,
        policy: PolicyDefinition,
    ) -> PolicyDefinition:
        """Registra una política nueva.

        Raises:
            PolicyValidationError:
                Cuando la política es inválida.
            PolicyAlreadyExistsError:
                Cuando el identificador ya está registrado.
        """
        validated = validate_policy(
            policy,
            allow_disabled=True,
        )

        if validated.policy_id in self._policies:
            raise PolicyAlreadyExistsError(
                validated.policy_id
            )

        self._policies[validated.policy_id] = validated

        return validated

    def upsert(
        self,
        policy: PolicyDefinition,
    ) -> PolicyDefinition:
        """Registra o reemplaza una política por identificador."""
        validated = validate_policy(
            policy,
            allow_disabled=True,
        )

        self._policies[validated.policy_id] = validated

        return validated

    def get(
        self,
        policy_id: str,
        default=None,
    ):
        """Obtiene una política o devuelve el valor predeterminado."""
        normalized = _require_policy_id(policy_id)

        return self._policies.get(
            normalized,
            default,
        )

    def require(
        self,
        policy_id: str,
    ) -> PolicyDefinition:
        """Obtiene una política y falla si no está registrada."""
        normalized = _require_policy_id(policy_id)

        policy = self._policies.get(
            normalized,
            _MISSING,
        )

        if policy is _MISSING:
            raise PolicyNotFoundError(normalized)

        return policy

    def remove(
        self,
        policy_id: str,
    ) -> PolicyDefinition:
        """Elimina y devuelve una política registrada."""
        normalized = _require_policy_id(policy_id)

        try:
            return self._policies.pop(normalized)
        except KeyError as exc:
            raise PolicyNotFoundError(
                normalized
            ) from exc

    def contains(
        self,
        policy_id: str,
    ) -> bool:
        """Comprueba explícitamente si existe una política."""
        normalized = _require_policy_id(policy_id)

        return normalized in self._policies

    def list(
        self,
        *,
        enabled: bool | None = None,
    ) -> tuple[PolicyDefinition, ...]:
        """Lista políticas en orden lexicográfico de identificador.

        Args:
            enabled:
                ``True`` limita el resultado a políticas habilitadas,
                ``False`` a políticas deshabilitadas y ``None`` devuelve
                todas las políticas.
        """
        if enabled is not None and not isinstance(enabled, bool):
            raise PolicyValidationError(
                "enabled must be a boolean or None",
                field="enabled",
                context={
                    "type": type(enabled).__name__,
                },
            )

        policies = (
            self._policies[policy_id]
            for policy_id in sorted(self._policies)
        )

        if enabled is None:
            return tuple(policies)

        return tuple(
            policy
            for policy in policies
            if policy.enabled is enabled
        )

    def ids(
        self,
        *,
        enabled: bool | None = None,
    ) -> tuple[str, ...]:
        """Devuelve identificadores en el mismo orden que ``list``."""
        return tuple(
            policy.policy_id
            for policy in self.list(
                enabled=enabled,
            )
        )

    def clear(self) -> tuple[PolicyDefinition, ...]:
        """Vacía el repositorio y devuelve su contenido anterior."""
        removed = self.list()
        self._policies.clear()

        return removed


__all__ = [
    "PolicyAlreadyExistsError",
    "PolicyNotFoundError",
    "PolicyRepository",
    "PolicyRepositoryError",
]
