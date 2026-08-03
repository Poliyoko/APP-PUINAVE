"""Servicio de fundación de la Fase IV."""

from __future__ import annotations

from .models import FoundationRequest, FoundationResponse
from .registry import dependency_gaps, phase_capabilities


class LearningEcosystemFoundation:
    def execute(
        self,
        request: FoundationRequest,
    ) -> FoundationResponse:
        if request.operation == "status":
            return FoundationResponse(
                operation="status",
                status="ok",
                data={
                    "component": "SPT-013A",
                    "version": "1.0.0",
                    "phase": "Fase Tecnológica IV",
                    "capabilityCount": len(phase_capabilities()),
                    "nativeEcosystem": True,
                    "localFirst": True,
                    "freeOpenTechnology": True,
                    "mandatoryProprietaryDependencies": [],
                    "noInvention": True,
                },
            )

        if request.operation == "capabilities":
            items = [
                {
                    "code": item.code,
                    "name": item.name,
                    "domain": item.domain,
                    "status": item.status,
                    "native": item.native,
                    "dependencies": list(item.dependencies),
                }
                for item in phase_capabilities()
            ]

            return FoundationResponse(
                operation="capabilities",
                status="ok",
                data={"total": len(items), "items": items},
            )

        if request.operation == "validate":
            gaps = list(dependency_gaps())

            return FoundationResponse(
                operation="validate",
                status="ok" if not gaps else "not_approved",
                data={
                    "approved": not gaps,
                    "dependencyGaps": gaps,
                    "nativeOnly": all(
                        item.native for item in phase_capabilities()
                    ),
                },
            )

        return FoundationResponse(
            operation=request.operation,
            status="unsupported_operation",
            data={},
            warnings=("La operación no está soportada.",),
        )