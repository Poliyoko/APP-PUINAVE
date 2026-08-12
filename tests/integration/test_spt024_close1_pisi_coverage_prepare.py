from sgoda.integration.spt024close1 import EXPECTED, build_coverage, summarize, component_from_path

def synthetic_paths():
    p=[]
    for i in range(1,18):
        c=f"SPT-024.{i}"
        p += [
            f"docs/06_Tecnologia/SPT-024/{c}/SGD-{c}.md",
            f"artifacts/development/{c}-v1.0.0/implementation-evidence.json",
            f"tests/integration/test_{c.replace('.','_').replace('-','_')}.py",
            f"config/integration/{c.replace('.','').replace('-','').lower()}/policy.json",
            f"Invoke-SGODA-{c.replace('.','')}-FINAL-v1.0.0-PS51.ps1",
        ]
    return p

def test_01_expected_count(): assert len(EXPECTED)==17
def test_02_first(): assert EXPECTED[0]=="SPT-024.1"
def test_03_last(): assert EXPECTED[-1]=="SPT-024.17"
def test_04_parser_1(): assert component_from_path("docs/SPT-024.1/x.md")=="SPT-024.1"
def test_05_parser_10(): assert component_from_path("x/SPT-024.10/y")=="SPT-024.10"
def test_06_parser_17(): assert component_from_path("x/SPT-024.17/y")=="SPT-024.17"
def test_07_parser_none(): assert component_from_path("SPT-024.170") is None
def test_07a_parser_underscore(): assert component_from_path("tests/test_SPT_024_17.py")=="SPT-024.17"
def test_07b_parser_compact_config(): assert component_from_path("config/spt02417/policy.json")=="SPT-024.17"
def test_07c_parser_compact_exec(): assert component_from_path("Invoke-SGODA-SPT-02417-FINAL.ps1")=="SPT-024.17"
def test_07d_parser_compact_exec_10(): assert component_from_path("Invoke-SGODA-SPT-02410-FINAL.ps1")=="SPT-024.10"
def test_08_coverage_len(): assert len(build_coverage(synthetic_paths()))==17
def test_09_all_covered(): assert all(x["covered"] for x in build_coverage(synthetic_paths()))
def test_10_docs(): assert all(x["docs"]==1 for x in build_coverage(synthetic_paths()))
def test_11_artifacts(): assert all(x["artifacts"]==1 for x in build_coverage(synthetic_paths()))
def test_12_tests(): assert all(x["tests"]==1 for x in build_coverage(synthetic_paths()))
def test_13_config(): assert all(x["config"]==1 for x in build_coverage(synthetic_paths()))
def test_14_exec(): assert all(x["executable"]==1 for x in build_coverage(synthetic_paths()))
def test_15_summary_pass(): assert summarize(synthetic_paths())["global_status"]=="PISI_GLOBAL_PREPARE_GATE_PASS"
def test_16_covered_count(): assert summarize(synthetic_paths())["covered_components"]==17
def test_17_missing_empty(): assert summarize(synthetic_paths())["missing_components"]==[]
def test_18_missing_one(): assert "SPT-024.17" in summarize([p for p in synthetic_paths() if "SPT-024.17" not in p])["missing_components"]
def test_19_hold(): assert summarize([p for p in synthetic_paths() if "SPT-024.17" not in p])["global_status"]=="PISI_GLOBAL_PREPARE_GATE_HOLD"
def test_20_nonempty_files(): assert all(x["files"]>=2 for x in build_coverage(synthetic_paths()))
