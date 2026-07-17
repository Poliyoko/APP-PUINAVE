from sgoda.repositories import (
    IndexPackage,
    IndexStore,
    RepositoryIndex,
    SyncMetadata,
)


def make_index(version: str) -> RepositoryIndex:
    return RepositoryIndex(
        "1.0",
        "official",
        "2026-07-17T12:00:00+00:00",
        (IndexPackage("demo", "plugin", version, "https://repo.example.org/demo", "a" * 64),),
    )


def make_metadata(digest: str) -> SyncMetadata:
    return SyncMetadata(
        "official",
        "https://repo.example.org/index.json",
        "2026-07-17T12:00:00+00:00",
        "updated",
        digest,
        1,
    )


def test_index_store_persists_and_backs_up(tmp_path) -> None:
    store = IndexStore(tmp_path)
    store.save("official", make_index("1.0.0"), make_metadata("a" * 64))
    store.save("official", make_index("1.1.0"), make_metadata("b" * 64))
    assert store.load_index("official").packages[0].version == "1.1.0"
    assert store.list_cached() == ("official",)
    assert list(store.previous_directory("official").glob("index-*.json"))
