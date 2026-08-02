"""Motor determinista de políticas SGD-114C."""

from __future__ import annotations

from datetime import datetime, timezone

from .policy_context import PolicyContext
from .policy_models import PolicyEvaluation
from .policy_registry import PolicyRegistry


def evaluate_policy(
    context: PolicyContext,
    registry: PolicyRegistry,
) -> PolicyEvaluation:
    results = tuple(
        executor(context, rule)
        for rule, executor in registry.items()
    )

    approved = not any(item.blocking for item in results)

    return PolicyEvaluation(
        policy_code=str(
            context.policy.get("policy_code", "SGD-114C")
        ),
        policy_version=str(
            context.policy.get("version", "1.0.0")
        ),
        increment=context.increment,
        approved=approved,
        results=results,
        generated_at_utc=datetime.now(
            timezone.utc
        ).isoformat(),
    )