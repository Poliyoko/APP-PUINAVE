
from __future__ import annotations

from typing import Iterable


DEFAULT_SAFEGUARDS = (
    "cultural_authority_required_for_sensitive_content",
    "no_identity_inference",
    "no_replacement_of_community_teachers",
    "explainable_recommendations",
    "human_review_available",
)


SENSITIVE_DOMAINS = {
    "sacred",
    "restricted",
    "ceremonial",
    "community_sensitive",
}


def safeguards_for_domain(
    cultural_domain: str,
) -> tuple[str, ...]:
    safeguards = list(DEFAULT_SAFEGUARDS)
    if cultural_domain in SENSITIVE_DOMAINS:
        safeguards.extend(
            (
                "restricted_content_blocked_by_default",
                "community_authorization_required",
            )
        )
    return tuple(safeguards)


def is_domain_allowed(
    cultural_domain: str,
    permissions: Iterable[str] = (),
) -> bool:
    if cultural_domain not in SENSITIVE_DOMAINS:
        return True
    return "community_authorized" in set(permissions)
