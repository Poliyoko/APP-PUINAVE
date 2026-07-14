"""Pruebas del generador de componentes."""
from sgoda.cli.main import main
from sgoda.core import BuilderConfig, ProjectBuilder
from sgoda.generators import ComponentGenerator

def initialize_project(tmp_path):
    ProjectBuilder(BuilderConfig.from_path(tmp_path)).initialize(project_name="SGODA Prueba")

def test_backend_generator_creates_expected_files(tmp_path):
    initialize_project(tmp_path)
    result = ComponentGenerator(tmp_path).generate("backend")
    assert result.written_files
    assert (tmp_path/"backend"/"pyproject.toml").is_file()
    assert (tmp_path/"backend"/"src"/"app"/"main.py").is_file()

def test_backend_generator_preserves_existing_file(tmp_path):
    initialize_project(tmp_path)
    readme = tmp_path/"backend"/"README.md"
    readme.write_text("contenido local",encoding="utf-8")
    result = ComponentGenerator(tmp_path).generate("backend")
    assert readme.read_text(encoding="utf-8") == "contenido local"
    assert readme in result.preserved_files

def test_generate_command_rejects_non_sgoda_project(tmp_path, capsys):
    code = main(["generate","backend",str(tmp_path)])
    assert code == 1
    assert "Proyecto SGODA inválido" in capsys.readouterr().out

def test_generate_backend_command(tmp_path):
    initialize_project(tmp_path)
    assert main(["generate","backend",str(tmp_path)]) == 0
