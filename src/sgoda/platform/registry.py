"""Registro institucional de capacidades."""

from __future__ import annotations

from dataclasses import dataclass, field

from .models import Capability


@dataclass(slots=True)
class CapabilityRegistry:
    _capabilities: dict[str, Capability] = field(default_factory=dict)

    def register(self, capability: Capability) -> None:
        if capability.code in self._capabilities:
            raise ValueError(
                f"Capacidad duplicada: {capability.code}"
            )
        self._capabilities[capability.code] = capability

    def get(self, code: str) -> Capability | None:
        return self._capabilities.get(code)

    def all(self) -> tuple[Capability, ...]:
        return tuple(
            self._capabilities[key]
            for key in sorted(self._capabilities)
        )

    def operations(self) -> tuple[str, ...]:
        return tuple(
            sorted(
                {
                    operation
                    for capability in self.all()
                    if capability.enabled
                    for operation in capability.operations
                }
            )
        )


def default_registry() -> CapabilityRegistry:
    registry = CapabilityRegistry()

    for capability in (
        Capability(
            "SPT-005",
            "Identidad Cultural Configurable",
            "1.0.0",
            True,
            ("identity",),
        ),
        Capability(
            "SPT-006A",
            "Motor Multilingüe Local",
            "0.2.0",
            True,
            ("translate", "tts"),
        ),
        Capability(
            "SPT-007A",
            "Motor Léxico Inteligente",
            "0.1.0",
            True,
            ("lexical_search",),
        ),
        Capability(
            "SPT-007B",
            "Motor Léxico Semántico",
            "1.0.0",
            True,
            ("semantic_search",),
        ),
        Capability(
            "SPT-007C",
            "Motor de Conocimiento",
            "1.0.0",
            True,
            ("knowledge",),
        ),
        Capability(
            "SPT-007D",
            "Motor de Razonamiento",
            "1.0.0",
            True,
            ("reasoning",),
        ),
        Capability(
            "SPT-008",
            "Tutor Inteligente",
            "1.0.0",
            True,
            ("learning_path", "evaluate_activity"),
        ),
        Capability(
            "SPT-009",
            "Ecosistema Conversacional",
            "1.0.0",
            True,
            ("conversation",),
        ),
    ):
        registry.register(capability)

    return registry