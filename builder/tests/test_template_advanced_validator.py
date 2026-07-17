import json
from pathlib import Path

import pytest

from sgoda.extensions import TemplateValidationError, TemplateValidator


def make_template(root: Path, *, undeclared: bool = False) -> Path:
    source = root / "template-source"
    render = source / "template"
    render.mkdir(parents=True)
    variable = "missing" if undeclared else "project_name"
    (render / "README.md").write_text(
        f"# {{{{ {variable} }}}}\n",
        encoding="utf-8",
    )
    (source / "sgoda.template.json").write_text(
        json.dumps({
            "schema_version": "1.0",
            "type": "template",
            "name": "advanced-template",
            "version": "1.0.0",
            "builder_requires": ">=1.8.0,<2.0.0",
            "description": "Plantilla avanzada",
            "render_root": "template",
            "variables": {
                "project_name": {
                    "required": True,
                    "description": "Nombre del proyecto",
                }
            },
            "files": ["template/README.md"],
            "dependencies": {},
        }),
        encoding="utf-8",
    )
    return source


def test_advanced_template_metadata(tmp_path) -> None:
    metadata = TemplateValidator().validate(make_template(tmp_path))
    assert metadata.name == "advanced-template"
    assert metadata.render_root == "template"
    assert metadata.variables[0].name == "project_name"
    assert metadata.variables[0].required is True


def test_undeclared_placeholder_is_rejected(tmp_path) -> None:
    with pytest.raises(TemplateValidationError):
        TemplateValidator().validate(
            make_template(tmp_path, undeclared=True)
        )
