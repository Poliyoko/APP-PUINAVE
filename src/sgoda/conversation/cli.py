from __future__ import annotations

import argparse
import json
from pathlib import Path

from sgoda.conversation import (
    ConversationMessage,
    ConversationRequest,
    ConversationalEcosystemService,
)
from sgoda.knowledge_engine import KnowledgeEngineService, KnowledgeGraph
from sgoda.reasoning_engine import LinguisticReasoningService
from sgoda.tutor import PuinaveTutorService


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--graph", required=True)
    parser.add_argument("--node", required=True)
    parser.add_argument("--message", required=True)
    parser.add_argument("--session", default="demo")
    parser.add_argument("--language", default="es")
    parser.add_argument("--output")
    args = parser.parse_args()

    graph = KnowledgeGraph.from_json(args.graph)

    service = ConversationalEcosystemService(
        KnowledgeEngineService(graph),
        LinguisticReasoningService(graph),
        PuinaveTutorService(graph),
    )

    response = service.converse(
        ConversationRequest(
            session_id=args.session,
            message=ConversationMessage(
                role="user",
                text=args.message,
                language=args.language,
            ),
            context_node_id=args.node,
        )
    )

    payload = {
        "session_id": response.session_id,
        "text": response.text,
        "language": response.language,
        "intent": response.intent,
        "sources": list(response.sources),
        "audio_text": response.audio_text,
        "unresolved": response.unresolved,
        "no_invention": response.no_invention,
    }

    serialized = json.dumps(
        payload,
        indent=2,
        ensure_ascii=False,
    )

    if args.output:
        target = Path(args.output)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(
            serialized + "\n",
            encoding="utf-8",
        )
    else:
        print(serialized)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())