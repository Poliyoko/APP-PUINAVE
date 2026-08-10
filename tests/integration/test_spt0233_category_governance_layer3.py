import json

from sgoda.integration.spt0233.governance import CategoryGovernance
from sgoda.integration.spt0233.layer3 import Spt0233Layer3GovernanceService
from sgoda.integration.spt0233.ledger import CategoryChangeLedger
from sgoda.integration.spt0233.proposal import build_category_proposal
from sgoda.integration.spt0233.registry import CategoryRegistryStore


def proposal(name="Astronomia"):
    value = build_category_proposal([name])
    assert value is not None
    return value


def initial_categories():
    return [
        {
            "id": "CAT-NATURE",
            "name": "Naturaleza",
            "aliases": [],
            "keywords": [],
            "metadata": {"parent_id": None},
        },
        {
            "id": "CAT-ANIMAL",
            "name": "Animales",
            "aliases": ["animal"],
            "keywords": ["fauna"],
            "metadata": {"parent_id": "CAT-NATURE"},
        },
    ]


def seed_registry(path):
    store = CategoryRegistryStore(path)
    return store.save(version=1, categories=initial_categories())


def test_registry_roundtrip_and_hash(tmp_path):
    path = tmp_path / "catalog.json"
    saved = seed_registry(path)
    loaded = CategoryRegistryStore(path).load()
    assert loaded.version == 1
    assert loaded.sha256 == saved.sha256
    assert len(loaded.categories) == 2


def test_registry_rejects_duplicate_ids(tmp_path):
    store = CategoryRegistryStore(tmp_path / "catalog.json")
    categories = initial_categories() + [
        {"id": "CAT-ANIMAL", "name": "Otro", "metadata": {}}
    ]
    try:
        store.save(version=1, categories=categories)
    except ValueError:
        pass
    else:
        raise AssertionError("duplicate ids must fail")


def test_registry_rejects_unknown_parent(tmp_path):
    store = CategoryRegistryStore(tmp_path / "catalog.json")
    categories = [
        {
            "id": "CAT-X",
            "name": "X",
            "metadata": {"parent_id": "CAT-NOT-FOUND"},
        }
    ]
    try:
        store.save(version=1, categories=categories)
    except ValueError:
        pass
    else:
        raise AssertionError("unknown parent must fail")


def test_registry_detects_content_tampering(tmp_path):
    path = tmp_path / "catalog.json"
    seed_registry(path)
    data = json.loads(path.read_text(encoding="utf-8"))
    data["categories"][0]["name"] = "ALTERADO"
    path.write_text(json.dumps(data), encoding="utf-8")
    try:
        CategoryRegistryStore(path).load()
    except ValueError:
        pass
    else:
        raise AssertionError("tampered registry must fail")


def test_governance_requires_human_reviewer():
    governance = CategoryGovernance()
    try:
        governance.review(
            proposal(),
            approve=True,
            reviewer="",
            reason="validada",
            category_id="CAT-ASTRONOMY",
        )
    except ValueError:
        pass
    else:
        raise AssertionError("human reviewer must be required")


def test_governance_rejection_never_creates_category():
    decision = CategoryGovernance().review(
        proposal(),
        approve=False,
        reviewer="linguista-01",
        reason="evidencia insuficiente",
    )
    assert decision.decision == "REJECTED"
    assert decision.category is None
    assert decision.automatic_creation is False


def test_governance_approval_produces_registry_candidate():
    decision = CategoryGovernance().review(
        proposal(),
        approve=True,
        reviewer="linguista-01",
        reason="categoria necesaria",
        category_id="CAT-ASTRONOMY",
        parent_id="CAT-NATURE",
    )
    assert decision.decision == "APPROVED_FOR_REGISTRY"
    assert decision.category["id"] == "CAT-ASTRONOMY"
    assert decision.category["metadata"]["parent_id"] == "CAT-NATURE"
    assert decision.human_approval is True


