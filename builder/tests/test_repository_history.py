from sgoda.cli.main import main
from sgoda.operations import HistoryStore


def test_repository_actions_are_recorded(tmp_path, capsys) -> None:
    workspace = str(tmp_path)
    assert main(["init", workspace, "--project-name", "repo-history"]) == 0
    capsys.readouterr()
    assert main(["repo", "add", "official", "https://repo.example.org", "--workspace", workspace]) == 0
    capsys.readouterr()
    assert main(["repo", "disable", "official", "--workspace", workspace]) == 0
    capsys.readouterr()
    events = HistoryStore(tmp_path).query(limit=10)
    types = {event.event_type for event in events}
    assert "repository_added" in types
    assert "repository_disabled" in types
