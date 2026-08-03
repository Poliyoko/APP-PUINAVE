"""SPT-016 — Motor de Analítica del Aprendizaje."""

from .metrics import engagement, mastery, progress
from .models import (
    AnalyticsCommand,
    AnalyticsResult,
    LearningEvent,
)
from .recommendations import recommend
from .repository import LearningEventRepository
from .service import LearningAnalyticsEngine
from .trends import alerts, score_trend

__all__ = [
    "AnalyticsCommand",
    "AnalyticsResult",
    "LearningAnalyticsEngine",
    "LearningEvent",
    "LearningEventRepository",
    "alerts",
    "engagement",
    "mastery",
    "progress",
    "recommend",
    "score_trend",
]