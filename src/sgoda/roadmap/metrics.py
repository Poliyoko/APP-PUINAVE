"""Cálculo de métricas ejecutivas."""

from __future__ import annotations

from .models import ComponentRecord, EcosystemMetrics


IMPLEMENTED_STATES = {
    "implemented",
    "validated",
    "technically_completed",
    "completed",
    "closed",
    "published",
    "released",
}


def calculate_metrics(
    components: list[ComponentRecord],
    assets: dict,
) -> EcosystemMetrics:
    total = len(components)

    implemented = sum(
        1
        for item in components
        if item.status.lower() in IMPLEMENTED_STATES
    )
    released = sum(
        1 for item in components if item.release_path
    )
    documented = sum(
        1 for item in components if item.documentation_paths
    )
    tested = sum(
        1 for item in components if item.test_paths
    )

    def percent(value: int) -> float:
        return round(
            (value / total * 100.0) if total else 0.0,
            2,
        )

    return EcosystemMetrics(
        total_components=total,
        implemented_components=implemented,
        pending_components=max(total - implemented, 0),
        released_components=released,
        documented_components=documented,
        tested_components=tested,
        total_test_files=len(assets["test_files"]),
        total_documents=len(assets["documents"]),
        total_releases=len(assets["releases"]),
        completion_percent=percent(implemented),
        documentation_percent=percent(documented),
        test_coverage_percent=percent(tested),
    )