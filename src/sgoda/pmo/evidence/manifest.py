from __future__ import annotations
import json
from datetime import datetime, timezone
from pathlib import Path
from .hasher import iter_files, sha256_file

def build_manifest(source: Path) -> dict:
    source=source.resolve(); base=source if source.is_dir() else source.parent
    entries=[]
    for file_path in iter_files(source):
        stat=file_path.stat()
        entries.append({
            "relative_path": file_path.resolve().relative_to(base).as_posix(),
            "size_bytes": stat.st_size,
            "sha256": sha256_file(file_path),
            "modified_at_utc": datetime.fromtimestamp(stat.st_mtime,tz=timezone.utc).isoformat(),
        })
    return {"schema":"sgoda.sems.manifest/v1",
            "generated_at_utc":datetime.now(timezone.utc).isoformat(),
            "source":source.as_posix(),"file_count":len(entries),
            "total_bytes":sum(i["size_bytes"] for i in entries),
            "hash_algorithm":"SHA-256","entries":entries}

def write_manifest(source: Path, destination: Path) -> dict:
    manifest=build_manifest(source); destination.parent.mkdir(parents=True,exist_ok=True)
    destination.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    return manifest