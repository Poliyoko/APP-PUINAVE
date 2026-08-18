"""Strategic institutional progress policy for SGODA DMP.

Policy v1.1.0 introduces:
- functional architecture precedence over PMO/evidence paths;
- strategic architecture weights summing exactly 100;
- zero strategic weight for historical-only records;
- proportional distribution of each architecture budget;
- deterministic phase, progress and pending-for-closure rules.

The mathematical engine remains in progress_metrics.py and is unchanged.
"""

from __future__ import annotations

from dataclasses import dataclass, replace
from pathlib import PurePosixPath
from typing import Iterable, Sequence

from .progress_metrics import ProgressInput


POLICY_VERSION = "1.1.0"

INSTITUTIONAL_ARCHITECTURES = (
    "Nucleo",
    "Builder",
    "CCP",
    "API",
    "ODA",
    "Multimedia",
    "Mobile",
    "Portal Web",
    "IA",
    "DMP",
)

ARCHITECTURE_WEIGHTS = {
    "Nucleo": 18.0,
    "Builder": 10.0,
    "CCP": 8.0,
    "API": 10.0,
    "ODA": 10.0,
    "Multimedia": 12.0,
    "Mobile": 8.0,
    "Portal Web": 8.0,
    "IA": 8.0,
    "DMP": 8.0,
}

if round(sum(ARCHITECTURE_WEIGHTS.values()), 10) != 100.0:
    raise RuntimeError(
        "Architecture weights must total exactly 100."
    )


CLASSIFICATION_PROGRESS = {
    "CLOSED_VERIFIED": 100.0,
    "IMPLEMENTED_NOT_CLOSED": 80.0,
    "DOCUMENT_ONLY": 25.0,
    "HISTORICAL_REFERENCE": 0.0,
    "UNKNOWN": 0.0,
}


PENDING_BY_CLASSIFICATION = {
    "CLOSED_VERIFIED": "",
    "IMPLEMENTED_NOT_CLOSED": (
        "Formal institutional closure/publication pending"
    ),
    "DOCUMENT_ONLY": (
        "Implementation, evidence and institutional closure pending"
    ),
    "HISTORICAL_REFERENCE": (
        "Historical reference; excluded from strategic progress weight"
    ),
    "UNKNOWN": (
        "Insufficient evidence; institutional review required"
    ),
}


# Functional paths are evaluated before governance/evidence paths.
FUNCTIONAL_KEYWORDS = {
    "Builder": (
        "/builder/",
        "builder/src/",
        "builder/tests/",
        "spb-",
    ),
    "CCP": (
        "/ccp/",
        "centro_conocimiento",
        "centro-conocimiento",
        "knowledge_center",
        "knowledge-centre",
    ),
    "API": (
        "/api/",
        "/routers/",
        "/routes/",
        "fastapi",
        "openapi",
        "endpoint",
    ),
    "ODA": (
        "/oda/",
        "objeto_digital",
        "objeto-digital",
        "learning_object",
        "learning-object",
    ),
    "Multimedia": (
        "/multimedia/",
        "audio_manager",
        "audio-manager",
        "/audio/",
        "/images/",
        "/imagenes/",
        "/media/",
        "tts",
        ".wav",
        ".mp3",
    ),
    "Mobile": (
        "/mobile/",
        "/flutter/",
        "android",
        "/ios/",
        ".dart",
    ),
    "Portal Web": (
        "/visible/",
        "/portal/",
        "/frontend/",
        "/web/",
        "sgoda-visible",
    ),
    "IA": (
        "/ia/",
        "/ai/",
        "intelligent",
        "inteligente",
        "semantic",
        "semant",
        "machine_learning",
        "machine-learning",
    ),
    "Nucleo": (
        "/core/",
        "src/sgoda/core/",
        "/engine/",
        "/platform/",
        "motor_",
        "motor-",
    ),
}


GOVERNANCE_KEYWORDS = (
    "/pmo/",
    "/audit/",
    "/auditor/",
    "/dashboard/",
    "/metrics/",
    "/traceability/",
    "/trazabilidad/",
    "/mmgr/",
    "estado_maestro",
    "estado-maestro",
    "master-deliverable",
    "master_deliverable",
)


EVIDENCE_PREFIXES = (
    "artifacts/",
    "releases/",
    "docs/",
)


@dataclass(frozen=True)
class PolicyDecision:
    code: str
    family: str
    classification: str
    phase: str
    architecture: str
    weight: float
    individual_progress: float
    pending_for_closure: str
    architecture_score: int
    architecture_basis: str
    policy_version: str = POLICY_VERSION


