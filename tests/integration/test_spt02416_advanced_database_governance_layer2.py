from sgoda.integration.spt02416l2 import AdvancedDatabaseGovernanceService
from sgoda.integration.spt02416l2.gate import AdvancedDatabaseGovernanceGate

def test_blocking_control_count(): assert len(AdvancedDatabaseGovernanceGate.BLOCKING)==18
def test_gate_passes(): assert AdvancedDatabaseGovernanceService().assess(10)["status"]=="ADVANCED_DATABASE_GOVERNANCE_GATE_PASS"
def test_no_failed_controls(): assert AdvancedDatabaseGovernanceService().assess(10)["failed_blocking_controls"]==[]
def test_roles_privileges(): assert AdvancedDatabaseGovernanceService().assess(1)["roles_privileges"]["valid"]
def test_schema_security(): assert AdvancedDatabaseGovernanceService().assess(1)["schema_security"]["valid"]
def test_migration_governance(): assert AdvancedDatabaseGovernanceService().assess(1)["migration_governance"]["valid"]
def test_advanced_auditing(): assert AdvancedDatabaseGovernanceService().assess(1)["advanced_auditing"]["valid"]
def test_transactional_integrity(): assert AdvancedDatabaseGovernanceService().assess(1)["transactional_integrity"]["valid"]
def test_persistence_protection(): assert AdvancedDatabaseGovernanceService().assess(1)["persistence_protection"]["valid"]
def test_postgresql_governance(): assert AdvancedDatabaseGovernanceService().assess(1)["postgresql_governance"]["valid"]
def test_no_role_change(): assert AdvancedDatabaseGovernanceService().assess(1)["roles_privileges"]["real_role_changed"] is False
def test_no_schema_change(): assert AdvancedDatabaseGovernanceService().assess(1)["schema_security"]["schema_changed"] is False
def test_no_migration_execution(): assert AdvancedDatabaseGovernanceService().assess(1)["migration_governance"]["migration_executed"] is False
def test_no_audit_config_change(): assert AdvancedDatabaseGovernanceService().assess(1)["advanced_auditing"]["audit_configuration_changed"] is False
def test_no_transaction_execution(): assert AdvancedDatabaseGovernanceService().assess(1)["transactional_integrity"]["transaction_executed"] is False
def test_no_persistence_change(): assert AdvancedDatabaseGovernanceService().assess(1)["persistence_protection"]["persistence_changed"] is False
def test_no_external_connection(): assert AdvancedDatabaseGovernanceService().assess(1)["external_connection_opened"] is False
def test_no_secret_exposure(): assert AdvancedDatabaseGovernanceService().assess(1)["secret_values_exposed"] is False
