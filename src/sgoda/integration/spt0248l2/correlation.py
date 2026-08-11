from __future__ import annotations
import hashlib
from collections import defaultdict
from typing import Iterable, Mapping


def _fingerprint(parts) -> str:
    material = "|".join(str(x) for x in parts).encode("utf-8")
    return hashlib.sha256(material).hexdigest()[:24].upper()


def correlate(events: Iterable[Mapping]) -> list:
    groups = defaultdict(list)

    for event in events:
        category = str(event.get("category", "UNKNOWN")).upper()
        source = str(event.get("source", "UNKNOWN")).lower()
        severity = str(event.get("severity", "INFO")).upper()
        groups[(category, source, severity)].append(dict(event))

    result = []
    for key in sorted(groups):
        category, source, severity = key
        records = groups[key]
        result.append({
            "correlation_id": "COR-" + _fingerprint([category, source, severity]),
            "category": category,
            "source": source,
            "severity": severity,
            "event_count": len(records),
            "fingerprint": _fingerprint([category, source, severity, len(records)]),
            "secret_values_exposed": False,
        })

    return result
