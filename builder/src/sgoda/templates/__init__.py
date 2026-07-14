"""Plantillas disponibles del SGODA Project Builder."""

from .api import build_api_files
from .backend import build_backend_files
from .database import build_database_files
from .docs import build_docs_files
from .frontend import build_frontend_files
from .module import build_module_files, normalize_module_name
from .workflow import build_workflow_files

__all__ = [
    "build_api_files",
    "build_backend_files",
    "build_database_files",
    "build_docs_files",
    "build_frontend_files",
    "build_module_files",
    "build_workflow_files",
    "normalize_module_name",
]
