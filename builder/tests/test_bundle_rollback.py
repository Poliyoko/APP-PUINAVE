from sgoda.extensions import (
    BundleExecutor,
    BundleItem,
    ExtensionBundle,
    ExtensionManager,
)


def test_transaction_rolls_back_on_missing_source(tmp_path) -> None:
    workspace = tmp_path / "project"
    bundle = ExtensionBundle(
        schema_version="1.0",
        name="broken",
        description="",
        created_at="x",
        updated_at="x",
        items=(
            BundleItem(
                type="plugin",
                name="missing",
                version="1.0.0",
                source=str(tmp_path / "does-not-exist"),
            ),
        ),
    )
    result = BundleExecutor(workspace).execute(bundle, "install")
    assert result.status == "ROLLED_BACK"
    assert result.rolled_back is True
    assert ExtensionManager(workspace).registry.get("plugin:missing") is None
