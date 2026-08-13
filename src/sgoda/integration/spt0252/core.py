from dataclasses import dataclass

REQUIRED_NATIVE_KEYS = ("code","name")
REQUIRED_PLATFORM_KEYS = ("platform_id","platform_name","native_language","support_languages","rlb","resources","branding")
PUINAVE_SUPPORT = ("es","en","it","pt")

@dataclass(frozen=True)
class ContractResult:
    valid: bool
    errors: tuple

def validate_native_language(native):
    errors=[]
    if not isinstance(native, dict):
        return ContractResult(False,("native_language_not_object",)).__dict__
    for k in REQUIRED_NATIVE_KEYS:
        if not str(native.get(k,"")).strip():
            errors.append(f"missing_native_{k}")
    return ContractResult(not errors,tuple(errors)).__dict__

def validate_support_languages(items):
    errors=[]
    if not isinstance(items, list):
        return ContractResult(False,("support_languages_not_list",)).__dict__
    seen=set()
    for idx,item in enumerate(items):
        if not isinstance(item,dict):
            errors.append(f"support_{idx}_not_object")
            continue
        code=str(item.get("code","")).strip().lower()
        name=str(item.get("name","")).strip()
        if not code: errors.append(f"support_{idx}_missing_code")
        if not name: errors.append(f"support_{idx}_missing_name")
        if code in seen and code: errors.append(f"support_{idx}_duplicate_code")
        seen.add(code)
    return ContractResult(not errors,tuple(errors)).__dict__

def validate_platform_contract(cfg):
    errors=[]
    if not isinstance(cfg,dict):
        return {"valid":False,"errors":["platform_not_object"]}
    for k in REQUIRED_PLATFORM_KEYS:
        if k not in cfg:
            errors.append(f"missing_{k}")
    nr=validate_native_language(cfg.get("native_language"))
    errors.extend(nr["errors"])
    sr=validate_support_languages(cfg.get("support_languages"))
    errors.extend(sr["errors"])
    if isinstance(cfg.get("native_language"),dict):
        native_code=str(cfg["native_language"].get("code","")).lower()
        for item in cfg.get("support_languages") or []:
            if isinstance(item,dict) and str(item.get("code","")).lower()==native_code and native_code:
                errors.append("native_language_cannot_be_support_language")
    rlb=cfg.get("rlb")
    if not isinstance(rlb,dict) or not rlb.get("instance_specific",False):
        errors.append("rlb_must_be_instance_specific")
    resources=cfg.get("resources")
    if not isinstance(resources,dict) or not resources.get("configurable_per_platform",False):
        errors.append("resources_must_be_configurable_per_platform")
    branding=cfg.get("branding")
    if not isinstance(branding,dict) or not branding.get("configurable_per_platform",False):
        errors.append("branding_must_be_configurable_per_platform")
    return {"valid":not errors,"errors":errors}

def sgoda_core_contract():
    return {
        "contract":"SGODA_CORE",
        "shared_capabilities":[
            "api","persistence","automation","pmo","auditor","security",
            "fld","oda","workflow","testing","evidence","governance"
        ],
        "must_not_embed":[
            "native_language_specific_lexicon",
            "native_language_specific_audio",
            "community_branding",
            "bible_url",
            "hardcoded_support_languages"
        ],
        "one_native_language_per_platform":True,
        "support_languages_configurable":True
    }

def reference_puinave_contract():
    return {
        "platform_id":"sgoda-puinave",
        "platform_name":"SGODA-PUINAVE",
        "native_language":{"code":"pui","name":"Puinave"},
        "support_languages":[
            {"code":"es","name":"EspaÃ±ol"},
            {"code":"en","name":"English"},
            {"code":"it","name":"Italiano"},
            {"code":"pt","name":"PortuguÃªs"},
        ],
        "rlb":{"instance_specific":True,"source":"RLB-PUINAVE"},
        "resources":{"configurable_per_platform":True,"bible":{"enabled":True,"url_configurable":True}},
        "branding":{"configurable_per_platform":True}
    }
