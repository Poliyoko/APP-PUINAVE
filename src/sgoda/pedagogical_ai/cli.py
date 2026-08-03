
from __future__ import annotations

import argparse
import json
from pathlib import Path

from .models import LearnerProfile, PedagogicalContext
from .service import PedagogicalAIService


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--knowledge-storage", required=True)
    parser.add_argument(
        "--operation",
        choices=("health", "demo"),
        required=True,
    )
    parser.add_argument("--output-json", required=True)
    args = parser.parse_args()

    service = PedagogicalAIService(
        args.knowledge_storage
    )

    if args.operation == "health":
        payload = service.health()
    else:
        service.knowledge_center.ingest_dictionary_entry(
            {
                "id": "AMDA",
                "word": "AMDA",
                "meaning": "Entrada léxica demostrativa.",
                "language": "pui",
                "tags": ["diccionario", "demostración"],
            }
        )
        payload = service.recommend(
            LearnerProfile(
                learner_id="demo",
                needs=("vocabulario",),
                recent_scores=(0.60, 0.70),
            ),
            PedagogicalContext(
                objective="Aprender la palabra AMDA",
                knowledge_query="AMDA",
                cultural_domain="language",
            ),
        )

    target = Path(args.output_json)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(
        json.dumps(
            payload,
            ensure_ascii=False,
            indent=2,
        ) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(payload, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
