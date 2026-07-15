"""Servicio de aplicación para consultar el estado operativo."""

from pathlib import Path

from .collector import OperationCollector
from .serializers import serialize_json, serialize_text


def render_status(
    workspace: str | Path,
    *,
    output_format: str = "text",
    detailed: bool = False,
) -> str:
    status = OperationCollector(workspace).collect()
    if output_format == "json":
        return serialize_json(status, detailed=detailed)
    if output_format == "text":
        return serialize_text(status, detailed=detailed)
    raise ValueError(f"Formato no soportado: {output_format}")
