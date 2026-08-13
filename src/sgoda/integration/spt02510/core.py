from hashlib import sha256
import json
import re

INSTANCE_ID_RE = re.compile(r"^sgoda-[a-z0-9][a-z0-9-]*$")
VERSION_RE = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")

ALLOWED_STATES = (
    "DRAFT", "VALIDATED", "MATERIALIZED", "REGISTERED",
    "SUSPENDED", "RETIRED", "ARCHIVED"
)

def _t(value):
    return str(value or "").strip()

def normalize_code(value):
    return _t(value).lower().replace("_", "-")

def normalize_instance_id(value):
    text = _t(value).lower().replace("_", "-").replace(" ", "-")
    return re.sub(r"-+", "-", text)

def validate_registry_record(record):
    errors = []
    if not isinstance(record, dict):
        return {"valid": False, "errors": ["record_not_object"]}
    required = ("instance_id","native_language","support_languages","package","lifecycle","governance")
    for key in required:
        if key not in record:
            errors.append("missing_" + key)
    instance_id = normalize_instance_id(record.get("instance_id"))
    if not INSTANCE_ID_RE.match(instance_id or ""):
        errors.append("instance_id_invalid")
    native = record.get("native_language")
    native_code = normalize_code(native.get("code")) if isinstance(native, dict) else ""
    if not native_code:
        errors.append("native_language_required")
    supports = record.get("support_languages")
    if not isinstance(supports, list):
        errors.append("support_languages_not_list")
        supports = []
    seen = set()
    support_codes = []
    for i,item in enumerate(supports):
        if not isinstance(item, dict):
            errors.append(f"support_{i}_not_object"); continue
        code = normalize_code(item.get("code"))
        if not code:
            errors.append(f"support_{i}_code_required")
        elif code == native_code:
            errors.append(f"support_{i}_equals_native")
        elif code in seen:
            errors.append(f"support_{i}_duplicate")
        else:
            seen.add(code); support_codes.append(code)
    package = record.get("package")
    if not isinstance(package, dict):
        errors.append("package_not_object")
    else:
        if not VERSION_RE.match(_t(package.get("version"))):
            errors.append("package_version_invalid")
        digest = _t(package.get("sha256")).lower()
        if len(digest) != 64 or any(c not in "0123456789abcdef" for c in digest):
            errors.append("package_sha256_invalid")
    lifecycle = record.get("lifecycle")
    state = _t(lifecycle.get("state")).upper() if isinstance(lifecycle, dict) else ""
    if state not in ALLOWED_STATES:
        errors.append("lifecycle_state_invalid")
    governance = record.get("governance")
    if not isinstance(governance, dict):
        errors.append("governance_not_object")
    else:
        if governance.get("shared_core_reference") is not True:
            errors.append("shared_core_reference_required")
        if governance.get("core_duplicated") is not False:
            errors.append("core_duplication_forbidden")
        if governance.get("auto_deployed") is not False:
            errors.append("auto_deployment_forbidden")
        if governance.get("production_changed") is not False:
            errors.append("production_change_forbidden")
        if governance.get("example_only") not in (True, False):
            errors.append("example_only_required")
    return {
        "valid": not errors, "errors": errors, "instance_id": instance_id,
        "native_language": native_code, "support_languages": support_codes,
        "state": state,
    }

def record_fingerprint(record):
    payload=json.dumps(record,ensure_ascii=False,sort_keys=True,separators=(",",":"))
    return sha256(payload.encode("utf-8")).hexdigest()

def build_master_registry(records):
    if not isinstance(records, list):
        return {"valid":False,"errors":["records_not_list"]}
    normalized=[]; ids=set(); errors=[]
    for i,record in enumerate(records):
        result=validate_registry_record(record)
        if not result["valid"]:
            errors.extend([f"record_{i}_{e}" for e in result["errors"]]); continue
        if result["instance_id"] in ids:
            errors.append(f"record_{i}_duplicate_instance_id"); continue
        ids.add(result["instance_id"])
        normalized.append({
            "instance_id":result["instance_id"],
            "native_language":result["native_language"],
            "support_languages":result["support_languages"],
            "package_version":record["package"]["version"],
            "package_sha256":record["package"]["sha256"].lower(),
            "lifecycle_state":result["state"],
            "example_only":record["governance"]["example_only"],
            "fingerprint":record_fingerprint(record),
        })
    return {
        "valid":not errors, "errors":errors,
        "registry_contract":"SGODA_MASTER_INSTANCE_REGISTRY_V1",
        "records":normalized,
        "real_instances":sum(1 for x in normalized if not x["example_only"]),
        "example_records":sum(1 for x in normalized if x["example_only"]),
    }

def can_transition(current_state, target_state):
    current=_t(current_state).upper(); target=_t(target_state).upper()
    transitions={
        "DRAFT":{"VALIDATED","ARCHIVED"},
        "VALIDATED":{"MATERIALIZED","ARCHIVED"},
        "MATERIALIZED":{"REGISTERED","ARCHIVED"},
        "REGISTERED":{"SUSPENDED","RETIRED"},
        "SUSPENDED":{"REGISTERED","RETIRED"},
        "RETIRED":{"ARCHIVED"},
        "ARCHIVED":set(),
    }
    return target in transitions.get(current,set())

def example_reference_record():
    # Deliberately generic: it proves the contract without selecting a real language/community.
    return {
        "instance_id":"sgoda-example-language",
        "native_language":{"code":"qaa","name":"Example Native Language"},
        "support_languages":[
            {"code":"es","name":"EspaÃ±ol"},
            {"code":"en","name":"English"},
            {"code":"it","name":"Italiano"},
            {"code":"pt","name":"PortuguÃªs"},
        ],
        "package":{"version":"1.0.0","sha256":"0"*64},
        "lifecycle":{"state":"MATERIALIZED"},
        "governance":{
            "shared_core_reference":True,
            "core_duplicated":False,
            "auto_deployed":False,
            "production_changed":False,
            "example_only":True,
        },
    }
