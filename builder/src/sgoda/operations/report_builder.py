"""Constructor de datos para reportes ejecutivos."""

from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path

from .collector import OperationCollector
from .history import HistoryService
from .report_models import ExecutiveRecommendation, ExecutiveReport
from .report_profiles import resolve_sections


class ExecutiveReportBuilder:
    """Construye reportes sin duplicar la lógica de observabilidad."""

    def __init__(self, workspace: str | Path) -> None:
        self.workspace = Path(workspace).expanduser().resolve()

    @staticmethod
    def _recommendations(status) -> tuple[ExecutiveRecommendation, ...]:
        recommendations: list[ExecutiveRecommendation] = []

        if status.audit.errors:
            recommendations.append(
                ExecutiveRecommendation(
                    code="AUDIT_ERRORS",
                    priority="high",
                    message=(
                        "Corregir los errores de auditoría antes de publicar "
                        "o desplegar el proyecto."
                    ),
                )
            )

        if status.audit.warnings:
            recommendations.append(
                ExecutiveRecommendation(
                    code="AUDIT_WARNINGS",
                    priority="medium",
                    message=(
                        "Revisar las advertencias para mejorar la calidad "
                        "operativa del proyecto."
                    ),
                )
            )

        if status.audit.information:
            recommendations.append(
                ExecutiveRecommendation(
                    code="INFORMATION_FINDINGS",
                    priority="low",
                    message=(
                        "Evaluar los hallazgos informativos y documentar "
                        "las decisiones adoptadas."
                    ),
                )
            )

        if not status.components:
            recommendations.append(
                ExecutiveRecommendation(
                    code="NO_COMPONENTS",
                    priority="low",
                    message=(
                        "Registrar o generar componentes para reflejar "
                        "el alcance funcional del proyecto."
                    ),
                )
            )

        if status.resources.available < status.resources.total:
            recommendations.append(
                ExecutiveRecommendation(
                    code="MISSING_RESOURCES",
                    priority="high",
                    message=(
                        "Restaurar los recursos obligatorios faltantes "
                        "antes de continuar con el ciclo de vida."
                    ),
                )
            )

        if not recommendations:
            recommendations.append(
                ExecutiveRecommendation(
                    code="MAINTAIN_HEALTH",
                    priority="low",
                    message=(
                        "Mantener las validaciones periódicas de auditoría, "
                        "calidad e historial."
                    ),
                )
            )

        return tuple(recommendations)

    def build(
        self,
        *,
        include_history: bool = True,
        history_limit: int = 20,
        profile: str = "executive",
        sections: tuple[str, ...] | None = None,
    ) -> ExecutiveReport:
        if history_limit < 1:
            raise ValueError("history_limit debe ser mayor que cero.")

        selected_sections = resolve_sections(profile, sections)
        status = OperationCollector(self.workspace).collect()
        history = ()
        if include_history and "history" in selected_sections:
            history = tuple(
                HistoryService(self.workspace).list(limit=history_limit)
            )

        return ExecutiveReport(
            title="Reporte Ejecutivo SGODA",
            generated_at=datetime.now(UTC).isoformat(),
            status=status,
            history=history,
            recommendations=(
                self._recommendations(status)
                if "recommendations" in selected_sections
                else ()
            ),
            profile=profile,
            sections=selected_sections,
            indicators={
                "quality_percentage": status.audit.score,
                "resource_coverage": round(
                    (status.resources.available / status.resources.total) * 100,
                    2,
                ) if status.resources.total else 100.0,
                "component_total": sum(status.components.values()),
                "extension_total": (
                    status.extensions.plugins + status.extensions.templates
                ),
                "history_events": len(history),
                "risk_level": (
                    "high" if status.health == "ERROR"
                    else "medium" if status.health == "WARNING"
                    else "low"
                ),
            },
            metadata={
                "history_included": include_history,
                "history_limit": history_limit,
                "model": "OperationStatus",
                "profile": profile,
            },
        )