def test_ledger_hash_chain_verifies(tmp_path):
    ledger = CategoryChangeLedger(tmp_path / "ledger.jsonl")
    ledger.append(
        action="TEST",
        proposal_id="P1",
        reviewer="r1",
        reason="ok",
        registry_version_before=1,
        registry_version_after=1,
        registry_sha_before="A",
        registry_sha_after="A",
        category_id=None,
    )
    ledger.append(
        action="TEST2",
        proposal_id="P2",
        reviewer="r2",
        reason="ok",
        registry_version_before=1,
        registry_version_after=2,
        registry_sha_before="A",
        registry_sha_after="B",
        category_id="CAT-B",
    )
    assert ledger.verify() is True
    assert ledger.read()[1]["previous_hash"] == ledger.read()[0]["event_hash"]


def test_ledger_detects_tampering(tmp_path):
    path = tmp_path / "ledger.jsonl"
    ledger = CategoryChangeLedger(path)
    ledger.append(
        action="TEST",
        proposal_id="P1",
        reviewer="r1",
        reason="ok",
        registry_version_before=1,
        registry_version_after=1,
        registry_sha_before="A",
        registry_sha_after="A",
        category_id=None,
    )
    text = path.read_text(encoding="utf-8").replace('"reason": "ok"', '"reason": "x"')
    path.write_text(text, encoding="utf-8")
    assert ledger.verify() is False


def test_layer3_rejection_preserves_registry_version(tmp_path):
    registry = tmp_path / "catalog.json"
    ledger = tmp_path / "ledger.jsonl"
    before = seed_registry(registry)
    service = Spt0233Layer3GovernanceService(registry, ledger)
    result = service.review_proposal(
        proposal(),
        approve=False,
        reviewer="linguista-01",
        reason="no procede",
    )
    assert result["decision"]["decision"] == "REJECTED"
    assert result["registry_after"]["version"] == before.version
    assert result["next_component"] == "SPT-023.4"


def test_layer3_human_approval_versions_registry(tmp_path):
    registry = tmp_path / "catalog.json"
    ledger = tmp_path / "ledger.jsonl"
    seed_registry(registry)
    service = Spt0233Layer3GovernanceService(registry, ledger)
    result = service.review_proposal(
        proposal(),
        approve=True,
        reviewer="linguista-01",
        reason="aprobada",
        category_id="CAT-ASTRONOMY",
        parent_id="CAT-NATURE",
    )
    assert result["registry_before"]["version"] == 1
    assert result["registry_after"]["version"] == 2
    assert result["decision"]["category"]["id"] == "CAT-ASTRONOMY"
    assert result["automatic_category_creation"] is False


def test_layer3_blocks_duplicate_category_id(tmp_path):
    registry = tmp_path / "catalog.json"
    ledger = tmp_path / "ledger.jsonl"
    seed_registry(registry)
    service = Spt0233Layer3GovernanceService(registry, ledger)
    try:
        service.review_proposal(
            proposal(),
            approve=True,
            reviewer="linguista-01",
            reason="intento duplicado",
            category_id="CAT-ANIMAL",
            parent_id="CAT-NATURE",
        )
    except ValueError:
        pass
    else:
        raise AssertionError("duplicate category id must fail")


def test_layer3_blocks_duplicate_category_name(tmp_path):
    registry = tmp_path / "catalog.json"
    ledger = tmp_path / "ledger.jsonl"
    seed_registry(registry)
    service = Spt0233Layer3GovernanceService(registry, ledger)
    try:
        service.review_proposal(
            proposal("Animales"),
            approve=True,
            reviewer="linguista-01",
            reason="intento duplicado",
            category_id="CAT-OTHER",
            parent_id="CAT-NATURE",
        )
    except ValueError:
        pass
    else:
        raise AssertionError("duplicate category name must fail")


def test_layer3_output_closes_spt0233_scope(tmp_path):
    registry = tmp_path / "catalog.json"
    ledger = tmp_path / "ledger.jsonl"
    seed_registry(registry)
    service = Spt0233Layer3GovernanceService(registry, ledger)
    result = service.review_proposal(
        proposal(),
        approve=True,
        reviewer="linguista-01",
        reason="aprobada",
        category_id="CAT-ASTRONOMY",
        parent_id="CAT-NATURE",
    )
    assert result["scope_status"] == "COMPLETE"
    assert result["human_approval_required"] is True
    assert result["traceability"] == "SHA256_CHAIN"
    assert result["next_component"] == "SPT-023.4"
