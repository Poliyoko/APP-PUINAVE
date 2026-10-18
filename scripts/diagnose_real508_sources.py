"""Inventario no destructivo de fuentes REAL508 para integración REST.

Uso: python scripts/diagnose_real508_sources.py
No lee contenido lingüístico, no modifica archivos y no publica datos.
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXCLUDED = {".git", ".venv", "venv", "node_modules", "build", ".dart_tool"}
EXTENSIONS = {".json", ".jsonl", ".csv", ".xlsx", ".xls", ".yaml", ".yml"}
TOKENS = ("real508", "real_508", "lexic", "léxic", "categor", "taxonomy", "corpus", "repositorio")
MAX_RESULTS = 150


def main() -> None:
    matches = []
    for path in ROOT.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in EXTENSIONS:
            continue
        relative = path.relative_to(ROOT)
        if any(part.lower() in EXCLUDED for part in relative.parts):
            continue
        if not any(token in str(relative).lower() for token in TOKENS):
            continue
        matches.append({"path": relative.as_posix(), "bytes": path.stat().st_size})
        if len(matches) >= MAX_RESULTS:
            break
    print(json.dumps({
        "project": "SGODA-PUINAVE",
        "mode": "read_only",
        "matched_count": len(matches),
        "truncated": len(matches) == MAX_RESULTS,
        "candidates": matches,
    }, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
