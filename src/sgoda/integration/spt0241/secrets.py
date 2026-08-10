from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


@dataclass(frozen=True)
class SecretCandidate:
    path: str
    line: int
    detector: str
    fingerprint: str

    def to_dict(self) -> dict:
        return {
            "path": self.path,
            "line": self.line,
            "detector": self.detector,
            "fingerprint": self.fingerprint,
        }


class SecretMetadataScanner:
    """
    Conservative scanner that reports metadata/fingerprints only.
    It never returns the secret value itself.
    """

    PATTERNS = (
        ("PRIVATE_KEY_MARKER", re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")),
        ("ASSIGNED_SECRET", re.compile(
            r"(?i)\b(password|passwd|secret|api[_-]?key|token)\b\s*[:=]\s*['\"][^'\"]{8,}['\"]"
        )),
    )

    TEXT_SUFFIXES = {
        ".py", ".ps1", ".json", ".yml", ".yaml", ".toml",
        ".ini", ".cfg", ".conf", ".env", ".md", ".txt",
    }

    @staticmethod
    def _fingerprint(path: str, line_no: int, detector: str) -> str:
        import hashlib
        material = f"{path}|{line_no}|{detector}".encode("utf-8")
        return hashlib.sha256(material).hexdigest().upper()[:24]

    def scan(
        self,
        *,
        root: Path,
        paths: Iterable[Path],
        max_bytes: int = 2 * 1024 * 1024,
    ) -> list[SecretCandidate]:
        candidates: list[SecretCandidate] = []

        for path in paths:
            if path.suffix.lower() not in self.TEXT_SUFFIXES:
                continue
            try:
                if path.stat().st_size > max_bytes:
                    continue
                text = path.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue

            rel = path.relative_to(root).as_posix()
            for line_no, line in enumerate(text.splitlines(), start=1):
                for detector, pattern in self.PATTERNS:
                    if pattern.search(line):
                        candidates.append(
                            SecretCandidate(
                                path=rel,
                                line=line_no,
                                detector=detector,
                                fingerprint=self._fingerprint(rel, line_no, detector),
                            )
                        )

        return candidates
