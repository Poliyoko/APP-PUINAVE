class SupplyChainSecurityGate:
    REQUIRED_BLOCKING_CONTROLS = frozenset({
        "SCM-WORKFLOW-PERMISSIONS",
        "SCM-ACTIONS-MUTABLE-BRANCH",
        "SCM-SECRET-USAGE",
        "SCM-EXPRESSION-INJECTION",
        "SCM-SCRIPT-EXECUTION",
        "SCM-DEPENDENCY-INTEGRITY",
        "SCM-SBOM",
        "SCM-ARTIFACT-INTEGRITY",
    })

    @classmethod
    def evaluate(cls, controls):
        by_id = {c["control_id"] if isinstance(c, dict) else c.control_id: c for c in controls}
        missing = sorted(cls.REQUIRED_BLOCKING_CONTROLS - set(by_id))
        if missing:
            return False, ["MISSING:" + item for item in missing]

        failed = []
        for control_id in sorted(cls.REQUIRED_BLOCKING_CONTROLS):
            c = by_id[control_id]
            passed = c["passed"] if isinstance(c, dict) else c.passed
            blocking = c["blocking"] if isinstance(c, dict) else c.blocking
            applicable = c["applicable"] if isinstance(c, dict) else c.applicable
            if blocking and applicable and not passed:
                failed.append(control_id)

        return not failed, failed
