"""SPT-007A — Motor Léxico Inteligente."""

from .models import (
    LexicalEntry,
    MultimediaResource,
    SearchHit,
    SearchQuery,
    SearchResponse,
)
from .multimedia import playback_manifest, resources_for_entry
from .normalizer import (
    levenshtein_distance,
    normalize_text,
    similarity,
    tokenize,
)
from .repository import LexicalRepository, entry_from_dict
from .search import LexicalSearchEngine
from .service import IntelligentLexicalService

__all__ = [
    "IntelligentLexicalService",
    "LexicalEntry",
    "LexicalRepository",
    "LexicalSearchEngine",
    "MultimediaResource",
    "SearchHit",
    "SearchQuery",
    "SearchResponse",
    "entry_from_dict",
    "levenshtein_distance",
    "normalize_text",
    "playback_manifest",
    "resources_for_entry",
    "similarity",
    "tokenize",
]