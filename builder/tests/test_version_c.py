from sgoda.cli.main import main


def test_version(capsys) -> None:
    assert main(["version"]) == 0
    assert "0.6.0" in capsys.readouterr().out
