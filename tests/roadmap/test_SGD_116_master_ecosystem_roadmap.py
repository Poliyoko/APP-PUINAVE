"""Pruebas SGD-116."""

import json
from pathlib import Path

from sgoda.roadmap.dependency_graph import (
    build_dependency_graph,
)
from sgoda.roadmap.discovery import (
    discover_components,
    discover_repository_assets,
)
from sgoda.roadmap.generator import generate_roadmap
from sgoda.roadmap.metrics import calculate_metrics
from sgoda.roadmap.models import ComponentRecord
from sgoda.roadmap.validator import validate_roadmap


def _repository(tmp_path: Path) -> Path:
    root = tmp_path
    (root / "config/test").mkdir(parents=True)
    (root / "src/example").mkdir(parents=True)
    (root / "tests/example").mkdir(parents=True)
    (root / "docs").mkdir(parents=True)
    (root / "releases/SPT-900-v1.0.0").mkdir(parents=True)

    (root / "src/example/module.py").write_text(
        "VALUE = 1\n",
        encoding="utf-8",
    )
    (root / "tests/example/test_module.py").write_text(
        "def test_ok(): assert True\n",
        encoding="utf-8",
    )
    (root / "docs/example.md").write_text(
        "# Example\n",
        encoding="utf-8",
    )

    component = {
        "increment_code": "SPT-900",
        "name": "Componente de prueba",
        "version": "1.0.0",
        "status": "technically_completed",
        "component_type": "test_component",
        "dependencies": [],
        "source": ["src/example/module.py"],
        "tests": ["tests/example/test_module.py"],
        "documentation": ["docs/example.md"],
    }
    (root / "config/test/SPT-900-component.json").write_text(
        json.dumps(component),
        encoding="utf-8",
    )
    return root


def _master_documents(root: Path) -> None:
    for name in (
        "00_INDICE_MAESTRO.md",
        "00_ARQUITECTURA_MAESTRA.md",
        "00_REGISTRO_MAESTRO_COMPONENTES.md",
    ):
        (root / "docs" / name).write_text(
            f"# {name}\n",
            encoding="utf-8",
        )


def test_SGD_116_discovers_component(tmp_path):
    root = _repository(tmp_path)
    components = discover_components(root)
    assert [item.code for item in components] == ["SPT-900"]


def test_SGD_116_discovers_assets(tmp_path):
    assets = discover_repository_assets(
        _repository(tmp_path)
    )
    assert len(assets["test_files"]) == 1
    assert len(assets["documents"]) == 1
    assert len(assets["releases"]) == 1


def test_SGD_116_builds_dependency_graph():
    components = [
        ComponentRecord(
            code="SPT-901",
            name="A",
            version="1",
            status="implemented",
            component_type="test",
            phase="Test",
            dependencies=["SPT-900"],
        ),
        ComponentRecord(
            code="SPT-900",
            name="B",
            version="1",
            status="implemented",
            component_type="test",
            phase="Test",
        ),
    ]
    graph = build_dependency_graph(components)
    assert graph.edges == [
        {"source": "SPT-901", "target": "SPT-900"}
    ]
    assert graph.missing_dependencies == []


def test_SGD_116_detects_missing_dependency():
    components = [
        ComponentRecord(
            code="SPT-901",
            name="A",
            version="1",
            status="implemented",
            component_type="test",
            phase="Test",
            dependencies=["SPT-999"],
        )
    ]
    graph = build_dependency_graph(components)
    assert graph.missing_dependencies


def test_SGD_116_detects_cycle():
    components = [
        ComponentRecord(
            code="SPT-900",
            name="A",
            version="1",
            status="implemented",
            component_type="test",
            phase="Test",
            dependencies=["SPT-901"],
        ),
        ComponentRecord(
            code="SPT-901",
            name="B",
            version="1",
            status="implemented",
            component_type="test",
            phase="Test",
            dependencies=["SPT-900"],
        ),
    ]
    assert build_dependency_graph(components).cycles


def test_SGD_116_calculates_metrics(tmp_path):
    root = _repository(tmp_path)
    components = discover_components(root)
    assets = discover_repository_assets(root)
    metrics = calculate_metrics(components, assets)
    assert metrics.total_components == 1
    assert metrics.completion_percent == 100.0
    assert metrics.total_releases == 1


def test_SGD_116_generates_master_documents(tmp_path):
    root = _repository(tmp_path)
    _master_documents(root)
    generate_roadmap(root, root / "artifacts/roadmap/SGD-116")
    assert (root / "docs/00_ROADMAP_MAESTRO.md").is_file()
    assert (root / "docs/00_DEPENDENCIAS_MAESTRAS.md").is_file()
    assert (root / "docs/00_TIMELINE_MAESTRO.md").is_file()
    assert (root / "docs/00_METRICAS_ECOSISTEMA.md").is_file()


def test_SGD_116_generates_dashboard(tmp_path):
    root = _repository(tmp_path)
    _master_documents(root)
    generate_roadmap(root, root / "artifacts/roadmap/SGD-116")
    assert (root / "dashboard/ecosystem-roadmap.json").is_file()
    assert (root / "dashboard/ecosystem-metrics.json").is_file()
    assert (root / "dashboard/dependency-graph.json").is_file()


