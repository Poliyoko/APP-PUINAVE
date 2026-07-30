"""Fachada de aplicación para el subsistema de gobernanza."""

from __future__ import annotations

import os
from collections.abc import Iterable, Mapping
from typing import Any, TypeAlias

from .models import PolicyDefinition
from .policy_engine import (
    evaluate_policies,
    evaluate_policy,
)
from .policy_loader import (
    load_policies,
    load_policy,
)
from .policy_repository import (
    PolicyAlreadyExistsError,
    PolicyRepository,
)
from .results import PolicyResult


PathInput: TypeAlias = str | os.PathLike[str]


class GovernanceService:
    """Coordina carga, registro, consulta y evaluación de políticas.

    El servicio no contiene lógica de reglas ni persistencia propia. Toda
    validación y operación de dominio se delega en los componentes
    especializados del paquete ``sgoda.governance``.

    Las operaciones múltiples de registro son atómicas respecto del
    repositorio: primero se valida la colección completa y después se
    modifican las políticas almacenadas.
    """

    __slots__ = ("_repository",)

    def __init__(
        self,
        repository: PolicyRepository | None = None,
    ) -> None:
        if repository is None:
            repository = PolicyRepository()
        elif not isinstance(repository, PolicyRepository):
            raise TypeError(
                "repository must be a PolicyRepository instance or None"
            )

        self._repository = repository

    @property
    def repository(self) -> PolicyRepository:
        """Devuelve el repositorio utilizado por el servicio."""
        return self._repository

    def register(
        self,
        policy: PolicyDefinition,
        *,
        replace: bool = False,
    ) -> PolicyDefinition:
        """Registra una política de dominio.

        Args:
            policy:
                Política que será incorporada al repositorio.
            replace:
                Cuando es ``True``, reemplaza una política existente con el
                mismo identificador. Cuando es ``False``, un duplicado genera
                ``PolicyAlreadyExistsError``.
        """
        self._require_replace(replace)

        if replace:
            return self._repository.upsert(policy)

        return self._repository.add(policy)

    def register_many(
        self,
        policies: Iterable[PolicyDefinition],
        *,
        replace: bool = False,
    ) -> tuple[PolicyDefinition, ...]:
        """Registra varias políticas de manera atómica.

        La colección completa se valida antes de modificar el repositorio.
        Los identificadores duplicados dentro de la colección son rechazados
        por ``PolicyRepository``.
        """
        self._require_replace(replace)

        validated = PolicyRepository(policies).list()

        if not replace:
            for policy in validated:
                if self._repository.contains(policy.policy_id):
                    raise PolicyAlreadyExistsError(
                        policy.policy_id
                    )

        for policy in validated:
            if replace:
                self._repository.upsert(policy)
            else:
                self._repository.add(policy)

        return validated

    def load(
        self,
        path: PathInput,
        *,
        replace: bool = False,
    ) -> PolicyDefinition:
        """Carga una política JSON y la registra."""
        policy = load_policy(path)

        return self.register(
            policy,
            replace=replace,
        )

    def load_many(
        self,
        paths: Iterable[PathInput],
        *,
        replace: bool = False,
    ) -> tuple[PolicyDefinition, ...]:
        """Carga y registra varias políticas de manera atómica."""
        policies = load_policies(paths)

        return self.register_many(
            policies,
            replace=replace,
        )

    def get(
        self,
        policy_id: str,
        default=None,
    ):
        """Obtiene una política o devuelve el valor predeterminado."""
        return self._repository.get(
            policy_id,
            default,
        )

    def require(
        self,
        policy_id: str,
    ) -> PolicyDefinition:
        """Obtiene una política registrada o genera error."""
        return self._repository.require(policy_id)

    def remove(
        self,
        policy_id: str,
    ) -> PolicyDefinition:
        """Elimina y devuelve una política registrada."""
        return self._repository.remove(policy_id)

    def policies(
        self,
        *,
        enabled: bool | None = None,
    ) -> tuple[PolicyDefinition, ...]:
        """Lista las políticas registradas en orden determinista."""
        return self._repository.list(
            enabled=enabled,
        )

    def policy_ids(
        self,
        *,
        enabled: bool | None = None,
    ) -> tuple[str, ...]:
        """Lista identificadores en orden determinista."""
        return self._repository.ids(
            enabled=enabled,
        )

    def evaluate(
        self,
        policy_id: str,
        values: Mapping[str, Any],
    ) -> PolicyResult:
        """Evalúa una política registrada."""
        policy = self._repository.require(policy_id)

        return evaluate_policy(
            policy,
            values,
        )

    def evaluate_all(
        self,
        values: Mapping[str, Any],
        *,
        enabled: bool | None = None,
    ) -> tuple[PolicyResult, ...]:
        """Evalúa las políticas seleccionadas del repositorio.

        Args:
            values:
                Contexto de valores compartido por todas las políticas.
            enabled:
                ``True`` evalúa solo políticas habilitadas; ``False`` incluye
                únicamente políticas deshabilitadas, que producirán resultados
                ``SKIPPED``; ``None`` evalúa todas.
        """
        policies = self._repository.list(
            enabled=enabled,
        )

        return evaluate_policies(
            policies,
            values,
        )

    def clear(self) -> tuple[PolicyDefinition, ...]:
        """Vacía el repositorio y devuelve las políticas removidas."""
        return self._repository.clear()

    @staticmethod
    def _require_replace(replace: object) -> None:
        """Valida la opción explícita de reemplazo."""
        if not isinstance(replace, bool):
            raise TypeError(
                "replace must be a boolean"
            )


__all__ = [
    "GovernanceService",
]
