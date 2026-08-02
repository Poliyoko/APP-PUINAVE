"""Motor adaptativo institucional SGD-114D."""

from __future__ import annotations

from pathlib import Path

from .adaptive_policy_models import AdaptivePolicyResult
from .adaptive_policy_rules import (
    evaluate_evidence_rule,
    evaluate_release_rule,
)


def evaluate_adaptive_policy(
    root: str | Path,
    increment_code: str,
) -> AdaptivePolicyResult:
    release = evaluate_release_rule(
        root,
        increment_code,
    )
    evidence = evaluate_evidence_rule(
        root,
        increment_code,
    )

    results = (release, evidence)
    approved = all(
        item.passed or not item.blocking
        for item in results
    )

    return AdaptivePolicyResult(
        increment_code=increment_code,
        approved=approved,
        exit_code=0 if approved else 2,
        results=results,
        evidence_path=(
            evidence.evidence[0]
            if evidence.evidence
            else None
        ),
        release_path=(
            release.evidence[0]
            if release.evidence
            else None
        ),
    )