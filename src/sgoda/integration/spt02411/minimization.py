from __future__ import annotations
from typing import Iterable


def minimize_fields(
    available_fields: Iterable[str],
    required_fields: Iterable[str],
) -> dict:
    available = list(dict.fromkeys(str(item) for item in available_fields))
    required = set(str(item) for item in required_fields)

    retained = [item for item in available if item in required]
    removed = [item for item in available if item not in required]

    return {
        "valid": set(retained) == required.intersection(available),
        "retained_fields": retained,
        "removed_fields": removed,
        "field_count_before": len(available),
        "field_count_after": len(retained),
        "minimized": len(removed) > 0,
        "data_modified_in_production": False,
        "secret_values_exposed": False,
    }
