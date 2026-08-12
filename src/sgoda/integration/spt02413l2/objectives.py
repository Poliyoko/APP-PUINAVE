from typing import Mapping

def assess_rto_rpo(profile: Mapping) -> dict:
    rto = int(profile.get("rto_minutes", 0))
    rpo = int(profile.get("rpo_minutes", 0))
    max_rto = int(profile.get("max_rto_minutes", 0))
    max_rpo = int(profile.get("max_rpo_minutes", 0))
    valid = rto > 0 and rpo >= 0 and max_rto > 0 and max_rpo >= 0 and rto <= max_rto and rpo <= max_rpo
    return {"valid": valid, "rto_minutes": rto, "rpo_minutes": rpo, "max_rto_minutes": max_rto, "max_rpo_minutes": max_rpo}
