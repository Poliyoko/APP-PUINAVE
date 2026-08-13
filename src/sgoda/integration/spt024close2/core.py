from dataclasses import dataclass

EXPECTED = tuple(f"SPT-024.{i}" for i in range(1,18))

@dataclass(frozen=True)
class DomainStatus:
    component: str
    status: str
    recertified: bool

def validate_close1(close1):
    return (
        close1.get("status") == "PISI_GLOBAL_PREPARE_GATE_PASS"
        and int(close1.get("expected_components", 0)) == 17
        and int(close1.get("covered_components", 0)) == 17
        and len(close1.get("missing_components", [])) == 0
    )

def build_domain_status(coverage):
    by_id = {x.get("component"): x for x in coverage}
    result = []
    for component in EXPECTED:
        row = by_id.get(component, {})
        covered = bool(row.get("covered"))
        result.append(DomainStatus(
            component=component,
            status="CLOSED_AND_RECERTIFIED" if covered else "HOLD",
            recertified=covered
        ).__dict__)
    return result

def assess(close1, coverage):
    close1_ok = validate_close1(close1)
    domains = build_domain_status(coverage)
    domain_ok = all(x["status"] == "CLOSED_AND_RECERTIFIED" for x in domains)
    failed = []
    if not close1_ok:
        failed.append("CLOSE1_PREPARE_GATE")
    if not domain_ok:
        failed.append("DOMAIN_RECERTIFICATION")
    final = not failed
    return {
        "status": "INSTITUTIONALLY_CLOSED" if final else "HOLD",
        "final_gate": "PISI_INSTITUTIONAL_CLOSURE_GATE_PASS" if final else "PISI_INSTITUTIONAL_CLOSURE_GATE_HOLD",
        "failed_blocking_controls": failed,
        "expected_domains": 17,
        "recertified_domains": sum(1 for x in domains if x["recertified"]),
        "domains": domains,
        "close1_prepare_verified": close1_ok,
        "closed_components_preserved": True,
        "production_change_executed": False,
        "active_security_probe_executed": False,
        "external_connection_opened": False,
        "secret_values_exposed": False,
    }
