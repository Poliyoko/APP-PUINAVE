"""SGODA Platform Kernel."""

from sgoda.kernel.application import create_application
from sgoda.kernel.registry import module_registry

__all__ = ["create_application", "module_registry"]
