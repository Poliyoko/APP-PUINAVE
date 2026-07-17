import json
from pathlib import Path

import pytest

from sgoda.extensions import (
    ExtensionValidationError,
    load_manifest,
    requirement_satisfied,
    validate_relative_path,
)


def make_plugin(tmp_path: Path, **overrides) -> Path:
    payload = {
        "schema_version": "1.0",
        "type": "plugin",
        "name": "plugin-ejemplo",
        "version": "1.11.0",
        "builder_requires": ">=1.2.0",
        "entry_point": "plugin:register",
    }
    payload.update(overrides)
    path = tmp_path / "sgoda.plugin.json"
    path.write_text(json.dumps(payload), encoding="utf-8")
    return tmp_path


def test_valid_plugin_manifest(tmp_path) -> None:
    manifest = load_manifest(make_plugin(tmp_path))
    assert manifest.name == "plugin-ejemplo"
    assert manifest.type == "plugin"


@pytest.mark.parametrize("value", ["../file", r"..\file", "/tmp/file", r"C:\file"])
def test_unsafe_paths_are_rejected(value) -> None:
    with pytest.raises(ExtensionValidationError):
        validate_relative_path(value)


def test_incompatible_builder_is_rejected(tmp_path) -> None:
    with pytest.raises(ExtensionValidationError):
        load_manifest(make_plugin(tmp_path, builder_requires=">=9.0.0"))


def test_requirement_comparison() -> None:
    assert requirement_satisfied(">=1.2.0", "1.11.0")
    assert not requirement_satisfied(">=2.0.0", "1.11.0")
