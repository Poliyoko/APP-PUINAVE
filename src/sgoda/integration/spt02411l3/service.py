from .recertification import recertify
from .governance import governance_controls
from .gate import evaluate
from .closure import closure_status
from .models import ClosureResult

class DataPrivacyClosureService:
    def close(self, layer1_status, layer2_status, evidence_records=12):
        rec = recertify()
        controls = governance_controls(layer1_status, layer2_status, rec)
        gate = evaluate(controls)
        return ClosureResult(
            closure_status(gate),
            gate["failed_controls"],
            [r.__dict__ for r in rec],
            evidence_records,
        ).to_dict()