from sgoda.cli.main import main


def test_version_bundles(capsys) -> None:
    assert main(["version"]) == 0
    assert "1.11.0" in capsys.readouterr().out
