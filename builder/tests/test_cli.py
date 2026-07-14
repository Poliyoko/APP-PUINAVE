from sgoda.cli.main import main

def test_version(capsys):
    assert main(["version"])==0
    assert "0.2.0" in capsys.readouterr().out

def test_init_validate(tmp_path):
    assert main(["validate", str(tmp_path)])==1
    assert main(["init", str(tmp_path)])==0
    assert main(["validate", str(tmp_path)])==0
