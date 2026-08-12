from dataclasses import dataclass
import re

EXPECTED = tuple(f"SPT-024.{i}" for i in range(1,18))

@dataclass(frozen=True)
class CoverageRecord:
    component: str
    files: int
    docs: int
    artifacts: int
    tests: int
    config: int
    executable: int
    covered: bool

def component_from_path(path):
    normalized = str(path).replace("\\\\", "/")
    patterns = (
        r"SPT-024\.(1[0-7]|[1-9])(?!\d)",
        r"SPT_024_(1[0-7]|[1-9])(?!\d)",
        r"SPT-024(1[0-7]|[1-9])(?!\d)",
        r"SPT024(1[0-7]|[1-9])(?!\d)",
    )
    for pattern in patterns:
        m = re.search(pattern, normalized, re.I)
        if m:
            return f"SPT-024.{int(m.group(1))}"
    return None

def build_coverage(paths):
    result=[]
    for component in EXPECTED:
        matched=[p for p in paths if component_from_path(p)==component]
        lowered=[p.lower().replace("\\\\","/") for p in matched]
        docs=sum(1 for p in lowered if p.startswith("docs/"))
        artifacts=sum(1 for p in lowered if p.startswith("artifacts/"))
        tests=sum(1 for p in lowered if p.startswith("tests/"))
        config=sum(1 for p in lowered if p.startswith("config/"))
        executable=sum(1 for p in lowered if p.endswith(".ps1") and ("invoke-sgoda" in p or "install-" in p))
        covered=bool(matched) and (docs>0 or artifacts>0)
        result.append(CoverageRecord(component,len(matched),docs,artifacts,tests,config,executable,covered).__dict__)
    return result

def summarize(paths):
    coverage=build_coverage(paths)
    missing=[x["component"] for x in coverage if not x["covered"]]
    return {
        "expected_components": len(EXPECTED),
        "covered_components": len(EXPECTED)-len(missing),
        "missing_components": missing,
        "coverage": coverage,
        "global_status": "PISI_GLOBAL_PREPARE_GATE_PASS" if not missing else "PISI_GLOBAL_PREPARE_GATE_HOLD",
    }
