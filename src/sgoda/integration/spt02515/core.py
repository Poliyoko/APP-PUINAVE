from hashlib import sha256
import json

ALLOWED_PROMOTIONS = {
    "DRAFT": {"VALIDATED"},
    "VALIDATED": {"APPROVED"},
    "APPROVED": {"PUBLISHED"},
    "PUBLISHED": {"RETIRED"},
    "RETIRED": set(),
}

def fingerprint(value):
    payload=json.dumps(value,ensure_ascii=False,sort_keys=True,separators=(",",":"))
    return sha256(payload.encode("utf-8")).hexdigest()

def can_promote(current_state,target_state):
    current=str(current_state or "").strip().upper()
    target=str(target_state or "").strip().upper()
    return target in ALLOWED_PROMOTIONS.get(current,set())

def validate_publication_package(package):
    errors=[]
    if not isinstance(package,dict):
        return {"valid":False,"errors":["package_not_object"]}
    for k in ("package_id","version","configuration_sha256","materialization_mode","governance"):
        if k not in package:
            errors.append("missing_"+k)
    if not str(package.get("package_id") or "").strip():
        errors.append("package_id_required")
    if not str(package.get("version") or "").strip():
        errors.append("package_version_required")
    digest=str(package.get("configuration_sha256") or "").lower()
    if len(digest)!=64 or any(c not in "0123456789abcdef" for c in digest):
        errors.append("configuration_sha256_invalid")
    if package.get("materialization_mode")!="DECLARATIVE_PACKAGE_ONLY":
        errors.append("materialization_mode_invalid")
    g=package.get("governance",{})
    if not isinstance(g,dict):
        errors.append("governance_not_object")
    else:
        if g.get("shared_core_reference") is not True:
            errors.append("shared_core_reference_required")
        if g.get("core_duplicated") is not False:
            errors.append("core_duplication_forbidden")
        if g.get("auto_deploy") is not False:
            errors.append("auto_deploy_forbidden")
        if g.get("production_change") is not False:
            errors.append("production_change_forbidden")
        if g.get("example_only") not in (True,False):
            errors.append("example_only_required")
    return {"valid":not errors,"errors":errors}

def build_promotion_record(package,current_state,target_state):
    v=validate_publication_package(package)
    errors=list(v["errors"])
    if not can_promote(current_state,target_state):
        errors.append("promotion_transition_forbidden")
    return {
        "valid":not errors,
        "errors":errors,
        "package_id":package.get("package_id") if isinstance(package,dict) else None,
        "from_state":str(current_state).upper(),
        "to_state":str(target_state).upper(),
        "package_sha256":fingerprint(package) if isinstance(package,dict) else None,
        "real_platform_deployed":False,
        "production_changed":False,
    }

def build_materialization_registry(records):
    if not isinstance(records,list):
        return {"valid":False,"errors":["records_not_list"]}
    errors=[]
    seen=set()
    out=[]
    for i,r in enumerate(records):
        if not isinstance(r,dict):
            errors.append(f"record_{i}_not_object")
            continue
        rid=str(r.get("materialization_id") or "").strip()
        if not rid:
            errors.append(f"record_{i}_id_required")
            continue
        if rid in seen:
            errors.append(f"record_{i}_duplicate_id")
            continue
        seen.add(rid)
        out.append(r)
    return {
        "valid":not errors,
        "errors":errors,
        "registry_contract":"SGODA_MATERIALIZATION_REGISTRY_V1",
        "records":out,
        "real_platform_count":sum(1 for x in out if x.get("real_platform") is True),
        "example_record_count":sum(1 for x in out if x.get("example_only") is True),
    }

def example_publication_package():
    return {
        "package_id":"sgoda-example-declarative-package",
        "version":"1.0.0",
        "configuration_sha256":"0"*64,
        "materialization_mode":"DECLARATIVE_PACKAGE_ONLY",
        "governance":{
            "shared_core_reference":True,
            "core_duplicated":False,
            "auto_deploy":False,
            "production_change":False,
            "example_only":True,
        },
    }

def example_materialization_record():
    return {
        "materialization_id":"example-materialization-001",
        "package_id":"sgoda-example-declarative-package",
        "state":"PUBLISHED",
        "real_platform":False,
        "example_only":True,
        "auto_deployed":False,
        "production_changed":False,
    }
