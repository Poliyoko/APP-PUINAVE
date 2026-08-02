"""CLI de SPT-007B."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .relations import SemanticRelationRepository
from .repository import LexicalRepository
from .search import LexicalSearchEngine
from .semantic_index import SemanticLexicalIndex
from .semantic_service import SemanticLexicalService


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--rlb", required=True)
    parser.add_argument("--relations", required=True)
    parser.add_argument("--query", required=True)
    parser.add_argument("--limit", type=int, default=20)
    parser.add_argument("--output")
    args = parser.parse_args()

    repository = LexicalRepository.from_json(args.rlb)
    relations = SemanticRelationRepository.from_json(
        args.relations
    )
    index = SemanticLexicalIndex()

    for entry in repository.all():
        variants = tuple(
            str(item)
            for item in entry.metadata.get("variants", [])
            if str(item).strip()
        )
        index.add_entry(entry, variants=variants)

    service = SemanticLexicalService(
        LexicalSearchEngine(repository),
        index,
        relations,
    )

    payload = service.to_dict(
        service.search(
            args.query,
            limit=args.limit,
        )
    )

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