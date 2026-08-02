"""CLI del Asistente Inteligente Institucional."""

from __future__ import annotations

import argparse
import json
from dataclasses import asdict
from pathlib import Path

from .faq import FaqRepository
from .knowledge_repository import KnowledgeRepository
from .models import ConsultaAsistente
from .service import InstitutionalAssistant


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("question")
    parser.add_argument(
        "--canonical",
        default=(
            "artifacts/rlb/SPT-001B-P08/"
            "canonical-repository-v1.0.0.json"
        ),
    )
    parser.add_argument(
        "--oda",
        default=(
            "artifacts/oda/SPT-002/"
            "oda-repository-v0.1.0.json"
        ),
    )
    parser.add_argument(
        "--faq",
        default="config/assistant/SPT-004A-faq.json",
    )
    parser.add_argument(
        "--unresolved",
        default=(
            "artifacts/assistant/SPT-004A/"
            "unresolved-questions.jsonl"
        ),
    )
    parser.add_argument(
        "--output",
        default=(
            "artifacts/assistant/SPT-004A/"
            "last-response.json"
        ),
    )
    args = parser.parse_args()

    assistant = InstitutionalAssistant(
        repository=KnowledgeRepository(
            canonical_path=args.canonical,
            oda_path=args.oda,
        ),
        faq=FaqRepository(args.faq),
        unresolved_path=args.unresolved,
    )

    response = assistant.answer(
        ConsultaAsistente(question=args.question)
    )

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(
            asdict(response),
            ensure_ascii=False,
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )

    print(response.answer)
    print(f"Intención: {response.intent}")
    print(f"Validada: {response.validated}")
    print(f"Fuentes: {len(response.sources)}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())