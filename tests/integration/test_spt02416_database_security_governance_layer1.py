from sgoda.integration.spt02416 import DatabaseSecurityService
from sgoda.integration.spt02416.gate import DatabaseSecurityGate

def test_blocking_control_count(): assert len(DatabaseSecurityGate.BLOCKING)==14
def test_gate_passes(): assert DatabaseSecurityService().assess(10)["status"]=="DATABASE_SECURITY_GOVERNANCE_GATE_PASS"
def test_no_failed_controls(): assert DatabaseSecurityService().assess(10)["failed_blocking_controls"]==[]
def test_access_governance(): assert DatabaseSecurityService().assess(1)["database_access"]["valid"]
def test_query_security(): assert DatabaseSecurityService().assess(1)["query_security"]["valid"]
def test_integrity_governance(): assert DatabaseSecurityService().assess(1)["data_integrity"]["valid"]
def test_audit_governance(): assert DatabaseSecurityService().assess(1)["database_auditing"]["valid"]
def test_postgresql_hardening(): assert DatabaseSecurityService().assess(1)["postgresql_hardening"]["valid"]
def test_persistence_governance(): assert DatabaseSecurityService().assess(1)["persistence_governance"]["valid"]
def test_no_query_execution(): assert DatabaseSecurityService().assess(1)["production_query_executed"] is False
def test_no_data_change(): assert DatabaseSecurityService().assess(1)["production_data_changed"] is False
def test_no_config_change(): assert DatabaseSecurityService().assess(1)["production_configuration_changed"] is False
def test_no_external_connection(): assert DatabaseSecurityService().assess(1)["external_connection_opened"] is False
def test_no_secret_exposure(): assert DatabaseSecurityService().assess(1)["secret_values_exposed"] is False
