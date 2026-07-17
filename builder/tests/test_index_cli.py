import json

from sgoda.cli.main import main
from sgoda.repositories import (
    IndexPackage,
    IndexStore,
    RepositoryIndex,
    SyncMetadata,
)


def seed(workspace):
    IndexStore(workspace).save(
        "official",
        RepositoryIndex(
            "1.0",
            "official",
            "2026-07-17T12:00:00+00:00",
            (IndexPackage("demo", "plugin", "1.0.0", "https://repo.example.org/demo", "a" * 64),),
        ),
        SyncMetadata(
            "official",
            "https://repo.example.org/index.json",
            "2026-07-17T12:01:00+00:00",
            "updated",
            "b" * 64,
            1,
        ),
    )


def test_index_cli_list_info_verify(tmp_path, capsys) -> None:
    seed(tmp_path)
    workspace = str(tmp_path)

    assert main(["index", "list", "--workspace", workspace, "--format", "json"]) == 0
    assert json.loads(capsys.readouterr().out)[0]["repository"] == "official"

    assert main(["index", "info", "official", "--workspace", workspace, "--format", "json"]) == 0
    assert json.loads(capsys.readouterr().out)["index"]["repository"] == "official"

    assert main(["index", "verify", "official", "--workspace", workspace, "--format", "json"]) == 0
    assert json.loads(capsys.readouterr().out)["valid"] is True
