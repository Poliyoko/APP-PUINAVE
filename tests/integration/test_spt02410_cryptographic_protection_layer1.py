from sgoda.integration.spt02410.data_policy import (
    classify_record,
    validate_storage_policy,
)
from sgoda.integration.spt02410.integrity import (
    build_hash_chain,
    hmac_sha256,
    verify_hmac_sha256,
)
from sgoda.integration.spt02410.key_policy import validate_key_reference
from sgoda.integration.spt02410.service import CryptographicProtectionService


def test_indirect_encryption_key_reference_passes():
    result = validate_key_reference({
        "key_reference": "keystore:DATA_KEY",
        "algorithm": "AES-256-GCM",
        "purpose": "ENCRYPTION",
        "enabled": True,
    })
    assert result["valid"] is True
    assert result["credential_reference_indirect"] is True


def test_plaintext_key_reference_fails():
    result = validate_key_reference({
        "key_reference": "hardcoded-key-value",
        "algorithm": "AES-256-GCM",
        "purpose": "ENCRYPTION",
        "enabled": True,
    })
    assert result["valid"] is False


def test_forbidden_algorithm_fails():
    result = validate_key_reference({
        "key_reference": "secretref:DATA_KEY",
        "algorithm": "DES",
        "purpose": "ENCRYPTION",
        "enabled": True,
    })
    assert result["valid"] is False


def test_inline_private_key_marker_fails():
    result = validate_key_reference({
        "key_reference": "-----BEGIN PRIVATE KEY-----",
        "algorithm": "ED25519",
        "purpose": "SIGNING",
        "enabled": True,
    })
    assert result["valid"] is False
    assert result["inline_key_material"] is True


def test_sensitive_classification_disallows_plaintext_persistence():
    result = classify_record({"classification": "LEXICAL_RESTRICTED"})
    assert result["sensitive"] is True
    assert result["plaintext_persistence_allowed"] is False


def test_sensitive_storage_requires_at_rest_and_in_transit_protection():
    secure = validate_storage_policy({
        "classification": "PERSONAL_DATA",
        "encrypted_at_rest": True,
        "encrypted_in_transit": True,
    })
    insecure = validate_storage_policy({
        "classification": "PERSONAL_DATA",
        "encrypted_at_rest": False,
        "encrypted_in_transit": True,
    })
    assert secure["valid"] is True
    assert insecure["valid"] is False


def test_public_storage_policy_remains_valid():
    result = validate_storage_policy({
        "classification": "PUBLIC",
        "encrypted_at_rest": False,
        "encrypted_in_transit": True,
    })
    assert result["valid"] is True


def test_hash_chain_links_records():
    chain = build_hash_chain([
        {"id": "1"},
        {"id": "2"},
        {"id": "3"},
    ])
    assert len(chain) == 3
    assert chain[0]["previous_hash"] == ""
    assert chain[1]["previous_hash"] == chain[0]["sha256"]
    assert chain[2]["previous_hash"] == chain[1]["sha256"]


def test_hmac_verification_passes():
    payload = {"id": "ODA-001", "value": "metadata-only"}
    key = b"TEST-ONLY-NONPRODUCTION"
    digest = hmac_sha256(payload, key)
    assert verify_hmac_sha256(payload, key, digest) is True


def test_hmac_verification_rejects_tampering():
    payload = {"id": "ODA-001", "value": "metadata-only"}
    key = b"TEST-ONLY-NONPRODUCTION"
    digest = hmac_sha256(payload, key)
    altered = {"id": "ODA-001", "value": "changed"}
    assert verify_hmac_sha256(altered, key, digest) is False


def test_full_crypto_gate_passes(tmp_path):
    result = CryptographicProtectionService(tmp_path, []).assess()
    assert result["status"] == "CRYPTOGRAPHIC_PROTECTION_GATE_PASS"
    assert result["failed_blocking_controls"] == []


def test_full_gate_has_no_real_crypto_side_effects(tmp_path):
    result = CryptographicProtectionService(tmp_path, []).assess()
    assert result["real_key_material_read"] is False
    assert result["real_key_rotated"] is False
    assert result["production_data_encrypted"] is False
    assert result["production_data_decrypted"] is False
    assert result["external_connection_opened"] is False
    assert result["secret_values_exposed"] is False
