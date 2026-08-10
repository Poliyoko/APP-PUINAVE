from pathlib import Path
from .audit import ClientSecurityAuditor
from .gate import ClientSecurityGate

class ClientSecurityService:
    def __init__(self,root:Path): self.root=Path(root)
    def assess(self):
        controls,surfaces=ClientSecurityAuditor(self.root).audit()
        passed,failed=ClientSecurityGate.evaluate(controls)
        return {
            "status":"CLIENT_SECURITY_GATE_PASS" if passed else "CLIENT_SECURITY_GATE_HOLD",
            "failed_control_ids":failed,
            "controls":[c.__dict__ for c in controls],
            "surfaces":[s.__dict__ for s in surfaces],
            "external_connection_opened":False,
            "flutter_app_executed_by_gate":False,
            "secret_values_exposed":False,
        }
