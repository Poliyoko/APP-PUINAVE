from sgoda.repositories import SyncClient


def test_sync_client_builds_index_url() -> None:
    assert SyncClient.index_url("https://repo.example.org") == "https://repo.example.org/index.json"
    assert SyncClient.index_url("https://repo.example.org/index.json") == "https://repo.example.org/index.json"
