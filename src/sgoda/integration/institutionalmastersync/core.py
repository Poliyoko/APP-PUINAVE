from hashlib import sha256
import json

MASTER_DOCUMENTS = [
    "docs/00_Estado_Maestro/SGD-000-Estado-Maestro-Institucional-v1.0.0.md",
    "docs/00_Estado_Maestro/SGD-002-Libro-Maestro-Institucional-SGODA-PUINAVE-v1.0.0.md",
    "docs/00_Estado_Maestro/RMI-021.2-Registro-Maestro-Institucional-Implementaciones-v1.0.0.md",
    "docs/00_INDICE_MAESTRO.md",
    "docs/00_REGISTRO_MAESTRO_COMPONENTES.md",
    "docs/01_Gobierno/SGD-100-Norma-Institucional-Nomenclatura.md",
]

def fingerprint(value):
    payload=json.dumps(value,ensure_ascii=False,sort_keys=True,separators=(",",":"))
    return sha256(payload.encode("utf-8")).hexdigest()

def validate_master_inventory(records):
    errors=[]
    if not isinstance(records,list):
        return {"valid":False,"errors":["records_not_list"]}
    by_path={}
    for i,row in enumerate(records):
        if not isinstance(row,dict):
            errors.append(f"record_{i}_not_object")
            continue
        p=row.get("path")
        if not p:
            errors.append(f"record_{i}_path_required")
            continue
        by_path[p]=row
        if row.get("tracked") is not True:
            errors.append(f"record_{i}_not_tracked")
        if row.get("exists") is not True:
            errors.append(f"record_{i}_not_present")
    missing=[p for p in MASTER_DOCUMENTS if p not in by_path]
    errors.extend("missing_"+p for p in missing)
    return {"valid":not errors,"errors":errors,"count":len(by_path)}

def validate_spt025_closure(close_assessment, manifest):
    errors=[]
    if not isinstance(close_assessment,dict) or not isinstance(manifest,dict):
        return {"valid":False,"errors":["closure_inputs_invalid"]}
    if close_assessment.get("status")!="INSTITUTIONALLY_CLOSED":
        errors.append("spt025_not_institutionally_closed")
    if close_assessment.get("final_gate")!="SPT025_INSTITUTIONAL_CLOSURE_GATE_PASS":
        errors.append("spt025_final_gate_not_pass")
    if int(close_assessment.get("recertified_components",0))!=16:
        errors.append("recertified_components_not_16")
    if manifest.get("component_coverage")!="16/16":
        errors.append("manifest_coverage_not_16_16")
    if manifest.get("replicability")!="PASS":
        errors.append("replicability_not_pass")
    if manifest.get("real_platform_deployed") is not False:
        errors.append("real_platform_deployed_forbidden")
    if manifest.get("core_duplicated") is not False:
        errors.append("core_duplication_forbidden")
    return {"valid":not errors,"errors":errors}

def build_traceability_rows(component_commits):
    rows=[]
    for i in range(1,17):
        cid=f"SPT-025.{i}"
        c=component_commits.get(cid)
        rows.append({
            "component":cid,
            "status":"INSTITUTIONALLY_CLOSED",
            "commit":c or "UNRESOLVED",
            "evidence_root":f"artifacts/development/SPT-025.{i}-v1.0.0",
            "documentation_root":f"docs/06_Tecnologia/SPT-025/SPT-025.{i}",
            "preserved":True,
        })
    return rows

def global_sync_gate(master_inventory, closure_validation, traceability_rows, repository_state):
    errors=[]
    if not master_inventory.get("valid"):
        errors.extend("master_"+x for x in master_inventory.get("errors",[]))
    if not closure_validation.get("valid"):
        errors.extend("closure_"+x for x in closure_validation.get("errors",[]))
    unresolved=[r["component"] for r in traceability_rows if r.get("commit")=="UNRESOLVED"]
    if unresolved:
        errors.extend("unresolved_commit_"+x for x in unresolved)
    if repository_state.get("local_head")!=repository_state.get("remote_head"):
        errors.append("local_remote_mismatch")
    if repository_state.get("staged",0)!=0:
        errors.append("staged_not_zero")
    if repository_state.get("deleted_tracked",0)!=0:
        errors.append("deleted_tracked_not_zero")
    return {
        "pass":not errors,
        "errors":errors,
        "spt025_reconciled":not closure_validation.get("errors"),
        "master_documents_reconciled":not master_inventory.get("errors"),
        "traceability_reconciled":not unresolved,
        "repository_reconciled":repository_state.get("local_head")==repository_state.get("remote_head"),
    }

def reference_master_inventory():
    return [{"path":p,"tracked":True,"exists":True} for p in MASTER_DOCUMENTS]

def reference_closure():
    return (
        {
            "status":"INSTITUTIONALLY_CLOSED",
            "final_gate":"SPT025_INSTITUTIONAL_CLOSURE_GATE_PASS",
            "recertified_components":16,
        },
        {
            "component_coverage":"16/16",
            "replicability":"PASS",
            "real_platform_deployed":False,
            "core_duplicated":False,
        },
    )
