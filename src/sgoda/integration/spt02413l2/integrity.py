import hashlib, json
from typing import Mapping

def canonical_sha256(value: Mapping) -> str:
    raw = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode("utf-8")
    return hashlib.sha256(raw).hexdigest().upper()
