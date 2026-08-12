ALLOWED={"MITIGATE","AVOID","TRANSFER","ACCEPT"}

def treatment_plan(record):
    valid=(record.treatment in ALLOWED and bool(record.owner) and record.status in {"IN_TREATMENT","MONITORED","ACCEPTED","CLOSED"} and 0 <= record.residual_score <= record.inherent_score)
    return {"risk_id":record.risk_id,"valid":valid,"treatment":record.treatment,"owner":record.owner,"status":record.status,"residual_score":record.residual_score,"treatment_executed":False}
