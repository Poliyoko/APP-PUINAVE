"""SPT-023.2 - Validacion y analisis semantico institucional."""

from .models import SemanticValidationResult
from .service import Spt0232SemanticValidationService
from .validator import validate_detector_word

__all__ = [
    "SemanticValidationResult",
    "Spt0232SemanticValidationService",
    "validate_detector_word",
]