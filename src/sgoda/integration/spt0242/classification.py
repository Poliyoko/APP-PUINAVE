from __future__ import annotations

from pathlib import PurePosixPath
from typing import Iterable

from .models import SecretAssessment


class SecretCandidateClassifier:
    """
    Classifies SPT-024.1 secret candidates using metadata only.

    It never requests, loads, stores or returns the candidate secret value.
    """

    EXAMPLE_TOKENS = (
        "example",
        "sample",
        "template",
        "fixture",
        "test_",
        "_test",
        "dummy",
        "placeholder",
    )

    DOC_TOKENS = (
        "docs/",
        "readme",
        ".md",
    )

    @classmethod
    def classify_one(cls, candidate: dict) -> SecretAssessment:
        path = str(candidate.get("path") or "").replace("\\", "/")
        detector = str(candidate.get("detector") or "")
        fingerprint = str(candidate.get("fingerprint") or "")
        line = int(candidate.get("line") or 0)

        lower = path.lower()
        name = PurePosixPath(lower).name

        if any(token in lower for token in cls.EXAMPLE_TOKENS):
            classification = "LIKELY_FALSE_POSITIVE"
            severity = "INFO"
            rotate = False
            remove = False
            rationale = "Candidate is located in example/test/template context."
        elif any(token in lower for token in cls.DOC_TOKENS):
            classification = "REVIEW_REQUIRED"
            severity = "WARNING"
            rotate = False
            remove = False
            rationale = "Documentation candidate requires manual validation."
        elif detector == "PRIVATE_KEY_MARKER":
            classification = "PROBABLE_REAL_SECRET"
            severity = "CRITICAL"
            rotate = True
            remove = True
            rationale = "Private-key marker outside an example context."
        elif detector == "ASSIGNED_SECRET":
            classification = "PROBABLE_REAL_SECRET"
            severity = "ERROR"
            rotate = True
            remove = True
            rationale = "Assigned secret-like value outside an example context."
        else:
            classification = "REVIEW_REQUIRED"
            severity = "WARNING"
            rotate = False
            remove = False
            rationale = "Unknown detector requires review."

        if name.endswith((".example", ".sample", ".template")):
            classification = "LIKELY_FALSE_POSITIVE"
            severity = "INFO"
            rotate = False
            remove = False
            rationale = "Explicit example/sample/template file."

        return SecretAssessment(
            path=path,
            line=line,
            detector=detector,
            fingerprint=fingerprint,
            classification=classification,
            severity=severity,
            requires_rotation=rotate,
            requires_removal_from_git=remove,
            rationale=rationale,
        )

    @classmethod
    def classify_many(
        cls,
        candidates: Iterable[dict],
    ) -> list[SecretAssessment]:
        return [cls.classify_one(item) for item in candidates]
