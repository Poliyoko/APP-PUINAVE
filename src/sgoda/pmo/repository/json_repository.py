"""Repositorio JSON para la fuente única de datos del PMO."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from sgoda.pmo.domain import Deliverable, Kpi, KpiState, Milestone, PmoStatus, Project, ProjectModel, Risk, RiskLevel


def _status(value: str) -> PmoStatus:
    return PmoStatus(value)


def load_project_model(path: str | Path) -> ProjectModel:
    data: dict[str, Any] = json.loads(Path(path).read_text(encoding="utf-8"))
    project_data = data["project"]
    project = Project(
        identifier=project_data["identifier"],
        name=project_data["name"],
        purpose=project_data.get("purpose", ""),
        status=_status(project_data.get("status", "in_progress")),
        repository_url=project_data.get("repository_url", ""),
        director=project_data.get("director", ""),
        current_hito=project_data.get("current_hito", ""),
        baseline_document=project_data.get("baseline_document", ""),
        metadata={
            "last_known_commit": project_data.get("last_known_commit", ""),
            "last_known_tests": project_data.get("last_known_tests", ""),
        },
    )
    deliverables = tuple(
        Deliverable(
            identifier=item["code"],
            code=item["code"],
            name=item["name"],
            executive_name=item.get("executive_name", item["name"]),
            purpose=item.get("purpose", ""),
            benefit=item.get("benefit", ""),
            status=_status(item.get("status", "planned")),
            progress=float(item.get("progress", 0.0)),
            evidence=item.get("evidence", ""),
            products=tuple(item.get("products", ())),
        )
        for item in data.get("deliverables", [])
    )
    risks = tuple(
        Risk(
            identifier=item["code"],
            code=item["code"],
            name=item["name"],
            level=RiskLevel(item.get("level", "medium")),
            probability=float(item.get("probability", 0.0)),
            impact=float(item.get("impact", 0.0)),
            mitigation=item.get("mitigation", ""),
        )
        for item in data.get("risks", [])
    )
    kpis = tuple(
        Kpi(
            identifier=item["code"],
            code=item["code"],
            name=item["name"],
            value=float(item.get("value", 0.0)),
            target=float(item.get("target", 0.0)),
            unit=item.get("unit", ""),
            state=KpiState(item.get("state", "on_track")),
        )
        for item in data.get("kpis", [])
    )
    milestones = tuple(
        Milestone(
            identifier=item["code"],
            code=item["code"],
            name=item["name"],
            description=item.get("description", ""),
            status=_status(item.get("status", "planned")),
        )
        for item in data.get("milestones", [])
    )
    return ProjectModel(
        schema_version=data.get("schema_version", "1.0.0"),
        project=project,
        deliverables=deliverables,
        risks=risks,
        kpis=kpis,
        milestones=milestones,
    )


def save_project_model(model: ProjectModel, path: str | Path) -> None:
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(model.to_dict(), ensure_ascii=False, indent=2), encoding="utf-8")
