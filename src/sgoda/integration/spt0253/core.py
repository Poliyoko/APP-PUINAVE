from dataclasses import dataclass

DEFAULT_REFERENCE_SUPPORT = ("es","en","it","pt")

@dataclass(frozen=True)
class LanguageDescriptor:
    code: str
    name: str
    role: str

def normalize_code(value):
    return str(value or "").strip().lower().replace("_","-")

def build_language_descriptor(code, name, role):
    code = normalize_code(code)
    name = str(name or "").strip()
    role = str(role or "").strip().lower()
    if not code:
        raise ValueError("language_code_required")
    if not name:
        raise ValueError("language_name_required")
    if role not in ("native","support"):
        raise ValueError("language_role_invalid")
    return LanguageDescriptor(code,name,role).__dict__

def validate_platform_language_model(cfg):
    errors=[]
    if not isinstance(cfg,dict):
        return {"valid":False,"errors":["platform_config_not_object"]}

    native=cfg.get("native_language")
    supports=cfg.get("support_languages")

    if not isinstance(native,dict):
        errors.append("native_language_not_object")
        native_code=""
    else:
        native_code=normalize_code(native.get("code"))
        if not native_code: errors.append("native_language_code_required")
        if not str(native.get("name","")).strip(): errors.append("native_language_name_required")

    if not isinstance(supports,list):
        errors.append("support_languages_not_list")
        supports=[]
    seen=set()
    for i,item in enumerate(supports):
        if not isinstance(item,dict):
            errors.append(f"support_{i}_not_object")
            continue
        code=normalize_code(item.get("code"))
        name=str(item.get("name","")).strip()
        if not code: errors.append(f"support_{i}_code_required")
        if not name: errors.append(f"support_{i}_name_required")
        if code and code==native_code:
            errors.append(f"support_{i}_cannot_equal_native_language")
        if code and code in seen:
            errors.append(f"support_{i}_duplicate_code")
        seen.add(code)

    if cfg.get("support_languages_hardcoded") is True:
        errors.append("support_languages_must_not_be_hardcoded")

    if cfg.get("independent_platform") is not True:
        errors.append("platform_must_be_independent")

    return {
        "valid": not errors,
        "errors": errors,
        "native_language_count": 1 if native_code else 0,
        "support_language_count": len([x for x in supports if isinstance(x,dict)]),
        "native_language_code": native_code,
        "support_language_codes": [normalize_code(x.get("code")) for x in supports if isinstance(x,dict) and normalize_code(x.get("code"))],
    }

def reference_puinave_model():
    return {
        "platform_id":"sgoda-puinave",
        "platform_name":"SGODA-PUINAVE",
        "independent_platform":True,
        "native_language":{"code":"pui","name":"Puinave","role":"native"},
        "support_languages":[
            {"code":"es","name":"EspaÃ±ol","role":"support"},
            {"code":"en","name":"English","role":"support"},
            {"code":"it","name":"Italiano","role":"support"},
            {"code":"pt","name":"PortuguÃªs","role":"support"},
        ],
        "support_languages_hardcoded":False,
        "output_selection":{"enabled":True,"mode":"user_selectable"},
        "navigation_language":{"configurable":True},
        "translation_targets":{"configurable":True},
        "definition_languages":{"configurable":True},
        "example_languages":{"configurable":True},
        "audio_languages":{"configurable":True},
    }

def build_independent_platform(platform_id, platform_name, native_language, support_languages):
    cfg={
        "platform_id":str(platform_id or "").strip(),
        "platform_name":str(platform_name or "").strip(),
        "independent_platform":True,
        "native_language":native_language,
        "support_languages":support_languages,
        "support_languages_hardcoded":False,
        "output_selection":{"enabled":True,"mode":"user_selectable"},
        "navigation_language":{"configurable":True},
        "translation_targets":{"configurable":True},
        "definition_languages":{"configurable":True},
        "example_languages":{"configurable":True},
        "audio_languages":{"configurable":True},
    }
    result=validate_platform_language_model(cfg)
    if not cfg["platform_id"]: result["errors"].append("platform_id_required")
    if not cfg["platform_name"]: result["errors"].append("platform_name_required")
    result["valid"]=not result["errors"]
    return cfg,result
