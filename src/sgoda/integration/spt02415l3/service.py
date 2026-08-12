from .recertification import build_recertification
from .governance import final_controls
from .gate import FinalApplicationApiGovernanceGate
from .closure import closure_status

class FinalApplicationApiGovernanceService:
    def assess(self, layer1_status, layer2_status):
        rec = build_recertification()
        controls = final_controls(layer1_status, layer2_status, rec)
        gate = FinalApplicationApiGovernanceGate.evaluate(controls)
        return {
            "status": closure_status(gate),
            "failed_blocking_controls": gate["failed"],
            "blocking_controls": gate["blocking_controls"],
            "recertification_records": [r.to_dict() for r in rec],
            "controls": controls,
            "active_attack_executed": False,
            "real_session_changed": False,
            "rate_limit_changed": False,
            "endpoint_changed": False,
            "exposure_changed": False,
            "production_changed": False,
            "external_connection_opened": False,
            "secret_values_exposed": False,
        }
