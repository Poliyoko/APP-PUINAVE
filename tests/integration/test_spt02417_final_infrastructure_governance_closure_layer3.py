from sgoda.integration.spt02417l3 import FinalInfrastructureGovernanceService, BLOCKING
L1="INFRASTRUCTURE_SECURITY_GOVERNANCE_GATE_PASS"
L2="ADVANCED_INFRASTRUCTURE_HARDENING_GOVERNANCE_GATE_PASS"
def r(): return FinalInfrastructureGovernanceService().assess(L1,L2)
def test_01(): assert len(BLOCKING)==24
def test_02(): assert r()["status"]=="INSTITUTIONALLY_CLOSED"
def test_03(): assert r()["final_gate"]=="FINAL_INFRASTRUCTURE_GOVERNANCE_GATE_PASS"
def test_04(): assert r()["failed_blocking_controls"]==[]
def test_05(): assert r()["recertification_records"]==9
def test_06(): assert r()["active_network_scan_executed"] is False
def test_07(): assert r()["service_action_executed"] is False
def test_08(): assert r()["port_changed"] is False
def test_09(): assert r()["firewall_changed"] is False
def test_10(): assert r()["network_configuration_changed"] is False
def test_11(): assert r()["tls_configuration_changed"] is False
def test_12(): assert r()["drift_remediation_executed"] is False
def test_13(): assert r()["production_change_executed"] is False
def test_14(): assert r()["external_connection_opened"] is False
def test_15(): assert r()["secret_values_exposed"] is False
def test_16(): assert r()["closed_components_preserved"] is True
def test_17(): assert all(x["status"]=="PASS" for x in r()["recertification"])
def test_18(): assert any(x["domain"]=="HARDENING" for x in r()["recertification"])
def test_19(): assert any(x["domain"]=="SERVICES" for x in r()["recertification"])
def test_20(): assert any(x["domain"]=="PORTS" for x in r()["recertification"])
def test_21(): assert any(x["domain"]=="NETWORK_SEGMENTATION" for x in r()["recertification"])
def test_22(): assert any(x["domain"]=="TLS_SECURE_COMMUNICATIONS" for x in r()["recertification"])
def test_23(): assert any(x["domain"]=="SECURE_CONFIGURATION" for x in r()["recertification"])
def test_24(): assert any(x["domain"]=="CONFIGURATION_DRIFT" for x in r()["recertification"])
def test_25(): assert any(x["domain"]=="INFRASTRUCTURE_CHANGES" for x in r()["recertification"])
def test_26(): assert any(x["domain"]=="INTEGRITY" for x in r()["recertification"])
def test_27(): assert r()["blocking_controls"]==24
