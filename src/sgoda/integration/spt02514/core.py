from hashlib import sha256
import json

def norm(v):
    return str(v or "").strip().lower().replace("_","-")

def fingerprint(value):
    payload=json.dumps(value,ensure_ascii=False,sort_keys=True,separators=(",",":"))
    return sha256(payload.encode("utf-8")).hexdigest()

def validate_composed_configuration(cfg):
    errors=[]
    if not isinstance(cfg,dict):
        return {"valid":False,"errors":["configuration_not_object"]}
    for k in ("template","platform","resources","identity","governance"):
        if k not in cfg: errors.append("missing_"+k)

    platform=cfg.get("platform",{})
    native=platform.get("native_language",{}) if isinstance(platform,dict) else {}
    native_code=norm(native.get("code")) if isinstance(native,dict) else ""
    if not native_code: errors.append("native_language_required")

    supports=platform.get("support_languages",[]) if isinstance(platform,dict) else []
    if not isinstance(supports,list):
        errors.append("support_languages_not_list"); supports=[]
    seen=set(); support_codes=[]
    for i,item in enumerate(supports):
        code=norm(item.get("code")) if isinstance(item,dict) else ""
        if not code: errors.append(f"support_{i}_invalid")
        elif code==native_code: errors.append(f"support_{i}_equals_native")
        elif code in seen: errors.append(f"support_{i}_duplicate")
        else: seen.add(code); support_codes.append(code)

    gov=cfg.get("governance",{})
    if not isinstance(gov,dict):
        errors.append("governance_invalid")
    else:
        if gov.get("shared_core_reference") is not True: errors.append("shared_core_reference_required")
        if gov.get("core_duplicated") is not False: errors.append("core_duplication_forbidden")
        if gov.get("auto_deployed") is not False: errors.append("auto_deploy_forbidden")
        if gov.get("production_changed") is not False: errors.append("production_change_forbidden")
        if gov.get("example_only") not in (True,False): errors.append("example_only_required")

    return {
        "valid":not errors,
        "errors":errors,
        "native_language":native_code,
        "support_languages":support_codes,
        "sha256":fingerprint(cfg) if not errors else None,
    }

def validate_instance_contract(cfg, expected_template_id=None):
    errors=[]
    check=validate_composed_configuration(cfg)
    if not check["valid"]:
        errors.extend(check["errors"])
    template=cfg.get("template",{}) if isinstance(cfg,dict) else {}
    tid=template.get("template_id") if isinstance(template,dict) else None
    version=template.get("version") if isinstance(template,dict) else None
    if not tid: errors.append("template_id_required")
    if not version: errors.append("template_version_required")
    if expected_template_id and tid!=expected_template_id:
        errors.append("template_id_mismatch")

    resources=cfg.get("resources",{}) if isinstance(cfg,dict) else {}
    if not isinstance(resources,dict):
        errors.append("resources_not_object")

    identity=cfg.get("identity",{}) if isinstance(cfg,dict) else {}
    if not isinstance(identity,dict):
        errors.append("identity_not_object")

    return {"valid":not errors,"errors":errors,"template_id":tid}

def declarative_materialization_gate(cfg, declared_sha256=None):
    c=validate_composed_configuration(cfg)
    i=validate_instance_contract(cfg)
    errors=[]
    errors.extend("config_"+x for x in c["errors"])
    errors.extend("contract_"+x for x in i["errors"])
    actual=fingerprint(cfg) if isinstance(cfg,dict) else None
    if declared_sha256 and actual!=declared_sha256:
        errors.append("sha256_mismatch")
    gov=cfg.get("governance",{}) if isinstance(cfg,dict) else {}
    if isinstance(gov,dict):
        if gov.get("auto_deployed") is not False: errors.append("auto_deploy_forbidden")
        if gov.get("production_changed") is not False: errors.append("production_change_forbidden")
    return {
        "pass":not errors,
        "errors":errors,
        "sha256":actual,
        "materialization_mode":"DECLARATIVE_PACKAGE_ONLY",
        "real_platform_deployed":False,
        "production_changed":False,
    }

def generic_composed_configuration():
    return {
        "template":{"template_id":"sgoda-language-platform-standard","version":"1.0.0"},
        "platform":{
            "native_language":{"code":"qaa","name":"Example Native Language"},
            "support_languages":[
                {"code":"es","name":"EspaÃ±ol"},
                {"code":"en","name":"English"},
                {"code":"it","name":"Italiano"},
                {"code":"pt","name":"PortuguÃªs"},
            ],
            "display_name":"SGODA Example Platform"
        },
        "resources":{"bible":{"enabled":False,"url":None},"catalog":[]},
        "identity":{"community":"Example Community","branding":"configurable"},
        "governance":{
            "shared_core_reference":True,
            "core_duplicated":False,
            "auto_deployed":False,
            "production_changed":False,
            "example_only":True,
        },
    }
