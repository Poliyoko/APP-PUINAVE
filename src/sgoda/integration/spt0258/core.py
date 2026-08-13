from hashlib import sha256
import json

def _t(value):
    return str(value or "").strip()

def normalize_code(value):
    return _t(value).lower().replace("_", "-")

def validate_language_contract(platform):
    errors = []
    native = platform.get("native_language")
    supports = platform.get("support_languages", [])
    if not isinstance(native, dict):
        errors.append("native_language_not_object")
        return errors
    native_code = normalize_code(native.get("code"))
    if not native_code:
        errors.append("native_language_code_required")
    seen = set()
    for index, item in enumerate(supports if isinstance(supports, list) else []):
        if not isinstance(item, dict):
            errors.append(f"support_{index}_not_object")
            continue
        code = normalize_code(item.get("code"))
        if code == native_code and code:
            errors.append(f"support_{index}_equals_native")
        if code in seen and code:
            errors.append(f"support_{index}_duplicate")
        if code:
            seen.add(code)
    return errors

def validate_bundle(bundle):
    errors = []
    required = {
        "platform.json",
        "rlb.json",
        "resources.json",
        "identity.json",
        "bootstrap-manifest.json",
    }
    if not isinstance(bundle, dict):
        return {"valid": False, "errors": ["bundle_not_object"]}
    missing = sorted(required.difference(bundle.keys()))
    if missing:
        errors.extend("missing_" + x for x in missing)

    platform = bundle.get("platform.json", {})
    rlb = bundle.get("rlb.json", {})
    resources = bundle.get("resources.json", {})
    identity = bundle.get("identity.json", {})
    manifest = bundle.get("bootstrap-manifest.json", {})

    errors.extend(validate_language_contract(platform))

    if platform.get("sgoda_core", {}).get("mode") != "shared_reference":
        errors.append("sgoda_core_mode_invalid")
    if platform.get("sgoda_core", {}).get("embedded_copy") is not False:
        errors.append("sgoda_core_embedded_copy_forbidden")

    native_code = normalize_code(platform.get("native_language", {}).get("code"))
    support_codes = [
        normalize_code(x.get("code"))
        for x in platform.get("support_languages", [])
        if isinstance(x, dict) and normalize_code(x.get("code"))
    ]

    if rlb.get("instance_specific") is not True:
        errors.append("rlb_not_instance_specific")
    if normalize_code(rlb.get("native_language")) != native_code:
        errors.append("rlb_native_language_mismatch")
    if list(rlb.get("support_languages", [])) != support_codes:
        errors.append("rlb_support_languages_mismatch")
    if rlb.get("bootstrap_state") != "EMPTY_READY":
        errors.append("rlb_bootstrap_state_invalid")

    if resources.get("instance_specific") is not True:
        errors.append("resources_not_instance_specific")
    if resources.get("bootstrap_state") != "READY":
        errors.append("resources_bootstrap_state_invalid")

    if identity.get("instance_specific") is not True:
        errors.append("identity_not_instance_specific")
    if identity.get("platform_id") != platform.get("platform_id"):
        errors.append("identity_platform_id_mismatch")

    if manifest.get("bootstrap_contract") != "SGODA_LANGUAGE_INSTANCE_V1":
        errors.append("bootstrap_contract_invalid")
    if manifest.get("shared_core_reference") is not True:
        errors.append("shared_core_reference_required")
    if manifest.get("core_copy_created") is not False:
        errors.append("core_copy_created_forbidden")
    if manifest.get("production_deployed") is not False:
        errors.append("production_deployment_forbidden")

    return {
        "valid": not errors,
        "errors": errors,
        "native_language": native_code,
        "support_languages": support_codes,
        "platform_id": platform.get("platform_id"),
    }

def compatibility_gate(bundle):
    result = validate_bundle(bundle)
    checks = {
        "language_contract": not any("native_language" in e or "support_" in e for e in result["errors"]),
        "rlb_contract": not any(e.startswith("rlb_") for e in result["errors"]),
        "resource_contract": not any(e.startswith("resources_") for e in result["errors"]),
        "identity_contract": not any(e.startswith("identity_") for e in result["errors"]),
        "sgoda_core_compatibility": not any("sgoda_core" in e or "shared_core" in e or "core_copy" in e for e in result["errors"]),
        "bootstrap_manifest": not any("bootstrap_contract" in e or "production_deployment" in e for e in result["errors"]),
    }
    checks["all_pass"] = all(checks.values()) and result["valid"]
    return checks

def bundle_sha256(bundle):
    text = json.dumps(bundle, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return sha256(text.encode("utf-8")).hexdigest()

def simulate_kurripaco_bundle():
    platform = {
        "platform_id": "sgoda-kurripaco",
        "platform_name": "SGODA-KURRIPACO",
        "independent_platform": True,
        "sgoda_core": {"mode": "shared_reference", "embedded_copy": False},
        "community": {"community_id": "kurripaco", "name": "Pueblo Kurripaco"},
        "native_language": {"code": "kpc", "name": "Kurripaco"},
        "support_languages": [
            {"code": "es", "name": "EspaÃ±ol"},
            {"code": "en", "name": "English"},
        ],
    }
    rlb = {
        "repository_id": "RLB-KPC",
        "instance_specific": True,
        "native_language": "kpc",
        "support_languages": ["es", "en"],
        "records": [],
        "bootstrap_state": "EMPTY_READY",
    }
    resources = {
        "instance_specific": True,
        "resources": [],
        "bootstrap_state": "READY",
    }
    identity = {
        "instance_specific": True,
        "platform_id": "sgoda-kurripaco",
        "platform_name": "SGODA-KURRIPACO",
        "branding": {"configurable_per_platform": True},
    }
    manifest = {
        "bootstrap_contract": "SGODA_LANGUAGE_INSTANCE_V1",
        "platform_id": "sgoda-kurripaco",
        "native_language": "kpc",
        "support_languages": ["es", "en"],
        "shared_core_reference": True,
        "core_copy_created": False,
        "production_deployed": False,
    }
    return {
        "platform.json": platform,
        "rlb.json": rlb,
        "resources.json": resources,
        "identity.json": identity,
        "bootstrap-manifest.json": manifest,
    }

def nondestructive_replication_trial():
    bundle = simulate_kurripaco_bundle()
    validation = validate_bundle(bundle)
    compatibility = compatibility_gate(bundle)
    return {
        "valid": validation["valid"],
        "compatibility": compatibility,
        "sha256": bundle_sha256(bundle),
        "deployed": False,
        "production_changed": False,
        "sgoda_puinave_modified": False,
        "core_duplicated": False,
    }
