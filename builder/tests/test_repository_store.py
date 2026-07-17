from sgoda.repositories import Repository, RepositoryStore


def test_repository_store_is_persistent_and_sorted(tmp_path) -> None:
    store = RepositoryStore(tmp_path)
    store.save([
        Repository("low", "https://low.example.org", priority=10),
        Repository("high", "https://high.example.org", priority=200),
    ])
    assert [item.name for item in store.list()] == ["high", "low"]
    assert store.path.is_file()
    assert RepositoryStore(tmp_path).get("high").url == "https://high.example.org"
