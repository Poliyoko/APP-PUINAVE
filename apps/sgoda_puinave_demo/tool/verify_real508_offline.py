#!/usr/bin/env python3
"""Fail-closed validation of bundled REAL508 data and media."""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1] / "assets" / "real508"
def main():
    lexical = ROOT / "lexico.json"
    if not lexical.is_file():
        raise SystemExit("BLOCKED: missing real508/lexico.json")
    data = json.loads(lexical.read_text(encoding="utf-8"))
    if isinstance(data, dict):
        data = data.get("records")
    if not isinstance(data, list) or len(data) != 508:
        raise SystemExit("BLOCKED: expected 508 lexical records")
    for n, row in enumerate(data, 1):
        code = f"{n:06d}"
        if not isinstance(row, dict) or str(row.get("lexical_id")) != code:
            raise SystemExit(f"BLOCKED: invalid lexical ID {code}")
        if not str(row.get("puinave", "")).strip() or not str(row.get("spanish", "")).strip():
            raise SystemExit(f"BLOCKED: empty lexical text {code}")
        audio = ROOT / "audio" / f"PU-{code}_pu.mp3"
        if not audio.is_file() or audio.stat().st_size == 0:
            raise SystemExit(f"BLOCKED: missing/empty audio {code}")
        if n <= 30:
            image = ROOT / "images" / f"{code}.webp"
            if not image.is_file() or image.stat().st_size == 0:
                raise SystemExit(f"BLOCKED: missing/empty image {code}")
    if data[0]["puinave"].strip() != "A" or data[0]["spanish"].strip() != "Mí":
        raise SystemExit("BLOCKED: expected REAL508 first entry A / Mí")
    print("PASS: 508 lexical records, 508 audio files, 30 images")
if __name__ == "__main__":
    main()