def test_SGD_116_validation_passes(tmp_path):
    root = _repository(tmp_path)
    _master_documents(root)
    generate_roadmap(root, root / "artifacts/roadmap/SGD-116")
    components = discover_components(root)
    result = validate_roadmap(root, components)
    assert result.passed is True


def test_SGD_116_validation_detects_broken_path(tmp_path):
    root = _repository(tmp_path)
    _master_documents(root)
    generate_roadmap(root, root / "artifacts/roadmap/SGD-116")
    (root / "src/example/module.py").unlink()
    result = validate_roadmap(
        root,
        discover_components(root),
    )
    assert result.passed is False
    assert result.broken_paths


def test_SGD_116_executive_summary_is_approved(tmp_path):
    root = _repository(tmp_path)
    _master_documents(root)
    paths = generate_roadmap(
        root,
        root / "artifacts/roadmap/SGD-116",
    )
    summary = json.loads(
        Path(paths["executive_summary"]).read_text(
            encoding="utf-8"
        )
    )
    assert summary["status"] == "approved"


def test_SGD_116_is_idempotent(tmp_path):
    root = _repository(tmp_path)
    _master_documents(root)
    output = root / "artifacts/roadmap/SGD-116"
    generate_roadmap(root, output)
    first = (output / "roadmap.json").read_text(
        encoding="utf-8"
    )
    generate_roadmap(root, output)
    second = (output / "roadmap.json").read_text(
        encoding="utf-8"
    )
    first_payload = json.loads(first)
    second_payload = json.loads(second)
    first_payload.pop("generated_at_utc")
    second_payload.pop("generated_at_utc")
    assert first_payload == second_payload

def test_SGD_116_normalizes_versioned_governance_dependencies():
    from sgoda.roadmap.discovery import canonical_component_code

    assert canonical_component_code(
        "SGD-114-v2.0.1"
    ) == "SGD-114"
    assert canonical_component_code(
        "SGD-115-v1.0.1"
    ) == "SGD-115"


def test_SGD_116_discovers_SGD_114_canonical_anchor(
    tmp_path,
):
    root = tmp_path
    (root / "src/sgoda/governance").mkdir(parents=True)
    (root / "tests/governance").mkdir(parents=True)
    (root / "docs/01_Gobierno").mkdir(parents=True)
    (root / "config/example").mkdir(parents=True)
    (root / "releases").mkdir(parents=True)

    (
        root
        / "src/sgoda/governance/repository_governance.py"
    ).write_text("VALUE = 1\n", encoding="utf-8")

    components = discover_components(root)
    codes = [item.code for item in components]

    assert "SGD-114" in codes
    anchor = next(
        item for item in components
        if item.code == "SGD-114"
    )
    assert anchor.metadata[
        "synthetic_canonical_anchor"
    ] is True

def test_SGD_116_canonicalizes_all_supported_version_suffixes():
    from sgoda.roadmap.discovery import canonical_component_code

    assert canonical_component_code("SGD-114-v2.0.1") == "SGD-114"
    assert canonical_component_code("SGD-115-v1.0.1") == "SGD-115"
    assert canonical_component_code("SPT-006A-v0.2.0") == "SPT-006A"
    assert canonical_component_code("ADR-010-v1.0.0") == "ADR-010"


def test_SGD_116_finds_repository_evidence_for_historical_code(
    tmp_path,
):
    from sgoda.roadmap.discovery import repository_evidence

    root = tmp_path
    (root / "docs").mkdir()
    (root / "docs/SGD-114-history.md").write_text(
        "# SGD-114\n",
        encoding="utf-8",
    )

    evidence = repository_evidence(root, "SGD-114")
    assert "docs/SGD-114-history.md" in evidence


def test_SGD_116_resolves_historical_dependency_with_evidence(
    tmp_path,
):
    root = tmp_path
    (root / "config/test").mkdir(parents=True)
    (root / "docs").mkdir(parents=True)
    (root / "releases").mkdir(parents=True)

    (root / "docs/SGD-114-history.md").write_text(
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
    (root / "config/test/SPT-901-component.json").write_text(
        json.dumps(payload),
        encoding="utf-8",
    )

    components = discover_components(root)
    graph = build_dependency_graph(components)

    assert "SGD-114" in [item.code for item in components]
    assert graph.missing_dependencies == []
    assert graph.historical_dependencies == [
        {"source": "SPT-901", "target": "SGD-114"}
    ]


def test_SGD_116_still_blocks_dependency_without_evidence(
    tmp_path,
):
    root = tmp_path
    (root / "config/test").mkdir(parents=True)
    (root / "releases").mkdir(parents=True)

    payload = {
        "increment_code": "SPT-901",
        "name": "Consumer",
        "version": "1.0.0",
        "status": "implemented",
        "component_type": "test",
        "dependencies": ["SGD-999-v9.9.9"],
    }
    (root / "config/test/SPT-901-component.json").write_text(
        json.dumps(payload),
        encoding="utf-8",
    )

    components = discover_components(root)
    graph = build_dependency_graph(components)

    assert graph.missing_dependencies == [
        {"source": "SPT-901", "target": "SGD-999"}
    ]