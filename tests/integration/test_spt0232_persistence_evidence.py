import json
from pathlib import Path

import pytest

from sgoda.integration.spt0232.evidence import (
    Spt0232EvidenceStore,
)
from sgoda.integration.spt0232.persistence import (
    canonical_json_bytes,
    read_json_verified,
    sha256_payload,
    write_json_atomic,
)
from sgoda.integration.spt0232.traceability import (
    build_traceability,
)


def analysis_payload():
    return {
        "component": "SPT-023.2",
        "source_component": "SPT-023.1",
        "source_batch_hash": "BATCH-0232",
        "layer": "CAPA_2",
        "policy": {
            "no_invention": True,
        },
        "results": [
            {
                "puinave": "AMDA",
                "normalized_puinave": "amda",
                "lexical_hash": "LEX-HASH-001",
                "institutional_decision": (
                    "READY_FOR_CATEGORY"
                ),
                "downstream_allowed": True,
            }
        ],
    }


def test_canonical_json_is_deterministic():
    first = {
        "b": 2,
        "a": 1,
    }

    second = {
        "a": 1,
        "b": 2,
    }

    assert canonical_json_bytes(first) == (
        canonical_json_bytes(second)
    )

    assert sha256_payload(first) == (
        sha256_payload(second)
    )


def test_atomic_write_and_verified_read(tmp_path):
    payload = analysis_payload()
    path = tmp_path / "analysis.json"

    record = write_json_atomic(
        path,
        payload,
    )

    assert path.exists()
    assert record["sha256"] == sha256_payload(
        payload
    )

    loaded = read_json_verified(
        path,
        record["sha256"],
    )

    assert loaded == payload


def test_verified_read_detects_tampering(tmp_path):
    path = tmp_path / "analysis.json"

    record = write_json_atomic(
        path,
        analysis_payload(),
    )

    path.write_text(
        '{"tampered":true}',
        encoding="utf-8",
    )

    with pytest.raises(
        ValueError,
        match="SHA256 mismatch",
    ):
        read_json_verified(
            path,
            record["sha256"],
        )


def test_traceability_contract():
    trace = build_traceability(
        analysis_payload()
    )

    assert trace["component"] == "SPT-023.2"
    assert trace["source_component"] == "SPT-023.1"
    assert trace["source_batch_hash"] == (
        "BATCH-0232"
    )
    assert trace["records"] == 1
    assert trace["lexical_hashes"] == [
        "LEX-HASH-001"
    ]
    assert trace["no_invention"] is True
    assert "SPT-007A" in trace["engines"]
    assert "SPT-007B" in trace["engines"]


def test_evidence_store_creates_three_artifacts(
    tmp_path,
):
    store = Spt0232EvidenceStore(
        tmp_path
    )

    result = store.persist(
        analysis_payload(),
        run_id="RUN-001",
        generated_at="2026-08-09T00:00:00+00:00",
    )

    run_dir = Path(result["run_dir"])

    assert (
        run_dir / "analysis.json"
    ).exists()

    assert (
        run_dir / "traceability.json"
    ).exists()

    assert (
        run_dir / "manifest.json"
    ).exists()


def test_manifest_hashes_match_files(tmp_path):
    store = Spt0232EvidenceStore(
        tmp_path
    )

    result = store.persist(
        analysis_payload(),
        run_id="RUN-002",
        generated_at="2026-08-09T00:00:00+00:00",
    )

    run_dir = Path(result["run_dir"])

    manifest = json.loads(
        (
            run_dir / "manifest.json"
        ).read_text(
            encoding="utf-8"
        )
    )

    analysis = read_json_verified(
        run_dir / "analysis.json",
        manifest["analysis_sha256"],
    )

    traceability = read_json_verified(
        run_dir / "traceability.json",
        manifest["traceability_sha256"],
    )

    assert analysis["component"] == (
        "SPT-023.2"
    )

    assert traceability["component"] == (
        "SPT-023.2"
    )


def test_existing_run_is_never_overwritten(
    tmp_path,
):
    store = Spt0232EvidenceStore(
        tmp_path
    )

    store.persist(
        analysis_payload(),
        run_id="RUN-003",
        generated_at="2026-08-09T00:00:00+00:00",
    )

    with pytest.raises(
        FileExistsError
    ):
        store.persist(
            analysis_payload(),
            run_id="RUN-003",
            generated_at=(
                "2026-08-09T00:00:01+00:00"
            ),
        )


def test_source_payload_is_not_mutated(
    tmp_path,
):
    payload = analysis_payload()

    original = json.loads(
        json.dumps(payload)
    )

    Spt0232EvidenceStore(
        tmp_path
    ).persist(
        payload,
        run_id="RUN-004",
        generated_at="2026-08-09T00:00:00+00:00",
    )

    assert payload == original


def test_manifest_declares_no_invention(
    tmp_path,
):
    result = Spt0232EvidenceStore(
        tmp_path
    ).persist(
        analysis_payload(),
        run_id="RUN-005",
        generated_at="2026-08-09T00:00:00+00:00",
    )

    manifest = result[
        "manifest_payload"
    ]

    assert manifest["no_invention"] is True
    assert manifest["schema"] == (
        "sgoda.spt0232.evidence.v1"
    )