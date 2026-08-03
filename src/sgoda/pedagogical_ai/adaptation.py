
from __future__ import annotations

from statistics import mean

from .models import LearnerProfile


def infer_difficulty(profile: LearnerProfile) -> str:
    if not profile.recent_scores:
        return "initial"

    average = mean(profile.recent_scores)

    if average < 0.50:
        return "reinforcement"
    if average < 0.80:
        return "guided"
    return "challenge"


def select_strategy(profile: LearnerProfile) -> str:
    needs = {item.casefold() for item in profile.needs}

    if "pronunciation" in needs or "pronunciación" in needs:
        return "multimedia_pronunciation_practice"
    if "vocabulary" in needs or "vocabulario" in needs:
        return "contextual_lexical_practice"
    if "comprehension" in needs or "comprensión" in needs:
        return "guided_comprehension"
    return "balanced_multimodal_learning"
