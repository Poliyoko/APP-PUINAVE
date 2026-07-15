"""Motor de salud operativa SGODA."""

from .models import HealthStatus


def calculate_health(*, errors: int, warnings: int) -> HealthStatus:
    """Calcula el estado general con reglas simples y extensibles."""
    if errors > 0:
        return "ERROR"
    if warnings > 0:
        return "WARNING"
    return "HEALTHY"
