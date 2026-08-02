"""Resolución canónica de evidencias y releases para SGD-114D v1.0.1."""

from __future__ import annotations

import re
from pathlib import Path

from .adaptive_policy_models import ResolvedArtifact


_INCREMENT_PATTERN = re.compile(
    r"^(?P<prefix>[A-Z]+)-(?P<number>\d+)(?P<suffix>[A-Z]?)"
    r"(?:-v?(?P<version>\d+(?:\.\d+)*))?$",
    re.IGNORECASE,
)


def canonical_increment_code(value: str) -> str:
    raw = str(value or "").strip().upper()
    match = _INCREMENT_PATTERN.fullmatch(raw)

    if match is None:
        return raw

    prefix = match.group("prefix")
    number = match.group("number")
    suffix = match.group("suffix") or ""

    return f"{prefix}-{number}{suffix}"


def parent_increment_code(value: str) -> str | None:
    canonical = canonical_increment_code(value)
    match = _INCREMENT_PATTERN.fullmatch(canonical)

    if match is None:
        return None

    suffix = match.group("suffix") or ""

    if not suffix:
        return None

    return f"{match.group('prefix')}-{match.group('number')}"


def increment_family(value: str) -> tuple[str, ...]:
    canonical = canonical_increment_code(value)
    parent = parent_increment_code(canonical)

    values = [canonical]

    if parent:
        values.append(parent)

    return tuple(dict.fromkeys(values))


def _non_empty_directory(path: Path) -> bool:
    if not path.is_dir():
        return False

    return any(
        item.is_file() and item.stat().st_size > 0
        for item in path.rglob("*")
    )


def _release_version(path: Path) -> tuple[int, ...]:
    match = re.search(
        r"-v(?P<version>\d+(?:\.\d+)*)$",
        path.name,
        re.IGNORECASE,
    )

    if match is None:
        return ()

    return tuple(
        int(part)
        for part in match.group("version").split(".")
    )


def resolve_evidence_directory(
    root: str | Path,
    increment_code: str,
) -> ResolvedArtifact:
    base = Path(root).resolve()
    candidates: list[Path] = []

    for code in increment_family(increment_code):
        candidates.extend(
            [
                base / "artifacts" / "pmo" / code / "evidence",
                base / "artifacts" / "pmo" / code,
                base / "artifacts" / code / "evidence",
                base / "artifacts" / code,
            ]
        )

    unique: list[Path] = []

    for candidate in candidates:
        resolved = candidate.resolve()

        if resolved not in unique:
            unique.append(resolved)

    for candidate in unique:
        if _non_empty_directory(candidate):
            return ResolvedArtifact(
                artifact_type="evidence",
                increment_code=increment_code,
                path=candidate,
                found=True,
                strategy=(
                    "canonical"
                    if canonical_increment_code(increment_code)
                    in candidate.parts
                    else "parent_family"
                ),
                candidates=tuple(str(item) for item in unique),
            )

    return ResolvedArtifact(
        artifact_type="evidence",
        increment_code=increment_code,
        path=None,
        found=False,
        strategy="not_found",
        candidates=tuple(str(item) for item in unique),
    )


def resolve_release_directory(
    root: str | Path,
    increment_code: str,
) -> ResolvedArtifact:
    base = Path(root).resolve()
    releases = base / "releases"
    family = increment_family(increment_code)
    candidate_records: list[tuple[int, int, tuple[int, ...], Path]] = []

    if releases.is_dir():
        for family_index, code in enumerate(family):
            exact = releases / code

            if exact.exists():
                candidate_records.append(
                    (family_index, 1, (), exact.resolve())
                )

            for candidate in releases.glob(f"{code}-v*"):
                candidate_records.append(
                    (
                        family_index,
                        0,
                        _release_version(candidate),
                        candidate.resolve(),
                    )
                )

    candidate_records.sort(
        key=lambda item: (
            item[0],
            item[1],
            tuple(-value for value in item[2]),
            str(item[3]).casefold(),
        )
    )

    ordered_candidates = tuple(
        str(item[3])
        for item in candidate_records
    )

    for family_index, _, _, candidate in candidate_records:
        if _non_empty_directory(candidate):
            return ResolvedArtifact(
                artifact_type="release",
                increment_code=increment_code,
                path=candidate,
                found=True,
                strategy=(
                    "canonical_versioned"
                    if family_index == 0
                    else "parent_versioned"
                ),
                candidates=ordered_candidates,
            )

    return ResolvedArtifact(
        artifact_type="release",
        increment_code=increment_code,
        path=None,
        found=False,
        strategy="not_found_or_empty",
        candidates=ordered_candidates,
    )