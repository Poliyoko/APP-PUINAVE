def acceptance_governance(record):
    required=bool(record.acceptance_required or record.treatment=="ACCEPT")
    return {"risk_id":record.risk_id,"required":required,"approval_required":required,"residual_review_required":required,"accepted_automatically":False,"valid":True}
