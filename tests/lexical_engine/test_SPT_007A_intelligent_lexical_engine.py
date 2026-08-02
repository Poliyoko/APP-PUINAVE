import json
from pathlib import Path

from sgoda.lexical_engine import (
    IntelligentLexicalService,
    LexicalRepository,
    SearchQuery,
    normalize_text,
    playback_manifest,
)
from sgoda.lexical_engine.search import LexicalSearchEngine


def _repository() -> LexicalRepository:
    return LexicalRepository.from_records(
        [
            {
                "id": "LEX-001",
                "puinave": "AMDA",
                "spanish": "casa",
                "english_us": "house",
                "italian": "casa",
                "validated": True,
                "category": "sustantivo",
                "multimedia": [
                    {
                        "type": "audio",
                        "language": "es",
                        "path": "media/audio/es/LEX-001.wav",
                        "validated": True,
                        "autoplay": True,
                    },
                    {
                        "type": "image",
                        "path": "media/images/LEX-001.webp",
                        "validated": True,
                    },
                ],
            },
            {
                "id": "LEX-002",
                "puinave": "DAPA",
                "spanish": "agua",
                "english_us": "water",
                "italian": "acqua",
                "validated": False,
                "category": "sustantivo",
            },
        ]
    )


def test_SPT_007A_normalizes_unicode_and_case() -> None:
    assert normalize_text("  CÁSÁ  ") == "cásá"


def test_SPT_007A_exact_search() -> None:
    engine = LexicalSearchEngine(_repository())
    result = engine.search(SearchQuery("AMDA"))

    assert result.total == 1
    assert result.hits[0].entry.entry_id == "LEX-001"
    assert result.hits[0].match_type == "exact"
    assert result.hits[0].matched_language == "pu"


def test_SPT_007A_multilingual_search() -> None:
    service = IntelligentLexicalService(_repository())
    result = service.search("house")

    assert result["total"] == 1
    assert result["results"][0]["puinave"] == "AMDA"
    assert result["results"][0]["english_us"] == "house"


def test_SPT_007A_prefix_search() -> None:
    engine = LexicalSearchEngine(_repository())
    result = engine.search(SearchQuery("wat"))

    assert result.hits[0].entry.entry_id == "LEX-002"
    assert result.hits[0].match_type == "prefix"


def test_SPT_007A_fuzzy_search() -> None:
    engine = LexicalSearchEngine(
        _repository(),
        fuzzy_threshold=0.60,
    )
    result = engine.search(SearchQuery("hous"))

    assert result.hits[0].entry.entry_id == "LEX-001"


def test_SPT_007A_can_filter_unvalidated() -> None:
    engine = LexicalSearchEngine(_repository())
    result = engine.search(
        SearchQuery(
            "agua",
            include_unvalidated=False,
        )
    )

    assert result.total == 0


def test_SPT_007A_ranking_is_deterministic() -> None:
    engine = LexicalSearchEngine(_repository())
    first = engine.search(SearchQuery("casa"))
    second = engine.search(SearchQuery("casa"))

    assert first.hits == second.hits
    assert first.hits[0].entry.entry_id == "LEX-001"


def test_SPT_007A_multimedia_manifest() -> None:
    entry = _repository().all()[0]
    manifest = playback_manifest(entry)

    assert manifest["entry_id"] == "LEX-001"
    assert manifest["autoplay_audio"][0]["language"] == "es"
    assert manifest["images"][0]["validated"] is True


def test_SPT_007A_reads_json_rlb(tmp_path: Path) -> None:
    path = tmp_path / "words.json"
    path.write_text(
        json.dumps(
            {
                "entries": [
                    {
                        "id": "LEX-003",
                        "puinave": "KADA",
                        "spanish": "sol",
                        "english": "sun",
                        "italian": "sole",
                    }
                ]
            }
        ),
        encoding="utf-8",
    )

    repository = LexicalRepository.from_json(path)

    assert len(repository) == 1
    assert repository.all()[0].english_us == "sun"


def test_SPT_007A_no_invention_contract() -> None:
    service = IntelligentLexicalService(_repository())
    result = service.search("palabra inexistente")

    assert result["total"] == 0
    assert result["no_invention"] is True
    assert result["results"] == []