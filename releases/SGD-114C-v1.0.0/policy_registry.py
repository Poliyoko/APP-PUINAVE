"""Registro de reglas SGD-114C."""

from __future__ import annotations

from dataclasses import dataclass, field

from .policy_models import PolicyRule
from .policy_rules import BUILTIN_RULES, RuleExecutor


@dataclass(slots=True)
class PolicyRegistry:
    _items: dict[str, tuple[PolicyRule, RuleExecutor]] = field(
        default_factory=dict
    )

    def register(
        self,
        rule: PolicyRule,
        executor: RuleExecutor,
    ) -> None:
        if rule.code in self._items:
            raise ValueError(f"Regla duplicada: {rule.code}")
        self._items[rule.code] = (rule, executor)

    def items(
        self,
    ) -> tuple[tuple[PolicyRule, RuleExecutor], ...]:
        return tuple(
            self._items[key]
            for key in sorted(self._items)
        )


def build_default_registry() -> PolicyRegistry:
    registry = PolicyRegistry()

    for rule, executor in BUILTIN_RULES:
        registry.register(rule, executor)

    return registry