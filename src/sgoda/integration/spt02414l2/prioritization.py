def prioritize(records):
    rank = {"CRITICAL":4,"HIGH":3,"MEDIUM":2,"LOW":1}
    return sorted(records,key=lambda r:(-rank.get(r.priority,0),-r.inherent_score,r.risk_id))
