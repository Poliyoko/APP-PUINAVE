from copy import deepcopy
import json
import subprocess
import sys

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from starlette.authentication import AuthCredentials, AuthenticationBackend, BaseUser
from starlette.middleware.authentication import AuthenticationMiddleware

from sgoda.integration.spt0233.catalog import CategoryCatalog
from sgoda.integration.spt0233.layer2 import Spt0233Layer2Classifier
from sgoda.integration.spt0233.layer3 import Spt0233Layer3GovernanceService
from sgoda.integration.spt0233.real508_preparation import prepare_real508
from sgoda.integration.spt0233.review_api import create_review_router


def catalog():
    return CategoryCatalog([{"id": "CAT-ANIMAL", "name": "Animales"}])


@pytest.mark.parametrize("decision", ["DUPLICATE_BLOCKED", "HUMAN_REVIEW_REQUIRED", "NOT_ELIGIBLE"])
def test_explicit_block_cannot_be_overridden(decision):
    result = Spt0233Layer2Classifier(catalog()).classify({
        "institutional_decision": decision, "downstream_allowed": True,
        "semantic_status": "MATCHED", "semantic_candidates": [{"category": "Animales"}],
    })
    assert result.status == "NOT_ELIGIBLE"


@pytest.mark.parametrize("flag", ["false", "true", 1])
def test_non_boolean_gate_does_not_enable_assignment(flag):
    result = Spt0233Layer2Classifier(catalog()).classify({
        "downstream_allowed": flag, "semantic_status": "MATCHED",
        "semantic_candidates": [{"category": "Animales"}],
    })
    assert result.status == "NOT_ELIGIBLE"


def test_valid_legacy_boolean_gate_is_preserved():
    result = Spt0233Layer2Classifier(catalog()).classify({
        "downstream_allowed": True, "semantic_status": "MATCHED",
        "semantic_candidates": [{"category": "Animales"}],
    })
    assert result.status == "ASSIGNED"


@pytest.mark.parametrize("records", [[{}, None], "bad", {}, None])
def test_batch_never_silently_loses_records(records):
    with pytest.raises(ValueError):
        Spt0233Layer2Classifier(catalog()).classify_batch({"results": records})


class Principal(BaseUser):
    @property
    def is_authenticated(self):
        return True

    @property
    def identity(self):
        return "test-issuer:reviewer-42"


class TestBackend(AuthenticationBackend):
    """Test fixture only, not a production credential verifier."""
    async def authenticate(self, conn):
        token = conn.headers.get("authorization")
        if token == "Bearer reviewer-test-fixture":
            return AuthCredentials(["authenticated", "human", "category:review"]), Principal()
        if token == "Bearer service-test-fixture":
            return AuthCredentials(["authenticated", "category:review"]), Principal()
        return None


def client(tmp_path, middleware=True):
    service = Spt0233Layer3GovernanceService(tmp_path / "registry.json", tmp_path / "ledger.jsonl")
    app = FastAPI()
    if middleware:
        app.add_middleware(AuthenticationMiddleware, backend=TestBackend())
    app.include_router(create_review_router(service))
    return TestClient(app)


BODY = {"proposed_name": "Astronomia", "approve": False, "reason": "Requires linguistic validation"}


def test_missing_middleware_fails_closed(tmp_path):
    response = client(tmp_path, False).post("/categories/proposals/review", json=BODY)
    assert response.status_code == 401
    assert not list(tmp_path.iterdir())


def test_spoofed_reviewer_header_is_not_authentication(tmp_path):
    response = client(tmp_path).post("/categories/proposals/review", json=BODY, headers={"X-Reviewer": "admin"})
    assert response.status_code == 401
    assert not list(tmp_path.iterdir())


def test_service_cannot_approve_as_human(tmp_path):
    response = client(tmp_path).post("/categories/proposals/review", json=BODY, headers={"Authorization": "Bearer service-test-fixture"})
    assert response.status_code == 403
    assert not list(tmp_path.iterdir())


