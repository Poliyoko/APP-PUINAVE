class ContinuityRecoveryGovernanceGate:
    def evaluate(self, controls):
        failed = [c for c in controls if c.blocking and not c.passed]
        return {"passed": len(failed) == 0, "failed_blocking_controls": len(failed), "failed_control_ids": [c.control_id for c in failed]}
