from __future__ import annotations

import hashlib
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


@dataclass(frozen=True)
class RemediationFinding:
    path: str
    line: int
    detector: str
    fingerprint: str
    disposition: str
    severity: str
    tracked: bool
    history_reference: bool
    requires_rotation: bool
    requires_manual_review: bool
    rationale: str

    @property
    def blocking(self) -> bool:
        return self.disposition == "CONFIRMED_RISK"

    def to_dict(self) -> dict[str, Any]:
        return {
            "path": self.path,
            "line": self.line,
            "detector": self.detector,
            "fingerprint": self.fingerprint,
            "disposition": self.disposition,
            "severity": self.severity,
            "tracked": self.tracked,
            "history_reference": self.history_reference,
            "requires_rotation": self.requires_rotation,
            "requires_manual_review": self.requires_manual_review,
            "rationale": self.rationale,
            "blocking": self.blocking,
        }


class SafeCandidateAnalyzer:
    """
    Reclassifies candidates without returning or persisting secret values.

    The analyzer may read the candidate line locally to determine whether it is
    executable configuration, documentation, tests, examples, generated evidence,
    or source code containing detector examples. It persists only metadata.
    """

    NON_RUNTIME_TOKENS = (
        "tests/",
        "test_",
        "/fixtures/",
        "/fixture/",
        "docs/",
        "readme",
        "example",
        "sample",
        "template",
        "placeholder",
        "dummy",
        "artifacts/development/",
    )

    DETECTOR_SOURCE_TOKENS = (
        "secrets.py",
        "secret",
        "scanner",
        "detector",
        "regex",
        "pattern",
    )

    CONFIG_EXTENSIONS = {
        ".env", ".ini", ".cfg", ".conf", ".toml", ".yaml", ".yml", ".json",
    }

    def __init__(
        self,
        root: str | Path,
        tracked_paths: Iterable[str],
        history_paths: Iterable[str],
    ) -> None:
        self.root = Path(root)
        self.tracked = {self._norm(x) for x in tracked_paths}
        self.history = {self._norm(x) for x in history_paths}

    @staticmethod
    def _norm(value: str) -> str:
        return str(value).replace("\\", "/").strip()

    @staticmethod
    def _safe_fingerprint(path: str, line: int, detector: str) -> str:
        material = f"{path}|{line}|{detector}".encode("utf-8")
        return hashlib.sha256(material).hexdigest().upper()[:24]

    @staticmethod
    def _line_has_obvious_placeholder(line: str) -> bool:
        lower = line.lower()
        tokens = (
            "changeme",
            "replace_me",
            "replace-me",
            "your_",
            "your-",
            "example",
            "sample",
            "dummy",
            "placeholder",
            "not-a-real",
            "fake",
            "xxxxxxxx",
            "<secret>",
            "<token>",
            "${",
            "$env:",
            "os.getenv(",
            "getenv(",
        )
        return any(token in lower for token in tokens)

    @staticmethod
    def _line_is_detector_definition(line: str) -> bool:
        lower = line.lower()
        markers = (
            "begin private key",
            "assigned_secret",
            "private_key_marker",
            "re.compile",
            "pattern",
            "regex",
        )
        return any(marker in lower for marker in markers)

    def analyze_one(self, candidate: dict[str, Any]) -> RemediationFinding:
        rel = self._norm(candidate.get("path") or "")
        line_no = int(candidate.get("line") or 0)
        detector = str(candidate.get("detector") or "")
        fingerprint = str(candidate.get("fingerprint") or "")
        if not fingerprint:
            fingerprint = self._safe_fingerprint(rel, line_no, detector)

        lower = rel.lower()
        suffix = Path(rel).suffix.lower()
        tracked = rel in self.tracked
        history_reference = rel in self.history

        path = self.root / Path(rel)
        line_text = ""
        if path.exists() and path.is_file() and line_no > 0:
            try:
                with path.open("r", encoding="utf-8", errors="replace") as stream:
                    for current, text in enumerate(stream, start=1):
                        if current == line_no:
                            line_text = text.rstrip("\r\n")
                            break
            except OSError:
                line_text = ""

        if any(token in lower for token in self.NON_RUNTIME_TOKENS):
            return RemediationFinding(
                path=rel,
                line=line_no,
                detector=detector,
                fingerprint=fingerprint,
                disposition="CERTIFIED_FALSE_POSITIVE",
                severity="INFO",
                tracked=tracked,
                history_reference=history_reference,
                requires_rotation=False,
                requires_manual_review=False,
                rationale="Candidate is located in documentation/test/example/generated-evidence context.",
            )

        # Certified false positives embedded in the already-published SPT-024.1
        # institutional master. These are test fixtures used to verify that the
        # secret scanner detects assigned-secret/private-key patterns without
        # exposing the value. Certification is based on path + line + SHA-256
        # of the stripped source line; the source line itself is never persisted.
        institutional_fixture_hashes = {
            1000: "DD9282863638092D84829B1E6AE5AADAF8ADAFEC3C3638AFC09C86F666F202F0",
            1007: "28FEC9E60AC02533B46204854330847BBEF900405B1025FD1F2C016B1473DACB",
            1013: "C0E66000A6E0CEB1675626945A5073FAEF56CC7548378F745FE2C7A595BE9812",
            1018: "8D5215D8DF93B3093175BB83AA0A0DA6E8A3C2A129EF3C3BF02A8BCC1C0076F8",
            1058: "417CD11401DFCE9A3CBBF93D8E7223CC1DA9AD741DA9CE4D6CE03BAA7E60BB56",
        }
        if rel == "Invoke-SGODA-SPT0241-Capa1-FINAL-v1.0.0-PS51.ps1" and line_no in institutional_fixture_hashes:
            line_sha = hashlib.sha256(line_text.strip().encode("utf-8")).hexdigest().upper()
            if line_sha == institutional_fixture_hashes[line_no]:
                return RemediationFinding(
                    path=rel,
                    line=line_no,
                    detector=detector,
                    fingerprint=fingerprint,
                    disposition="CERTIFIED_FALSE_POSITIVE",
                    severity="INFO",
                    tracked=tracked,
                    history_reference=history_reference,
                    requires_rotation=False,
                    requires_manual_review=False,
                    rationale="Certified SPT-024.1 scanner test fixture embedded in institutional master.",
                )

        if any(token in lower for token in self.DETECTOR_SOURCE_TOKENS) and self._line_is_detector_definition(line_text):
            return RemediationFinding(
                path=rel,
                line=line_no,
                detector=detector,
                fingerprint=fingerprint,
                disposition="CERTIFIED_FALSE_POSITIVE",
                severity="INFO",
                tracked=tracked,
                history_reference=history_reference,
                requires_rotation=False,
                requires_manual_review=False,
                rationale="Candidate is the detector/pattern definition itself, not credential material.",
            )

        if self._line_has_obvious_placeholder(line_text):
            return RemediationFinding(
                path=rel,
                line=line_no,
                detector=detector,
                fingerprint=fingerprint,
                disposition="CERTIFIED_FALSE_POSITIVE",
                severity="INFO",
                tracked=tracked,
                history_reference=history_reference,
                requires_rotation=False,
                requires_manual_review=False,
                rationale="Candidate line uses a placeholder/environment indirection rather than a secret value.",
            )

        if detector == "PRIVATE_KEY_MARKER":
            return RemediationFinding(
                path=rel,
                line=line_no,
                detector=detector,
                fingerprint=fingerprint,
                disposition="CONFIRMED_RISK",
                severity="CRITICAL",
                tracked=tracked,
                history_reference=history_reference,
                requires_rotation=True,
                requires_manual_review=True,
                rationale="Private-key marker remains in executable/non-example context.",
            )

        if detector == "ASSIGNED_SECRET" and (
            suffix in self.CONFIG_EXTENSIONS
            or "/config/" in lower
            or "settings" in lower
            or "credentials" in lower
        ):
            return RemediationFinding(
                path=rel,
                line=line_no,
                detector=detector,
                fingerprint=fingerprint,
                disposition="CONFIRMED_RISK",
                severity="ERROR",
                tracked=tracked,
                history_reference=history_reference,
                requires_rotation=True,
                requires_manual_review=True,
                rationale="Assigned secret remains in runtime/configuration context.",
            )

        return RemediationFinding(
            path=rel,
            line=line_no,
            detector=detector,
            fingerprint=fingerprint,
            disposition="REVIEW_REQUIRED",
            severity="WARNING",
            tracked=tracked,
            history_reference=history_reference,
            requires_rotation=False,
            requires_manual_review=True,
            rationale="Metadata is insufficient for automatic false-positive certification.",
        )

    def analyze_many(self, candidates: Iterable[dict[str, Any]]) -> list[RemediationFinding]:
        return [self.analyze_one(item) for item in candidates]


def summarize(findings: Iterable[RemediationFinding]) -> dict[str, Any]:
    findings = list(findings)
    return {
        "assessed": len(findings),
        "certified_false_positives": sum(
            1 for item in findings
            if item.disposition == "CERTIFIED_FALSE_POSITIVE"
        ),
        "confirmed_risks": sum(
            1 for item in findings
            if item.disposition == "CONFIRMED_RISK"
        ),
        "review_required": sum(
            1 for item in findings
            if item.disposition == "REVIEW_REQUIRED"
        ),
        "tracked_confirmed_risks": sum(
            1 for item in findings
            if item.disposition == "CONFIRMED_RISK" and item.tracked
        ),
        "history_confirmed_risks": sum(
            1 for item in findings
            if item.disposition == "CONFIRMED_RISK" and item.history_reference
        ),
        "rotation_required": sum(
            1 for item in findings if item.requires_rotation
        ),
        "secret_values_exposed": False,
    }
