"""Read-only REAL508 queue preparation using existing C2, without forged gates."""

import hashlib
import json
from dataclasses import asdict

from .catalog import CategoryCatalog
from .layer2 import Spt0233Layer2Classifier


def prepare_real508(source_view: dict, catalog: CategoryCatalog) -> dict:
    """Preserve IDs and fingerprint the effective R2 view; no semantic approval.

    SPT-023.2 results are not available for these records. Every record remains
    NOT_ELIGIBLE until a separately validated upstream integration exists.
    This prepares a queue, not certified assignments or new categories.
    """
    if source_view.get("schema") != "REAL508-R2-CONTROLLED-SOURCE-VIEW-v1.0.0":
        raise ValueError("Expected controlled REAL508 R2 view")
    records = source_view.get("records", [])
    if len(records) != 508 or {r["entry_id"] for r in records} != {f"{i:06d}" for i in range(1, 509)}:
        raise ValueError("Expected exactly 508 sequential IDs")
    canonical = json.dumps(source_view, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    fingerprint = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
    catalog_hash = hashlib.sha256(json.dumps(
        [asdict(category) for category in catalog.categories], ensure_ascii=False,
        sort_keys=True, separators=(",", ":"),
    ).encode("utf-8")).hexdigest()
    inputs = []
    for record in records:
        source = record["source_current"]
        if not source.get("puinave") or not source.get("es"):
            raise ValueError("Missing controlled source")
        source_hash = hashlib.sha256(json.dumps(source, ensure_ascii=False, sort_keys=True).encode("utf-8")).hexdigest()
        inputs.append({"source_index": int(record["entry_id"]), "puinave": source["puinave"],
                       "lexical_hash": source_hash, "institutional_decision": "NOT_ELIGIBLE",
                       "downstream_allowed": False})
    batch = Spt0233Layer2Classifier(catalog).classify_batch({"results": inputs, "source_batch_hash": fingerprint})
    for record, result in zip(records, batch["results"]):
        result["entry_id"] = record["entry_id"]
    batch.update({"preparation_status": "BLOCKED_PENDING_VALIDATED_SPT0232",
                  "catalog_sha256": catalog_hash,
                  "linguistic_certified": False, "publication_authorized": False,
                  "source_sha256_declared_not_reverified": source_view.get("source_sha256_declared_not_reverified")})
    return batch


def main() -> None:
    """Reproducible preparation; output must be separate from both inputs."""
    import argparse
    from pathlib import Path

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-view", required=True, type=Path)
    parser.add_argument("--taxonomy", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    if args.output.resolve() in {args.source_view.resolve(), args.taxonomy.resolve()}:
        parser.error("Output cannot replace an input")
    if args.output.exists():
        parser.error("Output already exists; choose a new evidence path")
    taxonomy = json.loads(args.taxonomy.read_text(encoding="utf-8"))
    catalog = CategoryCatalog([
        {"id": row["id"], "name": row["label_es"], "metadata": {
            "enabled": row["enabled"], "order": row["order"],
            "taxonomy_schema_version": taxonomy["schema_version"],
        }} for row in taxonomy["semantic_categories"] if row["enabled"] is True
    ])
    batch = prepare_real508(json.loads(args.source_view.read_text(encoding="utf-8")), catalog)
    with args.output.open("x", encoding="utf-8") as output:
        output.write(json.dumps(batch, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
