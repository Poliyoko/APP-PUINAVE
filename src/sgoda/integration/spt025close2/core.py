from hashlib import sha256
import json

EXPECTED_COMPONENTS = [f"SPT-025.{i}" for i in range(1,17)]

def fingerprint(value):
    payload=json.dumps(value,ensure_ascii=False,sort_keys=True,separators=(",",":"))
    return sha256(payload.encode("utf-8")).hexdigest()

def validate_close1_gate(data):
    errors=[]
    if not isinstance(data,dict):
        return {"valid":False,"errors":["close1_gate_not_object"]}
    if data.get("status")!="SPT025_GLOBAL_CLOSURE_PREPARE_GATE_PASS":
        errors.append("close1_global_gate_not_pass")
    if data.get("component_coverage")!="16/16":
        errors.append("component_coverage_not_16_of_16")
    if data.get("replicability")!="PASS":
        errors.append("replicability_not_pass")
    if data.get("global_quality_gate")!="PASS":
        errors.append("global_quality_gate_not_pass")
    if data.get("institutional_closure_prepare")!="APPROVED":
        errors.append("closure_prepare_not_approved")
    if data.get("real_platform_deployed") is not False:
        errors.append("real_platform_deployment_forbidden")
    if data.get("production_change") is not False:
        errors.append("production_change_forbidden")
    return {"valid":not errors,"errors":errors}

def build_master_ledger(component_records):
    errors=[]
    if not isinstance(component_records,list):
        return {"valid":False,"errors":["component_records_not_list"]}
    by_id={}
    for i,row in enumerate(component_records):
        if not isinstance(row,dict):
            errors.append(f"record_{i}_not_object")
            continue
        cid=str(row.get("component") or "").strip()
        if cid not in EXPECTED_COMPONENTS:
            errors.append(f"record_{i}_component_invalid")
            continue
        if cid in by_id:
            errors.append(f"record_{i}_duplicate_component")
            continue
        if row.get("closed") is not True:
            errors.append(f"record_{i}_not_closed")
        if row.get("preserved") is not True:
            errors.append(f"record_{i}_not_preserved")
        by_id[cid]=row
    missing=[x for x in EXPECTED_COMPONENTS if x not in by_id]
    if missing:
        errors.extend("missing_"+x for x in missing)
    ordered=[by_id[x] for x in EXPECTED_COMPONENTS if x in by_id]
    return {
        "valid":not errors,
        "errors":errors,
        "contract":"SGODA_SPT025_MASTER_CLOSURE_LEDGER_V1",
        "records":ordered,
        "closed_components":len([x for x in ordered if x.get("closed") is True]),
        "preserved_components":len([x for x in ordered if x.get("preserved") is True]),
        "sha256":fingerprint(ordered),
    }

def build_global_manifest(close1_gate, master_ledger):
    gate=validate_close1_gate(close1_gate)
    errors=list(gate["errors"])
    if not master_ledger.get("valid"):
        errors.extend("ledger_"+x for x in master_ledger.get("errors",[]))
    return {
        "valid":not errors,
        "errors":errors,
        "contract":"SGODA_SPT025_GLOBAL_CLOSURE_MANIFEST_V1",
        "component_coverage":"16/16",
        "replicability":"PASS" if not errors else "FAIL",
        "master_ledger_sha256":master_ledger.get("sha256"),
        "real_platform_deployed":False,
        "auto_deployment":False,
        "production_change":False,
        "core_duplicated":False,
    }

def final_recertification(close1_gate, master_ledger, global_manifest):
    errors=[]
    if not validate_close1_gate(close1_gate)["valid"]:
        errors.append("close1_gate_invalid")
    if not master_ledger.get("valid"):
        errors.append("master_ledger_invalid")
    if not global_manifest.get("valid"):
        errors.append("global_manifest_invalid")
    if master_ledger.get("closed_components")!=16:
        errors.append("closed_components_not_16")
    if master_ledger.get("preserved_components")!=16:
        errors.append("preserved_components_not_16")
    return {
        "pass":not errors,
        "errors":errors,
        "status":"INSTITUTIONALLY_CLOSED" if not errors else "HOLD",
        "component_coverage":"16/16",
        "final_recertification":"16/16" if not errors else "INCOMPLETE",
        "real_platform_deployed":False,
        "production_change":False,
    }

def example_component_records():
    return [
        {
            "component":f"SPT-025.{i}",
            "closed":True,
            "preserved":True,
            "repository":"PRESENT",
            "tests":"PASS",
            "evidence":"PRESENT",
        }
        for i in range(1,17)
    ]

def example_close1_gate():
    return {
        "status":"SPT025_GLOBAL_CLOSURE_PREPARE_GATE_PASS",
        "component_coverage":"16/16",
        "replicability":"PASS",
        "global_quality_gate":"PASS",
        "institutional_closure_prepare":"APPROVED",
        "real_platform_deployed":False,
        "production_change":False,
    }
