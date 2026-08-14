from hashlib import sha256
import json

FINAL_STATES = {"APPROVED", "PUBLISHED", "RETIRED"}

def fingerprint(value):
    payload = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return sha256(payload.encode("utf-8")).hexdigest()

def validate_publication_assessment(data):
    errors = []
    if not isinstance(data, dict):
        return {"valid": False, "errors": ["assessment_not_object"]}
    if data.get("status") != "DECLARATIVE_PACKAGE_PUBLICATION_GOVERNANCE_GATE_PASS":
        errors.append("publication_governance_gate_not_pass")
    if data.get("real_platform_count") not in (0, "0"):
        errors.append("real_platform_count_must_be_zero")
    if data.get("auto_deployment") not in (False, None):
        errors.append("auto_deployment_forbidden")
    if data.get("production_change") not in (False, None):
        errors.append("production_change_forbidden")
    if data.get("historical_kurripaco_reference_is_real_instance") not in (False, None):
        errors.append("example_reference_promoted_to_real_instance")
    return {"valid": not errors, "errors": errors}

def validate_materialization_registry(registry):
    errors = []
    if not isinstance(registry, dict):
        return {"valid": False, "errors": ["registry_not_object"], "records": []}
    if registry.get("contract") != "SGODA_MATERIALIZATION_REGISTRY_V1":
        errors.append("registry_contract_invalid")
    records = registry.get("records")
    if not isinstance(records, list):
        errors.append("records_not_list")
        records = []
    seen = set()
    for i, record in enumerate(records):
        if not isinstance(record, dict):
            errors.append(f"record_{i}_not_object")
            continue
        rid = str(record.get("materialization_id") or "").strip()
        if not rid:
            errors.append(f"record_{i}_id_required")
        elif rid in seen:
            errors.append(f"record_{i}_duplicate_id")
        else:
            seen.add(rid)
        if record.get("real_platform") is True:
            errors.append(f"record_{i}_real_platform_forbidden")
        if record.get("auto_deployed") is not False:
            errors.append(f"record_{i}_auto_deployed_forbidden")
        if record.get("production_changed") is not False:
            errors.append(f"record_{i}_production_changed_forbidden")
        if record.get("state") not in FINAL_STATES:
            errors.append(f"record_{i}_state_not_final")
    return {
        "valid": not errors,
        "errors": errors,
        "records": records,
        "real_platform_count": sum(1 for x in records if isinstance(x, dict) and x.get("real_platform") is True),
    }

def validate_promotion_ledger(ledger):
    errors = []
    if not isinstance(ledger, dict):
        return {"valid": False, "errors": ["ledger_not_object"], "records": []}
    if ledger.get("contract") != "SGODA_CONTROLLED_PROMOTION_LEDGER_V1":
        errors.append("promotion_contract_invalid")
    records = ledger.get("records")
    if not isinstance(records, list):
        errors.append("promotion_records_not_list")
        records = []
    for i, record in enumerate(records):
        if not isinstance(record, dict):
            errors.append(f"promotion_{i}_not_object")
            continue
        if record.get("valid") is not True:
            errors.append(f"promotion_{i}_not_valid")
        if str(record.get("to_state") or "").upper() not in FINAL_STATES:
            errors.append(f"promotion_{i}_target_not_final")
        if record.get("real_platform_deployed") is not False:
            errors.append(f"promotion_{i}_real_platform_forbidden")
        if record.get("production_changed") is not False:
            errors.append(f"promotion_{i}_production_change_forbidden")
    return {"valid": not errors, "errors": errors, "records": records}

def recertify(assessment, registry, ledger):
    a = validate_publication_assessment(assessment)
    r = validate_materialization_registry(registry)
    l = validate_promotion_ledger(ledger)
    errors = []
    errors.extend("assessment_" + e for e in a["errors"])
    errors.extend("registry_" + e for e in r["errors"])
    errors.extend("ledger_" + e for e in l["errors"])
    return {
        "pass": not errors,
        "errors": errors,
        "publication_recertification": "PASS" if not a["errors"] else "FAIL",
        "registry_recertification": "PASS" if not r["errors"] else "FAIL",
        "promotion_recertification": "PASS" if not l["errors"] else "FAIL",
        "real_platform_count": r.get("real_platform_count", 0),
        "auto_deployment": False,
        "production_change": False,
    }

def build_master_registry(registry):
    check = validate_materialization_registry(registry)
    if not check["valid"]:
        return {"valid": False, "errors": check["errors"]}
    records = list(check["records"])
    return {
        "valid": True,
        "errors": [],
        "contract": "SGODA_MASTER_MATERIALIZATION_REGISTRY_V1",
        "records": records,
        "record_count": len(records),
        "real_platform_count": check["real_platform_count"],
        "sha256": fingerprint(records),
    }

def final_promotion_gate(assessment, registry, ledger):
    rec = recertify(assessment, registry, ledger)
    master = build_master_registry(registry)
    errors = list(rec["errors"])
    if not master.get("valid"):
        errors.extend("master_" + e for e in master.get("errors", []))
    return {
        "pass": not errors,
        "errors": errors,
        "recertification": rec,
        "master_registry": master,
        "final_promotion_state": "APPROVED_FOR_INSTITUTIONAL_CLOSURE" if not errors else "HOLD",
        "real_platform_deployed": False,
        "production_changed": False,
        "core_duplicated": False,
    }

def example_assessment():
    return {
        "status": "DECLARATIVE_PACKAGE_PUBLICATION_GOVERNANCE_GATE_PASS",
        "real_platform_count": 0,
        "historical_kurripaco_reference_is_real_instance": False,
        "auto_deployment": False,
        "production_change": False,
    }

def example_registry():
    return {
        "contract": "SGODA_MATERIALIZATION_REGISTRY_V1",
        "records": [{
            "materialization_id": "example-materialization-001",
            "package_id": "sgoda-example-declarative-package",
            "state": "PUBLISHED",
            "real_platform": False,
            "example_only": True,
            "auto_deployed": False,
            "production_changed": False,
        }],
        "real_platform_count": 0,
        "example_record_count": 1,
    }

def example_ledger():
    return {
        "contract": "SGODA_CONTROLLED_PROMOTION_LEDGER_V1",
        "records": [{
            "valid": True,
            "package_id": "sgoda-example-declarative-package",
            "from_state": "APPROVED",
            "to_state": "PUBLISHED",
            "package_sha256": "0" * 64,
            "real_platform_deployed": False,
            "production_changed": False,
        }],
    }
