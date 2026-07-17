from sgoda.cli.main import main


def test_version_repositories(capsys) -> None:
    assert main(["version"]) == 0
    assert "1.12.0" in capsys.readouterr().out
