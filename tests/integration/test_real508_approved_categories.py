import copy
import json
from pathlib import Path

from sgoda.operational_platform.category_assignments import CONFIG, category_metadata
from sgoda.operational_platform.flutter_contracts import lexical_card
from sgoda.integration.spt0233.ledger import CategoryChangeLedger
from sgoda.integration.spt0233.registry import CategoryRegistryStore


def entry():
    return {'entry_id': '000001', 'puinave': 'A', 'spanish': 'Mí',
            'metadata': {'escritura_puinave': '(a)'}, 'validated': False}


def test_approved_category_reaches_flutter_contract_without_certifying_lexicon():
    value = entry()
    before = copy.deepcopy(value)
    card = lexical_card(value, ())
    assert card['category'] == 'personal_reference'
    assert card['categoryLabel'] == 'Referencia personal y posesión'
    assert card['categoryStatus'] == 'USER_APPROVED_EDUCATIONAL'
    assert card['categoryLinguisticCertified'] is False
    assert card['validated'] is False
    assert value == before


def test_different_spelling_gloss_or_pronunciation_blocks_assignment():
    for key in ('puinave', 'spanish', 'pronunciation'):
        value = entry()
        if key == 'pronunciation':
            value['metadata']['escritura_puinave'] += ' '
        else:
            value[key] += ' '
        result = category_metadata(value)
        assert result['categoryStatus'] == 'SOURCE_MISMATCH'
        assert 'category' not in result


def test_records_outside_real508_are_not_assigned():
    value = entry()
    value['entry_id'] = '999999'
    assert category_metadata(value) == {}


def test_95_assignments_reference_seven_categories_registered_by_existing_c3():
    payload = json.loads((CONFIG / 'category-assignments.json').read_text())
    records = payload['records']
    assert len(records) == len({r['entry_id'] for r in records}) == 508
    assert sum(r['status'] == 'USER_APPROVED_EDUCATIONAL' for r in records) == 95
    assert sum(r['status'] == 'DERIVED_PENDING_VALIDATION' for r in records) == 413
    registry = CategoryRegistryStore(CONFIG / 'category-registry.json').load()
    events = CategoryChangeLedger(CONFIG / 'category-ledger.jsonl')
    assert events.verify()
    ids = {r['category_id'] for r in records if r['status'] == 'USER_APPROVED_EDUCATIONAL'}
    assert ids == {e['category_id'] for e in events.read()}
    assert len(ids) == 7
    assert ids <= {r['id'] for r in registry.categories}
    assert all(r['linguistic_certified'] is False for r in records)


def test_derived_assignment_is_visible_without_fabricating_human_approval():
    value = {'entry_id': '000002', 'puinave': ' AYOT', 'spanish': 'Mi  perro',
             'metadata': {'escritura_puinave': 'ayot'}, 'validated': False}
    card = lexical_card(value, ())
    assert card['category'] == 'animals'
    assert card['categoryStatus'] == 'DERIVED_PENDING_VALIDATION'
    assert card['categoryLinguisticCertified'] is False
