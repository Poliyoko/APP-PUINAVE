from sgoda.pmo.repository.mmgr.progress_policy import (
    ARCHITECTURE_WEIGHTS,
    calculate_strategic_architecture_progress,
    decide,
)


def closed(code, architecture_path):
    return decide(
        code=code,
        family="SPT",
        classification="CLOSED_VERIFIED",
        source_paths=(architecture_path,),
    )


def test_strategic_budget_is_exactly_100():
    assert sum(ARCHITECTURE_WEIGHTS.values()) == 100


def test_empty_architecture_remains_in_denominator():
    result = calculate_strategic_architecture_progress(
        (
            closed(
                "API-1",
                "src/sgoda/api/routes/words.py",
            ),
        )
    )

    assert result["total_weight"] == 100
    assert "Portal Web" in result["by_architecture"]
    assert (
        result["by_architecture"]["Portal Web"]["deliverables"]
        == 0
    )
    assert (
        result["by_architecture"]["Portal Web"]["progress"]
        == 0
    )


def test_single_complete_api_does_not_make_project_100_percent():
    result = calculate_strategic_architecture_progress(
        (
            closed(
                "API-1",
                "src/sgoda/api/routes/words.py",
            ),
        )
    )

    assert result["global_progress"] == 10.0


def test_all_architectures_complete_equals_100():
    paths = {
        "Nucleo": "src/sgoda/core/engine.py",
        "Builder": "builder/src/sgoda/generator.py",
        "CCP": "src/sgoda/ccp/catalog.py",
        "API": "src/sgoda/api/routes/words.py",
        "ODA": "src/sgoda/oda/object.py",
        "Multimedia": "src/sgoda/multimedia/audio/service.py",
        "Mobile": "src/sgoda/mobile/flutter/client.py",
        "Portal Web": "src/sgoda/portal_web/frontend/app.py",
        "IA": "src/sgoda/ia/semantic_engine.py",
        "DMP": "src/sgoda/pmo/repository/mmgr/report.py",
    }

    decisions = tuple(
        closed(name, path)
        for name, path in paths.items()
    )

    result = calculate_strategic_architecture_progress(
        decisions
    )

    assert result["total_weight"] == 100
    assert result["global_progress"] == 100


def test_portal_web_zero_progress_penalizes_global_completion():
    paths = {
        "Nucleo": "src/sgoda/core/engine.py",
        "Builder": "builder/src/sgoda/generator.py",
        "CCP": "src/sgoda/ccp/catalog.py",
        "API": "src/sgoda/api/routes/words.py",
        "ODA": "src/sgoda/oda/object.py",
        "Multimedia": "src/sgoda/multimedia/audio/service.py",
        "Mobile": "src/sgoda/mobile/flutter/client.py",
        "IA": "src/sgoda/ia/semantic_engine.py",
        "DMP": "src/sgoda/pmo/repository/mmgr/report.py",
    }

    decisions = tuple(
        closed(name, path)
        for name, path in paths.items()
    )

    result = calculate_strategic_architecture_progress(
        decisions
    )

    # Everything complete except Portal Web (8 points).
    assert result["global_progress"] == 92.0
    assert (
        result["by_architecture"]["Portal Web"]["weight"]
        == 8.0
    )