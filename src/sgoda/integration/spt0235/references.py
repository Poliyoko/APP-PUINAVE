from __future__ import annotations

from pathlib import Path
from typing import Any


def validate_object_references(
    fld: dict[str, Any],
    oda: dict[str, Any],
    *,
    require_files: bool = False,
) -> dict[str, Any]:
    if fld.get("object_type") != "FLD":
        raise ValueError("FLD object is required.")
    if oda.get("object_type") != "ODA":
        raise ValueError("ODA object is required.")

    if fld.get("lexical_id") != oda.get("lexical_id"):
        raise ValueError("FLD/ODA lexical_id mismatch.")
    if oda.get("source_fld_sha256") != fld.get("fld_sha256"):
        raise ValueError("ODA source_fld_sha256 mismatch.")
    if oda.get("multimedia_manifest_sha256") != fld.get("multimedia_manifest_sha256"):
        raise ValueError("FLD/ODA multimedia manifest mismatch.")

    resources = dict(fld.get("resources") or {})
    if len(resources) != 5:
        raise ValueError("FLD must contain exactly five multimedia references.")

    required = {
        "image",
        "audio_puinave",
        "audio_es",
        "audio_en",
        "audio_it",
    }
    if set(resources) != required:
        raise ValueError("FLD multimedia resource set is invalid.")

    missing_files: list[str] = []
    for resource_type, item in resources.items():
        output_path = str((item or {}).get("output_path") or "").strip()
        sha256 = str((item or {}).get("sha256") or "").strip()

        if not output_path or not sha256:
            raise ValueError(f"Incomplete multimedia reference: {resource_type}")

        if require_files and not Path(output_path).is_file():
            missing_files.append(output_path)

    if missing_files:
        raise ValueError(
            "Missing referenced multimedia files: " + ", ".join(missing_files)
        )

    return {
        "lexical_id": str(fld["lexical_id"]),
        "resource_count": len(resources),
        "references_valid": True,
        "files_required": bool(require_files),
        "missing_files": missing_files,
    }
