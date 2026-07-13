from sgoda.core import BuilderConfig, ProjectBuilder

def test_initialize(tmp_path):
    b=ProjectBuilder(BuilderConfig.from_path(tmp_path))
    b.initialize()
    assert (tmp_path/"backend").is_dir()
    assert b.validate()==(True, [])
