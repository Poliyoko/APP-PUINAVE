"""SPT-024.16 Capa 1 â€” database/PostgreSQL security governance."""
from .service import DatabaseSecurityService
from .gate import DatabaseSecurityGate
__all__ = ["DatabaseSecurityService", "DatabaseSecurityGate"]
