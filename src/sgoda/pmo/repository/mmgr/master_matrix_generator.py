from __future__ import annotations

import csv
import json
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable

from .deliverable_classifier import ClassifiedDeliverable
from .source_traceability import DeliverableTraceability


@dataclass(frozen=True, slots=True)
class MasterMatrixRow:
    code: str
    family: str
    classification: str
    confidence: int
    reasons: tuple[str, ...]
    source_paths: tuple[str, ...]
    source_path_count: int
    tracked_source_count: int
    missing_source_count: int

    def to_dict(self) -> dict[str, object]:
        return asdict(self)


class MasterMatrixGenerator:
    """
    Deterministic exporter for the DMP Master Deliverables matrix.

    This layer does not invent progress percentages, weights or closure.
    It exports only the recertified information supplied by discovery,
    classification and traceability.
    """

    SCHEMA_VERSION = "1.0.0"

    def build_rows(
        self,
        classified: Iterable[ClassifiedDeliverable],
        traceability: Iterable[DeliverableTraceability],
    ) -> tuple[MasterMatrixRow, ...]:
        classified_by_code = {
            item.code: item
            for item in classified
        }

        trace_by_code = {
            item.code: item
            for item in traceability
        }

        codes = sorted(
            set(classified_by_code)
            | set(trace_by_code)
        )

        rows: list[MasterMatrixRow] = []

        for code in codes:
            classified_item = classified_by_code.get(code)
            trace_item = trace_by_code.get(code)

            if classified_item is None:
                raise ValueError(
                    f"Missing classification for {code}"
                )

            if trace_item is None:
                raise ValueError(
                    f"Missing traceability for {code}"
                )

            if classified_item.family != trace_item.family:
                raise ValueError(
                    f"Family mismatch for {code}"
                )

            rows.append(
                MasterMatrixRow(
                    code=code,
                    family=classified_item.family,
                    classification=classified_item.classification.value,
                    confidence=classified_item.confidence,
                    reasons=classified_item.reasons,
                    source_paths=classified_item.source_paths,
                    source_path_count=len(
                        classified_item.source_paths
                    ),
                    tracked_source_count=trace_item.tracked_source_count,
                    missing_source_count=trace_item.missing_source_count,
                )
            )

        return tuple(
            sorted(
                rows,
                key=lambda item: (
                    item.family,
                    item.code,
                ),
            )
        )

    def write_json(
        self,
        rows: Iterable[MasterMatrixRow],
        path: str | Path,
    ) -> Path:
        output = Path(path)
        output.parent.mkdir(parents=True, exist_ok=True)

        rows_tuple = tuple(rows)

        payload = {
            "schema_version": self.SCHEMA_VERSION,
            "record_count": len(rows_tuple),
            "records": [
                row.to_dict()
                for row in rows_tuple
            ],
        }

        output.write_text(
            json.dumps(
                payload,
                ensure_ascii=False,
                indent=2,
                sort_keys=True,
            )
            + "\n",
            encoding="utf-8",
            newline="\n",
        )

        return output

    def write_csv(
        self,
        rows: Iterable[MasterMatrixRow],
        path: str | Path,
    ) -> Path:
        output = Path(path)
        output.parent.mkdir(parents=True, exist_ok=True)

        fieldnames = (
            "code",
            "family",
            "classification",
            "confidence",
            "reasons",
            "source_path_count",
            "tracked_source_count",
            "missing_source_count",
            "source_paths",
        )

        with output.open(
            "w",
            encoding="utf-8",
            newline="",
        ) as handle:
            writer = csv.DictWriter(
                handle,
                fieldnames=fieldnames,
                lineterminator="\n",
            )
            writer.writeheader()

            for row in rows:
                writer.writerow(
                    {
                        "code": row.code,
                        "family": row.family,
                        "classification": row.classification,
                        "confidence": row.confidence,
                        "reasons": ";".join(row.reasons),
                        "source_path_count": row.source_path_count,
                        "tracked_source_count": row.tracked_source_count,
                        "missing_source_count": row.missing_source_count,
                        "source_paths": ";".join(row.source_paths),
                    }
                )

        return output

    def write_markdown(
        self,
        rows: Iterable[MasterMatrixRow],
        path: str | Path,
    ) -> Path:
        output = Path(path)
        output.parent.mkdir(parents=True, exist_ok=True)

        rows_tuple = tuple(rows)

        lines = [
            "# Matriz Maestra de Entregables — DMP",
            "",
            f"Registros: **{len(rows_tuple)}**",
            "",
            "| Código | Familia | Clasificación | Confianza | Fuentes | Tracked | Faltantes |",
            "|---|---|---|---:|---:|---:|---:|",
        ]

        for row in rows_tuple:
            lines.append(
                "| "
                + " | ".join(
                    (
                        row.code,
                        row.family,
                        row.classification,
                        str(row.confidence),
                        str(row.source_path_count),
                        str(row.tracked_source_count),
                        str(row.missing_source_count),
                    )
                )
                + " |"
            )

        output.write_text(
            "\n".join(lines) + "\n",
            encoding="utf-8",
            newline="\n",
        )

        return output