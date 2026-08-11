from __future__ import annotations
import re
from pathlib import Path
from typing import Iterable, List, Dict


ACTION_RE = re.compile(r"(?m)^\s*-\s*uses:\s*([^\s#]+)")
WRITE_ALL_RE = re.compile(r"(?im)^\s*permissions:\s*write-all\s*$")
DANGEROUS_RUN_RE = re.compile(
    r"(?i)(curl\s+[^|\r\n]+\|\s*(?:bash|sh)|wget\s+[^|\r\n]+\|\s*(?:bash|sh)|"
    r"\bInvoke-Expression\b|\biex\b|\beval\s+)"
)


def audit_workflows(root: Path, paths: Iterable[str]) -> Dict[str, List[str]]:
    mutable = []
    unpinned = []
    write_all = []
    dangerous = []

    for rel in paths:
        p = root / rel
        try:
            text = p.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue

        if WRITE_ALL_RE.search(text):
            write_all.append(rel)

        for ref in ACTION_RE.findall(text):
            if "@" not in ref:
                unpinned.append(f"{rel}:{ref}")
                continue

            version = ref.rsplit("@", 1)[1]
            low = version.lower()

            if low in {"main","master","latest","head","develop","dev"}:
                mutable.append(f"{rel}:{ref}")
            elif not re.fullmatch(r"[0-9a-fA-F]{40}", version):
                unpinned.append(f"{rel}:{ref}")

        if DANGEROUS_RUN_RE.search(text):
            dangerous.append(rel)

    return {
        "mutable_action_refs": sorted(set(mutable)),
        "unpinned_action_refs": sorted(set(unpinned)),
        "write_all_permissions": sorted(set(write_all)),
        "dangerous_run_markers": sorted(set(dangerous)),
    }
