from sgoda.core import BuilderConfig, ProjectBuilder


def test_validate_detects_missing_resources(tmp_path):
    valid, missing = ProjectBuilder(BuilderConfig.from_path(tmp_path)).validate()
    assert valid is False
    assert missing


def test_initialize_creates_valid_project(tmp_path):
    builder = ProjectBuilder(BuilderConfig.from_path(tmp_path))
    builder.initialize(project_name="Proyecto Prueba")
    valid, missing = builder.validate()
    assert valid is True
    assert missing == []
