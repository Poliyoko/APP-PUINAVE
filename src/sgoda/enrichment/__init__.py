"""Pipeline automatizado de enriquecimiento multimedia."""

from __future__ import annotations

from typing import Any

__all__ = [
    "EnrichmentJob",
    "EnrichmentNeed",
    "EnrichmentPipeline",
    "GeneratedResource",
    "MockEnrichmentProvider",
    "PlaybackManifest",
    "build_playback_manifest",
    "detect_needs",
    "plan_repository",
    "run_pipeline",
]


def __getattr__(name: str) -> Any:
    if name not in __all__:
        raise AttributeError(name)

    if name in {
        "EnrichmentJob",
        "EnrichmentNeed",
        "GeneratedResource",
        "PlaybackManifest",
    }:
        from . import models
        return getattr(models, name)

    if name in {"detect_needs", "plan_repository"}:
        from . import planner
        return getattr(planner, name)

    if name == "MockEnrichmentProvider":
        from . import providers
        return getattr(providers, name)

    if name == "build_playback_manifest":
        from . import playback
        return getattr(playback, name)

    from . import pipeline
    return getattr(pipeline, name)