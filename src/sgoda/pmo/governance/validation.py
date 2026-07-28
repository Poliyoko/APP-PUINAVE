"""Reglas de gobierno y validación del modelo PMO."""

from __future__ import annotations

from sgoda.pmo.domain import ProjectModel


class PmoValidationError(ValueError):
    """Error de validación del modelo PMO."""


def validate_project_model(model: ProjectModel) -> None:
    codes = [item.code for item in model.deliverables]
    if len(codes) != len(set(codes)):
        raise PmoValidationError("Hay entregables SPB duplicados")
    if not model.project.repository_url:
        raise PmoValidationError("El repositorio del proyecto es obligatorio")
    for item in model.deliverables:
        if not item.purpose.strip():
            raise PmoValidationError(f"El entregable {item.code} no tiene propósito")
        if not item.benefit.strip():
            raise PmoValidationError(f"El entregable {item.code} no tiene beneficio ejecutivo")
