from __future__ import annotations

import json
import re
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Any, Iterable

from .repository_discovery import DiscoveredDeliverable


class DeliverableClassification(str, Enum):
    CLOSED_VERIFIED = "CLOSED_VERIFIED"
    IMPLEMENTED_NOT_CLOSED = "IMPLEMENTED_NOT_CLOSED"
    HISTORICAL_REFERENCE = "HISTORICAL_REFERENCE"
    DOCUMENT_ONLY = "DOCUMENT_ONLY"
    UNKNOWN = "UNKNOWN"


@dataclass(frozen=True, slots=True)
class ClassificationSignals:
    strong_closure_files: tuple[str, ...] = ()
    release_paths: tuple[str, ...] = ()
    tag_names: tuple[str, ...] = ()
    evidence_paths: tuple[str, ...] = ()
    code_paths: tuple[str, ...] = ()
    test_paths: tuple[str, ...] = ()
    structured_evidence_files: tuple[str, ...] = ()


@dataclass(frozen=True, slots=True)
class ClassifiedDeliverable:
    code: str
    family: str
    classification: DeliverableClassification
    confidence: int
    reasons: tuple[str, ...]
    source_paths: tuple[str, ...]
    signals: ClassificationSignals


class DeliverableClassifier:
    """
    Deterministic institutional classifier.

    Rules:
    - reference frequency never implies closure;
    - child deliverables never close their parent implicitly;
    - textual closure requires exact code + closure term locally;
    - structured evidence may certify successful completion;
    - tags are complementary evidence, never sufficient alone.
    """

    CLOSURE_TERMS = (
        "closed",
        "cerrado",
        "cierre",
        "officially published",
        "officially closed",
        "aprobado",
        "publicado",
        "zero technical errors",
        "zero error",
    )

    POSITIVE_STRUCTURED_STATUSES = frozenset(
        {
            "ready",
            "pass",
            "passed",
            "closed",
            "approved",
            "aprobado",
            "published",
            "publicado",
            "valid",
            "validated",
            "success",
            "successful",
            "ok",
            "complete",
            "completed",
        }
    )

    STATUS_KEYS = frozenset(
        {
            "status",
            "state",
            "result",
            "gate",
            "outcome",
        }
    )

    NEGATIVE_COUNT_TOKENS = (
        "error",
        "errors",
        "missing",
        "not_ready",
        "notready",
        "invalid",
        "unexpected",
        "empty",
        "failed",
        "failure",
        "failures",
    )

    SUCCESS_COUNT_TOKENS = (
        "ready",
        "processed",
        "validated",
        "validated_records",
        "success",
        "successful",
        "passed",
        "complete",
        "completed",
    )

    def __init__(self, repository_root: str | Path) -> None:
        self.repository_root = Path(repository_root).resolve()

    @staticmethod
    def _is_release_path(path: str) -> bool:
        lower = path.lower()
        return lower.startswith("releases/") or "/releases/" in lower

    @staticmethod
    def _is_evidence_path(path: str) -> bool:
        lower = path.lower()
        return (
            lower.startswith("artifacts/")
            or "evidence" in lower
            or "evidencia" in lower
        )

    @staticmethod
    def _is_code_path(path: str) -> bool:
        lower = path.lower()
        return (
            lower.startswith("src/")
            or lower.startswith("builder/src/")
            or lower.startswith("tools/")
        )

    @staticmethod
    def _is_test_path(path: str) -> bool:
        lower = path.lower()
        return (
            lower.startswith("tests/")
            or lower.startswith("builder/tests/")
            or "/tests/" in lower
        )

    @staticmethod
    def _exact_code_pattern(code: str) -> re.Pattern[str]:
        return re.compile(
            rf"(?i)(?<![A-Za-z0-9])"
            rf"{re.escape(code)}"
            rf"(?![A-Za-z0-9.])"
        )

    @classmethod
    def _closure_pattern(cls) -> re.Pattern[str]:
        terms = "|".join(
            re.escape(term)
            for term in sorted(
                cls.CLOSURE_TERMS,
                key=len,
                reverse=True,
            )
        )

        return re.compile(
            rf"(?i)(?<![A-Za-z0-9])(?:{terms})(?![A-Za-z0-9])"
        )

    @staticmethod
    def _structured_candidate_path(path: str) -> bool:
        lower = path.lower()

        if not lower.endswith(".json"):
            return False

        return any(
            token in lower
            for token in (
                "summary",
                "manifest",
                "closure",
                "cierre",
                "publication",
                "publicacion",
                "report",
                "result",
                "evidence",
            )
        )

    def _read_text(self, path: str) -> str:
        full = self.repository_root / Path(path)

        if not full.is_file():
            return ""

        if full.stat().st_size > 10 * 1024 * 1024:
            return ""

        try:
            return full.read_text(
                encoding="utf-8",
                errors="replace",
            )
        except OSError:
            return ""

    def _path_or_content_references_code(
        self,
        path: str,
        code: str,
        text: str,
    ) -> bool:
        pattern = self._exact_code_pattern(code)

        return bool(
            pattern.search(path)
            or pattern.search(text)
        )

    def _closure_files(
        self,
        paths: Iterable[str],
        code: str,
    ) -> tuple[str, ...]:
        closure: list[str] = []

        code_pattern = self._exact_code_pattern(code)
        closure_pattern = self._closure_pattern()

        for path in paths:
            lower_path = path.lower()

            if not (
                lower_path.startswith("docs/")
                or lower_path.startswith("releases/")
                or lower_path.startswith("artifacts/")
                or lower_path.startswith("tools/")
                or "closure" in lower_path
                or "cierre" in lower_path
                or "publication" in lower_path
                or "publicacion" in lower_path
            ):
                continue

            text = self._read_text(path)

            if not text:
                continue

            for line in text.splitlines():
                if (
                    code_pattern.search(line)
                    and closure_pattern.search(line)
                ):
                    closure.append(path)
                    break

        return tuple(sorted(set(closure)))

    @classmethod
    def _scalar_status_positive(
        cls,
        key: str,
        value: Any,
    ) -> bool:
        normalized_key = key.strip().lower()

        if normalized_key not in cls.STATUS_KEYS:
            return False

        if not isinstance(value, str):
            return False

        return (
            value.strip().lower()
            in cls.POSITIVE_STRUCTURED_STATUSES
        )

    @classmethod
    def _dict_count_contract_positive(
        cls,
        value: dict[str, Any],
    ) -> bool:
        numeric: dict[str, float] = {}

        for key, candidate in value.items():
            if (
                isinstance(candidate, (int, float))
                and not isinstance(candidate, bool)
            ):
                numeric[key.strip().lower()] = float(candidate)

        if not numeric:
            return False

        negative_values = [
            number
            for key, number in numeric.items()
            if any(
                token in key
                for token in cls.NEGATIVE_COUNT_TOKENS
            )
        ]

        if any(number != 0 for number in negative_values):
            return False

        success_values = [
            number
            for key, number in numeric.items()
            if any(
                token == key
                or key.endswith("_" + token)
                or key.startswith(token + "_")
                for token in cls.SUCCESS_COUNT_TOKENS
            )
        ]

        positive_success = [
            number
            for number in success_values
            if number > 0
        ]

        if not positive_success:
            return False

        total_candidates = [
            numeric[key]
            for key in (
                "records",
                "total",
                "total_records",
                "validated_records",
                "processed",
            )
            if key in numeric
            and numeric[key] > 0
        ]

        if not total_candidates:
            return True

        reference = max(total_candidates)

        return any(
            value_number == reference
            for value_number in positive_success
        )

    @classmethod
    def _structured_object_positive(
        cls,
        value: Any,
    ) -> bool:
        if isinstance(value, dict):
            for key, child in value.items():
                if cls._scalar_status_positive(key, child):
                    return True

            if cls._dict_count_contract_positive(value):
                return True

            return any(
                cls._structured_object_positive(child)
                for child in value.values()
            )

        if isinstance(value, list):
            return any(
                cls._structured_object_positive(child)
                for child in value
            )

        return False

    def _structured_evidence_files(
        self,
        paths: Iterable[str],
        code: str,
    ) -> tuple[str, ...]:
        verified: list[str] = []

        for path in paths:
            if not self._structured_candidate_path(path):
                continue

            text = self._read_text(path)

            if not text:
                continue

            if not self._path_or_content_references_code(
                path,
                code,
                text,
            ):
                continue

            try:
                payload = json.loads(text)
            except (json.JSONDecodeError, TypeError):
                continue

            if self._structured_object_positive(payload):
                verified.append(path)

        return tuple(sorted(set(verified)))

    def classify(
        self,
        item: DiscoveredDeliverable,
        *,
        tag_names: Iterable[str] = (),
    ) -> ClassifiedDeliverable:
        paths = tuple(sorted(set(item.source_paths)))
        tags = tuple(sorted(set(tag_names)))

        closure_files = self._closure_files(
            paths,
            item.code,
        )

        structured_files = self._structured_evidence_files(
            paths,
            item.code,
        )

        release_paths = tuple(
            path
            for path in paths
            if self._is_release_path(path)
        )

        evidence_paths = tuple(
            path
            for path in paths
            if self._is_evidence_path(path)
        )

        code_paths = tuple(
            path
            for path in paths
            if self._is_code_path(path)
        )

        test_paths = tuple(
            path
            for path in paths
            if self._is_test_path(path)
        )

        reasons: list[str] = []

        if (
            closure_files
            and (
                release_paths
                or tags
            )
        ):
            classification = (
                DeliverableClassification.CLOSED_VERIFIED
            )
            confidence = 100
            reasons.append(
                "code_local_closure_plus_release_or_tag"
            )

        elif closure_files:
            classification = (
                DeliverableClassification.CLOSED_VERIFIED
            )
            confidence = 95
            reasons.append(
                "code_local_explicit_closure"
            )

        elif (
            structured_files
            and (
                release_paths
                or tags
            )
        ):
            classification = (
                DeliverableClassification.CLOSED_VERIFIED
            )
            confidence = 95
            reasons.append(
                "structured_success_plus_release_or_tag"
            )

        elif structured_files:
            classification = (
                DeliverableClassification.CLOSED_VERIFIED
            )
            confidence = 90
            reasons.append(
                "authoritative_structured_success"
            )

        elif (
            code_paths
            and test_paths
            and evidence_paths
        ):
            classification = (
                DeliverableClassification.IMPLEMENTED_NOT_CLOSED
            )
            confidence = 80
            reasons.append(
                "code_tests_evidence"
            )

        elif code_paths and test_paths:
            classification = (
                DeliverableClassification.IMPLEMENTED_NOT_CLOSED
            )
            confidence = 70
            reasons.append(
                "code_and_tests"
            )

        elif evidence_paths and not code_paths:
            classification = (
                DeliverableClassification.HISTORICAL_REFERENCE
            )
            confidence = 55
            reasons.append(
                "institutional_evidence_reference"
            )

        elif paths:
            classification = (
                DeliverableClassification.DOCUMENT_ONLY
            )
            confidence = 40
            reasons.append(
                "repository_reference_only"
            )

        else:
            classification = (
                DeliverableClassification.UNKNOWN
            )
            confidence = 0
            reasons.append(
                "no_repository_evidence"
            )

        return ClassifiedDeliverable(
            code=item.code,
            family=item.family,
            classification=classification,
            confidence=confidence,
            reasons=tuple(reasons),
            source_paths=paths,
            signals=ClassificationSignals(
                strong_closure_files=closure_files,
                release_paths=release_paths,
                tag_names=tags,
                evidence_paths=evidence_paths,
                code_paths=code_paths,
                test_paths=test_paths,
                structured_evidence_files=structured_files,
            ),
        )