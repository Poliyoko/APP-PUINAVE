from hashlib import sha256
import json
import re

PLATFORM_ID_RE = re.compile(r"^sgoda-[a-z0-9][a-z0-9-]*$")

def _t(value):
    return str(value or "").strip()

def normalize_code(value):
    return _t(value).lower().replace("_", "-")

def normalize_platform_id(value):
    text = _t(value).lower().replace("_", "-").replace(" ", "-")
    return re.sub(r"-+", "-", text)

def validate_bootstrap_spec(spec):
    errors = []
    if not isinstance(spec, dict):
        return {"valid": False, "errors": ["bootstrap_spec_not_object"]}

    for key in (
        "platform_id", "platform_name", "community", "native_language",
        "support_languages", "rlb", "resources", "identity"
    ):
        if key not in spec:
            errors.append("missing_" + key)

    platform_id = normalize_platform_id(spec.get("platform_id"))
    if not platform_id or not PLATFORM_ID_RE.match(platform_id):
        errors.append("platform_id_invalid")

    if not _t(spec.get("platform_name")):
        errors.append("platform_name_required")

    native = spec.get("native_language")
    native_code = ""
    if not isinstance(native, dict):
        errors.append("native_language_not_object")
    else:
        native_code = normalize_code(native.get("code"))
        if not native_code:
            errors.append("native_language_code_required")
        if not _t(native.get("name")):
            errors.append("native_language_name_required")

    supports = spec.get("support_languages")
    if not isinstance(supports, list):
        errors.append("support_languages_not_list")
        supports = []

    seen = set()
    support_codes = []
    for index, item in enumerate(supports):
        if not isinstance(item, dict):
            errors.append(f"support_{index}_not_object")
            continue
        code = normalize_code(item.get("code"))
        if not code:
            errors.append(f"support_{index}_code_required")
        if not _t(item.get("name")):
            errors.append(f"support_{index}_name_required")
        if code and code == native_code:
            errors.append(f"support_{index}_cannot_equal_native")
        if code and code in seen:
            errors.append(f"support_{index}_duplicate_code")
        if code:
            seen.add(code)
            support_codes.append(code)

    if spec.get("independent_platform") is not True:
        errors.append("independent_platform_required")

    if spec.get("sgoda_core_mode") != "shared_reference":
        errors.append("sgoda_core_mode_must_be_shared_reference")

    for key, message in (
        ("rlb", "rlb_instance_specific_required"),
        ("resources", "resources_instance_specific_required"),
        ("identity", "identity_instance_specific_required"),
    ):
        value = spec.get(key)
        if not isinstance(value, dict) or value.get("instance_specific") is not True:
            errors.append(message)

    community = spec.get("community")
    if (
        not isinstance(community, dict)
        or not _t(community.get("community_id"))
        or not _t(community.get("name"))
    ):
        errors.append("community_identity_invalid")

    return {
        "valid": not errors,
        "errors": errors,
        "platform_id": platform_id,
        "native_language": native_code,
        "support_language_codes": support_codes,
    }

def build_bootstrap_bundle(spec):
    validation = validate_bootstrap_spec(spec)
    if not validation["valid"]:
        return {"valid": False, "errors": validation["errors"]}

    platform_id = validation["platform_id"]
    native_code = validation["native_language"]
    support_codes = validation["support_language_codes"]

    platform = {
        "platform_id": platform_id,
        "platform_name": _t(spec["platform_name"]),
        "independent_platform": True,
        "sgoda_core": {
            "mode": "shared_reference",
            "embedded_copy": False,
        },
        "community": spec["community"],
        "native_language": spec["native_language"],
        "support_languages": spec["support_languages"],
    }

    rlb = {
        "repository_id": "RLB-" + native_code.upper(),
        "instance_specific": True,
        "native_language": native_code,
        "support_languages": support_codes,
        "records": [],
        "bootstrap_state": "EMPTY_READY",
    }

    resources = {
        "instance_specific": True,
        "resources": spec["resources"].get("catalog", []),
        "bootstrap_state": "READY",
    }

    identity = dict(spec["identity"])
    identity["instance_specific"] = True
    identity["platform_id"] = platform_id
    identity["platform_name"] = _t(spec["platform_name"])

    manifest = {
        "bootstrap_contract": "SGODA_LANGUAGE_INSTANCE_V1",
        "platform_id": platform_id,
        "native_language": native_code,
        "support_languages": support_codes,
        "shared_core_reference": True,
        "core_copy_created": False,
        "production_deployed": False,
    }

    bundle = {
        "platform.json": platform,
        "rlb.json": rlb,
        "resources.json": resources,
        "identity.json": identity,
        "bootstrap-manifest.json": manifest,
    }
    return {"valid": True, "bundle": bundle, "manifest": manifest}

def bundle_fingerprint(bundle):
    payload = json.dumps(
        bundle,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    return sha256(payload.encode("utf-8")).hexdigest()

def reference_puinave_bootstrap_spec():
    return {
        "platform_id": "sgoda-puinave",
        "platform_name": "SGODA-PUINAVE",
        "independent_platform": True,
        "sgoda_core_mode": "shared_reference",
        "community": {
            "community_id": "puinave",
            "name": "Pueblo Puinave",
        },
        "native_language": {
            "code": "pui",
            "name": "Puinave",
        },
        "support_languages": [
            {"code": "es", "name": "EspaÃ±ol"},
            {"code": "en", "name": "English"},
            {"code": "it", "name": "Italiano"},
            {"code": "pt", "name": "PortuguÃªs"},
        ],
        "rlb": {"instance_specific": True},
        "resources": {
            "instance_specific": True,
            "catalog": [],
        },
        "identity": {
            "instance_specific": True,
            "branding": {"configurable_per_platform": True},
        },
    }
