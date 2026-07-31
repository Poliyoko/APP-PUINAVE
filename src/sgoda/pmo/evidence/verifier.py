from __future__ import annotations
import hashlib, json, zipfile
from pathlib import Path
from .hasher import calculate_sha256
from .models import IntegrityResult

def verify_path(path:Path,expected_sha256:str)->IntegrityResult:
    actual=calculate_sha256(path); valid=actual.lower()==expected_sha256.lower()
    return IntegrityResult(valid,expected_sha256.lower(),actual.lower(),
                           details="integrity-ok" if valid else "sha256-mismatch")

def verify_archive_contents(path:Path)->tuple[bool,list[str]]:
    errors=[]
    with zipfile.ZipFile(path,"r") as z:
        bad=z.testzip()
        if bad: errors.append(f"crc-error:{bad}")
        names=set(z.namelist())
        if "manifest.json" not in names: return False,errors+["missing:manifest.json"]
        manifest=json.loads(z.read("manifest.json").decode("utf-8"))
        for entry in manifest.get("entries",[]):
            member=f"payload/{entry['relative_path']}"
            if member not in names: errors.append(f"missing:{member}"); continue
            actual=hashlib.sha256(z.read(member)).hexdigest()
            if actual.lower()!=entry["sha256"].lower(): errors.append(f"sha256-mismatch:{member}")
    return not errors,errors