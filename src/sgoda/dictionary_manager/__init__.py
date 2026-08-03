"""SPT-013B — Gestor Institucional del Diccionario Digital."""

from .import_export import (
    entry_from_dict,
    entry_to_dict,
    export_entries,
    load_entries,
)
from .models import (
    DictionaryCommand,
    DictionaryResult,
    LexicalEntry,
    LexicalExample,
)
from .repository import DictionaryRepository
from .service import InstitutionalDictionaryManager

__all__ = [
    "DictionaryCommand",
    "DictionaryRepository",
    "DictionaryResult",
    "InstitutionalDictionaryManager",
    "LexicalEntry",
    "LexicalExample",
    "entry_from_dict",
    "entry_to_dict",
    "export_entries",
    "load_entries",
]