from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class ConversationMessage:
    role: str
    text: str
    language: str = "es"
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class ConversationRequest:
    session_id: str
    message: ConversationMessage
    context_node_id: str | None = None
    mode: str = "knowledge"


@dataclass(frozen=True, slots=True)
class ConversationResponse:
    session_id: str
    text: str
    language: str
    intent: str
    sources: tuple[str, ...]
    audio_text: str | None = None
    unresolved: bool = False
    no_invention: bool = True