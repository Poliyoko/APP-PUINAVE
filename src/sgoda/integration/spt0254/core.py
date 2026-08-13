from dataclasses import dataclass
from hashlib import sha256
import json

REQUIRED_LEXEME_KEYS = (
    "lexical_id","native_language","native_form","meanings",
    "pronunciation","audio","images","metadata"
)

@dataclass(frozen=True)
class ValidationResult:
    valid: bool
    errors: tuple

def normalize_code(value):
    return str(value or "").strip().lower().replace("_","-")

def _nonempty(value):
    return bool(str(value or "").strip())

def validate_meanings(meanings, support_language_codes):
    errors=[]
    if not isinstance(meanings,dict):
        return ["meanings_not_object"]
    for code in support_language_codes:
        value=meanings.get(code)
        if value is None:
            continue
        if isinstance(value,dict):
            if "text" in value and not _nonempty(value.get("text")):
                errors.append(f"meaning_{code}_text_empty")
        elif not _nonempty(value):
            errors.append(f"meaning_{code}_empty")
    unknown=[normalize_code(k) for k in meanings.keys() if normalize_code(k) not in support_language_codes]
    if unknown:
        errors.extend(f"meaning_language_not_enabled:{x}" for x in unknown)
    return errors

def validate_lexeme(record, native_code, support_language_codes):
    errors=[]
    if not isinstance(record,dict):
        return {"valid":False,"errors":["lexeme_not_object"]}
    for k in REQUIRED_LEXEME_KEYS:
        if k not in record:
            errors.append(f"missing_{k}")
    if not _nonempty(record.get("lexical_id")):
        errors.append("lexical_id_required")
    if normalize_code(record.get("native_language")) != normalize_code(native_code):
        errors.append("native_language_mismatch")
    if not _nonempty(record.get("native_form")):
        errors.append("native_form_required")
    support=[normalize_code(x) for x in support_language_codes]
    if normalize_code(native_code) in support:
        errors.append("native_language_cannot_be_support_language")
    errors.extend(validate_meanings(record.get("meanings"),support))
    pronunciation=record.get("pronunciation")
    if not isinstance(pronunciation,dict):
        errors.append("pronunciation_not_object")
    audio=record.get("audio")
    if not isinstance(audio,dict):
        errors.append("audio_not_object")
    images=record.get("images")
    if not isinstance(images,list):
        errors.append("images_not_list")
    metadata=record.get("metadata")
    if not isinstance(metadata,dict):
        errors.append("metadata_not_object")
    return {"valid":not errors,"errors":errors}

def build_repository_contract(platform_id, native_code, support_language_codes):
    support=[]
    seen=set()
    for code in support_language_codes:
        c=normalize_code(code)
        if not c or c==normalize_code(native_code) or c in seen:
            continue
        seen.add(c)
        support.append(c)
    return {
        "contract":"PARAMETRIC_RLB_INSTANCE_DATA",
        "platform_id":str(platform_id or "").strip(),
        "native_language":normalize_code(native_code),
        "support_languages":support,
        "instance_specific":True,
        "sgoda_core_contains_lexical_data":False,
        "lexeme_required_keys":list(REQUIRED_LEXEME_KEYS),
        "supports_pronunciation":True,
        "supports_native_audio":True,
        "supports_images":True,
        "supports_metadata":True,
        "support_language_meanings_configurable":True,
        "backward_compatibility_adapter_required":True
    }

def content_fingerprint(record):
    payload=json.dumps(record,ensure_ascii=False,sort_keys=True,separators=(",",":"))
    return sha256(payload.encode("utf-8")).hexdigest()

def reference_puinave_lexeme():
    return {
        "lexical_id":"PUINAVE-000001",
        "native_language":"pui",
        "native_form":"AMDA",
        "meanings":{
            "es":{"text":"..."},
            "en":{"text":"..."},
            "it":{"text":"..."},
            "pt":{"text":"..."}
        },
        "pronunciation":{"notation":"","validated":False},
        "audio":{"native":"","speaker":"","validated":False},
        "images":[],
        "metadata":{"source":"RLB-PUINAVE","status":"reference"}
    }
