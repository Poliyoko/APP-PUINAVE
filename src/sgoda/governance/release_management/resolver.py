
from __future__ import annotations

import re

from .models import ReleaseIdentity


_INCREMENT_PATTERN = re.compile(
    r"^(?P<code>(?:SGD|SPT|SPB|SPA|ADR|SIB)-[A-Z0-9.-]+?)-v(?P<version>.+)$",
    re.IGNORECASE,
)


def canonical_release_name(
    increment_code: str,
    version: str,
) -> str:
    code = str(increment_code or "").strip()
    normalized_version = str(version or "").strip()

    if not code:
        raise ValueError("increment_code is required")

    if not normalized_version:
        raise ValueError("version is required")

    if code.casefold().endswith(
        ("-v" + normalized_version).casefold()
    ):
        return code

    return f"{code}-v{normalized_version}"


def parse_release_name(name: str) -> ReleaseIdentity:
    normalized = str(name or "").strip()
    match = _INCREMENT_PATTERN.match(normalized)

    if not match:
        raise ValueError(
            f"invalid institutional release name: {name}"
        )

    code = match.group("code")
    version = match.group("version")

    return ReleaseIdentity(
        increment_code=code,
        version=version,
        release_name=canonical_release_name(
            code,
            version,
        ),
    )


def collapse_duplicate_revision(
    name: str,
) -> str:
    identity = parse_release_name(name)
    version = identity.version

    parts = version.split(".")

    if (
        len(parts) >= 2
        and parts[-1].isdigit()
        and parts[-2].isdigit()
        and parts[-1] == parts[-2]
        and "-R" in version.upper()
    ):
        version = ".".join(parts[:-1])

    return canonical_release_name(
        identity.increment_code,
        version,
    )
