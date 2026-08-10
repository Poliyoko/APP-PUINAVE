from __future__ import annotations

from collections import Counter
from typing import Iterable

from .models import SecurityAsset


class AttackSurfaceModel:
    @staticmethod
    def build(assets: Iterable[SecurityAsset]) -> dict:
        assets = list(assets)
        exposed = [asset for asset in assets if asset.exposed_surface]

        return {
            "asset_count": len(assets),
            "exposed_surface_count": len(exposed),
            "criticality": dict(
                sorted(Counter(asset.criticality for asset in assets).items())
            ),
            "asset_types": dict(
                sorted(Counter(asset.asset_type for asset in assets).items())
            ),
            "exposed_assets": [
                {
                    "asset_id": asset.asset_id,
                    "path": asset.path,
                    "criticality": asset.criticality,
                    "asset_type": asset.asset_type,
                }
                for asset in exposed
            ],
        }
