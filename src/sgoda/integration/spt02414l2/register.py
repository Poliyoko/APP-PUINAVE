from .models import RiskRecord

def build_master_register():
    return [
        RiskRecord("RISK-001","Lexical data integrity",20,10,"HIGH","MITIGATE","PISI_RISK_OWNER","IN_TREATMENT",False,False),
        RiskRecord("RISK-002","Credential exposure",25,8,"CRITICAL","MITIGATE","PISI_RISK_OWNER","IN_TREATMENT",False,False),
        RiskRecord("RISK-003","Service availability",15,6,"HIGH","MITIGATE","PISI_CONTINUITY_OWNER","MONITORED",False,False),
        RiskRecord("RISK-004","Third-party dependency disruption",12,6,"HIGH","TRANSFER","PISI_SUPPLY_CHAIN_OWNER","MONITORED",True,True),
    ]
