from sgoda.core import BuilderConfig,ProjectBuilder
def test_initialize_creates_valid_project(tmp_path):
    b=ProjectBuilder(BuilderConfig.from_path(tmp_path)); b.initialize(project_name="Prueba"); assert b.validate()[0] is True