def classification_progress(classification: str) -> float:
    return CLASSIFICATION_PROGRESS.get(
        classification,
        0.0,
    )


def pending_for_closure(classification: str) -> str:
    return PENDING_BY_CLASSIFICATION.get(
        classification,
        PENDING_BY_CLASSIFICATION["UNKNOWN"],
    )


def phase_for_family(family: str) -> str:
    normalized = family.strip().upper()

    if normalized in {"ADR", "SGD"}:
        return "Gobierno Institucional"

    if normalized == "SPB":
        return "Construccion Base"

    if normalized in {
        "SPT",
        "REAL",
        "AUDIO",
        "VISIBLE",
    }:
        return "Fase Tecnologica"

    return "Sin Asignar"


def _normalize_paths(
    source_paths: Iterable[str],
) -> tuple[str, ...]:
    return tuple(
        str(PurePosixPath(path))
        .replace("\\", "/")
        .lower()
        for path in source_paths
    )


def _functional_scores(
    paths: Sequence[str],
) -> dict[str, int]:
    scores = {
        architecture: 0
        for architecture in INSTITUTIONAL_ARCHITECTURES
    }

    for path in paths:

        # Evidence/documentation is useful, but receives less
        # architectural authority than implementation paths.
        is_evidence = path.startswith(EVIDENCE_PREFIXES)

        multiplier = 1 if is_evidence else 4

        for architecture, keywords in FUNCTIONAL_KEYWORDS.items():
            for keyword in keywords:
                if keyword in path:
                    scores[architecture] += multiplier

    return scores


def _infer_architecture_detailed(
    source_paths: Iterable[str],
    *,
    family: str,
) -> tuple[str, int, str]:

    paths = _normalize_paths(source_paths)
    scores = _functional_scores(paths)

    normalized_family = family.strip().upper()

    # Family-specific deterministic signals.
    if normalized_family == "SPB":
        scores["Builder"] += 2

    if normalized_family == "AUDIO":
        scores["Multimedia"] += 15

    if normalized_family == "VISIBLE":
        scores["Portal Web"] += 15

    # DMP is selected only when governance signals exist
    # and no stronger functional architecture wins.
    governance_score = 0

    for path in paths:
        for keyword in GOVERNANCE_KEYWORDS:
            if keyword in path:
                governance_score += 1

    maximum_functional = max(scores.values())

    if maximum_functional > 0:
        winners = sorted(
            architecture
            for architecture, score in scores.items()
            if score == maximum_functional
        )

        return (
            winners[0],
            maximum_functional,
            "FUNCTIONAL",
        )

    if governance_score > 0:
        return (
            "DMP",
            governance_score,
            "GOVERNANCE",
        )

    # ADR and SGD are governance-oriented only in the absence
    # of any functional evidence.
    if normalized_family in {"ADR", "SGD"}:
        return (
            "DMP",
            1,
            "FAMILY_GOVERNANCE",
        )

    # Neutral fallback for genuinely unresolved records.
    return (
        "Nucleo",
        0,
        "UNRESOLVED",
    )




def _infer_interface_architecture_r2(source_paths):
    """Return a strong interface architecture signal.

    R2 intentionally requires direct implementation-oriented evidence.
    Generic mentions of Flutter, mobile, web or frontend are not enough
    to override an existing architectural classification.
    """

    normalized = tuple(
        str(path).replace("\\", "/").lower()
        for path in (source_paths or ())
    )

    mobile_score = 0
    web_score = 0

    for path in normalized:

        # Strong Mobile evidence.
        if "/flutter/" in path:
            mobile_score += 12

        if "/mobile/" in path:
            mobile_score += 12

        if "/android/" in path or "/ios/" in path:
            mobile_score += 12

        if "flutter_contract" in path:
            mobile_score += 10

        if "flutter-client" in path:
            mobile_score += 10

        if "flutter_client" in path:
            mobile_score += 10

        if path.endswith("flutter-identity.json"):
            mobile_score += 10

        # Strong Portal Web evidence.
        if "/portal_web/" in path or "/portal-web/" in path:
            web_score += 12

        if "/web_portal/" in path or "/web-portal/" in path:
            web_score += 12

        if "/frontend/" in path:
            web_score += 10

        if path.endswith("web-identity.json"):
            web_score += 10

        # Weak references deliberately receive no productive score.
        # This prevents documentation that merely mentions Flutter,
        # mobile, web or frontend from stealing another architecture.

    if mobile_score == 0 and web_score == 0:
        return None, 0

    if mobile_score > web_score:
        return "Mobile", mobile_score

    if web_score > mobile_score:
        return "Portal Web", web_score

    # Equal strong evidence is intentionally unresolved at this layer.
    return None, 0

