from __future__ import annotations
import json
import re
from pathlib import Path
from typing import Iterable, Dict, List


HTTP_RE = re.compile(r"(?i)\bhttp://(?!localhost\b|127\.0\.0\.1\b)")
VCS_RE = re.compile(r"(?i)(git\+https?://|github\.com/.+\.git)(?![^\s#]*@[0-9a-f]{7,40})")


def audit_dependencies(root: Path, paths: Iterable[str]) -> Dict[str, List[str]]:
    insecure_sources = []
    unpinned_vcs = []
    missing_lock_companion = []

    normalized = [p.replace("\\", "/") for p in paths]
    lower = {p.lower() for p in normalized}

    for rel in normalized:
        p = root / rel
        try:
            text = p.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue

        if HTTP_RE.search(text):
            insecure_sources.append(rel)
        if VCS_RE.search(text):
            unpinned_vcs.append(rel)

        name = p.name.lower()
        parent = str(Path(rel).parent).replace("\\", "/").lower()
        if name == "package.json":
            if f"{parent}/package-lock.json".lstrip("./") not in lower and f"{parent}/yarn.lock".lstrip("./") not in lower and f"{parent}/pnpm-lock.yaml".lstrip("./") not in lower:
                missing_lock_companion.append(rel)
        elif name == "pubspec.yaml":
            if f"{parent}/pubspec.lock".lstrip("./") not in lower:
                missing_lock_companion.append(rel)

    return {
        "insecure_sources": sorted(set(insecure_sources)),
        "unpinned_vcs": sorted(set(unpinned_vcs)),
        "missing_lock_companion": sorted(set(missing_lock_companion)),
    }
