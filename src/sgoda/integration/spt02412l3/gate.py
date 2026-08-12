def evaluate(controls):
    failed = [key for key, value in controls.items() if not value]
    return {
        "passed": not failed,
        "failed_controls": failed,
        "blocking_controls": len(controls),
    }
