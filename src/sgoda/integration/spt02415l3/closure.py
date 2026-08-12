def closure_status(gate):
    return "INSTITUTIONALLY_CLOSED" if gate["passed"] else "CLOSURE_HOLD"
