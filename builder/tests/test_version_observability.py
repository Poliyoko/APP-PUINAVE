from sgoda.cli.main import main


def test_version(capsys) -> None:
    assert main(["version"]) == 0
    assert "1.4.0" in capsys.readouterr().out
