from sgoda.extensions import CatalogEntry, CatalogSnapshot, CatalogStore


def test_catalog_store_roundtrip(tmp_path) -> None:
    store = CatalogStore(tmp_path)
    snapshot = CatalogSnapshot(
        schema_version="1.0",
        indexed_at="2026-07-16T00:00:00+00:00",
        entries=(
            CatalogEntry(
                type="plugin",
                name="alpha",
                version="1.0.0",
                description="A",
                builder_requires=">=1.12.0",
                enabled=True,
                status="compatible",
                location="/tmp/alpha",
                indexed_at="2026-07-16T00:00:00+00:00",
            ),
        ),
    )
    store.save(snapshot)
    loaded = store.load()
    assert loaded.entries[0].name == "alpha"
    assert loaded.statistics()["plugins"] == 1
