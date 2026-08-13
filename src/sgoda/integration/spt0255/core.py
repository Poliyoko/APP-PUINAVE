from dataclasses import dataclass
from hashlib import sha256
import json

ALLOWED_RESOURCE_TYPES = (
    "bible","dictionary","grammar","story","song","video","audio",
    "document","website","education","culture","custom"
)

@dataclass(frozen=True)
class ResourceValidation:
    valid: bool
    errors: tuple

def normalize_code(value):
    return str(value or "").strip().lower().replace("_","-")

def normalize_resource_type(value):
    return str(value or "").strip().lower().replace(" ","_")

def validate_resource(resource, native_code, support_codes):
    errors=[]
    if not isinstance(resource,dict):
        return {"valid":False,"errors":["resource_not_object"]}

    rid=str(resource.get("resource_id","")).strip()
    name=str(resource.get("name","")).strip()
    rtype=normalize_resource_type(resource.get("type"))
    enabled=resource.get("enabled")
    scope=normalize_code(resource.get("language_scope"))

    if not rid: errors.append("resource_id_required")
    if not name: errors.append("resource_name_required")
    if rtype not in ALLOWED_RESOURCE_TYPES: errors.append("resource_type_invalid")
    if not isinstance(enabled,bool): errors.append("resource_enabled_must_be_boolean")

    allowed_scopes={normalize_code(native_code),"multilingual","none"}
    allowed_scopes.update(normalize_code(x) for x in support_codes)
    if scope not in allowed_scopes:
        errors.append("resource_language_scope_not_enabled")

    source=resource.get("source")
    if not isinstance(source,dict):
        errors.append("resource_source_not_object")
    else:
        mode=str(source.get("mode","")).strip().lower()
        if mode not in ("url","local","none"):
            errors.append("resource_source_mode_invalid")
        if mode=="url" and not str(source.get("url","")).strip():
            errors.append("resource_url_required")
        if mode=="local" and not str(source.get("path","")).strip():
            errors.append("resource_local_path_required")

    if rtype=="bible":
        if resource.get("platform_configurable") is not True:
            errors.append("bible_must_be_platform_configurable")
        if source and isinstance(source,dict) and source.get("mode")=="url":
            if resource.get("url_configurable") is not True:
                errors.append("bible_url_must_be_configurable")

    return {"valid":not errors,"errors":errors}

def validate_catalog(catalog):
    errors=[]
    if not isinstance(catalog,dict):
        return {"valid":False,"errors":["catalog_not_object"]}
    native=normalize_code(catalog.get("native_language"))
    supports=[normalize_code(x) for x in catalog.get("support_languages",[]) if normalize_code(x)]
    if not native: errors.append("catalog_native_language_required")
    if native in supports: errors.append("native_language_cannot_be_support_language")
    if catalog.get("instance_specific") is not True:
        errors.append("catalog_must_be_instance_specific")
    if catalog.get("sgoda_core_embeds_resource_values") is not False:
        errors.append("sgoda_core_must_not_embed_resource_values")

    ids=set()
    resources=catalog.get("resources")
    if not isinstance(resources,list):
        errors.append("catalog_resources_not_list")
        resources=[]
    for idx,res in enumerate(resources):
        result=validate_resource(res,native,supports)
        errors.extend(f"resource_{idx}:{e}" for e in result["errors"])
        if isinstance(res,dict):
            rid=str(res.get("resource_id","")).strip()
            if rid and rid in ids:
                errors.append(f"resource_{idx}:duplicate_resource_id")
            ids.add(rid)
    return {
        "valid":not errors,
        "errors":errors,
        "resource_count":len(resources),
        "enabled_count":len([x for x in resources if isinstance(x,dict) and x.get("enabled") is True]),
    }

def reference_puinave_catalog():
    return {
        "platform_id":"sgoda-puinave",
        "native_language":"pui",
        "support_languages":["es","en","it","pt"],
        "instance_specific":True,
        "sgoda_core_embeds_resource_values":False,
        "resources":[
            {
                "resource_id":"PUINAVE-BIBLE-001",
                "name":"Biblia Puinave",
                "type":"bible",
                "enabled":True,
                "language_scope":"pui",
                "platform_configurable":True,
                "url_configurable":True,
                "source":{"mode":"url","url":"<CONFIGURABLE-BIBLE-URL>"},
                "metadata":{"category":"spiritual-cultural","optional":True}
            }
        ]
    }

def build_resource(resource_id,name,rtype,language_scope,enabled=True,source_mode="none",source_value=""):
    source={"mode":source_mode}
    if source_mode=="url": source["url"]=source_value
    elif source_mode=="local": source["path"]=source_value
    result={
        "resource_id":str(resource_id or "").strip(),
        "name":str(name or "").strip(),
        "type":normalize_resource_type(rtype),
        "enabled":bool(enabled),
        "language_scope":normalize_code(language_scope),
        "platform_configurable":True,
        "source":source,
        "metadata":{}
    }
    if result["type"]=="bible":
        result["url_configurable"]=True
    return result

def catalog_fingerprint(catalog):
    payload=json.dumps(catalog,ensure_ascii=False,sort_keys=True,separators=(",",":"))
    return sha256(payload.encode("utf-8")).hexdigest()