def test_body_cannot_override_verified_identity(tmp_path):
    response = client(tmp_path).post("/categories/proposals/review", json={**BODY, "reviewer": "admin"},
                                    headers={"Authorization": "Bearer reviewer-test-fixture"})
    assert response.status_code == 422
    assert not list(tmp_path.iterdir())


def test_verified_identity_is_persisted_in_ledger(tmp_path):
    response = client(tmp_path).post("/categories/proposals/review", json=BODY,
                                    headers={"Authorization": "Bearer reviewer-test-fixture"})
    assert response.status_code == 200
    assert response.json()["decision"]["reviewer"] == "test-issuer:reviewer-42"
    assert response.json()["ledger_event"]["reviewer"] == "test-issuer:reviewer-42"
    assert "test-issuer:reviewer-42" in (tmp_path / "ledger.jsonl").read_text()


def test_approval_reuses_existing_c3_and_verified_identity(tmp_path):
    response = client(tmp_path).post("/categories/proposals/review",
                                    json={**BODY, "approve": True, "category_id": "CAT-ASTRONOMY"},
                                    headers={"Authorization": "Bearer reviewer-test-fixture"})
    assert response.status_code == 200
    assert response.json()["decision"]["reviewer"] == "test-issuer:reviewer-42"
    assert (tmp_path / "registry.json").exists()


def test_invalid_reason_has_sanitized_response_and_no_writes(tmp_path):
    response = client(tmp_path).post("/categories/proposals/review", json={**BODY, "reason": " "},
                                    headers={"Authorization": "Bearer reviewer-test-fixture"})
    assert response.status_code == 422
    assert response.json()["detail"] == "Invalid category review"
    assert not list(tmp_path.iterdir())


def view():
    return {"schema": "REAL508-R2-CONTROLLED-SOURCE-VIEW-v1.0.0", "records": [
        {"entry_id": f"{i:06d}", "source_current": {"puinave": "synthetic", "es": "test"}}
        for i in range(1, 509)]}


def test_preparation_preserves_508_and_never_forges_semantic_gate():
    source = view()
    before = deepcopy(source)
    batch = prepare_real508(source, catalog())
    assert source == before
    assert batch["records_processed"] == 508
    assert batch["status_counts"] == {"NOT_ELIGIBLE": 508}
    assert [r["entry_id"] for r in batch["results"]] == [r["entry_id"] for r in source["records"]]
    assert batch["linguistic_certified"] is False
    assert batch["publication_authorized"] is False


def test_effective_source_change_invalidates_batch_fingerprint():
    source = view()
    before = prepare_real508(source, catalog())
    source["records"][329]["source_current"]["es"] = "changed synthetic source"
    after = prepare_real508(source, catalog())
    assert before["source_batch_hash"] != after["source_batch_hash"]
    assert before["results"][329]["lexical_hash"] != after["results"][329]["lexical_hash"]


def test_duplicate_source_id_is_rejected():
    source = view()
    source["records"][1]["entry_id"] = "000001"
    with pytest.raises(ValueError):
        prepare_real508(source, catalog())


@pytest.mark.parametrize("destination", ["source", "existing"])
def test_cli_never_overwrites_inputs_or_existing_outputs(tmp_path, destination):
    source = tmp_path / "source.json"
    source.write_text(json.dumps(view()))
    taxonomy = tmp_path / "taxonomy.json"
    taxonomy.write_text(json.dumps({"schema_version": "1.0.0", "semantic_categories": []}))
    output = source if destination == "source" else tmp_path / "existing.json"
    if destination == "existing":
        output.write_text("preserved")
    before = output.read_bytes()
    result = subprocess.run([sys.executable, "-m", "sgoda.integration.spt0233.real508_preparation",
                             "--source-view", str(source), "--taxonomy", str(taxonomy),
                             "--output", str(output)], capture_output=True)
    assert result.returncode != 0
    assert output.read_bytes() == before
