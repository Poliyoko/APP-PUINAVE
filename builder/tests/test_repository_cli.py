import json

from sgoda.cli.main import main


def test_repository_cli_lifecycle(tmp_path, capsys) -> None:
    workspace = str(tmp_path)
    assert main([
        "repo", "add", "official", "https://repo.example.org",
        "--workspace", workspace, "--trusted", "--priority", "200",
        "--format", "json",
    ]) == 0
    payload = json.loads(capsys.readouterr().out)
    assert payload["name"] == "official"
    assert payload["trusted"] is True

    assert main(["repo", "disable", "official", "--workspace", workspace]) == 0
    capsys.readouterr()

    assert main([
        "repo", "list", "--workspace", workspace, "--format", "json"
    ]) == 0
    listed = json.loads(capsys.readouterr().out)
    assert listed[0]["enabled"] is False

    assert main(["repo", "enable", "official", "--workspace", workspace]) == 0
    capsys.readouterr()
    assert main(["repo", "info", "official", "--workspace", workspace, "--format", "json"]) == 0
    assert json.loads(capsys.readouterr().out)["enabled"] is True

    assert main(["repo", "remove", "official", "--workspace", workspace]) == 0
