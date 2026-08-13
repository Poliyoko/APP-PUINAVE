from sgoda.integration.spt024close2 import EXPECTED, validate_close1, build_domain_status, assess

def close1():
    return {"status":"PISI_GLOBAL_PREPARE_GATE_PASS","expected_components":17,"covered_components":17,"missing_components":[]}

def coverage():
    return [{"component":f"SPT-024.{i}","covered":True} for i in range(1,18)]

def test_01_expected(): assert len(EXPECTED)==17
def test_02_close1_pass(): assert validate_close1(close1())
def test_03_close1_hold_status(): assert not validate_close1({**close1(),"status":"HOLD"})
def test_04_close1_hold_count(): assert not validate_close1({**close1(),"covered_components":16})
def test_05_domains_len(): assert len(build_domain_status(coverage()))==17
def test_06_domains_closed(): assert all(x["status"]=="CLOSED_AND_RECERTIFIED" for x in build_domain_status(coverage()))
def test_07_assess_status(): assert assess(close1(),coverage())["status"]=="INSTITUTIONALLY_CLOSED"
def test_08_final_gate(): assert assess(close1(),coverage())["final_gate"]=="PISI_INSTITUTIONAL_CLOSURE_GATE_PASS"
def test_09_failed_empty(): assert assess(close1(),coverage())["failed_blocking_controls"]==[]
def test_10_recertified_17(): assert assess(close1(),coverage())["recertified_domains"]==17
def test_11_prepare_verified(): assert assess(close1(),coverage())["close1_prepare_verified"] is True
def test_12_closed_preserved(): assert assess(close1(),coverage())["closed_components_preserved"] is True
def test_13_no_prod_change(): assert assess(close1(),coverage())["production_change_executed"] is False
def test_14_no_probe(): assert assess(close1(),coverage())["active_security_probe_executed"] is False
def test_15_no_external(): assert assess(close1(),coverage())["external_connection_opened"] is False
def test_16_no_secret(): assert assess(close1(),coverage())["secret_values_exposed"] is False
def test_17_missing_domain_hold(): assert assess(close1(),coverage()[:-1])["status"]=="HOLD"
def test_18_missing_domain_gate(): assert assess(close1(),coverage()[:-1])["final_gate"]=="PISI_INSTITUTIONAL_CLOSURE_GATE_HOLD"
def test_19_missing_domain_failed(): assert "DOMAIN_RECERTIFICATION" in assess(close1(),coverage()[:-1])["failed_blocking_controls"]
def test_20_close1_failed(): assert "CLOSE1_PREPARE_GATE" in assess({"status":"HOLD"},coverage())["failed_blocking_controls"]
