from __future__ import annotations
from typing import Iterable, Mapping


def validate_versions(records: Iterable[Mapping]) -> dict:
    records = list(records)
    versions = [int(item.get("version", 0)) for item in records]
    key_ids = [str(item.get("key_id", "")) for item in records]

    unique_versions = len(versions) == len(set(versions))
    positive_versions = all(version > 0 for version in versions)
    ordered = versions == sorted(versions)
    one_key = len(set(key_ids)) == 1 if key_ids else False

    return {
        "valid": bool(records) and unique_versions and positive_versions and ordered and one_key,
        "version_count": len(versions),
        "unique_versions": unique_versions,
        "positive_versions": positive_versions,
        "ordered": ordered,
        "single_key_family": one_key,
    }
