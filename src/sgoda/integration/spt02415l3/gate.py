class FinalApplicationApiGovernanceGate:
    @staticmethod
    def evaluate(controls):
        failed = [name for name, passed in controls.items() if not passed]
        return {"passed": not failed, "failed": failed, "blocking_controls": len(controls)}
