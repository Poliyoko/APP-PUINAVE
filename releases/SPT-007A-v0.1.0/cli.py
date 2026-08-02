"""CLI de SPT-007A."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .repository import LexicalRepository
from .service import IntelligentLexicalService


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--rlb", required=True)
    parser.add_argument("--query", required=True)
    parser.add_argument("--limit", type=int, default=20)
    parser.add_argument(
        "--languages",
        default="pu,es,en-US,it",
    )
    parser.add_argument("--output")
    parser.add_argument(
        "--validated-only",
        action="store_true",
    )
    parser.add_argument(
        "--no-fuzzy",
        action="store_true",
    )
    args = parser.parse_args()

    repository = LexicalRepository.from_json(args.rlb)
    service = IntelligentLexicalService(repository)

    result = service.search(
        text=args.query,
        languages=tuple(
            item.strip()
            for item in args.languages.split(",")
            if item.strip()
        ),
        limit=args.limit,
        include_unvalidated=not args.validated_only,
        fuzzy=not args.no_fuzzy,
    )

    serialized = json.dumps(
        result,
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