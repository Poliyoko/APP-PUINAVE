from datetime import datetime,timezone
def build_provenance(source_component,source_id,actor="SGODA-PUINAVE",license_name="institutional"):
    return {"source_component":source_component,"source_id":source_id,"actor":actor,"license":license_name,"recorded_at_utc":datetime.now(timezone.utc).isoformat()}