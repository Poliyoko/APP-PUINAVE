def residual_risk(record):
    reduction=record.inherent_score-record.residual_score
    valid=record.residual_score >= 0 and reduction >= 0
    return {"risk_id":record.risk_id,"valid":valid,"inherent_score":record.inherent_score,"residual_score":record.residual_score,"risk_reduction":reduction,"review_required":True}
