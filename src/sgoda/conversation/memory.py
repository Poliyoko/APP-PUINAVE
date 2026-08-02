from __future__ import annotations

from collections import defaultdict

from .models import ConversationMessage


class ConversationMemory:
    def __init__(self, maximum_messages: int = 20) -> None:
        self.maximum_messages = maximum_messages
        self._messages: dict[str, list[ConversationMessage]] = defaultdict(list)

    def add(
        self,
        session_id: str,
        message: ConversationMessage,
    ) -> None:
        bucket = self._messages[session_id]
        bucket.append(message)
        del bucket[:-self.maximum_messages]

    def history(
        self,
        session_id: str,
    ) -> tuple[ConversationMessage, ...]:
        return tuple(self._messages.get(session_id, []))