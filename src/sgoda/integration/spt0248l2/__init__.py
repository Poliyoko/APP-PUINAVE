"""SPT-024.8 Capa 2 â€” event correlation, incident management, alerting and response."""
from .service import EventCorrelationService
from .gate import EventCorrelationGate

__all__ = ["EventCorrelationService", "EventCorrelationGate"]
