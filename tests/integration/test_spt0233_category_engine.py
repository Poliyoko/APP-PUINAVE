from sgoda.integration.spt0233 import CategoryCatalog, Spt0233CategoryService


def catalog():
    return CategoryCatalog(
        [
            {
                "id": "CAT-ANIMAL",
                "name": "Animales",
                "aliases": ["animal"],
                "keywords": ["fauna"],
            },
            {
                "id": "CAT-PLANT",
                "name": "Plantas",
                "aliases": ["planta"],
                "keywords": ["flora"],
            },
        ]
    )


def ready(**extra):
    item = {
        "source_index": 1,
        "puinave": "AMDA",
        "lexical_hash": "abc",
        "institutional_decision": "READY_FOR_CATEGORY",
        "downstream_allowed": True,
        "semantic_status": "MATCHED",
        "semantic_candidates": [],
        "metadata": {},
    }
    item.update(extra)
    return item


def test_exact_existing_category_assignment():
    service = Spt0233CategoryService(catalog())
    result = service.assign(
        ready(semantic_candidates=[{"category": "Animales"}])
    )
    assert result.assignment_status == "ASSIGNED"
    assert result.category_id == "CAT-ANIMAL"
    assert result.no_invention is True


def test_alias_existing_category_assignment():
    service = Spt0233CategoryService(catalog())
    result = service.assign(
        ready(semantic_candidates=[{"category": "planta"}])
    )
    assert result.assignment_status == "ASSIGNED"
    assert result.category_id == "CAT-PLANT"


def test_keyword_existing_category_assignment():
    service = Spt0233CategoryService(catalog())
    result = service.assign(
        ready(semantic_candidates=[{"domain": "fauna"}])
    )
    assert result.assignment_status == "ASSIGNED"
    assert result.confidence == 0.85


def test_no_match_requires_review_and_creates_nothing():
    service = Spt0233CategoryService(catalog())
    before = service.catalog.categories
    result = service.assign(
        ready(semantic_candidates=[{"domain": "astronomia"}])
    )
    after = service.catalog.categories
    assert result.assignment_status == "REVIEW_REQUIRED"
    assert result.category_id is None
    assert before == after


def test_ambiguous_existing_categories_requires_review():
    service = Spt0233CategoryService(catalog())
    result = service.assign(
        ready(
            semantic_candidates=[
                {"category": "Animales"},
                {"category": "Plantas"},
            ]
        )
    )
    assert result.assignment_status == "AMBIGUOUS"
    assert result.requires_human_validation is True


def test_not_ready_input_is_blocked():
    service = Spt0233CategoryService(catalog())
    item = ready(institutional_decision="HUMAN_REVIEW_REQUIRED")
    result = service.assign(item)
    assert result.assignment_status == "NOT_ELIGIBLE"
    assert result.category_id is None


def test_spt0232_compatible_inference_from_downstream_allowed():
    service = Spt0233CategoryService(catalog())
    item = ready(
        institutional_decision="",
        semantic_candidates=[{"category": "Animales"}],
    )
    result = service.assign(item)
    assert result.assignment_status == "ASSIGNED"


def test_batch_contract_routes_to_spt0234_without_auto_creation():
    service = Spt0233CategoryService(catalog())
    batch = service.assign_batch(
        {
            "component": "SPT-023.2",
            "source_batch_hash": "batch-sha",
            "results": [
                ready(semantic_candidates=[{"category": "Animales"}]),
                ready(semantic_candidates=[{"domain": "astronomia"}]),
            ],
        }
    )
    assert batch["component"] == "SPT-023.3"
    assert batch["source_component"] == "SPT-023.2"
    assert batch["next_component"] == "SPT-023.4"
    assert batch["assigned"] == 1
    assert batch["review_required"] == 1
    assert batch["automatic_category_creation"] is False
    assert batch["no_invention"] is True


def test_duplicate_catalog_ids_are_rejected():
    try:
        CategoryCatalog(
            [
                {"id": "CAT-X", "name": "Uno"},
                {"id": "CAT-X", "name": "Dos"},
            ]
        )
    except ValueError:
        pass
    else:
        raise AssertionError("duplicate category ids must fail")
