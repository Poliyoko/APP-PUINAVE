"""Coordinación determinista de evaluaciones de políticas de gobernanza."""

from __future__ import annotations

from collections.abc import Iterable, Mapping
from typing import Any

from .exceptions import (
    PolicyEvaluationError,
    PolicyValidationError,
)
from .models import PolicyDefinition
from .policy_validator import (
    validate_policies,
    validate_policy,
)
from .results import PolicyResult
from .rule_evaluator import evaluate_rule


_DISABLED_POLICY_MESSAGE = "Policy is disabled and was not evaluated"


def _require_values(
    values: Any,
    *,
    policy_id: str | None = None,
) -> Mapping[str, Any]:
    """Valida el contexto utilizado por la evaluación."""
    if not isinstance(values, Mapping):
        raise PolicyValidationError(
            "values must be a mapping",
            policy_id=policy_id,
            field="values",
            context={
                "type": type(values).__name__,
            },
        )

    return values


def _policy_metadata(
    policy: PolicyDefinition,
) -> dict[str, Any]:
    """Construye metadatos deterministas del resultado agregado."""
    return {
        "policy_metadata": policy.metadata,
        "rule_count": len(policy.rules),
    }


def evaluate_policy(
    policy: PolicyDefinition,
    values: Mapping[str, Any],
) -> PolicyResult:
    """Evalúa una política contra un contexto de valores.

    La política se valida semánticamente antes de procesar sus reglas.
    Las reglas se evalúan en el mismo orden en que fueron declaradas.

    Una política deshabilitada produce un ``PolicyResult`` omitido, sin
    resultados de reglas. Los errores operacionales de reglas individuales
    permanecen representados mediante ``RuleResultStatus.ERROR`` por
    ``evaluate_rule``.

    Args:
        policy:
            Definición de política que será evaluada.
        values:
            Contexto de valores accesible mediante las rutas declaradas en
            las reglas.

    Returns:
        Resultado agregado e inmutable de la política.

    Raises:
        PolicyValidationError:
            Si la política o el contexto incumplen el contrato de dominio.
        PolicyEvaluationError:
            Si ocurre un error inesperado al coordinar la evaluación.
    """
    if not isinstance(policy, PolicyDefinition):
        raise PolicyValidationError(
            "policy must be a PolicyDefinition instance",
            field="policy",
            context={
                "type": type(policy).__name__,
            },
        )

    normalized_values = _require_values(
        values,
        policy_id=policy.policy_id,
    )

    validate_policy(
        policy,
        allow_disabled=True,
    )

    metadata = _policy_metadata(policy)

    if not policy.enabled:
        metadata["evaluation"] = "skipped"

        return PolicyResult(
            policy_id=policy.policy_id,
            name=policy.name,
            version=policy.version,
            rule_results=(),
            enabled=False,
            message=_DISABLED_POLICY_MESSAGE,
            metadata=metadata,
        )

    try:
        rule_results = tuple(
            evaluate_rule(
                rule,
                normalized_values,
                policy_id=policy.policy_id,
            )
            for rule in policy.rules
        )
    except PolicyValidationError:
        raise
    except Exception as exc:
        raise PolicyEvaluationError(
            "policy evaluation could not be completed",
            policy_id=policy.policy_id,
            context={
                "cause": str(exc),
                "exception_type": type(exc).__name__,
            },
        ) from exc

    metadata["evaluation"] = "completed"

    return PolicyResult(
        policy_id=policy.policy_id,
        name=policy.name,
        version=policy.version,
        rule_results=rule_results,
        enabled=True,
        metadata=metadata,
    )


def evaluate_policies(
    policies: Iterable[PolicyDefinition],
    values: Mapping[str, Any],
) -> tuple[PolicyResult, ...]:
    """Evalúa varias políticas conservando el orden de entrada.

    Todas las políticas se validan antes de iniciar la evaluación. De esta
    manera no se producen resultados parciales cuando la colección contiene
    políticas inválidas o identificadores duplicados.
    """
    normalized_values = _require_values(values)

    validated_policies = validate_policies(
        policies,
        allow_disabled=True,
    )

    return tuple(
        evaluate_policy(
            policy,
            normalized_values,
        )
        for policy in validated_policies
    )


__all__ = [
    "evaluate_policies",
    "evaluate_policy",
]
