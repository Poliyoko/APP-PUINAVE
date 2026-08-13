from hashlib import sha256
import json

def _t(v): return str(v or "").strip()
def normalize_code(v): return _t(v).lower().replace("_","-")

def validate_platform_identity(cfg):
    errors=[]
    if not isinstance(cfg,dict):
        return {"valid":False,"errors":["platform_identity_not_object"]}
    for k in ("platform_id","platform_name","community","native_language","branding","institutional_texts","cultural_metadata","presentation"):
        if k not in cfg: errors.append("missing_"+k)
    if not _t(cfg.get("platform_id")): errors.append("platform_id_required")
    if not _t(cfg.get("platform_name")): errors.append("platform_name_required")
    if cfg.get("instance_specific") is not True: errors.append("identity_must_be_instance_specific")
    if cfg.get("sgoda_core_embeds_identity_values") is not False: errors.append("sgoda_core_must_not_embed_identity_values")

    c=cfg.get("community")
    if not isinstance(c,dict): errors.append("community_not_object")
    else:
        if not _t(c.get("community_id")): errors.append("community_id_required")
        if not _t(c.get("name")): errors.append("community_name_required")
        if "territory" not in c: errors.append("community_territory_required")
        if "contact_metadata" not in c: errors.append("community_contact_metadata_required")

    n=cfg.get("native_language")
    if not isinstance(n,dict): errors.append("native_language_not_object")
    else:
        if not normalize_code(n.get("code")): errors.append("native_language_code_required")
        if not _t(n.get("name")): errors.append("native_language_name_required")

    b=cfg.get("branding")
    if not isinstance(b,dict): errors.append("branding_not_object")
    else:
        if b.get("configurable_per_platform") is not True: errors.append("branding_must_be_configurable_per_platform")
        for k in ("logo","icon","theme"):
            if k not in b: errors.append("branding_missing_"+k)

    for key,msg in (
        ("institutional_texts","institutional_texts_must_be_configurable_per_platform"),
        ("cultural_metadata","cultural_metadata_must_be_configurable_per_platform"),
        ("presentation","presentation_must_be_configurable_per_platform"),
    ):
        x=cfg.get(key)
        if not isinstance(x,dict): errors.append(key+"_not_object")
        elif x.get("configurable_per_platform") is not True: errors.append(msg)
    return {"valid":not errors,"errors":errors}

def reference_puinave_identity():
    return {
      "platform_id":"sgoda-puinave","platform_name":"SGODA-PUINAVE",
      "instance_specific":True,"sgoda_core_embeds_identity_values":False,
      "community":{"community_id":"puinave","name":"Pueblo Puinave","territory":{"configurable":True,"value":""},"contact_metadata":{"configurable":True}},
      "native_language":{"code":"pui","name":"Puinave"},
      "branding":{"configurable_per_platform":True,"logo":{"mode":"resource_reference","value":""},"icon":{"mode":"resource_reference","value":""},"theme":{"primary_token":"platform-primary","secondary_token":"platform-secondary","configurable":True}},
      "institutional_texts":{"configurable_per_platform":True,"title":"SGODA-PUINAVE","slogan":"TecnologÃ­a para preservar la memoria del pueblo Puinave."},
      "cultural_metadata":{"configurable_per_platform":True,"community_description":"","cultural_notes":"","attribution":""},
      "presentation":{"configurable_per_platform":True,"default_navigation_language":"es","show_native_language_first":True}
    }

def build_platform_identity(platform_id,platform_name,community_id,community_name,native_code,native_name):
    cfg=reference_puinave_identity()
    cfg["platform_id"]=_t(platform_id); cfg["platform_name"]=_t(platform_name)
    cfg["community"]["community_id"]=_t(community_id); cfg["community"]["name"]=_t(community_name)
    cfg["native_language"]={"code":normalize_code(native_code),"name":_t(native_name)}
    cfg["institutional_texts"]["title"]=_t(platform_name); cfg["institutional_texts"]["slogan"]=""
    return cfg,validate_platform_identity(cfg)

def identity_fingerprint(cfg):
    return sha256(json.dumps(cfg,ensure_ascii=False,sort_keys=True,separators=(",",":")).encode("utf-8")).hexdigest()
