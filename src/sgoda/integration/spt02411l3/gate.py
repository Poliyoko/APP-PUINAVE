def evaluate(controls):
    failed = [k for k, v in controls.items() if not v]
    return {"passed": not failed, "failed_controls": failed, "blocking_controls": len(controls)}