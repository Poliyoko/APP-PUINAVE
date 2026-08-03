from __future__ import annotations

import json
from pathlib import Path

from sgoda.dictionary_manager import (
    DictionaryCommand,
    InstitutionalDictionaryManager,
)


def _entry() -> dict:
    return {
        "entry_id": "LEX-001",
        "puinave": "AMDA",
        "spanish": "casa",
        "english_us": "house",
        "italian": "casa",
        "grammatical_category": "sustantivo",
        "lexical_family": "vivienda",
        "dialectal_variants": ["amda"],
        "synonyms": ["hogar"],
        "antonyms": [],
        "examples": [
            {
                "language": "pu",
                "text": "AMDA",
                "translation": "casa",
            }
        ],
        "validated": True,
    }


def test_SPT_013B_creates_entry() -> None:
    manager = InstitutionalDictionaryManager()
    result = manager.execute(
        DictionaryCommand(
            operation="create",
            payload=_entry(),
        )
    )

    assert result.status == "ok"
    assert result.data["entry_id"] == "LEX-001"


def test_SPT_013B_rejects_invalid_id() -> None:
    manager = InstitutionalDictionaryManager()
    payload = _entry()
    payload["entry_id"] = "BAD"

    result = manager.execute(
        DictionaryCommand(
            operation="create",
            payload=payload,
        )
    )

    assert result.status == "invalid_entry"


def test_SPT_013B_requires_puinave() -> None:
    manager = InstitutionalDictionaryManager()
    payload = _entry()
    payload["puinave"] = ""

    result = manager.execute(
        DictionaryCommand(
            operation="create",
            payload=payload,
        )
    )

    assert result.status == "invalid_entry"


def test_SPT_013B_requires_spanish() -> None:
    manager = InstitutionalDictionaryManager()
    payload = _entry()
    payload["spanish"] = ""

    result = manager.execute(
        DictionaryCommand(
            operation="create",
            payload=payload,
        )
    )

    assert result.status == "invalid_entry"


def test_SPT_013B_rejects_duplicate() -> None:
    manager = InstitutionalDictionaryManager()
    command = DictionaryCommand(
        operation="create",
        payload=_entry(),
    )
    manager.execute(command)

    result = manager.execute(command)

    assert result.status == "duplicate"


def test_SPT_013B_gets_entry() -> None:
    manager = InstitutionalDictionaryManager()
    manager.execute(
        DictionaryCommand(
            operation="create",
            payload=_entry(),
        )
    )

    result = manager.execute(
        DictionaryCommand(
            operation="get",
            payload={"entry_id": "LEX-001"},
        )
    )

    assert result.status == "ok"
    assert result.data["puinave"] == "AMDA"


def test_SPT_013B_searches_spanish() -> None:
    manager = InstitutionalDictionaryManager()
    manager.execute(
        DictionaryCommand(
            operation="create",
            payload=_entry(),
        )
    )

    result = manager.execute(
        DictionaryCommand(
            operation="search",
            payload={"query": "casa"},
        )
    )

    assert result.data["total"] == 1


def test_SPT_013B_searches_english() -> None:
    manager = InstitutionalDictionaryManager()
    manager.execute(
        DictionaryCommand(
            operation="create",
            payload=_entry(),
        )
    )

    result = manager.execute(
        DictionaryCommand(
            operation="search",
            payload={"query": "house"},
        )
    )

    assert result.data["total"] == 1


def test_SPT_013B_preserves_variants() -> None:
    manager = InstitutionalDictionaryManager()
    result = manager.execute(
        DictionaryCommand(
            operation="create",
            payload=_entry(),
        )
    )

    assert result.data["dialectal_variants"] == ["amda"]


def test_SPT_013B_preserves_examples() -> None:
    manager = InstitutionalDictionaryManager()
    result = manager.execute(
        DictionaryCommand(
            operation="create",
            payload=_entry(),
        )
    )

    assert len(result.data["examples"]) == 1


def test_SPT_013B_reports_stats() -> None:
    manager = InstitutionalDictionaryManager()
    manager.execute(
        DictionaryCommand(
            operation="create",
            payload=_entry(),
        )
    )

    result = manager.execute(
        DictionaryCommand(operation="stats")
    )

    assert result.data["total"] == 1
    assert result.data["validated"] == 1


def test_SPT_013B_imports_json(tmp_path: Path) -> None:
    source = tmp_path / "dictionary.json"
    source.write_text(
        json.dumps({"entries": [_entry()]}),
        encoding="utf-8",
    )

    manager = InstitutionalDictionaryManager()
    result = manager.execute(
        DictionaryCommand(
            operation="import_json",
            payload={"path": str(source)},
        )
    )

    assert result.status == "ok"
    assert result.data["imported"] == 1


def test_SPT_013B_exports_json(tmp_path: Path) -> None:
    manager = InstitutionalDictionaryManager()
    manager.execute(
        DictionaryCommand(
            operation="create",
            payload=_entry(),
        )
    )

    target = tmp_path / "export.json"
    result = manager.execute(
        DictionaryCommand(
            operation="export_json",
            payload={"path": str(target)},
        )
    )

    assert result.status == "ok"
    assert target.exists()


def test_SPT_013B_upserts_entry() -> None:
    manager = InstitutionalDictionaryManager()
    manager.execute(
        DictionaryCommand(
            operation="create",
            payload=_entry(),
        )
    )
    payload = _entry()
    payload["spanish"] = "hogar"

    result = manager.execute(
        DictionaryCommand(
            operation="upsert",
            payload=payload,
        )
    )

    assert result.data["spanish"] == "hogar"


def test_SPT_013B_preserves_no_invention() -> None:
    manager = InstitutionalDictionaryManager()
    result = manager.execute(
        DictionaryCommand(operation="list")
    )

    assert result.no_invention is True


def test_SPT_013B_rejects_unknown_operation() -> None:
    manager = InstitutionalDictionaryManager()
    result = manager.execute(
        DictionaryCommand(operation="unknown")
    )

    assert result.status == "unsupported_operation"