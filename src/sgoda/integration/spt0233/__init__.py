"""SPT-023.3 - Motor institucional de categorias."""

from .catalog import CategoryCatalog
from .models import CategoryAssignmentResult
from .service import Spt0233CategoryService

__all__ = [
    "CategoryAssignmentResult",
    "CategoryCatalog",
    "Spt0233CategoryService",
]
