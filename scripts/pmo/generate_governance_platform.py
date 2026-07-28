"""Genera las vistas del PMO Digital desde el modelo único de datos."""

from __future__ import annotations

import argparse
from pathlib import Path

from sgoda.pmo.generators import dashboard_html, dashboard_markdown, deliverable_catalog_markdown, dmp_markdown, executive_report_markdown, technical_document_markdown
from sgoda.pmo.governance import validate_project_model
from sgoda.pmo.repository import load_project_model


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8", newline="\n")


def generate(model_path: Path, output_root: Path) -> list[Path]:
    model = load_project_model(model_path)
    validate_project_model(model)
    files = {
        output_root / "docs/Dashboard/Dashboard_Ejecutivo.md": dashboard_markdown(model),
        output_root / "docs/Dashboard/dashboard_ejecutivo.html": dashboard_html(model),
        output_root / "docs/00_DMP/DMP_v2.0.md": dmp_markdown(model),
        output_root / "docs/Reportes/Informe_Ejecutivo_Direccion.md": executive_report_markdown(model),
        output_root / "docs/01_PMO/Documento_Tecnico_PMO_Digital.md": technical_document_markdown(model),
        output_root / "docs/08_Entregables/Catalogo_Ejecutivo_Entregables.md": deliverable_catalog_markdown(model),
    }
    for path, content in files.items():
        write(path, content)
    return list(files)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", default="knowledge/project_model.json")
    parser.add_argument("--output", default=".")
    args = parser.parse_args()
    generated = generate(Path(args.model), Path(args.output))
    for path in generated:
        print(path)


if __name__ == "__main__":
    main()
