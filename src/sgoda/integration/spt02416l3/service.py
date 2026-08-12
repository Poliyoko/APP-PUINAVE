from .recertification import build_recertification
from .governance import final_controls
from .gate import FinalDatabaseGovernanceGate
from .closure import closure_status

class FinalDatabaseGovernanceService:
    def assess(self, layer1_status, layer2_status):
        rec = build_recertification()
        controls = final_controls(layer1_status, layer2_status, rec)
        gate = FinalDatabaseGovernanceGate.evaluate(controls)
        return {
            "status": closure_status(gate),
            "failed_blocking_controls": gate["failed"],
            "blocking_controls": gate["blocking_controls"],
            "recertification_records": [r.to_dict() for r in rec],
            "controls": controls,
            "real_role_changed": False,
            "schema_changed": False,
            "migration_executed": False,
            "audit_configuration_changed": False,
            "transaction_executed": False,
            "persistence_changed": False,
            "postgresql_configuration_changed": False,
            "external_connection_opened": False,
            "secret_values_exposed": False,
        }
