from __future__ import annotations
import re
from pathlib import Path
from typing import Dict, List


class DependencyAudit:
    INSECURE_URL = re.compile(r"(?i)\bhttp://(?!localhost\b|127\.0\.0\.1\b)")
    UNPINNED_VCS = re.compile(r"(?i)(git\+https?://|github\.com/.+\.git)(?![^\s#]*@[0-9a-f]{7,40})")

    @staticmethod
    def _read(root: Path, rel: str) -> str:
        try:
            return (root / rel).read_text(encoding="utf-8", errors="replace")
        except OSError:
            return ""

    @classmethod
    def assess(cls, root: Path, paths: List[str]) -> Dict[str, object]:
        insecure_urls: List[str] = []
        unpinned_vcs: List[str] = []
        manifests: List[dict] = []

        for rel in paths:
            text = cls._read(root, rel)
            manifests.append({"path": rel, "size": len(text.encode("utf-8"))})

            if cls.INSECURE_URL.search(text):
                insecure_urls.append(rel)
            if cls.UNPINNED_VCS.search(text):
                unpinned_vcs.append(rel)

        return {
            "manifests": manifests,
            "insecure_urls": sorted(set(insecure_urls)),
            "unpinned_vcs": sorted(set(unpinned_vcs)),
        }
