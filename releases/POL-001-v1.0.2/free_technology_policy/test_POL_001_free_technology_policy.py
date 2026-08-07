
from __future__ import annotations

import json
from pathlib import Path

from sgoda.governance.free_technology_policy import (
    APPROVED,
    PROHIBITED,
    REVIEW,
    classify,
    compose_images,
    normalize_name,
    package_json_names,
    requirement_names,
    scan_repository,
    technology_index,
    workflow_node_types,
    write_reports,
)


def registry() -> dict:
    return {
        "technologies": [
            {
                "name": "fastapi",
                "aliases": ["FastAPI"],
                "classification": APPROVED,
                "reason": "MIT",
                "adr_required": False,
            },
            {
                "name": "n8n-nodes-base.webhook",
                "aliases": [],
                "classification": REVIEW,
                "reason": "Fair-code",
                "adr_required": True,
            },
            {
                "name": "commercial-sdk",
                "aliases": [],
                "classification": PROHIBITED,
                "reason": "Pago obligatorio",
                "adr_required": True,
            },
        ]
    }


def write_registry(root: Path) -> Path:
    path = root / "config/policies/POL-001-technology-registry.json"
    path.parent.mkdir(parents=True)
    path.write_text(json.dumps(registry()), encoding="utf-8")
    return path


def test_normalize_name() -> None:
    assert normalize_name("n8n-nodes-base.webhook") == "n8nnodesbasewebhook"


def test_technology_index_includes_aliases() -> None:
    index = technology_index(registry())
    assert "fastapi" in index


def test_approved_classification() -> None:
    assert classify("FastAPI", registry())[0] == APPROVED


def test_unknown_requires_review() -> None:
    assert classify("unknown", registry())[0] == REVIEW


def test_requirements_parser(tmp_path: Path) -> None:
    path = tmp_path / "requirements.txt"
    path.write_text("fastapi==1.0\n# comment\npytest>=8\n", encoding="utf-8")
    assert requirement_names(path) == ["fastapi", "pytest"]


def test_package_json_parser(tmp_path: Path) -> None:
    path = tmp_path / "package.json"
    path.write_text(
        json.dumps({"dependencies": {"axios": "1"}, "devDependencies": {"vitest": "1"}}),
        encoding="utf-8",
    )
    assert package_json_names(path) == ["axios", "vitest"]


def test_compose_parser(tmp_path: Path) -> None:
    path = tmp_path / "docker-compose.yml"
    path.write_text("services:\n  db:\n    image: postgres:16\n", encoding="utf-8")
    assert compose_images(path) == ["postgres:16"]


def test_workflow_nodes_parser(tmp_path: Path) -> None:
    path = tmp_path / "workflow.json"
    path.write_text(
        json.dumps({"nodes": [{"type": "n8n-nodes-base.webhook"}]}),
        encoding="utf-8",
    )
    assert workflow_node_types(path) == ["n8n-nodes-base.webhook"]


def test_scan_blocks_prohibited_dependency(tmp_path: Path) -> None:
    registry_path = write_registry(tmp_path)
    (tmp_path / "requirements.txt").write_text(
        "commercial-sdk==1.0\n", encoding="utf-8"
    )
    report = scan_repository(tmp_path, registry_path)
    assert report["counts"][PROHIBITED] == 1
    assert not report["approved"]


def test_approved_adr_exception(tmp_path: Path) -> None:
    registry_path = write_registry(tmp_path)
    (tmp_path / "requirements.txt").write_text(
        "commercial-sdk==1.0\n", encoding="utf-8"
    )
    adr = tmp_path / "docs/03_ADR"
    adr.mkdir(parents=True)
    (adr / "ADR-999.md").write_text(
        "Estado: Aprobado\nTecnología: commercial-sdk\n",
        encoding="utf-8",
    )
    report = scan_repository(tmp_path, registry_path)
    assert report["counts"][PROHIBITED] == 0
    assert report["approved"]


def test_project_dependencies_are_registered() -> None:
    production_registry = {
        "technologies": [
            {"name": "uvicorn", "aliases": ["uvicorn[standard]"]},
            {"name": "pydantic", "aliases": []},
            {"name": "httpx", "aliases": []},
            {"name": "openpyxl", "aliases": []},
        ]
    }
    index = technology_index(production_registry)
    assert normalize_name("uvicorn") in index
    assert normalize_name("uvicorn[standard]") in index
    assert normalize_name("pydantic") in index
    assert normalize_name("httpx") in index
    assert normalize_name("openpyxl") in index


def test_reports_are_written(tmp_path: Path) -> None:
    report = {
        "counts": {APPROVED: 1, REVIEW: 0, PROHIBITED: 0},
        "approved": True,
        "findings": [
            {
                "source": "requirements.txt",
                "technology": "fastapi",
                "classification": APPROVED,
                "reason": "MIT",
            }
        ],
    }
    write_reports(report, tmp_path / "artifacts")
    assert (tmp_path / "artifacts/institutional-compliance.json").is_file()
    assert (tmp_path / "artifacts/institutional-compliance.md").is_file()
