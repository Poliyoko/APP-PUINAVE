"""SPT-023.2 - evidencia institucional reproducible."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .persistence import (
    sha256_payload,
    write_json_atomic,
)
from .traceability import build_traceability


class Spt0232EvidenceStore:
    """Persiste resultados y manifiesto verificable de SPT-023.2."""

    def __init__(
        self,
        root: str | Path,
    ) -> None:
        self.root = Path(root)

    def persist(
        self,
        analysis: dict[str, Any],
        *,
        run_id: str | None = None,
        generated_at: str | None = None,
    ) -> dict[str, Any]:
        if run_id is None:
            run_id = uuid.uuid4().hex

        if generated_at is None:
            generated_at = datetime.now(
                timezone.utc
            ).isoformat()

        run_dir = self.root / run_id

        if run_dir.exists():
            raise FileExistsError(
                f"SPT-023.2 run already exists: {run_id}"
            )

        run_dir.mkdir(
            parents=True,
            exist_ok=False,
        )

        traceability = build_traceability(
            analysis
        )

        analysis_record = write_json_atomic(
            run_dir / "analysis.json",
            analysis,
        )

        trace_record = write_json_atomic(
            run_dir / "traceability.json",
            traceability,
        )

        manifest = {
            "schema": "sgoda.spt0232.evidence.v1",
            "component": "SPT-023.2",
            "layer": "CAPA_3",
            "run_id": run_id,
            "generated_at": generated_at,
            "source_component": traceability[
                "source_component"
            ],
            "source_batch_hash": traceability[
                "source_batch_hash"
            ],
            "analysis_sha256": analysis_record[
                "sha256"
            ],
            "traceability_sha256": trace_record[
                "sha256"
            ],
            "payload_sha256": sha256_payload(
                analysis
            ),
            "records": traceability["records"],
            "no_invention": True,
            "files": {
                "analysis": "analysis.json",
                "traceability": "traceability.json",
            },
        }

        manifest_record = write_json_atomic(
            run_dir / "manifest.json",
            manifest,
        )

        return {
            "run_id": run_id,
            "generated_at": generated_at,
            "run_dir": run_dir.as_posix(),
            "analysis": analysis_record,
            "traceability": trace_record,
            "manifest": manifest_record,
            "manifest_payload": manifest,
        }