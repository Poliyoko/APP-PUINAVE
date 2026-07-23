"""Repositorios del subsistema DMP."""

from .base import DmpRepository
from .memory import InMemoryDmpRepository

__all__ = ["DmpRepository", "InMemoryDmpRepository"]
