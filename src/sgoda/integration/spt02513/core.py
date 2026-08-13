from copy import deepcopy
from hashlib import sha256
import json

def merge(a,b):
    if isinstance(a,dict) and isinstance(b,dict):
        r=deepcopy(a)
        for k,v in b.items():
            r[k]=merge(r[k],v) if k in r else deepcopy(v)
        return r
    return deepcopy(b)

def norm(v):
    return str(v or "").strip().lower().replace("_","-")

def validate_profile(p):
    e=[]
    if not isinstance(p,dict): return {"valid":False,"errors":["profile_not_object"]}
    for k in ("profile_id","template_id","native_language","support_languages","governance"):
        if k not in p: e.append("missing_"+k)
    n=p.get("native_language",{})
    nc=norm(n.get("code")) if isinstance(n,dict) else ""
    if not nc: e.append("native_language_required")
    seen=set(); supports=[]
    for i,x in enumerate(p.get("support_languages",[]) if isinstance(p.get("support_languages",[]),list) else []):
        c=norm(x.get("code")) if isinstance(x,dict) else ""
        if not c: e.append(f"support_{i}_invalid")
        elif c==nc: e.append(f"support_{i}_equals_native")
        elif c in seen: e.append(f"support_{i}_duplicate")
        else: seen.add(c); supports.append(c)
    g=p.get("governance",{})
    if not isinstance(g,dict): e.append("governance_invalid")
    else:
        if g.get("example_only") not in (True,False): e.append("example_only_required")
        if g.get("auto_deploy") is not False: e.append("auto_deploy_forbidden")
        if g.get("production_change") is not False: e.append("production_change_forbidden")
    return {"valid":not e,"errors":e,"native_language":nc,"support_languages":supports,"template_id":p.get("template_id")}

def resolve_profiles(profiles):
    if not isinstance(profiles,list) or not profiles:
        return {"valid":False,"errors":["profiles_required"]}
    r=deepcopy(profiles[0]); b=validate_profile(r)
    if not b["valid"]: return {"valid":False,"errors":b["errors"]}
    native=b["native_language"]; template=b["template_id"]
    for i,overlay in enumerate(profiles[1:],1):
        c=merge(r,overlay); v=validate_profile(c)
        if not v["valid"]: return {"valid":False,"errors":[f"profile_{i}_{x}" for x in v["errors"]]}
        if v["native_language"]!=native: return {"valid":False,"errors":[f"profile_{i}_native_language_change_forbidden"]}
        if v["template_id"]!=template: return {"valid":False,"errors":[f"profile_{i}_template_change_forbidden"]}
        r=c
    return {"valid":True,"errors":[],"resolved":r}

def compose(template,profiles,overlay):
    if template.get("native_language",{}).get("mode")!="CONFIGURABLE_EXACTLY_ONE":
        return {"valid":False,"errors":["template_native_contract_invalid"]}
    if template.get("support_languages",{}).get("mode")!="CONFIGURABLE_0_TO_N":
        return {"valid":False,"errors":["template_support_contract_invalid"]}
    if template.get("support_languages",{}).get("hard_coded") is not False:
        return {"valid":False,"errors":["hard_coded_support_languages_forbidden"]}
    g=template.get("governance",{})
    if g.get("shared_core_reference") is not True or g.get("duplicate_core") is not False or g.get("auto_deploy") is not False or g.get("production_change") is not False:
        return {"valid":False,"errors":["template_governance_invalid"]}
    rp=resolve_profiles(profiles)
    if not rp["valid"]: return rp
    p=rp["resolved"]; pv=validate_profile(p)
    if pv["template_id"]!=template.get("template_id"): return {"valid":False,"errors":["template_profile_mismatch"]}
    cfg=merge({
        "template":{"template_id":template["template_id"],"version":template["version"]},
        "platform":{"native_language":p["native_language"],"support_languages":p["support_languages"]},
        "resources":p.get("resource_profile",{}),
        "identity":p.get("identity_profile",{}),
        "governance":{"shared_core_reference":True,"core_duplicated":False,"auto_deployed":False,"production_changed":False,"example_only":p["governance"]["example_only"]}
    },overlay or {})
    nc=norm(cfg["platform"]["native_language"].get("code"))
    if nc!=pv["native_language"]: return {"valid":False,"errors":["instance_overlay_native_language_change_forbidden"]}
    seen=set(); sc=[]
    for i,x in enumerate(cfg["platform"].get("support_languages",[])):
        c=norm(x.get("code")) if isinstance(x,dict) else ""
        if not c:return {"valid":False,"errors":[f"support_{i}_invalid"]}
        if c==nc:return {"valid":False,"errors":[f"support_{i}_equals_native"]}
        if c in seen:return {"valid":False,"errors":[f"support_{i}_duplicate"]}
        seen.add(c); sc.append(c)
    gg=cfg["governance"]
    if gg.get("shared_core_reference") is not True:return {"valid":False,"errors":["shared_core_reference_required"]}
    if gg.get("core_duplicated") is not False:return {"valid":False,"errors":["core_duplication_forbidden"]}
    if gg.get("auto_deployed") is not False:return {"valid":False,"errors":["auto_deploy_forbidden"]}
    if gg.get("production_changed") is not False:return {"valid":False,"errors":["production_change_forbidden"]}
    payload=json.dumps(cfg,ensure_ascii=False,sort_keys=True,separators=(",",":"))
    return {"valid":True,"errors":[],"configuration":cfg,"native_language":nc,"support_languages":sc,"sha256":sha256(payload.encode("utf-8")).hexdigest()}

def generic_template():
    return {"template_id":"sgoda-language-platform-standard","version":"1.0.0","native_language":{"mode":"CONFIGURABLE_EXACTLY_ONE"},"support_languages":{"mode":"CONFIGURABLE_0_TO_N","hard_coded":False},"governance":{"shared_core_reference":True,"duplicate_core":False,"auto_deploy":False,"production_change":False}}

def generic_base_profile():
    return {"profile_id":"example-base-profile","template_id":"sgoda-language-platform-standard","native_language":{"code":"qaa","name":"Example Native Language"},"support_languages":[{"code":"es"},{"code":"en"}],"resource_profile":{"bible":{"enabled":False,"url":None}},"identity_profile":{"community":"Example Community"},"governance":{"example_only":True,"auto_deploy":False,"production_change":False}}

def generic_extension_profile():
    return {"profile_id":"example-extension-profile","support_languages":[{"code":"es"},{"code":"en"},{"code":"it"},{"code":"pt"}],"identity_profile":{"theme":"configurable"}}

def generic_overlay():
    return {"platform":{"display_name":"SGODA Example Platform"},"governance":{"shared_core_reference":True,"core_duplicated":False,"auto_deployed":False,"production_changed":False,"example_only":True}}
