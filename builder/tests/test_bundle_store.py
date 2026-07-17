from sgoda.extensions import BundleItem, BundleStore, ExtensionBundle


def test_bundle_store_roundtrip(tmp_path) -> None:
    store = BundleStore(tmp_path)
    bundle = ExtensionBundle(
        schema_version="1.0",
        name="base",
        description="Bundle base",
        created_at="2026-07-17T00:00:00+00:00",
        updated_at="2026-07-17T00:00:00+00:00",
        items=(BundleItem("plugin", "alpha", "1.0.0", "/tmp/alpha"),),
    )
    store.save(bundle)
    assert store.load("base").items[0].key == "plugin:alpha"
    assert [item.name for item in store.list()] == ["base"]
