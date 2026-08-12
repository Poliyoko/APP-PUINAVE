import hashlib,json

def canonical_sha256(value):
    raw=json.dumps(value,sort_keys=True,separators=(",",":"),ensure_ascii=True).encode("utf-8")
    return hashlib.sha256(raw).hexdigest().upper()
