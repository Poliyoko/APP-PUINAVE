def assess_hardening_baseline(p):
    checks={"secure_defaults":bool(p.get("secure_defaults")),"least_functionality":bool(p.get("least_functionality")),"secret_indirection":bool(p.get("secret_indirection")),"debug_disabled_by_policy":bool(p.get("debug_disabled_by_policy")),"administrative_surface_governance":bool(p.get("administrative_surface_governance")),"hardening_review_required":bool(p.get("hardening_review_required"))}
    return {"valid":all(checks.values()),**checks,"production_changed":False}
