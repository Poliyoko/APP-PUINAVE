from typing import Iterable

def evidence_ledger(records: Iterable[dict]) -> list:
    result = []
    for item in records:
        result.append({"control_id": item["control_id"], "status": "PASS" if item["passed"] else "FAIL", "blocking": bool(item["blocking"])})
    return result
