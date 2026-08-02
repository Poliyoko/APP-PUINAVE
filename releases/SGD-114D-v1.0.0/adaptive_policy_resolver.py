"""Resolución adaptativa de evidencias y releases."""

from __future__ import annotations

import re
from pathlib import Path

from .adaptive_policy_models import ResolvedArtifact


_VERSION_SUFFIX = re.compile(
    r"^(?P<code>[A-Z]+-\d+[A-Z]?)(?:-v?\d+(?:\.\d+)*)?$",
    re.IGNORECASE,
)


def canonical_increment_code(value: str) -> str:
    raw = str(value or "").strip().upper()
    match = _VERSION_SUFFIX.match(raw)
    return match.group("code") if match else raw


def increment_family(value: str) -> tuple[str, ...]:
    canonical = canonical_increment_code(value)
    family = [canonical]

    if canonical and canonical[-1].isalpha():
        family.append(canonical[:-1])

    return tuple(dict.fromkeys(item for item in family if item))


def _non_empty_directory(path: Path) -> bool:
    return path.is_dir() and any(
        item.is_file() and item.stat().st_size > 0
        for item in path.rglob("*")
    )


def resolve_evidence_directory(
    root: str | Path,
    increment_code: str,
) -> ResolvedArtifact:
    base = Path(root)
    family = increment_family(increment_code)
    candidates: list[Path] = []

    for code in family:
        candidates.extend(
            [
                base / "artifacts" / "pmo" / code / "evidence",
                base / "artifacts" / "pmo" / code,
                base / "artifacts" / code / "evidence",
                base / "artifacts" / code,
            ]
        )

    seen: set[Path] = set()

    for candidate in candidates:
        candidate = candidate.resolve()

        if candidate in seen:
            continue

        seen.add(candidate)

        if _non_empty_directory(candidate):
            strategy = (
                "canonical"
                if candidate.name == "evidence"
                else "compatible_parent"
            )

            return ResolvedArtifact(
                artifact_type="evidence",
                increment_code=increment_code,
                path=candidate,
                found=True,
                strategy=strategy,
                candidates=tuple(str(item) for item in candidates),
            )

    return ResolvedArtifact(
        artifact_type="evidence",
        increment_code=increment_code,
        path=None,
        found=False,
        strategy="not_found",
        candidates=tuple(str(item) for item in candidates),
    )


def resolve_release_directory(
    root: str | Path,
    increment_code: str,
) -> ResolvedArtifact:
    base = Path(root)
    releases = base / "releases"
    family = increment_family(increment_code)
    candidates: list[Path] = []

    if releases.is_dir():
        for code in family:
            candidates.extend(
                sorted(
                    releases.glob(f"{code}-v*"),
                    reverse=True,
                )
            )
            candidates.append(releases / code)

    for candidate in candidates:
        if _non_empty_directory(candidate):
            return ResolvedArtifact(
                artifact_type="release",
                increment_code=increment_code,
                path=candidate.resolve(),
                found=True,
                strategy="versioned_family_match",
                candidates=tuple(str(item) for item in candidates),
            )

    return ResolvedArtifact(
        artifact_type="release",
        increment_code=increment_code,
        path=None,
        found=False,
        strategy="not_found",
        candidates=tuple(str(item) for item in candidates),
    )