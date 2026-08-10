from __future__ import annotations

from pathlib import Path

from .models import SecurityAsset
from .policy import SecurityInventoryPolicy


class AssetClassifier:
    def __init__(self, policy: SecurityInventoryPolicy | None = None) -> None:
        self.policy = policy or SecurityInventoryPolicy.default()

    def classify(self, path: Path, *, root: Path) -> SecurityAsset:
        rel = path.relative_to(root).as_posix()
        lower = rel.lower()
        suffix = path.suffix.lower()

        if lower.endswith(".ps1"):
            asset_type = "POWERSHELL"
        elif suffix == ".py":
            asset_type = "PYTHON"
        elif suffix == ".json":
            asset_type = "JSON"
        elif suffix in {".md", ".txt"}:
            asset_type = "DOCUMENTATION"
        elif suffix in {".wav", ".mp3", ".flac", ".ogg", ".m4a"}:
            asset_type = "AUDIO"
        elif suffix in {".png", ".jpg", ".jpeg", ".webp", ".svg"}:
            asset_type = "IMAGE"
        elif suffix in {".xlsx", ".xls", ".csv"}:
            asset_type = "LEXICAL_DATA"
        else:
            asset_type = "OTHER"

        exposed = any(token in lower for token in self.policy.public_surface_tokens)

        if any(token in lower for token in self.policy.critical_path_tokens):
            criticality = "HIGH"
        elif asset_type in {"POWERSHELL", "PYTHON", "JSON", "LEXICAL_DATA"}:
            criticality = "MEDIUM"
        else:
            criticality = "LOW"

        if asset_type == "LEXICAL_DATA":
            classification = "INSTITUTIONAL_DATA"
        elif asset_type in {"AUDIO", "IMAGE"}:
            classification = "CULTURAL_RESOURCE"
        elif suffix in self.policy.sensitive_extensions:
            classification = "SENSITIVE"
        else:
            classification = "INTERNAL"

        asset_id = "AST-" + rel.replace("/", "_").replace("\\", "_").upper()

        return SecurityAsset(
            asset_id=asset_id,
            path=rel,
            asset_type=asset_type,
            criticality=criticality,
            data_classification=classification,
            exposed_surface=exposed,
            metadata={"suffix": suffix},
        )
