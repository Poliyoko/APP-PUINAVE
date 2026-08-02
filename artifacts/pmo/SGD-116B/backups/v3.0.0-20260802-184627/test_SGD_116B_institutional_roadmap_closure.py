"""Pruebas institucionales SGD-116B."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from sgoda.roadmap.aliases import (
    canonical_component_code,
    is_supported_component_code,
    resolve_alias,
)
from sgoda.roadmap.dependency_graph import (
    build_dependency_graph,
)
from sgoda.roadmap.discovery import (
    discover_components,
    institutional_evidence,
)
from sgoda.roadmap.models import ComponentRecord
from sgoda.roadmap.validator import validate_roadmap


def _component(
    code: str,
    *,
    dependencies: list[str] | None = None,
    historical: bool = False,
) -> ComponentRecord:
    return ComponentRecord(
        code=code,
        name=code,
        version="1.0.0",
        status="implemented",
        component_type="test",
        phase="Test",
        dependencies=dependencies or [],
        metadata={
            "synthetic_canonical_anchor": historical
        },
    )


@pytest.mark.parametrize(
    ("raw", "canonical"),
    [
        ("SGD-114-v2.0.1", "SGD-114"),
        ("SGD-115-v1.0.1", "SGD-115"),
        ("SPT-006A-v0.2.0", "SPT-006A"),
        ("ADR-010-v1.0.0", "ADR-010"),
        ("SPB-007", "SPB-007"),
        ("SIB-001", "SIB-001"),
    ],
)
def test_SGD_116B_resolves_aliases(
    raw,
    canonical,
):
    assert canonical_component_code(raw) == canonical


def test_SGD_116B_reports_alias_change():
    result = resolve_alias("SGD-114-v2.0.1")
    assert result.changed is True
    assert result.valid_format is True


def test_SGD_116B_rejects_unsupported_format():
    assert is_supported_component_code("XYZ-001") is False


def test_SGD_116B_finds_institutional_evidence(
    tmp_path,
):
    root = tmp_path
    (root / "docs").mkdir()
    path = root / "docs/SGD-114-history.md"
    path.write_text("# SGD-114\n", encoding="utf-8")

    assert (
        "docs/SGD-114-history.md"
        in institutional_evidence(root, "SGD-114")
    )


def test_SGD_116B_discovers_descriptor_component(
    tmp_path,
):
    root = tmp_path
    (root / "config/test").mkdir(parents=True)
    (root / "releases").mkdir()

    payload = {
        "increment_code": "SPT-900",
        "name": "Test",
        "version": "1.0.0",
        "status": "implemented",
        "component_type": "test",
    }

    (
        root / "config/test/SPT-900-component.json"
    ).write_text(
        json.dumps(payload),
        encoding="utf-8",
    )

    assert [
        item.code
        for item in discover_components(root)
    ] == ["SPT-900"]


def test_SGD_116B_preserves_historical_component(
    tmp_path,
):
    root = tmp_path
    (root / "config/test").mkdir(parents=True)
    (root / "docs").mkdir()
    (root / "releases").mkdir()

    (
        root / "docs/SGD-114-history.md"
    ).write_text(
        "# SGD-114\n",
        encoding="utf-8",
    )

    payload = {
        "increment_code": "SPT-901",
        "name": "Consumer",
        "version": "1.0.0",
        "status": "implemented",
        "component_type": "test",
        "dependencies": ["SGD-114-v2.0.1"],
    }

    (
        root / "config/test/SPT-901-component.json"
    ).write_text(
        json.dumps(payload),
        encoding="utf-8",
    )

    components = discover_components(root)
    assert {"SPT-901", "SGD-114"} == {
        item.code for item in components
    }


def test_SGD_116B_classifies_found_dependency():
    graph = build_dependency_graph(
        [
            _component(
                "SPT-901",
                dependencies=["SGD-114"],
            ),
            _component("SGD-114"),
        ]
    )

    assert graph.edges == [
        {
            "source": "SPT-901",
            "target": "SGD-114",
            "status": "FOUND",
        }
    ]


def test_SGD_116B_classifies_aliased_dependency():
    graph = build_dependency_graph(
        [
            _component(
                "SPT-901",
                dependencies=["SGD-114-v2.0.1"],
            ),
            _component("SGD-114"),
        ]
    )

    assert graph.resolved_aliases == [
        {
            "source": "SPT-901",
            "raw_target": "SGD-114-v2.0.1",
            "target": "SGD-114",
            "status": "ALIASED",
        }
    ]


def test_SGD_116B_classifies_historical_dependency():
    graph = build_dependency_graph(
        [
            _component(
                "SPT-901",
                dependencies=["SGD-114-v2.0.1"],
            ),
            _component(
                "SGD-114",
                historical=True,
            ),
        ]
    )

    assert graph.historical_dependencies == [
        {
            "source": "SPT-901",
            "target": "SGD-114",
            "status": "HISTORICAL",
        }
    ]


def test_SGD_116B_blocks_missing_dependency():
    graph = build_dependency_graph(
        [
            _component(
                "SPT-901",
                dependencies=["SGD-999-v9.9.9"],
            )
        ]
    )

    assert graph.missing_dependencies == [
        {
            "source": "SPT-901",
            "target": "SGD-999",
            "status": "MISSING",
        }
    ]


def test_SGD_116B_detects_cycle():
    graph = build_dependency_graph(
        [
            _component(
                "SPT-900",
                dependencies=["SPT-901"],
            ),
            _component(
                "SPT-901",
                dependencies=["SPT-900"],
            ),
        ]
    )

    assert graph.cycles


def test_SGD_116B_validation_blocks_missing(
    tmp_path,
):
    root = tmp_path
    (root / "docs").mkdir()

    for name in (
        "00_INDICE_MAESTRO.md",
        "00_ARQUITECTURA_MAESTRA.md",
        "00_REGISTRO_MAESTRO_COMPONENTES.md",
        "00_ROADMAP_MAESTRO.md",
        "00_DEPENDENCIAS_MAESTRAS.md",
        "00_TIMELINE_MAESTRO.md",
        "00_METRICAS_ECOSISTEMA.md",
    ):
        (root / "docs" / name).write_text(
            "# Document\n",
            encoding="utf-8",
        )

    result = validate_roadmap(
        root,
        [
            _component(
                "SPT-901",
                dependencies=["SGD-999"],
            )
        ],
    )

    assert result.passed is False
    assert result.missing_dependencies


def test_SGD_116B_validation_accepts_historical(
    tmp_path,
):
    root = tmp_path
    (root / "docs").mkdir()

    for name in (
        "00_INDICE_MAESTRO.md",
        "00_ARQUITECTURA_MAESTRA.md",
        "00_REGISTRO_MAESTRO_COMPONENTES.md",
        "00_ROADMAP_MAESTRO.md",
        "00_DEPENDENCIAS_MAESTRAS.md",
        "00_TIMELINE_MAESTRO.md",
        "00_METRICAS_ECOSISTEMA.md",
    ):
        (root / "docs" / name).write_text(
            "# Document\n",
            encoding="utf-8",
        )

    result = validate_roadmap(
        root,
        [
            _component(
                "SPT-901",
                dependencies=["SGD-114-v2.0.1"],
            ),
            _component(
                "SGD-114",
                historical=True,
            ),
        ],
    )

    assert result.passed is True
    assert result.missing_dependencies == []