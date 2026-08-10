from sgoda.integration.spt0233.catalog import CategoryCatalog
from sgoda.integration.spt0233.hierarchy import CategoryHierarchy
from sgoda.integration.spt0233.layer2 import Spt0233Layer2Classifier
from sgoda.integration.spt0233.proposal import build_category_proposal


def catalog():
    return CategoryCatalog(
        [
            {
                "id": "CAT-NATURE",
                "name": "Naturaleza",
                "aliases": ["naturaleza"],
                "keywords": ["entorno"],
            },
            {
                "id": "CAT-ANIMAL",
                "name": "Animales",
                "aliases": ["animal"],
                "keywords": ["fauna"],
                "metadata": {"parent_id": "CAT-NATURE"},
            },
            {
                "id": "CAT-BIRD",
                "name": "Aves",
                "aliases": ["ave"],
                "keywords": ["pajaro"],
                "metadata": {"parent_id": "CAT-ANIMAL"},
            },
            {
                "id": "CAT-PLANT",
                "name": "Plantas",
                "aliases": ["planta"],
                "keywords": ["flora"],
                "metadata": {"parent_id": "CAT-NATURE"},
            },
        ]
    )


def ready(**extra):
    item = {
        "source_index": 7,
        "puinave": "AMDA",
        "lexical_hash": "lex-001",
        "institutional_decision": "READY_FOR_CATEGORY",
        "semantic_candidates": [],
        "metadata": {},
        "context": {},
    }
    item.update(extra)
    return item


def test_hierarchy_resolves_principal_category():
    hierarchy = CategoryHierarchy(catalog())
    principal = hierarchy.principal("CAT-BIRD")
    assert principal.category_id == "CAT-NATURE"


def test_hierarchy_resolves_nested_subcategories():
    hierarchy = CategoryHierarchy(catalog())
    assert [item.category_id for item in hierarchy.subcategories("CAT-BIRD")] == [
        "CAT-ANIMAL",
        "CAT-BIRD",
    ]


def test_exact_match_reuses_existing_category():
    classifier = Spt0233Layer2Classifier(catalog())
    result = classifier.classify(
        ready(semantic_candidates=[{"category": "Aves"}])
    )
    assert result.status == "ASSIGNED"
    assert result.principal_category_id == "CAT-NATURE"
    assert result.selected_category_id == "CAT-BIRD"
    assert result.subcategory_ids == ("CAT-ANIMAL", "CAT-BIRD")
    assert result.confidence == 1.0


def test_keyword_match_reuses_existing_category_with_confidence():
    classifier = Spt0233Layer2Classifier(catalog())
    result = classifier.classify(
        ready(semantic_candidates=[{"domain": "flora"}])
    )
    assert result.status == "ASSIGNED"
    assert result.selected_category_id == "CAT-PLANT"
    assert result.confidence == 0.85


def test_no_existing_match_creates_proposal_only():
    cat = catalog()
    before = cat.categories
    classifier = Spt0233Layer2Classifier(cat)
    result = classifier.classify(
        ready(semantic_candidates=[{"category": "Astronomia"}])
    )
    assert result.status == "PROPOSAL_REQUIRED"
    assert result.proposal is not None
    assert result.proposal.automatic_creation is False
    assert cat.categories == before


def test_proposal_is_deterministic():
    one = build_category_proposal(["Astronomia"])
    two = build_category_proposal(["Astronomia"])
    assert one is not None
    assert two is not None
    assert one.proposal_id == two.proposal_id


def test_empty_category_evidence_requires_review_without_proposal():
    classifier = Spt0233Layer2Classifier(catalog())
    result = classifier.classify(ready())
    assert result.status == "REVIEW_REQUIRED"
    assert result.proposal is None


def test_ambiguous_best_match_requires_review():
    classifier = Spt0233Layer2Classifier(catalog())
    result = classifier.classify(
        ready(
            semantic_candidates=[
                {"category": "Aves"},
                {"category": "Plantas"},
            ]
        )
    )
    assert result.status == "AMBIGUOUS"
    assert result.selected_category_id is None


def test_not_eligible_input_is_blocked():
    classifier = Spt0233Layer2Classifier(catalog())
    result = classifier.classify(
        ready(institutional_decision="HUMAN_REVIEW_REQUIRED")
    )
    assert result.status == "NOT_ELIGIBLE"


def test_traceability_decision_id_is_deterministic():
    classifier = Spt0233Layer2Classifier(catalog())
    item = ready(semantic_candidates=[{"category": "Aves"}])
    one = classifier.classify(item)
    two = classifier.classify(item)
    assert one.trace.decision_id == two.trace.decision_id


def test_batch_contract_reports_status_counts():
    classifier = Spt0233Layer2Classifier(catalog())
    batch = classifier.classify_batch(
        {
            "source_batch_hash": "batch-001",
            "results": [
                ready(semantic_candidates=[{"category": "Aves"}]),
                ready(
                    source_index=8,
                    lexical_hash="lex-002",
                    semantic_candidates=[{"category": "Astronomia"}],
                ),
            ],
        }
    )
    assert batch["records_processed"] == 2
    assert batch["status_counts"]["ASSIGNED"] == 1
    assert batch["status_counts"]["PROPOSAL_REQUIRED"] == 1
    assert batch["automatic_category_creation"] is False


def test_invalid_hierarchy_parent_is_rejected():
    broken = CategoryCatalog(
        [
            {
                "id": "CAT-X",
                "name": "X",
                "metadata": {"parent_id": "CAT-NOT-FOUND"},
            }
        ]
    )
    try:
        CategoryHierarchy(broken)
    except ValueError:
        pass
    else:
        raise AssertionError("unknown parent must fail")
