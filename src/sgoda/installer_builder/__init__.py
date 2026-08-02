from __future__ import annotations
from typing import Any

__all__ = [
    "GeneratedPackage",
    "IncrementSpec",
    "SpecificationError",
    "generate_package",
    "validate_code",
    "validate_generated_package",
    "validate_name",
]


def __getattr__(name: str) -> Any:
    if name not in __all__:
        raise AttributeError(name)
    if name in {"GeneratedPackage", "IncrementSpec"}:
        from . import models
        return getattr(models, name)
    if name == "generate_package":
        from . import generator
        return getattr(generator, name)
    from . import validator
    return getattr(validator, name)