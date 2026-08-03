from __future__ import annotations

import json
from pathlib import Path

from sgoda.multimedia_engine import (
    IntelligentMultimediaEngine,
    MultimediaCommand,
)


def _resource(
    resource_id: str = "MED-001",
    media_type: str = "image",
    language: str = "und",
    uri: str = "media/images/LEX-001.webp",
    media_format: str = "webp",
    validated: bool = True,
) -> dict:
    return {
        "resource_id": resource_id,
        "entry_id": "LEX-001",
        "media_type": media_type,
        "language": language,
        "uri": uri,
        "format": media_format,
        "validated": validated,
    }


def test_SPT_014_registers_resource() -> None:
    engine = IntelligentMultimediaEngine()
    result = engine.execute(
        MultimediaCommand(
            operation="register",
            payload=_resource(),
        )
    )

    assert result.status == "ok"
    assert result.data["resource_id"] == "MED-001"


def test_SPT_014_rejects_invalid_resource_id() -> None:
    engine = IntelligentMultimediaEngine()
    payload = _resource()
    payload["resource_id"] = "BAD"

    result = engine.execute(
        MultimediaCommand(
            operation="register",
            payload=payload,
        )
    )

    assert result.status == "invalid_resource"


def test_SPT_014_rejects_invalid_entry_id() -> None:
    engine = IntelligentMultimediaEngine()
    payload = _resource()
    payload["entry_id"] = "BAD"

    result = engine.execute(
        MultimediaCommand(
            operation="register",
            payload=payload,
        )
    )

    assert result.status == "invalid_resource"


def test_SPT_014_rejects_invalid_format() -> None:
    engine = IntelligentMultimediaEngine()
    payload = _resource()
    payload["format"] = "exe"

    result = engine.execute(
        MultimediaCommand(
            operation="register",
            payload=payload,
        )
    )

    assert result.status == "invalid_resource"


def test_SPT_014_rejects_absolute_uri() -> None:
    engine = IntelligentMultimediaEngine()
    payload = _resource()
    payload["uri"] = "/root/private/file.webp"

    result = engine.execute(
        MultimediaCommand(
            operation="register",
            payload=payload,
        )
    )

    assert result.status == "invalid_resource"


def test_SPT_014_detects_duplicate_id() -> None:
    engine = IntelligentMultimediaEngine()
    command = MultimediaCommand(
        operation="register",
        payload=_resource(),
    )
    engine.execute(command)

    result = engine.execute(command)

    assert result.status == "duplicate_id"


def test_SPT_014_gets_resource() -> None:
    engine = IntelligentMultimediaEngine()
    engine.execute(
        MultimediaCommand(
            operation="register",
            payload=_resource(),
        )
    )

    result = engine.execute(
        MultimediaCommand(
            operation="get",
            payload={"resource_id": "MED-001"},
        )
    )

    assert result.status == "ok"


def test_SPT_014_lists_resources_for_entry() -> None:
    engine = IntelligentMultimediaEngine()
    engine.execute(
        MultimediaCommand(
            operation="register",
            payload=_resource(),
        )
    )

    result = engine.execute(
        MultimediaCommand(
            operation="for_entry",
            payload={"entry_id": "LEX-001"},
        )
    )

    assert result.data["total"] == 1


def test_SPT_014_filters_validated_resources() -> None:
    engine = IntelligentMultimediaEngine()
    engine.execute(
        MultimediaCommand(
            operation="register",
            payload=_resource(validated=False),
        )
    )

    result = engine.execute(
        MultimediaCommand(
            operation="for_entry",
            payload={
                "entry_id": "LEX-001",
                "validated_only": True,
            },
        )
    )

    assert result.data["total"] == 0


def test_SPT_014_builds_incomplete_oda() -> None:
    engine = IntelligentMultimediaEngine()
    engine.execute(
        MultimediaCommand(
            operation="register",
            payload=_resource(),
        )
    )

    result = engine.execute(
        MultimediaCommand(
            operation="build_oda",
            payload={"entry_id": "LEX-001"},
        )
    )

    assert result.status == "ok"
    assert result.data["complete"] is False
    assert "audio_puinave" in result.data["missing_types"]


def test_SPT_014_builds_complete_oda() -> None:
    engine = IntelligentMultimediaEngine()
    resources = [
        _resource(),
        _resource(
            "MED-002",
            "audio_puinave",
            "pu",
            "media/audio/LEX-001-pu.wav",
            "wav",
        ),
        _resource(
            "MED-003",
            "audio_spanish",
            "es",
            "media/audio/LEX-001-es.wav",
            "wav",
        ),
        _resource(
            "MED-004",
            "audio_english_us",
            "en-US",
            "media/audio/LEX-001-en.wav",
            "wav",
        ),
    ]

    for item in resources:
        engine.execute(
            MultimediaCommand(
                operation="register",
                payload=item,
            )
        )

    result = engine.execute(
        MultimediaCommand(
            operation="build_oda",
            payload={"entry_id": "LEX-001"},
        )
    )

    assert result.data["complete"] is True
    assert result.data["missing_types"] == []


def test_SPT_014_imports_manifest(tmp_path: Path) -> None:
    path = tmp_path / "manifest.json"
    path.write_text(
        json.dumps({"resources": [_resource()]}),
        encoding="utf-8",
    )

    engine = IntelligentMultimediaEngine()
    result = engine.execute(
        MultimediaCommand(
            operation="import_manifest",
            payload={"path": str(path)},
        )
    )

    assert result.data["imported"] == 1


def test_SPT_014_exports_manifest(tmp_path: Path) -> None:
    engine = IntelligentMultimediaEngine()
    engine.execute(
        MultimediaCommand(
            operation="register",
            payload=_resource(),
        )
    )
    target = tmp_path / "export.json"

    result = engine.execute(
        MultimediaCommand(
            operation="export_manifest",
            payload={"path": str(target)},
        )
    )

    assert result.status == "ok"
    assert target.exists()


def test_SPT_014_audit_passes_clean_repository() -> None:
    engine = IntelligentMultimediaEngine()
    engine.execute(
        MultimediaCommand(
            operation="register",
            payload=_resource(),
        )
    )

    result = engine.execute(
        MultimediaCommand(operation="audit")
    )

    assert result.status == "ok"
    assert result.data["approved"] is True


def test_SPT_014_reports_stats() -> None:
    engine = IntelligentMultimediaEngine()
    engine.execute(
        MultimediaCommand(
            operation="register",
            payload=_resource(),
        )
    )

    result = engine.execute(
        MultimediaCommand(operation="stats")
    )

    assert result.data["total"] == 1
    assert result.data["images"] == 1


def test_SPT_014_preserves_no_invention() -> None:
    result = IntelligentMultimediaEngine().execute(
        MultimediaCommand(operation="stats")
    )

    assert result.no_invention is True


def test_SPT_014_rejects_unknown_operation() -> None:
    result = IntelligentMultimediaEngine().execute(
        MultimediaCommand(operation="unknown")
    )

    assert result.status == "unsupported_operation"


def test_SPT_014_is_deterministic() -> None:
    engine = IntelligentMultimediaEngine()
    request = MultimediaCommand(operation="stats")

    assert engine.execute(request) == engine.execute(request)