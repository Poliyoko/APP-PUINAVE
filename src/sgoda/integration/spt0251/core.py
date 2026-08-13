from dataclasses import dataclass
import re

CATEGORY_CORE="CORE_CANDIDATE"
CATEGORY_INSTANCE="INSTANCE_SPECIFIC"
CATEGORY_SHARED="SHARED_CONFIGURABLE"
CATEGORY_REVIEW="REVIEW_REQUIRED"
SUPPORT_LANGUAGE_CODES=("es","en","it","pt")
INSTANCE_HINTS=("puinave","rlb","bible","biblia","audio","image","imagen","community","comunidad","branding","logo")
CORE_HINTS=("src/sgoda/","tests/","config/integration/","docs/06_tecnologia/")

@dataclass(frozen=True)
class Finding:
    path:str
    category:str
    reasons:tuple

def _normalize_text(text):
    if text is None:
        return ""
    if isinstance(text, str):
        return text
    if isinstance(text, (dict, list, tuple)):
        import json
        try:
            return json.dumps(text, ensure_ascii=False, sort_keys=True)
        except Exception:
            return str(text)
    return str(text)

def classify(path,text=""):
    p=str(path).lower().replace("\\","/")
    body=_normalize_text(text).lower()
    reasons=[]
    coupling=any(h in p for h in INSTANCE_HINTS) or any(x in body for x in ("puinave","app-puinave","spt-004b","bible","biblia","repositorio lexico"))
    core=any(p.startswith(h) for h in CORE_HINTS)
    configurable=("config" in p)
    if coupling: reasons.append("LANGUAGE_OR_INSTANCE_COUPLING")
    if core: reasons.append("CORE_STRUCTURE")
    if configurable: reasons.append("CONFIGURABLE_SURFACE")
    if coupling and (core or configurable): category=CATEGORY_SHARED
    elif coupling: category=CATEGORY_INSTANCE
    elif core: category=CATEGORY_CORE
    else: category=CATEGORY_REVIEW
    return Finding(path,category,tuple(reasons)).__dict__

def audit(entries):
    findings=[classify(x["path"],x.get("text","")) for x in entries]
    counts={CATEGORY_CORE:0,CATEGORY_INSTANCE:0,CATEGORY_SHARED:0,CATEGORY_REVIEW:0}
    for f in findings: counts[f["category"]]+=1
    return {
      "findings":findings,
      "counts":counts,
      "support_language_model":{
        "native_language_per_platform":1,
        "support_languages_configurable":True,
        "example_support_languages":list(SUPPORT_LANGUAGE_CODES),
        "hardcoded_output_languages_allowed":False
      },
      "replicability_principles":{
        "one_native_language_per_platform":True,
        "independent_platforms":True,
        "shared_sgoda_core":True,
        "rlb_instance_specific":True,
        "bible_resource_configurable_per_platform":True,
        "support_languages_configurable_per_platform":True
      }
    }
