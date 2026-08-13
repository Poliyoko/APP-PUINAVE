from hashlib import sha256
import json
import re

ID_RE = re.compile(r"^[a-z0-9][a-z0-9._-]*$")
VERSION_RE = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")

def _t(value):
    return str(value or "").strip()

def normalize_id(value):
    return _t(value).lower().replace(" ", "-").replace("_", "-")

def normalize_code(value):
    return _t(value).lower().replace("_", "-")

def validate_template(template):
    errors = []
    if not isinstance(template, dict):
        return {"valid": False, "errors": ["template_not_object"]}
    for key in ("template_id","version","native_language","support_languages","features","resources","identity","governance"):
        if key not in template:
            errors.append("missing_" + key)

    tid = normalize_id(template.get("template_id"))
    if not ID_RE.match(tid or ""):
        errors.append("template_id_invalid")
    if not VERSION_RE.match(_t(template.get("version"))):
        errors.append("template_version_invalid")

    native = template.get("native_language")
    if not isinstance(native, dict) or native.get("mode") != "CONFIGURABLE_EXACTLY_ONE":
        errors.append("native_language_contract_invalid")

    support = template.get("support_languages")
    if not isinstance(support, dict):
        errors.append("support_languages_contract_invalid")
    else:
        if support.get("mode") != "CONFIGURABLE_0_TO_N":
            errors.append("support_languages_mode_invalid")
        if support.get("hard_coded") is not False:
            errors.append("hard_coded_support_languages_forbidden")

    for key, msg in (
        ("resources","resources_configurable_required"),
        ("identity","identity_configurable_required"),
        ("features","features_configurable_required"),
    ):
        value = template.get(key)
        if not isinstance(value, dict) or value.get("configurable") is not True:
            errors.append(msg)

    governance = template.get("governance")
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

    return {"valid": not errors, "errors": errors, "template_id": tid}

def validate_profile(profile):
    errors = []
    if not isinstance(profile, dict):
        return {"valid": False, "errors": ["profile_not_object"]}
    for key in ("profile_id","version","template_id","native_language","support_languages","resource_profile","identity_profile","governance"):
        if key not in profile:
            errors.append("missing_" + key)

    pid = normalize_id(profile.get("profile_id"))
    tid = normalize_id(profile.get("template_id"))
    if not ID_RE.match(pid or ""):
        errors.append("profile_id_invalid")
    if not ID_RE.match(tid or ""):
        errors.append("template_id_invalid")
    if not VERSION_RE.match(_t(profile.get("version"))):
        errors.append("profile_version_invalid")

    native = profile.get("native_language")
    native_code = normalize_code(native.get("code")) if isinstance(native, dict) else ""
    if not native_code:
        errors.append("native_language_required")

    supports = profile.get("support_languages")
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
        elif code == native_code:
            errors.append(f"support_{index}_equals_native")
        elif code in seen:
            errors.append(f"support_{index}_duplicate")
        else:
            seen.add(code)
            support_codes.append(code)

    governance = profile.get("governance")
    if not isinstance(governance, dict):
        errors.append("governance_not_object")
    else:
        if governance.get("example_only") not in (True, False):
            errors.append("example_only_required")
        if governance.get("auto_deploy") is not False:
            errors.append("auto_deploy_forbidden")
        if governance.get("production_change") is not False:
            errors.append("production_change_forbidden")

    return {
        "valid": not errors,
        "errors": errors,
        "profile_id": pid,
        "template_id": tid,
        "native_language": native_code,
        "support_languages": support_codes,
    }

def template_profile_compatible(template, profile):
    t = validate_template(template)
    p = validate_profile(profile)
    errors = []
    if not t["valid"]:
        errors.extend("template_" + e for e in t["errors"])
    if not p["valid"]:
        errors.extend("profile_" + e for e in p["errors"])
    if t["valid"] and p["valid"] and t["template_id"] != p["template_id"]:
        errors.append("profile_template_mismatch")
    return {"compatible": not errors, "errors": errors}

def fingerprint(value):
    payload = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return sha256(payload.encode("utf-8")).hexdigest()

def build_catalog(templates, profiles):
    if not isinstance(templates, list) or not isinstance(profiles, list):
        return {"valid": False, "errors": ["catalog_inputs_not_lists"]}
    errors = []
    template_ids = set()
    profile_ids = set()
    template_records = []
    profile_records = []

    for i, template in enumerate(templates):
        result = validate_template(template)
        if not result["valid"]:
            errors.extend(f"template_{i}_{e}" for e in result["errors"])
            continue
        if result["template_id"] in template_ids:
            errors.append(f"template_{i}_duplicate_id")
            continue
        template_ids.add(result["template_id"])
        template_records.append({
            "template_id": result["template_id"],
            "version": template["version"],
            "fingerprint": fingerprint(template),
        })

    for i, profile in enumerate(profiles):
        result = validate_profile(profile)
        if not result["valid"]:
            errors.extend(f"profile_{i}_{e}" for e in result["errors"])
            continue
        if result["profile_id"] in profile_ids:
            errors.append(f"profile_{i}_duplicate_id")
            continue
        profile_ids.add(result["profile_id"])
        profile_records.append({
            "profile_id": result["profile_id"],
            "template_id": result["template_id"],
            "version": profile["version"],
            "native_language": result["native_language"],
            "support_languages": result["support_languages"],
            "example_only": profile["governance"]["example_only"],
            "fingerprint": fingerprint(profile),
        })

    for profile in profiles:
        if isinstance(profile, dict):
            tid = normalize_id(profile.get("template_id"))
            if tid and tid not in template_ids:
                errors.append("profile_references_unknown_template")

    return {
        "valid": not errors,
        "errors": errors,
        "catalog_contract": "SGODA_INSTANCE_TEMPLATE_PROFILE_CATALOG_V1",
        "templates": template_records,
        "profiles": profile_records,
        "real_instance_count": 0,
        "example_profile_count": sum(1 for x in profile_records if x["example_only"]),
    }

def generic_template():
    return {
        "template_id": "sgoda-language-platform-standard",
        "version": "1.0.0",
        "native_language": {"mode": "CONFIGURABLE_EXACTLY_ONE"},
        "support_languages": {"mode": "CONFIGURABLE_0_TO_N", "hard_coded": False},
        "features": {"configurable": True},
        "resources": {"configurable": True, "bible_optional": True},
        "identity": {"configurable": True},
        "governance": {
            "shared_core_reference": True,
            "duplicate_core": False,
            "auto_deploy": False,
            "production_change": False,
        },
    }

def generic_example_profile():
    return {
        "profile_id": "example-language-profile",
        "version": "1.0.0",
        "template_id": "sgoda-language-platform-standard",
        "native_language": {"code": "qaa", "name": "Example Native Language"},
        "support_languages": [
            {"code": "es", "name": "EspaÃ±ol"},
            {"code": "en", "name": "English"},
            {"code": "it", "name": "Italiano"},
            {"code": "pt", "name": "PortuguÃªs"},
        ],
        "resource_profile": {"bible": {"enabled": False, "url": None}},
        "identity_profile": {"community": "Example Community", "branding": "configurable"},
        "governance": {
            "example_only": True,
            "auto_deploy": False,
            "production_change": False,
        },
    }
