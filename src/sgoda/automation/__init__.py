"""Orquestador multimedia SGODA-PUINAVE."""

from __future__ import annotations

__all__ = [
    "ColaTrabajosMultimedia",
    "TrabajoMultimedia",
    "deterministic_job_id",
    "planificar",
]


def __getattr__(name: str):
    if name in {"ColaTrabajosMultimedia", "deterministic_job_id"}:
        from . import job_queue
        return getattr(job_queue, name)
    if name == "TrabajoMultimedia":
        from .models import TrabajoMultimedia
        return TrabajoMultimedia
    if name == "planificar":
        from .planner import planificar
        return planificar
    raise AttributeError(name)