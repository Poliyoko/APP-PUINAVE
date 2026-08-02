"""SPT-007C — Motor de Conocimiento Lingüístico y Cultural."""

from .graph import KnowledgeGraph
from .inference import explain_inference, infer_transitive_edges
from .models import (
    InferenceStep,
    KnowledgeEdge,
    KnowledgeNode,
    KnowledgeResult,
)
from .navigation import concept_path, recommend_related
from .oda_bridge import learning_resources
from .service import KnowledgeEngineService

__all__ = [
    "InferenceStep",
    "KnowledgeEdge",
    "KnowledgeEngineService",
    "KnowledgeGraph",
    "KnowledgeNode",
    "KnowledgeResult",
    "concept_path",
    "explain_inference",
    "infer_transitive_edges",
    "learning_resources",
    "recommend_related",
]