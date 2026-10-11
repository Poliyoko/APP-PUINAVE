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


def test_unapproved_records_are_not_assigned():
    value = entry()
    value['entry_id'] = '000002'
    assert category_metadata(value) == {}


def test_95_assignments_reference_seven_categories_registered_by_existing_c3():
    payload = json.loads((CONFIG / 'category-assignments.json').read_text())
    records = payload['records']
    assert len(records) == len({r['entry_id'] for r in records}) == 95
    registry = CategoryRegistryStore(CONFIG / 'category-registry.json').load()
    events = CategoryChangeLedger(CONFIG / 'category-ledger.jsonl')
    assert events.verify()
    ids = {r['category_id'] for r in records}
    assert ids == {e['category_id'] for e in events.read()}
    assert len(ids) == 7
    assert ids <= {r['id'] for r in registry.categories}
    assert all(r['linguistic_certified'] is False for r in records)
