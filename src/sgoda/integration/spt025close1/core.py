from hashlib import sha256
import json
import re

EXPECTED_COMPONENTS = [f"SPT-025.{i}" for i in range(1, 17)]
FINAL_GATE_STATUSES = {
    "SPT-025.1": "TECHNICALLY_CLOSED",
    "SPT-025.2": "TECHNICALLY_CLOSED",
    "SPT-025.3": "TECHNICALLY_CLOSED",
    "SPT-025.4": "TECHNICALLY_CLOSED",
    "SPT-025.5": "TECHNICALLY_CLOSED",
    "SPT-025.6": "TECHNICALLY_CLOSED",
    "SPT-025.7": "TECHNICALLY_CLOSED",
    "SPT-025.8": "TECHNICALLY_CLOSED",
    "SPT-025.9": "TECHNICALLY_CLOSED",
    "SPT-025.10": "TECHNICALLY_CLOSED",
    "SPT-025.11": "TECHNICALLY_CLOSED",
    "SPT-025.12": "TECHNICALLY_CLOSED",
    "SPT-025.13": "TECHNICALLY_CLOSED",
    "SPT-025.14": "TECHNICALLY_CLOSED",
    "SPT-025.15": "TECHNICALLY_CLOSED",
    "SPT-025.16": "TECHNICALLY_CLOSED",
}

def fingerprint(value):
    payload = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return sha256(payload.encode("utf-8")).hexdigest()

def component_from_path(path):
    p = str(path or "").replace("\\", "/")
    m = re.search(r"SPT-025\.(1[0-6]|[1-9])(?:[^0-9]|$)", p, re.I)
    return f"SPT-025.{int(m.group(1))}" if m else None

def build_coverage(paths):
    paths = [str(x).replace("\\", "/") for x in paths]
    rows = []
    for component in EXPECTED_COMPONENTS:
        n = component.split(".")[-1]
        needles = [
            f"SPT-025.{n}",
            f"spt025{n}",
            f"spt025-{n}",
        ]
        hits = [p for p in paths if any(x.lower() in p.lower() for x in needles)]
        rows.append({
            "component": component,
            "present": bool(hits),
            "path_count": len(hits),
            "code": any("/src/" in ("/"+p.lower()) or p.lower().startswith("src/") for p in hits),
            "tests": any("/tests/" in ("/"+p.lower()) or p.lower().startswith("tests/") for p in hits),
            "config": any("/config/" in ("/"+p.lower()) or p.lower().startswith("config/") for p in hits),
            "docs": any("/docs/" in ("/"+p.lower()) or p.lower().startswith("docs/") for p in hits),
            "evidence": any("artifacts/development/" in p.lower() for p in hits),
            "executable": any(p.lower().endswith(".ps1") and f"spt025{n}" in p.lower().replace(".","") for p in hits),
        })
    return rows

def summarize_coverage(rows):
    missing = [r["component"] for r in rows if not r["present"]]
    incomplete = [
        r["component"] for r in rows
        if not all(r[k] for k in ("code","tests","config","docs","evidence","executable"))
    ]
    return {
        "expected_components": len(EXPECTED_COMPONENTS),
        "covered_components": len(EXPECTED_COMPONENTS) - len(missing),
        "missing_components": missing,
        "incomplete_components": incomplete,
        "coverage_percent": round((len(EXPECTED_COMPONENTS)-len(missing))*100/len(EXPECTED_COMPONENTS), 2),
        "complete": not missing and not incomplete,
    }

def validate_replicability_contract(contract):
    errors = []
    if not isinstance(contract, dict):
        return {"valid": False, "errors": ["contract_not_object"]}
    if contract.get("one_native_language_per_platform") is not True:
        errors.append("one_native_language_per_platform_required")
    if contract.get("support_languages") != "0..N_CONFIGURABLE":
        errors.append("support_languages_contract_invalid")
    if contract.get("hard_coded_support_languages") is not False:
        errors.append("hard_coded_support_languages_forbidden")
    if contract.get("shared_core_reference") is not True:
        errors.append("shared_core_reference_required")
    if contract.get("core_duplicated") is not False:
        errors.append("core_duplication_forbidden")
    if contract.get("rlb_instance_specific") is not True:
        errors.append("rlb_instance_specific_required")
    if contract.get("resources_instance_specific") is not True:
        errors.append("resources_instance_specific_required")
    if contract.get("identity_instance_specific") is not True:
        errors.append("identity_instance_specific_required")
    if contract.get("real_platform_deployed") is not False:
        errors.append("real_platform_deployment_forbidden")
    return {"valid": not errors, "errors": errors}

def global_quality_gate(rows, replicability_contract, final_promotion_gate):
    coverage = summarize_coverage(rows)
    repl = validate_replicability_contract(replicability_contract)
    errors = []
    if not coverage["complete"]:
        errors.append("coverage_incomplete")
    if not repl["valid"]:
        errors.extend("replicability_" + x for x in repl["errors"])
    if final_promotion_gate != "PASS":
        errors.append("final_promotion_gate_not_pass")
    return {
        "pass": not errors,
        "errors": errors,
        "coverage": coverage,
        "replicability": repl,
        "final_promotion_gate": final_promotion_gate,
        "institutional_closure_prepare": "APPROVED" if not errors else "HOLD",
    }

def synthetic_paths():
    rows = []
    for i in range(1,17):
        rows.extend([
            f"Invoke-SGODA-SPT025{i}-Synthetic-FINAL-v1.0.0-PS51.ps1",
            f"src/sgoda/integration/spt025{i}/core.py",
            f"tests/integration/test_spt025{i}_synthetic.py",
            f"config/integration/spt025{i}/policy.json",
            f"docs/06_Tecnologia/SPT-025/SPT-025.{i}/SGD-SPT025.{i}.md",
            f"artifacts/development/SPT-025.{i}-v1.0.0/implementation-evidence.json",
        ])
    return rows

def reference_replicability_contract():
    return {
        "one_native_language_per_platform": True,
        "support_languages": "0..N_CONFIGURABLE",
        "hard_coded_support_languages": False,
        "shared_core_reference": True,
        "core_duplicated": False,
        "rlb_instance_specific": True,
        "resources_instance_specific": True,
        "identity_instance_specific": True,
        "real_platform_deployed": False,
    }
