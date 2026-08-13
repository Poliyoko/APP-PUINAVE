from hashlib import sha256
import json
import re

INSTANCE_ID_RE = re.compile(r"^sgoda-[a-z0-9][a-z0-9-]*$")

def _t(value):
    return str(value or "").strip()

def normalize_code(value):
    return _t(value).lower().replace("_", "-")

def normalize_instance_id(value):
    text = _t(value).lower().replace("_", "-").replace(" ", "-")
    return re.sub(r"-+", "-", text)

def validate_materialization_spec(spec):
    errors = []
    if not isinstance(spec, dict):
        return {"valid": False, "errors": ["spec_not_object"]}

    required = (
        "platform_id",
        "platform_name",
        "native_language",
        "support_languages",
        "community",
        "identity",
        "resources",
        "rlb",
        "governance",
    )
    for key in required:
        if key not in spec:
            errors.append("missing_" + key)

    platform_id = normalize_instance_id(spec.get("platform_id"))
    if not platform_id or not INSTANCE_ID_RE.match(platform_id):
        errors.append("platform_id_invalid")

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
        if code == native_code and code:
            errors.append(f"support_{index}_equals_native")
        if code in seen and code:
            errors.append(f"support_{index}_duplicate")
        if code:
            seen.add(code)
            support_codes.append(code)

    governance = spec.get("governance")
    if not isinstance(governance, dict):
        errors.append("governance_not_object")
    else:
        if governance.get("shared_core_reference") is not True:
            errors.append("shared_core_reference_required")
        if governance.get("duplicate_core") is not False:
            errors.append("duplicate_core_forbidden")
        if governance.get("auto_deploy") is not False:
            errors.append("auto_deploy_forbidden")
        if governance.get("production_change") is not False:
            errors.append("production_change_forbidden")

    for key, msg in (
        ("identity", "identity_instance_specific_required"),
        ("resources", "resources_instance_specific_required"),
        ("rlb", "rlb_instance_specific_required"),
    ):
        value = spec.get(key)
        if not isinstance(value, dict) or value.get("instance_specific") is not True:
            errors.append(msg)

    return {
        "valid": not errors,
        "errors": errors,
        "platform_id": platform_id,
        "native_language": native_code,
        "support_language_codes": support_codes,
    }

def build_materialization_package(spec):
    validation = validate_materialization_spec(spec)
    if not validation["valid"]:
        return {"valid": False, "errors": validation["errors"]}

    platform_id = validation["platform_id"]
    native_code = validation["native_language"]
    support_codes = validation["support_language_codes"]

    files = {
        "instance/platform.json": {
            "platform_id": platform_id,
            "platform_name": _t(spec["platform_name"]),
            "community": spec["community"],
            "native_language": spec["native_language"],
            "support_languages": spec["support_languages"],
            "sgoda_core": {
                "mode": "shared_reference",
                "embedded_copy": False,
            },
        },
        "instance/identity.json": spec["identity"],
        "instance/resources.json": spec["resources"],
        "instance/rlb.json": {
            "instance_specific": True,
            "native_language": native_code,
            "support_languages": support_codes,
            "records": [],
            "bootstrap_state": "EMPTY_READY",
        },
        "instance/governance.json": spec["governance"],
        "instance/rollback-manifest.json": {
            "rollback_supported": True,
            "destructive_cleanup_required": False,
            "production_restore_required": False,
            "scope": "generated_instance_package_only",
        },
    }

    file_hashes = {}
    for path, content in files.items():
        payload = json.dumps(
            content,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        )
        file_hashes[path] = sha256(payload.encode("utf-8")).hexdigest()

    package_manifest = {
        "materialization_contract": "SGODA_INSTANCE_PACKAGE_V1",
        "platform_id": platform_id,
        "native_language": native_code,
        "support_languages": support_codes,
        "shared_core_reference": True,
        "core_duplicated": False,
        "auto_deployed": False,
        "production_changed": False,
        "file_hashes": file_hashes,
    }

    files["instance/package-manifest.json"] = package_manifest

    return {
        "valid": True,
        "platform_id": platform_id,
        "files": files,
        "manifest": package_manifest,
    }

def package_fingerprint(package):
    payload = json.dumps(
        package,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    return sha256(payload.encode("utf-8")).hexdigest()

def reference_kurripaco_materialization_spec():
    return {
        "platform_id": "sgoda-kurripaco",
        "platform_name": "SGODA-KURRIPACO",
        "native_language": {
            "code": "kpc",
            "name": "Kurripaco",
        },
        "support_languages": [
            {"code": "es", "name": "EspaÃ±ol"},
            {"code": "en", "name": "English"},
        ],
        "community": {
            "community_id": "kurripaco",
            "name": "Pueblo Kurripaco",
        },
        "identity": {
            "instance_specific": True,
            "branding": {
                "configurable_per_platform": True,
            },
        },
        "resources": {
            "instance_specific": True,
            "catalog": [],
        },
        "rlb": {
            "instance_specific": True,
        },
        "governance": {
            "shared_core_reference": True,
            "duplicate_core": False,
            "auto_deploy": False,
            "production_change": False,
        },
    }
