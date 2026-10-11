"""Read approved REAL508 metadata; never write or normalize lexical data."""

import hashlib
import json
from functools import lru_cache
from pathlib import Path

from sgoda.integration.spt0233.registry import CategoryRegistryStore
from sgoda.integration.spt0233.ledger import CategoryChangeLedger

CONFIG = Path(__file__).resolve().parents[3] / 'config' / 'real508'


@lru_cache(maxsize=1)
def approved_assignments():
    payload = json.loads((CONFIG / 'category-assignments.json').read_text(encoding='utf-8'))
    registry = CategoryRegistryStore(CONFIG / 'category-registry.json').load()
    if not CategoryChangeLedger(CONFIG / 'category-ledger.jsonl').verify():
        raise ValueError('Category approval ledger integrity failed')
    catalog = {item['id']: item['name'] for item in registry.categories}
    records = {item['entry_id']: item for item in payload['records']}
    if len(records) != len(payload['records']):
        raise ValueError('Duplicate category assignment ID')
    for item in records.values():
        if item['category_id'] not in catalog or item['status'] not in {
            'USER_APPROVED_EDUCATIONAL', 'DERIVED_PENDING_VALIDATION'}:
            raise ValueError('Invalid approved category assignment')
    return records, catalog


def category_metadata(entry):
    records, catalog = approved_assignments()
    item = records.get(str(entry['entry_id']))
    if item is None:
        return {}
    values = [entry.get('puinave', ''), entry.get('spanish', ''),
              entry.get('metadata', {}).get('escritura_puinave', '')]
    digest = hashlib.sha256(json.dumps(values, ensure_ascii=False, separators=(',', ':')).encode()).hexdigest()
    if digest != item['source_row_sha256']:
        return {'categoryStatus': 'SOURCE_MISMATCH', 'categoryLinguisticCertified': False}
    return {'category': item['category_id'], 'categoryLabel': catalog[item['category_id']],
            'categoryStatus': item['status'], 'categoryLinguisticCertified': False}
