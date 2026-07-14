import json
from sgoda.core import BuilderConfig, ProjectBuilder


def test_initializer_generates_directories_and_files(tmp_path):
    result = ProjectBuilder(BuilderConfig.from_path(tmp_path)).initialize(project_name="Proyecto Prueba")
    assert result.written_files
    assert (tmp_path / "README.md").is_file()
    assert (tmp_path / "sgoda.project.json").is_file()
    assert (tmp_path / "data/json/palabras.json").is_file()
    manifest = json.loads((tmp_path / "sgoda.project.json").read_text(encoding="utf-8"))
    assert manifest["project"]["name"] == "Proyecto Prueba"


def test_initializer_preserves_existing_files_without_force(tmp_path):
    readme = tmp_path / "README.md"
    readme.write_text("contenido existente", encoding="utf-8")
    result = ProjectBuilder(BuilderConfig.from_path(tmp_path)).initialize(project_name="Proyecto Prueba")
    assert readme.read_text(encoding="utf-8") == "contenido existente"
    assert readme in result.preserved_files


def test_initializer_overwrites_existing_files_with_force(tmp_path):
    readme = tmp_path / "README.md"
    readme.write_text("contenido existente", encoding="utf-8")
    ProjectBuilder(BuilderConfig.from_path(tmp_path)).initialize(project_name="Proyecto Prueba", force=True)
    assert "# Proyecto Prueba" in readme.read_text(encoding="utf-8")
