from copy import deepcopy
from hashlib import sha256
import json
import re

ID_RE = re.compile(r"^[a-z0-9][a-z0-9._-]*$")
VERSION_RE = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")

def _t(value):
    return str(value or "").strip()

def normalize_id(value):
    value = _t(value).lower().replace(" ", "-").replace("_", "-")
    return re.sub(r"-+", "-", value)

def normalize_code(value):
    return _t(value).lower().replace("_", "-")

def validate_template(template):
    errors = []
    if not isinstance(template, dict):
        return {"valid": False, "errors": ["template_not_object"]}

    required = ("template_id","version","native_language","support_languages",
                "features","resources","identity","governance")
    for key in required:
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

    supports = template.get("support_languages")
    if not isinstance(supports, dict):
        errors.append("support_languages_contract_invalid")
    else:
        if supports.get("mode") != "CONFIGURABLE_0_TO_N":
            errors.append("support_languages_mode_invalid")
        if supports.get("hard_coded") is not False:
            errors.append("hard_coded_support_languages_forbidden")

    for key in ("features","resources","identity"):
        obj = template.get(key)
        if not isinstance(obj, dict) or obj.get("configurable") is not True:
            errors.append(key + "_configurable_required")

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

    required = ("profile_id","version","template_id","native_language",
                "support_languages","resource_profile","identity_profile","governance")
    for key in required:
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
    normalized_supports = []
    for i, item in enumerate(supports):
        if not isinstance(item, dict):
            errors.append(f"support_{i}_not_object")
            continue
        code = normalize_code(item.get("code"))
        if not code:
            errors.append(f"support_{i}_code_required")
        elif code == native_code:
            errors.append(f"support_{i}_equals_native")
        elif code in seen:
            errors.append(f"support_{i}_duplicate")
        else:
            seen.add(code)
            normalized_supports.append(code)

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
        "support_languages": normalized_supports,
    }

def deep_merge(base, overlay):
    if isinstance(base, dict) and isinstance(overlay, dict):
        result = deepcopy(base)
        for key, value in overlay.items():
            if key in result:
                result[key] = deep_merge(result[key], value)
            else:
                result[key] = deepcopy(value)
        return result
    return deepcopy(overlay)

def validate_inheritance(parent_profile, child_profile):
    errors = []
    p = validate_profile(parent_profile)
    c = validate_profile(child_profile)
    if not p["valid"]:
        errors.extend("parent_" + e for e in p["errors"])
    if not c["valid"]:
        errors.extend("child_" + e for e in c["errors"])
    if p["valid"] and c["valid"]:
        if p["template_id"] != c["template_id"]:
            errors.append("inheritance_template_mismatch")
        if c["native_language"] != p["native_language"]:
            errors.append("inheritance_native_language_change_forbidden")
    return {"valid": not errors, "errors": errors}

def resolve_profile_inheritance(parent_profile, child_overlay):
    child = deep_merge(parent_profile, child_overlay)
    check = validate_inheritance(parent_profile, child)
    return {"valid": check["valid"], "errors": check["errors"], "resolved": child}

def validate_template_profile_compatibility(template, profile):
    errors = []
    t = validate_template(template)
    p = validate_profile(profile)
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

def configuration_quality_gate(template, parent_profile, child_overlay):
    resolved = resolve_profile_inheritance(parent_profile, child_overlay)
    if not resolved["valid"]:
        return {"pass": False, "errors": resolved["errors"]}
    compatibility = validate_template_profile_compatibility(template, resolved["resolved"])
    result = validate_profile(resolved["resolved"])
    errors = list(compatibility["errors"]) + list(result["errors"])
    return {
        "pass": not errors,
        "errors": errors,
        "resolved_profile": resolved["resolved"],
        "sha256": fingerprint(resolved["resolved"]),
        "native_language": result.get("native_language"),
        "support_languages": result.get("support_languages", []),
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

def generic_parent_profile():
    return {
        "profile_id": "example-parent-profile",
        "version": "1.0.0",
        "template_id": "sgoda-language-platform-standard",
        "native_language": {"code": "qaa", "name": "Example Native Language"},
        "support_languages": [
            {"code": "es", "name": "EspaÃ±ol"},
            {"code": "en", "name": "English"},
        ],
        "resource_profile": {"bible": {"enabled": False, "url": None}},
        "identity_profile": {"community": "Example Community", "branding": "configurable"},
        "governance": {
            "example_only": True,
            "auto_deploy": False,
            "production_change": False,
        },
    }

def generic_child_overlay():
    return {
        "profile_id": "example-child-profile",
        "version": "1.0.1",
        "support_languages": [
            {"code": "es", "name": "EspaÃ±ol"},
            {"code": "en", "name": "English"},
            {"code": "it", "name": "Italiano"},
            {"code": "pt", "name": "PortuguÃªs"},
        ],
        "identity_profile": {"theme": "configurable"},
    }
