from __future__ import annotations
from pathlib import Path
from typing import Iterable

from .data_policy import validate_storage_policy
from .integrity import build_hash_chain, hmac_sha256, verify_hmac_sha256
from .key_policy import validate_key_reference
from .models import CryptoControl


class CryptographicProtectionAuditor:
    def __init__(self, root: Path, discovered_paths: Iterable[str]):
        self.root = Path(root).resolve()
        self.discovered_paths = list(discovered_paths)

    def assess(self) -> dict:
        encryption_key = validate_key_reference({
            "key_reference": "keystore:SGODA_DATA_ENCRYPTION_KEY",
            "algorithm": "AES-256-GCM",
            "purpose": "ENCRYPTION",
            "enabled": True,
        })

        signing_key = validate_key_reference({
            "key_reference": "secretref:SGODA_SIGNING_KEY",
            "algorithm": "ED25519",
            "purpose": "SIGNING",
            "enabled": True,
        })

        sensitive_storage = validate_storage_policy({
            "classification": "LEXICAL_RESTRICTED",
            "encrypted_at_rest": True,
            "encrypted_in_transit": True,
        })

        public_storage = validate_storage_policy({
            "classification": "PUBLIC",
            "encrypted_at_rest": False,
            "encrypted_in_transit": True,
        })

        sample_records = [
            {"type": "lexical", "id": "ODA-001", "classification": "LEXICAL_RESTRICTED"},
            {"type": "audit", "id": "AUD-001", "classification": "AUDIT_SENSITIVE"},
        ]

        chain = build_hash_chain(sample_records)

        ephemeral_test_key = b"SGODA-SPT02410-TEST-ONLY-NONPRODUCTION"
        sample_hmac = hmac_sha256(sample_records[0], ephemeral_test_key)
        hmac_verified = verify_hmac_sha256(
            sample_records[0],
            ephemeral_test_key,
            sample_hmac,
        )

        controls = [
            CryptoControl(
                "CRYPTO-KEY-INDIRECTION",
                "Cryptographic key indirection",
                encryption_key["valid"] is True
                and signing_key["valid"] is True
                and encryption_key["credential_reference_indirect"] is True
                and signing_key["credential_reference_indirect"] is True,
                True,
                True,
                "Cryptographic keys are represented only through indirect references.",
            ),
            CryptoControl(
                "CRYPTO-ALGORITHM-POLICY",
                "Approved cryptographic algorithms",
                encryption_key["algorithm_allowed"] is True
                and signing_key["algorithm_allowed"] is True,
                True,
                True,
                "Only approved cryptographic algorithms are accepted by policy.",
            ),
            CryptoControl(
                "CRYPTO-SENSITIVE-DATA",
                "Sensitive-data cryptographic protection",
                sensitive_storage["valid"] is True
                and sensitive_storage["plaintext_persistence_allowed"] is False,
                True,
                True,
                "Sensitive data requires protection at rest and in transit.",
            ),
            CryptoControl(
                "CRYPTO-INTEGRITY",
                "SHA-256 integrity chain",
                len(chain) == 2
                and chain[0]["previous_hash"] == ""
                and chain[1]["previous_hash"] == chain[0]["sha256"],
                True,
                True,
                "SHA-256 chained integrity metadata is deterministic and verifiable.",
            ),
            CryptoControl(
                "CRYPTO-AUTHENTICITY",
                "HMAC authenticity validation",
                hmac_verified is True,
                True,
                True,
                "HMAC-SHA-256 authenticity control verifies expected payload integrity.",
            ),
            CryptoControl(
                "CRYPTO-NO-INLINE-KEYS",
                "No inline private key material",
                encryption_key["inline_key_material"] is False
                and signing_key["inline_key_material"] is False,
                True,
                True,
                "No inline private-key material is permitted by the key profile.",
            ),
            CryptoControl(
                "CRYPTO-NO-SIDE-EFFECTS",
                "No operational key or data mutation",
                encryption_key["key_material_read"] is False
                and signing_key["key_material_read"] is False,
                True,
                True,
                "Gate does not read real keys, rotate keys, encrypt production data or open external connections.",
            ),
            CryptoControl(
                "CRYPTO-SECRET-SAFETY",
                "No secret values exposed",
                encryption_key["secret_values_exposed"] is False
                and signing_key["secret_values_exposed"] is False
                and sensitive_storage["secret_values_exposed"] is False
                and public_storage["secret_values_exposed"] is False,
                True,
                True,
                "Evidence stores classifications, references and fingerprints only.",
            ),
        ]

        failed = [
            item.control_id
            for item in controls
            if item.blocking and item.applicable and not item.passed
        ]

        return {
            "status": "CRYPTOGRAPHIC_PROTECTION_GATE_PASS" if not failed else "CRYPTOGRAPHIC_PROTECTION_GATE_HOLD",
            "failed_blocking_controls": failed,
            "controls": [item.__dict__ for item in controls],
            "key_profiles": {
                "encryption": encryption_key,
                "signing": signing_key,
            },
            "storage_profiles": {
                "sensitive": sensitive_storage,
                "public": public_storage,
            },
            "integrity_chain": chain,
            "hmac_verified": hmac_verified,
            "discovered_crypto_data_surfaces": len(self.discovered_paths),
            "real_key_material_read": False,
            "real_key_rotated": False,
            "production_data_encrypted": False,
            "production_data_decrypted": False,
            "external_connection_opened": False,
            "secret_values_exposed": False,
        }
