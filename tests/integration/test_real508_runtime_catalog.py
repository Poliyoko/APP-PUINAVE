from pathlib import Path
from fastapi.testclient import TestClient
from sgoda.operational_platform.api import create_app
from sgoda.operational_platform.database import OperationalRepository


def client(ids, **options):
    repository = OperationalRepository()
    repository.upsert_entries({'entry_id': i, 'puinave': 'Prueba', 'spanish': 'Prueba'} for i in ids)
    root = Path(__file__).resolve().parents[2]
    return TestClient(create_app(root / 'config/operational_platform/SPT-011-runtime.json',
                                 'UNUSED', repository=repository, **options))


def test_real508_requires_all_canonical_ids_and_never_falls_back_to_pilot():
    status = client(f'{i:06d}' for i in range(1, 26)).get('/dataset/status').json()
    assert status['record_count'] == 25
    assert status['ready'] is False
    assert len(status['missing_ids']) == 483
    assert status['pilot_fallback'] is False


def test_508_different_ids_do_not_pass_completeness_gate():
    ids = [f'{i:06d}' for i in range(1, 508)] + ['PU-000508']
    status = client(ids).get('/dataset/status').json()
    assert status['ready'] is False
    assert status['missing_ids'] == ['000508']
    assert status['unexpected_ids'] == ['PU-000508']


def test_real508_complete_dataset_and_taxonomy_are_available():
    api = client(f'{i:06d}' for i in range(1, 509))
    status = api.get('/dataset/status').json()
    assert status['ready'] is True
    assert status['record_count'] == 508
    taxonomy = api.get('/categories/taxonomy').json()
    assert taxonomy['instance_id'] == 'puinave'
    assert len(taxonomy['semantic_categories']) == 20
    assert any(c['id'] == 'personal_reference' for c in taxonomy['semantic_categories'])


def test_deployment_cors_is_explicit_and_does_not_allow_other_origins():
    api = client([], cors_origins=['http://192.168.1.20:8080'])
    response = api.options('/dataset/status', headers={
        'Origin': 'http://192.168.1.20:8080', 'Access-Control-Request-Method': 'GET'})
    assert response.status_code == 200
    assert response.headers['access-control-allow-origin'] == 'http://192.168.1.20:8080'
    response = api.options('/dataset/status', headers={
        'Origin': 'https://unconfigured.example', 'Access-Control-Request-Method': 'GET'})
    assert response.status_code == 400
