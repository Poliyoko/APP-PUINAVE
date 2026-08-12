from .acceptance import acceptance_governance
from .exceptions import exception_governance
from .prioritization import prioritize
from .register import build_master_register
from .residual import residual_risk
from .treatment import treatment_plan

class RiskRegisterAuditor:
    def assess(self):
        records=prioritize(build_master_register())
        return {
            "records":[r.__dict__ for r in records],
            "treatments":[treatment_plan(r) for r in records],
            "residuals":[residual_risk(r) for r in records],
            "exceptions":[exception_governance(r) for r in records],
            "acceptances":[acceptance_governance(r) for r in records],
            "treatment_executed":False,
            "acceptance_executed":False,
            "production_changed":False,
            "external_connection_opened":False,
            "secret_values_exposed":False,
        }
