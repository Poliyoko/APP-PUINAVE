"""Diagnóstico operativo de la plataforma."""

from __future__ import annotations

import importlib.util
from pathlib import Path


REQUIRED_MODULES = {
    "identity": "sgoda.identity",
    "language_engine": "sgoda.language_engine",
    "lexical_engine": "sgoda.lexical_engine",
    "knowledge_engine": "sgoda.knowledge_engine",
    "reasoning_engine": "sgoda.reasoning_engine",
    "tutor": "sgoda.tutor",
    "conversation": "sgoda.conversation",
}


def module_health() -> dict[str, bool]:
    return {
        name: importlib.util.find_spec(module) is not None
        for name, module in REQUIRED_MODULES.items()
    }


def repository_health(root: str | Path) -> dict:
    base = Path(root)
    modules = module_health()

    required_paths = {
        "pytest": base / "pytest.ini",
        "governance_policy": (
            base
            / "config"
            / "governance"
            / "SGD-114C-policy.json"
        ),
        "roadmap_validation": (
            base
            / "artifacts"
            / "roadmap"
            / "SGD-116"
            / "validation.json"
        ),
    }

    paths = {
        key: value.exists()
        for key, value in required_paths.items()
    }

    healthy = all(modules.values()) and all(paths.values())

    return {
        "healthy": healthy,
        "modules": modules,
        "paths": paths,
    }