"""CLI de SPT-007C."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .graph import KnowledgeGraph
from .service import KnowledgeEngineService


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--graph", required=True)
    parser.add_argument("--node", required=True)
    parser.add_argument("--output")
    args = parser.parse_args()

    service = KnowledgeEngineService(
        KnowledgeGraph.from_json(args.graph)
    )
    payload = service.query(args.node)

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