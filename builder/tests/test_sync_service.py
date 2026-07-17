import json

from sgoda.repositories import (
    RepositoryService,
    SyncResponse,
    SyncService,
)


class FakeClient:
    def __init__(self, responses):
        self.responses = iter(responses)
        self.calls = []

    def fetch(self, url, *, etag=None, last_modified=None):
        self.calls.append((url, etag, last_modified))
        return next(self.responses)


def index_content(version="1.0.0"):
    return json.dumps({
        "schema_version": "1.0",
        "repository": "official",
        "generated_at": "2026-07-17T12:00:00+00:00",
        "packages": [{
            "name": "demo",
            "type": "plugin",
            "version": version,
            "download_url": "https://repo.example.org/demo.sgoda",
            "sha256": "a" * 64,
            "description": "Demo",
        }],
    })


def test_sync_updates_then_uses_conditional_request(tmp_path) -> None:
    RepositoryService(tmp_path).add("official", "https://repo.example.org")
    client = FakeClient([
        SyncResponse(200, index_content(), "https://repo.example.org/index.json", '"v1"', "Thu, 17 Jul 2026 12:00:00 GMT"),
        SyncResponse(304, None, "https://repo.example.org/index.json", '"v1"', "Thu, 17 Jul 2026 12:00:00 GMT"),
    ])
    service = SyncService(tmp_path, client=client)
    first = service.sync("official")
    second = service.sync("official")
    assert first.changed is True
    assert second.changed is False
    assert client.calls[1][1] == '"v1"'


def test_invalid_remote_index_keeps_previous_cache(tmp_path) -> None:
    RepositoryService(tmp_path).add("official", "https://repo.example.org")
    client = FakeClient([
        SyncResponse(200, index_content(), "https://repo.example.org/index.json"),
        SyncResponse(200, '{"bad": true}', "https://repo.example.org/index.json"),
    ])
    service = SyncService(tmp_path, client=client)
    service.sync("official")
    before = service.store.index_path("official").read_text(encoding="utf-8")
    try:
        service.sync("official", force=True)
    except Exception:
        pass
    after = service.store.index_path("official").read_text(encoding="utf-8")
    assert after == before
