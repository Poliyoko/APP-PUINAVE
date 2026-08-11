class IdentityAccessSecurityGate:
    BLOCKING = frozenset({
        "IAM-DENY-DEFAULT",
        "IAM-RBAC",
        "IAM-LEAST-PRIVILEGE",
        "IAM-SEPARATION-DUTIES",
        "IAM-SERVICE-IDENTITY",
        "IAM-AUTHN",
        "IAM-SECRET-INDIRECTION",
    })

    @classmethod
    def evaluate(cls, controls):
        by_id = {
            c["control_id"] if isinstance(c, dict) else c.control_id: c
            for c in controls
        }

        missing = sorted(cls.BLOCKING - set(by_id))
        if missing:
            return False, ["MISSING:" + item for item in missing]

        failed = []

        for control_id in sorted(cls.BLOCKING):
            control = by_id[control_id]
            passed = control["passed"] if isinstance(control, dict) else control.passed
            blocking = control["blocking"] if isinstance(control, dict) else control.blocking
            applicable = control["applicable"] if isinstance(control, dict) else control.applicable

            if blocking and applicable and not passed:
                failed.append(control_id)

        return not failed, failed