def infer_architecture(
    source_paths: Iterable[str],
    *,
    family: str,
) -> tuple[str, int]:
    interface_architecture, interface_score = _infer_interface_architecture_r2(source_paths)
    if interface_architecture is not None:
        return interface_architecture, interface_score

    """Backward-compatible public architecture API.

    Detailed architecture basis remains an internal policy concern.
    """
    architecture, score, _basis = _infer_architecture_detailed(
        source_paths,
        family=family,
    )
    return architecture, score

def decide(
    *,
    code: str,
    family: str,
    classification: str,
    source_paths: Iterable[str],
    weight: float = 1.0,
) -> PolicyDecision:

    source_paths = tuple(source_paths or ())

    interface_architecture, interface_score = (
        _infer_interface_architecture_r2(source_paths)
    )

    if interface_architecture is not None:
        architecture = interface_architecture
        score = interface_score
        basis = "FUNCTIONAL"
    else:
        architecture, score, basis = _infer_architecture_detailed(
            source_paths,
            family=family,
        )

    return PolicyDecision(
        code=code,
        family=family,
        classification=classification,
        phase=phase_for_family(family),
        architecture=architecture,
        weight=float(weight),
        individual_progress=classification_progress(
            classification
        ),
        pending_for_closure=pending_for_closure(
            classification
        ),
        architecture_score=score,
        architecture_basis=basis,
    )


def assign_strategic_weights(
    decisions: Iterable[PolicyDecision],
) -> tuple[PolicyDecision, ...]:
    """Distribute each architecture budget among active records.

    Historical references and unknown records receive zero strategic weight.
    Architecture budgets remain fixed and sum to 100.
    """

    values = tuple(decisions)

    active_by_architecture: dict[str, list[PolicyDecision]] = {
        architecture: []
        for architecture in INSTITUTIONAL_ARCHITECTURES
    }

    for decision in values:
        if decision.classification in {
            "HISTORICAL_REFERENCE",
            "UNKNOWN",
        }:
            continue

        active_by_architecture[
            decision.architecture
        ].append(decision)

    per_record_weight: dict[str, float] = {}

    for architecture in INSTITUTIONAL_ARCHITECTURES:
        active = active_by_architecture[architecture]

        if not active:
            continue

        architecture_budget = (
            ARCHITECTURE_WEIGHTS[architecture]
        )

        weight = architecture_budget / len(active)

        for decision in active:
            per_record_weight[decision.code] = weight

    weighted: list[PolicyDecision] = []

    for decision in values:
        weighted.append(
            replace(
                decision,
                weight=per_record_weight.get(
                    decision.code,
                    0.0,
                ),
            )
        )

    return tuple(weighted)


def to_progress_input(
    decision: PolicyDecision,
) -> ProgressInput:
    return ProgressInput(
        code=decision.code,
        classification=decision.classification,
        family=decision.family,
        phase=decision.phase,
        architecture=decision.architecture,
        weight=decision.weight,
        individual_progress=decision.individual_progress,
        pending_for_closure=decision.pending_for_closure,
    )
def calculate_strategic_architecture_progress(decisions):
    """Calculate project progress against the full 100-point architecture budget.

    Every institutional architecture remains in the denominator.
    Architectures without active deliverables have 0 percent progress,
    rather than disappearing from the project calculation.
    """

    values = tuple(decisions)

    architecture_progress = {}
    weighted_total = 0.0

    for architecture in INSTITUTIONAL_ARCHITECTURES:
        active = tuple(
            decision
            for decision in values
            if (
                decision.architecture == architecture
                and decision.classification
                not in {
                    "HISTORICAL_REFERENCE",
                    "UNKNOWN",
                }
            )
        )

        if active:
            progress = (
                sum(
                    decision.individual_progress
                    for decision in active
                )
                / len(active)
            )
        else:
            progress = 0.0

        budget = float(
            ARCHITECTURE_WEIGHTS[architecture]
        )

        contribution = (
            budget * progress / 100.0
        )

        weighted_total += contribution

        architecture_progress[architecture] = {
            "weight": budget,
            "deliverables": len(active),
            "progress": progress,
            "weighted_contribution": contribution,
        }

    total_budget = sum(
        float(value)
        for value in ARCHITECTURE_WEIGHTS.values()
    )

    if round(total_budget, 10) != 100.0:
        raise ValueError(
            "Strategic architecture budget must equal 100."
        )

    return {
        "total_weight": total_budget,
        "global_progress": weighted_total,
        "by_architecture": architecture_progress,
    }