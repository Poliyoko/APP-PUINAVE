from __future__ import annotations

import json
from pathlib import Path

from sgoda.learning_platform import (
    DigitalDictionary,
    LearningPlatformService,
    LearningRequest,
    MediaLibrary,
)


def _dictionary(tmp_path: Path) -> Path:
    path = tmp_path / "dictionary.json"
    path.write_text(
        json.dumps(
            {
                "entries": [
                    {
                        "entry_id": "LEX-001",
                        "puinave": "AMDA",
                        "spanish": "casa",
                        "english_us": "house",
                        "italian": "casa",
                        "category": "sustantivo",
                        "validated": True,
                    },
                    {
                        "entry_id": "LEX-999",
                        "puinave": "NO-VALIDADO",
                        "validated": False,
                    },
                ]
            }
        ),
        encoding="utf-8",
    )
    return path


def _media(tmp_path: Path) -> Path:
    path = tmp_path / "media.json"
    path.write_text(
        json.dumps(
            {
                "resources": [
                    {
                        "entry_id": "LEX-001",
                        "media_type": "image",
                        "uri": "media/images/LEX-001.webp",
                        "validated": True,
                        "autoplay": True,
                    },
                    {
                        "entry_id": "LEX-001",
                        "media_type": "audio_puinave",
                        "uri": "media/audio/LEX-001-pu.wav",
                        "validated": True,
                        "autoplay": True,
                    },
                ]
            }
        ),
        encoding="utf-8",
    )
    return path


def _service(tmp_path: Path) -> LearningPlatformService:
    dictionary = DigitalDictionary()
    dictionary.load(_dictionary(tmp_path))

    media = MediaLibrary()
    media.load(_media(tmp_path))

    return LearningPlatformService(
        dictionary,
        media,
    )


def test_SPT_012_loads_only_validated_dictionary(
    tmp_path: Path,
) -> None:
    dictionary = DigitalDictionary()
    dictionary.load(_dictionary(tmp_path))

    assert len(dictionary.all()) == 1
    assert dictionary.get("LEX-001") is not None


def test_SPT_012_searches_dictionary(
    tmp_path: Path,
) -> None:
    response = _service(tmp_path).execute(
        LearningRequest(
            operation="search_dictionary",
            learner_id="LEARNER-001",
            payload={"query": "casa"},
        )
    )

    assert response.status == "ok"
    assert response.data["total"] == 1


def test_SPT_012_builds_oda(
    tmp_path: Path,
) -> None:
    response = _service(tmp_path).execute(
        LearningRequest(
            operation="get_oda",
            learner_id="LEARNER-001",
            entry_id="LEX-001",
        )
    )

    assert response.status == "ok"
    assert response.data["odaId"] == "ODA-LEX-001"
    assert response.data["noInvention"] is True


def test_SPT_012_oda_contains_media(
    tmp_path: Path,
) -> None:
    response = _service(tmp_path).execute(
        LearningRequest(
            operation="get_oda",
            learner_id="LEARNER-001",
            entry_id="LEX-001",
        )
    )

    assert len(response.data["media"]) == 2


def test_SPT_012_builds_learning_path(
    tmp_path: Path,
) -> None:
    response = _service(tmp_path).execute(
        LearningRequest(
            operation="build_path",
            learner_id="LEARNER-001",
            entry_id="LEX-001",
            payload={"level": "initial"},
        )
    )

    assert response.status == "ok"
    assert len(response.data["steps"]) == 5


def test_SPT_012_evaluates_correct_answer(
    tmp_path: Path,
) -> None:
    response = _service(tmp_path).execute(
        LearningRequest(
            operation="evaluate_answer",
            learner_id="LEARNER-001",
            entry_id="LEX-001",
            payload={"answer": "casa"},
        )
    )

    assert response.data["correct"] is True


def test_SPT_012_evaluates_incorrect_answer(
    tmp_path: Path,
) -> None:
    response = _service(tmp_path).execute(
        LearningRequest(
            operation="evaluate_answer",
            learner_id="LEARNER-001",
            entry_id="LEX-001",
            payload={"answer": "árbol"},
        )
    )

    assert response.data["correct"] is False
    assert response.data["noInvention"] is True


def test_SPT_012_records_progress(
    tmp_path: Path,
) -> None:
    service = _service(tmp_path)
    response = service.execute(
        LearningRequest(
            operation="record_progress",
            learner_id="LEARNER-001",
            entry_id="LEX-001",
            payload={
                "step": "observe",
                "score": 80,
            },
        )
    )

    assert response.status == "ok"
    assert response.data["score"] == 80.0


def test_SPT_012_returns_progress(
    tmp_path: Path,
) -> None:
    service = _service(tmp_path)
    service.execute(
        LearningRequest(
            operation="record_progress",
            learner_id="LEARNER-001",
            entry_id="LEX-001",
            payload={"step": "listen"},
        )
    )
    response = service.execute(
        LearningRequest(
            operation="get_progress",
            learner_id="LEARNER-001",
            entry_id="LEX-001",
        )
    )

    assert "listen" in response.data["completedSteps"]


def test_SPT_012_exposes_integrated_capabilities(
    tmp_path: Path,
) -> None:
    response = _service(tmp_path).execute(
        LearningRequest(
            operation="capabilities",
            learner_id="LEARNER-001",
        )
    )

    assert response.status == "ok"
    assert "SPT-007A" in response.data["lexical"]
    assert response.data["tutor"] == "SPT-008"
    assert response.data["conversation"] == "SPT-009"
    assert response.data["operationalPlatform"] == "SPT-011"


def test_SPT_012_returns_not_found_without_invention(
    tmp_path: Path,
) -> None:
    response = _service(tmp_path).execute(
        LearningRequest(
            operation="get_oda",
            learner_id="LEARNER-001",
            entry_id="UNKNOWN",
        )
    )

    assert response.status == "not_found"
    assert response.no_invention is True


def test_SPT_012_rejects_unsupported_operation(
    tmp_path: Path,
) -> None:
    response = _service(tmp_path).execute(
        LearningRequest(
            operation="unknown",
            learner_id="LEARNER-001",
        )
    )

    assert response.status == "unsupported_operation"


def test_SPT_012_is_deterministic(
    tmp_path: Path,
) -> None:
    service = _service(tmp_path)
    request = LearningRequest(
        operation="get_oda",
        learner_id="LEARNER-001",
        entry_id="LEX-001",
    )

    assert service.execute(request) == service.execute(request)


def test_SPT_012_preserves_four_languages(
    tmp_path: Path,
) -> None:
    response = _service(tmp_path).execute(
        LearningRequest(
            operation="get_oda",
            learner_id="LEARNER-001",
            entry_id="LEX-001",
        )
    )

    assert set(response.data["languages"]) == {
        "pu",
        "es",
        "en-US",
        "it",
    }