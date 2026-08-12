def assess_query_security(profile):
    checks={
        "parameterized_queries":bool(profile.get("parameterized_queries")),
        "dynamic_sql_review":bool(profile.get("dynamic_sql_review")),
        "identifier_allowlists":bool(profile.get("identifier_allowlists")),
        "transaction_boundaries":bool(profile.get("transaction_boundaries")),
        "unsafe_query_construction_blocked":bool(profile.get("unsafe_query_construction_blocked")),
    }
    return {"valid":all(checks.values()),**checks,"query_executed":False}
