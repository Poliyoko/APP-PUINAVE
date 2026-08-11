from __future__ import annotations
import hashlib
import re
from pathlib import Path
from typing import Iterable


SECRET_LOG_RE = re.compile(
    r"""(?ix)
    \b(?:print|logger\.(?:debug|info|warning|error|critical)|logging\.(?:debug|info|warning|error|critical))
    \s*\(
    [^\n]{0,240}
    \b(?:password|passwd|secret|api[_-]?key|token|client[_-]?secret)\b
    """
)

DANGEROUS_EXCEPTION_RE = re.compile(
    r"(?i)(traceback\.print_exc\(\)|exc_info\s*=\s*True)"
)


def _fingerprint(path: str, line: int, detector: str) -> str:
    material = f"{path}|{line}|{detector}".encode("utf-8")
    return hashlib.sha256(material).hexdigest()[:24].upper()


def scan_sources(root: Path, paths: Iterable[str]) -> dict:
    findings = []

    for rel in sorted(set(paths)):
        p = root / rel
        if not p.is_file():
            continue
        try:
            lines = p.read_text(encoding="utf-8", errors="replace").splitlines()
        except OSError:
            continue

        for idx, line in enumerate(lines, 1):
            if SECRET_LOG_RE.search(line):
                findings.append({
                    "path": rel.replace("\\", "/"),
                    "line": idx,
                    "detector": "SEC-LOG-SECRET",
                    "fingerprint": _fingerprint(rel, idx, "SEC-LOG-SECRET"),
                    "severity": "CRITICAL",
                    "secret_value_exposed": False,
                })

            if DANGEROUS_EXCEPTION_RE.search(line):
                findings.append({
                    "path": rel.replace("\\", "/"),
                    "line": idx,
                    "detector": "SEC-LOG-TRACE",
                    "fingerprint": _fingerprint(rel, idx, "SEC-LOG-TRACE"),
                    "severity": "WARNING",
                    "secret_value_exposed": False,
                })

    return {
        "findings": findings,
        "secret_log_findings": [f for f in findings if f["detector"] == "SEC-LOG-SECRET"],
        "trace_findings": [f for f in findings if f["detector"] == "SEC-LOG-TRACE"],
        "secret_values_exposed": False,
    }
