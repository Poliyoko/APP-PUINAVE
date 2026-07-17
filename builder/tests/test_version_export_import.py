from sgoda.cli.main import main

def test_version_export_import(capsys) -> None:
    assert main(["version"]) == 0
    assert "1.13.0" in capsys.readouterr().out
