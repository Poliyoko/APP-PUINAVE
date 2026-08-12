def exception_governance(record):
    if not record.exception:
        return {"risk_id":record.risk_id,"exception":False,"valid":True,"approval_required":False,"expiry_required":False}
    return {"risk_id":record.risk_id,"exception":True,"valid":record.acceptance_required,"approval_required":True,"expiry_required":True}
