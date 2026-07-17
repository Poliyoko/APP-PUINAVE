import json
import zipfile
from pathlib import Path

from sgoda.extensions import ExportService, ExtensionManager


def make_plugin(root: Path) -> Path:
    source = root / "tamper"
    source.mkdir()
    (source / "plugin.py").write_text("x = 1\n", encoding="utf-8")
    (source / "sgoda.plugin.json").write_text(
        json.dumps(
            {
                "schema_version": "1.0",
                "type": "plugin",
                "name": "tamper",
                "version": "1.0.0",
                "builder_requires": ">=1.13.0,<2.0.0",
                "entry_point": "plugin:x",
                "dependencies": {},
            }
        ),
        encoding="utf-8",
    )
    return source


def replace_zip_entry(
    package: Path,
    entry_name: str,
    replacement: bytes,
) -> None:
    temporary = package.with_suffix(".tmp.zip")

    with zipfile.ZipFile(package, "r") as source:
        with zipfile.ZipFile(
            temporary,
            "w",
            compression=zipfile.ZIP_DEFLATED,
        ) as target:
            for item in source.infolist():
                if item.filename == entry_name:
                    continue

                target.writestr(item, source.read(item.filename))

            target.writestr(entry_name, replacement)

    temporary.replace(package)


def test_modified_package_fails_verification(tmp_path) -> None:
    workspace = tmp_path / "workspace"

    ExtensionManager(workspace).install(
        make_plugin(tmp_path),
        expected_type="plugin",
    )

    package = ExportService(workspace).create(
        tmp_path / "tampered",
    )

    replace_zip_entry(
        package,
        "plugins/tamper/plugin.py",
        b"x = 99\n",
    )

    result = ExportService(workspace).verify(package)

    assert result["valid"] is False
    assert any(
        "Checksum inválido" in error
        for error in result["errors"]
    )
