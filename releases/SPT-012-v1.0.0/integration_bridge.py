"""Puente de integración con motores SGODA."""

from __future__ import annotations

from typing import Any


class IntegrationBridge:
    """Registra capacidades sin inventar resultados lingüísticos."""

    def capabilities(self) -> dict[str, Any]:
        return {
            "lexical": [
                "SPT-007A",
                "SPT-007B",
                "SPT-007C",
                "SPT-007D",
            ],
            "tutor": "SPT-008",
            "conversation": "SPT-009",
            "operationalPlatform": "SPT-011",
            "mode": "local_first",
            "noInvention": True,
        }

    def tutor_feedback(
        self,
        entry: dict[str, Any],
        answer: str,
    ) -> dict[str, Any]:
        expected = str(entry.get("spanish") or "").casefold().strip()
        received = str(answer or "").casefold().strip()
        correct = bool(expected) and expected == received

        return {
            "correct": correct,
            "expected": entry.get("spanish", ""),
            "feedback": (
                "Respuesta correcta."
                if correct
                else "Revisa nuevamente la ficha léxica."
            ),
            "source": f"RLB:{entry['entry_id']}",
            "noInvention": True,
        }