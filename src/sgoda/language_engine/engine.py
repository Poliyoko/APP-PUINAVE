"""Motor multilingüe local."""

from __future__ import annotations

import json
from pathlib import Path

from .diagnostic import run_diagnostic
from .licensing import approved_models
from .translation import ArgosLocalTranslator


class FreeLocalLanguageEngine:
    def __init__(
        self,
        *,
        allowlist_path: str | Path,
        models_root: str | Path,
    ) -> None:
        self.allowlist_path = Path(allowlist_path)
        self.models_root = Path(models_root)

    def diagnostic(self) -> dict:
        result = run_diagnostic(self.models_root)
        result["approved_translation_models"] = len(
            approved_models(
                self.allowlist_path,
                purpose="translation",
            )
        )
        result["approved_tts_models_en_us"] = len(
            approved_models(
                self.allowlist_path,
                purpose="tts",
                locale="en-US",
            )
        )
        result["approved_tts_models_it_it"] = len(
            approved_models(
                self.allowlist_path,
                purpose="tts",
                locale="it-IT",
            )
        )
        return result

    def translation_inventory(self) -> dict:
        pairs = ArgosLocalTranslator.available_pairs()
        return {
            "installed_pairs": [
                {"source": source, "target": target}
                for source, target in pairs
            ],
            "required_pairs": [
                {"source": "es", "target": "en"},
                {"source": "es", "target": "it"},
            ],
        }

    def publish_diagnostic(
        self,
        output_path: str | Path,
    ) -> Path:
        output = Path(output_path)
        output.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "diagnostic": self.diagnostic(),
            "translation_inventory": self.translation_inventory(),
            "policy": {
                "offline_only": True,
                "paid_services_allowed": False,
                "api_keys_required": False,
                "unknown_license_policy": "block",
            },
        }
        output.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        return output