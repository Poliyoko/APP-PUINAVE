from sgoda.integration.spt02416l3 import FinalDatabaseGovernanceService
from sgoda.integration.spt02416l3.recertification import build_recertification
from sgoda.integration.spt02416l3.governance import final_controls

L1="DATABASE_SECURITY_GOVERNANCE_GATE_PASS"
L2="ADVANCED_DATABASE_GOVERNANCE_GATE_PASS"

def test_thirteen_recertifications(): assert len(build_recertification()) == 13
def test_all_recertified(): assert all(r.decision=="RECERTIFIED" for r in build_recertification())
def test_twenty_five_controls(): assert len(final_controls(L1,L2,build_recertification())) == 25
def test_institutional_closure_passes(): assert FinalDatabaseGovernanceService().assess(L1,L2)["status"]=="INSTITUTIONALLY_CLOSED"
def test_invalid_layer1_holds(): assert FinalDatabaseGovernanceService().assess("BAD",L2)["status"]=="CLOSURE_HOLD"
def test_invalid_layer2_holds(): assert FinalDatabaseGovernanceService().assess(L1,"BAD")["status"]=="CLOSURE_HOLD"
def test_no_failed_controls(): assert FinalDatabaseGovernanceService().assess(L1,L2)["failed_blocking_controls"]==[]
def test_access_governance(): assert FinalDatabaseGovernanceService().assess(L1,L2)["controls"]["database_access_governance"]
def test_query_governance(): assert FinalDatabaseGovernanceService().assess(L1,L2)["controls"]["secure_query_governance"]
def test_integrity_governance(): assert FinalDatabaseGovernanceService().assess(L1,L2)["controls"]["data_integrity_governance"]
def test_auditing_governance(): assert FinalDatabaseGovernanceService().assess(L1,L2)["controls"]["database_auditing_governance"]
def test_postgresql_hardening(): assert FinalDatabaseGovernanceService().assess(L1,L2)["controls"]["postgresql_hardening_governance"]
def test_persistence_governance(): assert FinalDatabaseGovernanceService().assess(L1,L2)["controls"]["persistence_governance"]
def test_roles_privileges_governance(): assert FinalDatabaseGovernanceService().assess(L1,L2)["controls"]["roles_privileges_governance"]
def test_schema_security_governance(): assert FinalDatabaseGovernanceService().assess(L1,L2)["controls"]["schema_security_governance"]
def test_migration_governance(): assert FinalDatabaseGovernanceService().assess(L1,L2)["controls"]["migration_governance"]
def test_advanced_database_auditing(): assert FinalDatabaseGovernanceService().assess(L1,L2)["controls"]["advanced_database_auditing"]
def test_transactional_integrity(): assert FinalDatabaseGovernanceService().assess(L1,L2)["controls"]["transactional_integrity_governance"]
def test_persistence_protection(): assert FinalDatabaseGovernanceService().assess(L1,L2)["controls"]["persistence_protection_governance"]
def test_postgresql_advanced_governance(): assert FinalDatabaseGovernanceService().assess(L1,L2)["controls"]["postgresql_advanced_governance"]
def test_no_role_change(): assert FinalDatabaseGovernanceService().assess(L1,L2)["real_role_changed"] is False
def test_no_schema_change(): assert FinalDatabaseGovernanceService().assess(L1,L2)["schema_changed"] is False
def test_no_migration_execution(): assert FinalDatabaseGovernanceService().assess(L1,L2)["migration_executed"] is False
def test_no_transaction_execution(): assert FinalDatabaseGovernanceService().assess(L1,L2)["transaction_executed"] is False
def test_no_secret_exposure(): assert FinalDatabaseGovernanceService().assess(L1,L2)["secret_values_exposed"] is False
